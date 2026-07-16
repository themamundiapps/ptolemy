"""Tests for the Synastry feature: the ephemeris inter-aspect finder, the
prompt-assembly function in services/synastry.py, and the /chart/synastry
endpoint's wiring (two natal computations -> overlays/aspects -> prompt ->
AI call). The Anthropic call is monkeypatched throughout, matching the
project's convention (see test_analysis.py)."""
from fastapi.testclient import TestClient

from app.main import app
from app.services import ephemeris, rate_limit, synastry

client = TestClient(app)

_PERSON_A = {
    "name": "Alex",
    "date": "1990-06-15",
    "time": "14:30",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "tz_offset": -3.0,
}

_PERSON_B = {
    "name": "Sam",
    "date": "1988-11-02",
    "time": "08:15",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "tz_offset": -5.0,
}


# ---------------------------------------------------------------------------
# find_synastry_aspects (pure function, no network)
# ---------------------------------------------------------------------------


def test_synastry_orbs_cover_all_seven_classical_planets():
    assert set(ephemeris.SYNASTRY_ASPECT_ORBS.keys()) == set(ephemeris.CLASSICAL_PLANETS.keys())


def test_find_synastry_aspects_checks_all_49_combinations():
    # Every chart-A body at 0 deg, every chart-B body at 40 deg: a flat 40 deg
    # separation for all 49 pairs, more than 8 deg (the widest possible
    # averaged orb) from the nearest major aspect angle (0 or 60) -- proves
    # every one of the 7x7 pairs was actually evaluated and correctly found
    # nothing, not skipped.
    longitudes_a = {name: 0.0 for name in ephemeris.CLASSICAL_PLANETS}
    longitudes_b = {name: 40.0 for name in ephemeris.CLASSICAL_PLANETS}
    assert ephemeris.find_synastry_aspects(longitudes_a, longitudes_b) == []


def test_find_synastry_aspects_finds_a_conjunction_within_orb():
    longitudes_a = {"Sun": 100.0}
    longitudes_b = {"Moon": 104.0}
    hits = ephemeris.find_synastry_aspects(longitudes_a, longitudes_b)
    assert len(hits) == 1
    assert hits[0] == {"planet_a": "Sun", "planet_b": "Moon", "aspect": "conjunction", "angle": 4.0, "orb": 4.0}


def test_find_synastry_aspects_respects_the_tighter_mercury_orb():
    # Mercury/Mercury allowed orb is 5 deg (average of 5 and 5) -- 6 deg apart
    # falls outside it and must not register as a conjunction.
    longitudes_a = {"Mercury": 10.0}
    longitudes_b = {"Mercury": 16.0}
    assert ephemeris.find_synastry_aspects(longitudes_a, longitudes_b) == []


# ---------------------------------------------------------------------------
# build_synastry_prompt (pure function, no network)
# ---------------------------------------------------------------------------


def _planet(name="Venus", sign="Taurus", house=2, dignities=None):
    return {"name": name, "sign": sign, "house": house, "dignities": dignities or []}


def _base_kwargs(**overrides):
    kwargs = dict(
        name_a="Alex",
        asc_sign_a="Leo",
        temperament_a="Choleric",
        planets_a=[_planet()],
        name_b="Sam",
        asc_sign_b="Pisces",
        temperament_b="Phlegmatic",
        planets_b=[_planet(name="Mars", sign="Aries", house=1)],
        house_overlays=[{"planet": "Venus", "from_chart": "A", "house": 8}],
        inter_aspects=[{"planet_a": "Sun", "planet_b": "Moon", "aspect": "trine", "orb": 2.3}],
    )
    kwargs.update(overrides)
    return kwargs


def test_prompt_includes_both_natives_headers():
    prompt = synastry.build_synastry_prompt(**_base_kwargs())
    assert "First native: Alex" in prompt
    assert "Ascendant: Leo · Temperament: Choleric" in prompt
    assert "Second native: Sam" in prompt
    assert "Ascendant: Pisces · Temperament: Phlegmatic" in prompt


