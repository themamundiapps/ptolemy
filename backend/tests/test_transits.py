"""Tests for the Daily Transits feature: the transits calculation service
and the /chart/transits endpoint."""
from fastapi.testclient import TestClient

from app.main import app
from app.services import ephemeris, interpretations, transits

client = TestClient(app)

_NATAL_PAYLOAD = {
    "date": "1990-06-15",
    "time": "14:30",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "tz_offset": -3.0,
}


# ---------------------------------------------------------------------------
# moon_phase_name
# ---------------------------------------------------------------------------


def test_moon_phase_name_covers_all_eight_phases_without_gaps():
    names = {transits.moon_phase_name(angle) for angle in range(0, 360, 5)}
    assert names == {
        "New Moon",
        "Waxing Crescent",
        "First Quarter",
        "Waxing Gibbous",
        "Full Moon",
        "Waning Gibbous",
        "Last Quarter",
        "Waning Crescent",
    }


def test_moon_phase_name_boundaries():
    assert transits.moon_phase_name(0) == "New Moon"
    assert transits.moon_phase_name(179.9) == "Waxing Gibbous"
    assert transits.moon_phase_name(180) == "Full Moon"
    assert transits.moon_phase_name(359.9) == "Waning Crescent"


# ---------------------------------------------------------------------------
# find_transits
# ---------------------------------------------------------------------------


def test_find_transits_detects_an_exact_conjunction():
    # Transiting Sun placed exactly on natal Moon (at longitude 50) should
    # register as a conjunction with ~0 orb.
    natal = {"Sun": 10.0, "Moon": 50.0, "Mercury": 20.0, "Venus": 300.0, "Mars": 120.0, "Jupiter": 200.0, "Saturn": 280.0}
    jd_ut = ephemeris.julian_day_ut("2026-07-15", "12:00", 0.0)
    sun_lon, _ = ephemeris.calc_planet(jd_ut, ephemeris.CLASSICAL_PLANETS["Sun"])

    # Shift natal Moon to sit exactly where transiting Sun is today, so the
    # test doesn't depend on hardcoding today's real ephemeris position.
    natal["Moon"] = sun_lon
    hits = transits.find_transits(natal, jd_ut)

    sun_moon_hits = [h for h in hits if h["transiting_planet"] == "Sun" and h["natal_planet"] == "Moon"]
    assert len(sun_moon_hits) == 1
    assert sun_moon_hits[0]["aspect"] == "conjunction"
    assert sun_moon_hits[0]["orb"] < 0.1
    assert sun_moon_hits[0]["aspect_symbol"] == "☌"
    assert sun_moon_hits[0]["interpretation_key"] == "sun_moon"
    assert sun_moon_hits[0]["is_harmonious"] is True


def test_find_transits_respects_per_planet_orb_not_averaged():
    # Natal point placed 4 degrees from the transiting Sun: within the Sun's
    # own 2 degree orb? no -- outside it. Placed 4 degrees away should NOT
    # register a Sun transit (unlike natal-to-natal aspects, which average
    # both bodies' orbs and could reach further).
    jd_ut = ephemeris.julian_day_ut("2026-07-15", "12:00", 0.0)
    sun_lon, _ = ephemeris.calc_planet(jd_ut, ephemeris.CLASSICAL_PLANETS["Sun"])
    natal = {"Sun": (sun_lon + 4) % 360}
    hits = transits.find_transits(natal, jd_ut)
    sun_hits = [h for h in hits if h["transiting_planet"] == "Sun"]
    assert sun_hits == []


def test_find_transits_sorted_by_orb_ascending():
    jd_ut = ephemeris.julian_day_ut("2026-07-15", "12:00", 0.0)
    natal = {name: (i * 47.0) % 360 for i, name in enumerate(ephemeris.CLASSICAL_PLANETS)}
    hits = transits.find_transits(natal, jd_ut)
    orbs = [h["orb"] for h in hits]
    assert orbs == sorted(orbs)


def test_is_applying_true_when_transiting_body_moving_toward_exactness():
    jd_ut = ephemeris.julian_day_ut("2026-07-15", "12:00", 0.0)
    moon_id = ephemeris.CLASSICAL_PLANETS["Moon"]
    moon_lon, _ = ephemeris.calc_planet(jd_ut, moon_id)
    # Natal point just ahead of the Moon in its direction of travel (Moon
    # moves toward increasing longitude) -- so the Moon is applying to it.
    natal_lon = (moon_lon + 0.9) % 360
    assert transits._is_applying(jd_ut, moon_id, natal_lon, 0.0) is True
    # Natal point just behind -- the Moon is separating from it.
    natal_lon_behind = (moon_lon - 0.9) % 360
    assert transits._is_applying(jd_ut, moon_id, natal_lon_behind, 0.0) is False


