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

    def fake_generate(chart_context: str, messages: list[dict], depth: str = "standard") -> str:
        captured["context"] = chart_context
        captured["messages"] = messages
        captured["depth"] = depth
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
    assert captured["depth"] == "standard"


def test_chat_endpoint_carries_multi_turn_history_through(monkeypatch):
    captured = {}

    def fake_generate(chart_context: str, messages: list[dict], depth: str = "standard") -> str:
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
    def fake_generate(chart_context: str, messages: list[dict], depth: str = "standard") -> str:
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


# ---------------------------------------------------------------------------
# depth / response register
# ---------------------------------------------------------------------------


def test_chat_endpoint_passes_depth_through_to_generate_chat_reply(monkeypatch):
    captured = {}

    def fake_generate(chart_context: str, messages: list[dict], depth: str = "standard") -> str:
        captured["depth"] = depth
        return "ok"

    monkeypatch.setattr(chat, "generate_chat_reply", fake_generate)

    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "user", "content": "Hello"}], "depth": "traditional"}
    response = client.post("/api/v1/chat/astrologer", json=payload)

    assert response.status_code == 200
    assert captured["depth"] == "traditional"


def test_chat_endpoint_defaults_depth_to_standard_when_omitted(monkeypatch):
    captured = {}

    def fake_generate(chart_context: str, messages: list[dict], depth: str = "standard") -> str:
        captured["depth"] = depth
        return "ok"

    monkeypatch.setattr(chat, "generate_chat_reply", fake_generate)

    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "user", "content": "Hello"}]}
    response = client.post("/api/v1/chat/astrologer", json=payload)

    assert response.status_code == 200
    assert captured["depth"] == "standard"


def test_chat_endpoint_rejects_an_unrecognized_depth():
    payload = {**_NATAL_PAYLOAD, "messages": [{"role": "user", "content": "Hello"}], "depth": "expert"}
    response = client.post("/api/v1/chat/astrologer", json=payload)
    assert response.status_code == 422


class _FakeMessages:
    """Stands in for Anthropic's `client.messages`, capturing the kwargs
    generate_chat_reply actually sent instead of hitting the network --
    mirrors the module's own `response.content[i].type == "text"` shape."""

    def __init__(self, captured: dict):
        self._captured = captured

    def create(self, **kwargs):
        self._captured.update(kwargs)
        block = type("Block", (), {"type": "text", "text": "ok"})()
        return type("Response", (), {"content": [block]})()


class _FakeAnthropic:
    def __init__(self, captured: dict):
        self.messages = _FakeMessages(captured)


def _capture_system_prompt(monkeypatch, depth: str | None) -> str:
    captured: dict = {}
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
    monkeypatch.setattr(chat, "Anthropic", lambda api_key=None: _FakeAnthropic(captured))
    kwargs = {} if depth is None else {"depth": depth}
    chat.generate_chat_reply("CONTEXT", [{"role": "user", "content": "hi"}], **kwargs)
    return captured["system"]


def test_generate_chat_reply_standard_depth_leaves_the_prompt_unchanged(monkeypatch):
    # No `depth` argument at all -- the exact call shape every caller used
    # before `depth` existed -- must produce the exact prompt it always did.
    system = _capture_system_prompt(monkeypatch, None)
    assert system == f"{chat.SYSTEM_PROMPT}\n\nContext:\nCONTEXT"


def test_generate_chat_reply_explicit_standard_depth_also_leaves_the_prompt_unchanged(monkeypatch):
    system = _capture_system_prompt(monkeypatch, "standard")
    assert system == f"{chat.SYSTEM_PROMPT}\n\nContext:\nCONTEXT"


def test_generate_chat_reply_plain_depth_appends_the_plain_register_block(monkeypatch):
    system = _capture_system_prompt(monkeypatch, "plain")
    assert system == f"{chat.SYSTEM_PROMPT}\n\nContext:\nCONTEXT\n\n{chat.REGISTER_BLOCKS['plain']}"


def test_generate_chat_reply_traditional_depth_appends_the_traditional_register_block(monkeypatch):
    system = _capture_system_prompt(monkeypatch, "traditional")
    assert system == f"{chat.SYSTEM_PROMPT}\n\nContext:\nCONTEXT\n\n{chat.REGISTER_BLOCKS['traditional']}"


def test_generate_chat_reply_unrecognized_depth_falls_back_to_no_register_block(monkeypatch):
    # Defensive only -- the schema's pattern already rejects this before it
    # reaches here, but generate_chat_reply shouldn't crash if it ever did.
    system = _capture_system_prompt(monkeypatch, "bogus")
    assert system == f"{chat.SYSTEM_PROMPT}\n\nContext:\nCONTEXT"