def test_prompt_formats_house_overlay_line_naming_both_natives():
    prompt = synastry.build_synastry_prompt(**_base_kwargs())
    assert "Venus (of Alex) falls in House 8 of Sam" in prompt


def test_prompt_uses_traditional_glyphs_for_inter_aspects():
    prompt = synastry.build_synastry_prompt(**_base_kwargs())
    assert "Sun (Alex) △ Moon (Sam) — orb 2.3" in prompt


def test_prompt_falls_back_to_none_within_orb_when_no_inter_aspects():
    prompt = synastry.build_synastry_prompt(**_base_kwargs(inter_aspects=[]))
    assert "None within orb." in prompt


def test_prompt_asks_for_the_five_traditional_sections():
    prompt = synastry.build_synastry_prompt(**_base_kwargs())
    for phrase in [
        "overall compatibility signature",
        "strongest points of harmony",
        "main points of tension",
        "each native brings",
        "traditional prognosis",
    ]:
        assert phrase in prompt


# ---------------------------------------------------------------------------
# /chart/synastry endpoint (AI call monkeypatched)
# ---------------------------------------------------------------------------


def test_synastry_endpoint_returns_14_house_overlays(monkeypatch):
    monkeypatch.setattr(synastry, "generate_synastry_analysis", lambda prompt: "A fake reading.")
    response = client.post("/api/v1/chart/synastry", json={"person_a": _PERSON_A, "person_b": _PERSON_B})
    assert response.status_code == 200
    body = response.json()
    assert len(body["house_overlays"]) == 14
    assert {o["from_chart"] for o in body["house_overlays"]} == {"A", "B"}


def test_synastry_endpoint_uses_provided_names(monkeypatch):
    monkeypatch.setattr(synastry, "generate_synastry_analysis", lambda prompt: "A fake reading.")
    response = client.post("/api/v1/chart/synastry", json={"person_a": _PERSON_A, "person_b": _PERSON_B})
    body = response.json()
    assert body["person_a_name"] == "Alex"
    assert body["person_b_name"] == "Sam"


def test_synastry_endpoint_defaults_names_when_not_given(monkeypatch):
    monkeypatch.setattr(synastry, "generate_synastry_analysis", lambda prompt: "A fake reading.")
    person_a = {**_PERSON_A, "name": None}
    person_b = {**_PERSON_B, "name": None}
    response = client.post("/api/v1/chart/synastry", json={"person_a": person_a, "person_b": person_b})
    body = response.json()
    assert body["person_a_name"] == "Native 1"
    assert body["person_b_name"] == "Native 2"


def test_synastry_endpoint_sorts_aspects_by_exactness(monkeypatch):
    monkeypatch.setattr(synastry, "generate_synastry_analysis", lambda prompt: "A fake reading.")
    response = client.post("/api/v1/chart/synastry", json={"person_a": _PERSON_A, "person_b": _PERSON_B})
    orbs = [a["orb"] for a in response.json()["aspects"]]
    assert orbs == sorted(orbs)


def test_synastry_endpoint_surfaces_ai_failure_as_503(monkeypatch):
    def fake_generate(prompt: str) -> str:
        raise synastry.SynastryError("ANTHROPIC_API_KEY is not configured")

    monkeypatch.setattr(synastry, "generate_synastry_analysis", fake_generate)
    response = client.post("/api/v1/chart/synastry", json={"person_a": _PERSON_A, "person_b": _PERSON_B})
    assert response.status_code == 503


def test_synastry_endpoint_rejects_when_rate_limited(monkeypatch):
    monkeypatch.setattr(rate_limit, "check_and_consume", lambda user_id: False)
    response = client.post(
        "/api/v1/chart/synastry", json={"person_a": _PERSON_A, "person_b": _PERSON_B, "user_id": "some-user"}
    )
    assert response.status_code == 429
    assert response.json()["detail"] == rate_limit.LIMIT_MESSAGE
