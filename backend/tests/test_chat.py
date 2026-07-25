"""Tests for the astrologer chat feature: the pure prompt-assembly function
in services/chat.py, and the /chat/astrologer endpoint's wiring (chart
computation -> context -> AI call). The actual Anthropic call is
monkeypatched throughout, matching the project's convention (see
test_analysis.py) of not hitting a real AI provider from the test suite.
"""
from fastapi.testclient import TestClient

from app.main import app
from app.services import chat, rate_limit

client = TestClient(app)

_NATAL_PAYLOAD = {
    "date": "1990-06-15",
    "time": "14:30",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "tz_offset": -3.0,
}


# ---------------------------------------------------------------------------
# build_chart_context (pure function, no network)
# ---------------------------------------------------------------------------


def _planet(name="Venus", sign="Taurus", house=2, dignities=None):
    return {"name": name, "sign": sign, "house": house, "dignities": dignities or []}


def _base_kwargs(**overrides):
    kwargs = dict(
        ascendant_sign="Leo",
        midheaven_sign="Taurus",
        sect="Diurnal",
        temperament_label="Choleric",
        planets=[_planet()],
        house_lord_lines=["House 1 — Lord: Sun — in House 5"],
        aspects=[{"planet_a": "Venus", "planet_b": "Mars", "aspect": "trine", "orb": 2.345}],
        fortune_sign="Cancer",
        fortune_house=12,
        spirit_sign="Capricorn",
        spirit_house=6,
    )
    kwargs.update(overrides)
    return kwargs


def test_context_includes_all_header_fields():
    context = chat.build_chart_context(**_base_kwargs())
    assert "Ascendant: Leo" in context
    assert "Midheaven: Taurus" in context
    assert "Sect: Diurnal" in context
    assert "Temperament: Choleric" in context


def test_context_formats_a_planet_line_with_dignity():
    context = chat.build_chart_context(**_base_kwargs(planets=[_planet(dignities=["domicile"])]))
    assert "Venus — Taurus — House 2 — Domicile" in context


def test_context_labels_a_planet_with_no_dignity_as_peregrine():
    context = chat.build_chart_context(**_base_kwargs(planets=[_planet(dignities=[])]))
    assert "Peregrine" in context


def test_context_uses_traditional_glyphs_for_aspects():
    context = chat.build_chart_context(
        **_base_kwargs(aspects=[{"planet_a": "Sun", "planet_b": "Moon", "aspect": "square", "orb": 1.0}])
    )
    assert "Sun □ Moon — orb 1.0°" in context


def test_context_falls_back_to_none_within_orb_when_no_aspects():
    context = chat.build_chart_context(**_base_kwargs(aspects=[]))
    assert "None within orb." in context


# ---------------------------------------------------------------------------
# /chat/astrologer endpoint (AI call monkeypatched)
# ---------------------------------------------------------------------------


def test_chat_endpoint_returns_the_generated_reply(monkeypatch):
    captured = {}

    def fake_generate(chart_context: str, messages: list[dict]) -> str:
        captured["context"] = chart_context
        captured["messages"] = messages
        return "Your chart shows a diurnal nativity ruled by the Sun."

    monkeypatch.setattr(chat, "generate_chat_reply", fake_generate)

    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "user", "content": "What is my sect?"}]}
    response = client.post("/api/v1/chat/astrologer", json=payload)

    assert response.status_code == 200
    assert response.json()["reply"] == "Your chart shows a diurnal nativity ruled by the Sun."
    # The chart context actually reached the AI call with real data baked in,
    # and the conversation history was passed through untouched.
    assert "Ascendant:" in captured["context"]
    assert captured["messages"] == [{"role": "user", "content": "What is my sect?"}]


def test_chat_endpoint_carries_multi_turn_history_through(monkeypatch):
    captured = {}

    def fake_generate(chart_context: str, messages: list[dict]) -> str:
        captured["messages"] = messages
        return "ok"

    monkeypatch.setattr(chat, "generate_chat_reply", fake_generate)

    payload = {
        **_NATAL_PAYLOAD,
        "messages": [
            {"role": "user", "content": "What is my sect?"},
            {"role": "assistant", "content": "Yours is a diurnal chart."},
            {"role": "user", "content": "What does that mean for my temperament?"},
        ],
    }
    response = client.post("/api/v1/chat/astrologer", json=payload)

    assert response.status_code == 200
    assert len(captured["messages"]) == 3
    assert captured["messages"][-1] == {"role": "user", "content": "What does that mean for my temperament?"}


def test_chat_endpoint_surfaces_ai_failure_as_503(monkeypatch):
    def fake_generate(chart_context: str, messages: list[dict]) -> str:
        raise chat.ChatError("ANTHROPIC_API_KEY is not configured")

    monkeypatch.setattr(chat, "generate_chat_reply", fake_generate)

    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "user", "content": "Hello"}]}
    response = client.post("/api/v1/chat/astrologer", json=payload)
    assert response.status_code == 503


def test_chat_endpoint_rejects_when_rate_limited(monkeypatch):
    monkeypatch.setattr(rate_limit, "check_and_consume", lambda user_id: False)
    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "user", "content": "Hello"}], "user_id": "some-user"}
    response = client.post("/api/v1/chat/astrologer", json=payload)
    assert response.status_code == 429
    assert response.json()["detail"] == rate_limit.LIMIT_MESSAGE


def test_chat_endpoint_rejects_empty_message_history():
    payload = {**_NATAL_PAYLOAD, "messages": []}
    response = client.post("/api/v1/chat/astrologer", json=payload)
    assert response.status_code == 422


def test_chat_endpoint_rejects_invalid_role():
    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "system", "content": "Hello"}]}
    response = client.post("/api/v1/chat/astrologer", json=payload)
    assert response.status_code == 422