# ---------------------------------------------------------------------------
# /chart/transits endpoint
# ---------------------------------------------------------------------------


def test_transits_endpoint_returns_moon_position_and_sorted_transits():
    response = client.post("/api/v1/chart/transits", json=_NATAL_PAYLOAD)
    assert response.status_code == 200
    body = response.json()

    assert "sign" in body["moon_position"]
    assert "house" in body["moon_position"]
    assert 1 <= body["moon_position"]["house"] <= 12
    assert body["moon_position"]["phase_name"] in {
        "New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
        "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent",
    }

    orbs = [t["orb"] for t in body["transits"]]
    assert orbs == sorted(orbs)
    for t in body["transits"]:
        assert t["orb"] <= transits.TRANSIT_ORBS[t["transiting_planet"]]


def test_transits_endpoint_moon_natal_aspect_is_within_one_degree_when_present():
    response = client.post("/api/v1/chart/transits", json=_NATAL_PAYLOAD)
    body = response.json()
    moon_natal_aspect = body["moon_natal_aspect"]
    if moon_natal_aspect is not None:
        assert moon_natal_aspect["transiting_planet"] == "Moon"
        assert moon_natal_aspect["orb"] <= 1.0
        # Must be the closest Moon transit, i.e. present in the full list too.
        moon_transits = [t for t in body["transits"] if t["transiting_planet"] == "Moon"]
        assert moon_transits[0] == moon_natal_aspect


# ---------------------------------------------------------------------------
# /interpretations/transit -- content parsing (ptolemy-transits.md)
# ---------------------------------------------------------------------------

ALL_PLANETS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn"]


def test_parses_exactly_49_entries():
    assert len(interpretations._transit_interpretations()) == 49


def test_every_transiting_natal_combination_is_present_with_a_body():
    for transiting in ALL_PLANETS:
        for natal in ALL_PLANETS:
            result = interpretations.get_transit_interpretation(transiting, natal, "conjunction")
            assert result is not None, f"missing transiting {transiting} to natal {natal}"
            assert result.body


def test_unknown_pair_returns_none():
    assert interpretations.get_transit_interpretation("Uranus", "Sun", "conjunction") is None


def test_harmonious_aspects_use_the_base_text_unmodified():
    base = interpretations.get_transit_interpretation("Sun", "Moon", "conjunction")
    for aspect_type in ("conjunction", "trine", "sextile"):
        result = interpretations.get_transit_interpretation("Sun", "Moon", aspect_type)
        assert result.body == base.body
        assert not result.body.startswith("With friction,")


def test_friction_prefix_lowercases_an_ordinary_leading_word():
    assert interpretations._apply_friction_prefix("This transit brings tension.") == (
        "With friction, this transit brings tension."
    )


def test_friction_prefix_keeps_a_leading_planet_name_capitalized():
    # "Venus harmonizes with Mercury..." must stay "Venus", not "venus" --
    # it's a proper noun, not capitalized merely for sentence position.
    assert interpretations._apply_friction_prefix("Venus harmonizes with Mercury.") == (
        "With friction, Venus harmonizes with Mercury."
    )


def test_square_and_opposition_apply_the_friction_prefix_to_the_real_content():
    base = interpretations.get_transit_interpretation("Sun", "Moon", "conjunction")
    for aspect_type in ("square", "opposition"):
        result = interpretations.get_transit_interpretation("Sun", "Moon", aspect_type)
        assert result.body.startswith("With friction, ")
        assert result.body != base.body


def test_friction_prefix_never_lowercases_a_leading_planet_name_across_all_49_entries():
    for transiting in ALL_PLANETS:
        for natal in ALL_PLANETS:
            result = interpretations.get_transit_interpretation(transiting, natal, "square")
            for planet in ALL_PLANETS:
                assert not result.body.startswith(f"With friction, {planet.lower()} ")


def test_endpoint_returns_interpretation_for_known_pair():
    response = client.get(
        "/api/v1/interpretations/transit",
        params={"transiting": "Sun", "natal": "Moon", "aspect_type": "conjunction"},
    )
    assert response.status_code == 200
    assert response.json()["body"]


def test_endpoint_404s_for_unknown_pair():
    response = client.get(
        "/api/v1/interpretations/transit",
        params={"transiting": "Uranus", "natal": "Sun", "aspect_type": "conjunction"},
    )
    assert response.status_code == 404
