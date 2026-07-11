"""Tests for the Chart Analysis feature: the pure prompt-assembly function
in services/analysis.py, and the /chart/analysis endpoint's wiring (chart
computation -> prompt -> AI call). The actual Anthropic call is monkeypatched
throughout, matching the project's convention of not hitting a real AI
provider from the test suite (see services/synthesis.py, left untested for
the same reason) -- everything short of the network call is fully tested.
"""
from fastapi.testclient import TestClient

from app.main import app
from app.services import analysis

client = TestClient(app)

_NATAL_PAYLOAD = {
    "date": "1990-06-15",
    "time": "14:30",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "tz_offset": -3.0,
}


# ---------------------------------------------------------------------------
# build_analysis_prompt (pure function, no network)
# ---------------------------------------------------------------------------


def _planet(name="Venus", sign="Taurus", house=2, dignities=None, orientation="Oriental"):
    return {"name": name, "sign": sign, "house": house, "dignities": dignities or [], "orientation": orientation}


def _base_kwargs(**overrides):
    kwargs = dict(
        ascendant_sign="Leo",
        midheaven_sign="Taurus",
        season="Summer",
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


def test_prompt_includes_all_header_fields():
    prompt = analysis.build_analysis_prompt(**_base_kwargs())
    assert "Ascendant: Leo" in prompt
    assert "Midheaven: Taurus" in prompt
    assert "Season of birth: Summer" in prompt
    assert "Sect: Diurnal" in prompt
    assert "Temperament: Choleric" in prompt


def test_prompt_formats_a_planet_line_with_dignity_and_orientation():
    prompt = analysis.build_analysis_prompt(
        **_base_kwargs(planets=[_planet(dignities=["domicile"], orientation="Occidental")])
    )
    assert "Venus — Taurus — House 2 — Domicile — Occidental" in prompt


def test_prompt_labels_a_planet_with_no_dignity_as_peregrine():
    prompt = analysis.build_analysis_prompt(**_base_kwargs(planets=[_planet(dignities=[])]))
    assert "Peregrine" in prompt


def test_prompt_uses_traditional_glyphs_for_aspects():
    prompt = analysis.build_analysis_prompt(
        **_base_kwargs(aspects=[{"planet_a": "Sun", "planet_b": "Moon", "aspect": "square", "orb": 1.0}])
    )
    assert "Sun □ Moon — orb 1.0°" in prompt


def test_prompt_falls_back_to_none_within_orb_when_no_aspects():
    prompt = analysis.build_analysis_prompt(**_base_kwargs(aspects=[]))
    assert "None within orb." in prompt


def test_prompt_includes_house_lords_and_lots():
    prompt = analysis.build_analysis_prompt(**_base_kwargs())
    assert "House 1 — Lord: Sun — in House 5" in prompt
    assert "Lot of Fortune: Cancer — House 12" in prompt
    assert "Lot of Spirit: Capricorn — House 6" in prompt


def test_prompt_asks_for_the_five_traditional_sections():
    prompt = analysis.build_analysis_prompt(**_base_kwargs())
    for phrase in [
        "overall chart signature",
        "dominant planets",
        "natural strength",
        "challenge or difficulty",
        "fundamental nature",
    ]:
        assert phrase in prompt


# ---------------------------------------------------------------------------
# /chart/analysis endpoint (AI call monkeypatched)
# ---------------------------------------------------------------------------


def test_analysis_endpoint_returns_the_generated_text(monkeypatch):
    captured_prompt = {}

    def fake_generate(prompt: str) -> str:
        captured_prompt["value"] = prompt
        return "A fake but specific reading of this nativity."

    monkeypatch.setattr(analysis, "generate_analysis", fake_generate)

    response = client.post("/api/v1/chart/analysis", json=_NATAL_PAYLOAD)
    assert response.status_code == 200
    assert response.json()["analysis"] == "A fake but specific reading of this nativity."
    # The prompt actually reached the AI call with real chart data baked in,
    # not a stub -- confirms the endpoint's computation -> prompt wiring.
    assert "Ascendant:" in captured_prompt["value"]
    assert "Sun " in captured_prompt["value"] or "Sun —" in captured_prompt["value"]


def test_analysis_endpoint_surfaces_ai_failure_as_503(monkeypatch):
    def fake_generate(prompt: str) -> str:
        raise analysis.AnalysisError("ANTHROPIC_API_KEY is not configured")

    monkeypatch.setattr(analysis, "generate_analysis", fake_generate)

    response = client.post("/api/v1/chart/analysis", json=_NATAL_PAYLOAD)
    assert response.status_code == 503


def test_analysis_endpoint_orientality_is_never_set_for_the_sun(monkeypatch):
    captured_prompt = {}

    def fake_generate(prompt: str) -> str:
        captured_prompt["value"] = prompt
        return "ok"

    monkeypatch.setattr(analysis, "generate_analysis", fake_generate)
    client.post("/api/v1/chart/analysis", json=_NATAL_PAYLOAD)

    sun_line = next(line for line in captured_prompt["value"].splitlines() if line.startswith("Sun —"))
    orientation_field = sun_line.split(" — ")[-1]
    assert orientation_field == "—"
