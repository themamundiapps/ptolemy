"""Tests for the aspect-pair interpretation content parser and endpoint.

The planet-sign/planet-house/lot endpoints predate this file and were
verified manually rather than with pytest; this file covers the aspect-pair
feature (Session 8) and its square/trine/opposition extension (Session 9),
including the real ptolemy-aspects.md / ptolemy-aspects-extended.md content
files, not synthetic stand-ins.
"""
from fastapi.testclient import TestClient

from app.main import app
from app.services import interpretations

client = TestClient(app)

ALL_PLANETS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn"]
ALL_ANGLES = ["ASC", "DSC", "MC", "IC"]

# Conjunction never has an extended entry (the file only adds square/trine/
# opposition), so using it isolates "base pair lookup" behavior in tests
# that aren't specifically about the square/trine/opposition override.
_BASE_ONLY_ASPECT = "conjunction"


def test_parses_exactly_49_pairs():
    # 21 planet-planet pairs (C(7,2)) + 4 angles x 7 planets = 49.
    assert len(interpretations._aspect_pair_interpretations()) == 49


def test_every_planet_planet_pair_is_present():
    for i, a in enumerate(ALL_PLANETS):
        for b in ALL_PLANETS[i + 1 :]:
            result = interpretations.get_aspect_interpretation(a, b, _BASE_ONLY_ASPECT)
            assert result is not None, f"missing pair {a}-{b}"
            assert result.body
            assert result.citation


def test_every_planet_angle_pair_is_present():
    for planet in ALL_PLANETS:
        for angle in ALL_ANGLES:
            result = interpretations.get_aspect_interpretation(planet, angle, _BASE_ONLY_ASPECT)
            assert result is not None, f"missing pair {planet}-{angle}"
            assert result.body
            assert result.citation


def test_lookup_is_order_independent():
    a = interpretations.get_aspect_interpretation("Venus", "Saturn", _BASE_ONLY_ASPECT)
    b = interpretations.get_aspect_interpretation("Saturn", "Venus", _BASE_ONLY_ASPECT)
    assert a is not None
    assert a is b


def test_lookup_is_case_insensitive():
    a = interpretations.get_aspect_interpretation("venus", "saturn", _BASE_ONLY_ASPECT)
    b = interpretations.get_aspect_interpretation("VENUS", "SATURN", _BASE_ONLY_ASPECT)
    c = interpretations.get_aspect_interpretation("Venus", "Saturn", _BASE_ONLY_ASPECT)
    assert a is b is c


def test_angle_names_stay_uppercase_not_titlecased():
    # A lowercase "asc" query param must still resolve -- ASC is not a
    # planet name and must not become "Asc".
    result = interpretations.get_aspect_interpretation("Sun", "asc", _BASE_ONLY_ASPECT)
    assert result is not None
    assert result is interpretations.get_aspect_interpretation("Sun", "ASC", _BASE_ONLY_ASPECT)


def test_unknown_pair_returns_none():
    assert interpretations.get_aspect_interpretation("Sun", "Sun", _BASE_ONLY_ASPECT) is None
    assert interpretations.get_aspect_interpretation("Pluto", "Sun", _BASE_ONLY_ASPECT) is None


def test_citation_includes_quote_and_attribution():
    result = interpretations.get_aspect_interpretation("Sun", "Moon", _BASE_ONLY_ASPECT)
    assert result.citation.startswith('"')
    assert "—" in result.citation
    assert "Valens" in result.citation or "Ptolemy" in result.citation


def test_endpoint_returns_interpretation_for_known_pair():
    response = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Venus", "planet_b": "Saturn", "aspect_type": _BASE_ONLY_ASPECT},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["body"]
    assert body["citation"]


def test_endpoint_is_order_independent():
    r1 = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Venus", "planet_b": "Saturn", "aspect_type": "trine"},
    )
    r2 = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Saturn", "planet_b": "Venus", "aspect_type": "trine"},
    )
    assert r1.json() == r2.json()


def test_endpoint_handles_angle_names():
    response = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Jupiter", "planet_b": "MC", "aspect_type": _BASE_ONLY_ASPECT},
    )
    assert response.status_code == 200
    assert response.json()["body"]


def test_endpoint_404s_for_unknown_pair():
    response = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Sun", "planet_b": "Sun", "aspect_type": _BASE_ONLY_ASPECT},
    )
    assert response.status_code == 404


def test_endpoint_422s_for_invalid_aspect_type():
    response = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Sun", "planet_b": "Moon", "aspect_type": "not-a-real-aspect"},
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Extended square/trine/opposition interpretations (ptolemy-aspects-extended.md)
# ---------------------------------------------------------------------------

_PAIRS_WITHOUT_EXTENDED_ENTRIES = {frozenset({"Sun", "Mercury"}), frozenset({"Sun", "Venus"})}


def test_parses_141_extended_entries():
    # 19 planetary pairs with entries (21 total minus Sun-Mercury/Sun-Venus,
    # which are astronomically impossible at square/trine/opposition) x 3
    # aspect types = 57, plus 4 angles x 7 planets x 3 aspect types = 84.
    assert len(interpretations._extended_aspect_interpretations()) == 141


def test_specific_entry_used_for_square_trine_opposition():
    for aspect_type in ("square", "trine", "opposition"):
        result = interpretations.get_aspect_interpretation("Venus", "Saturn", aspect_type)
        assert result is not None
        assert result.citation == "", f"{aspect_type} should use the un-cited specific passage, not the base text"


def test_venus_saturn_trine_matches_the_documented_example():
    result = interpretations.get_aspect_interpretation("Venus", "Saturn", "trine")
    assert result.body.startswith("The trine between Venus and Saturn")


def test_specific_entry_is_order_independent():
    a = interpretations.get_aspect_interpretation("Venus", "Saturn", "square")
    b = interpretations.get_aspect_interpretation("Saturn", "Venus", "square")
    assert a is not None
    assert a is b


def test_conjunction_and_sextile_always_use_base_text():
    for aspect_type in ("conjunction", "sextile"):
        result = interpretations.get_aspect_interpretation("Venus", "Saturn", aspect_type)
        assert result is not None
        assert result.citation != "", f"{aspect_type} should still use the cited base text"


def test_sun_mercury_has_no_specific_entries_and_falls_back_to_base():
    # Astronomically impossible aspects (Mercury's max elongation from the
    # Sun is ~28 degrees) -- the extended file intentionally omits these,
    # and the base pair text must still answer the query rather than 404.
    for aspect_type in ("square", "trine", "opposition"):
        result = interpretations.get_aspect_interpretation("Sun", "Mercury", aspect_type)
        assert result is not None
        assert result.citation != ""


def test_sun_venus_has_no_specific_entries_and_falls_back_to_base():
    for aspect_type in ("square", "trine", "opposition"):
        result = interpretations.get_aspect_interpretation("Sun", "Venus", aspect_type)
        assert result is not None
        assert result.citation != ""


def test_no_pair_other_than_sun_mercury_and_sun_venus_is_missing_extended_entries():
    for i, a in enumerate(ALL_PLANETS):
        for b in ALL_PLANETS[i + 1 :]:
            pair = frozenset({a, b})
            for aspect_type in ("square", "trine", "opposition"):
                result = interpretations.get_aspect_interpretation(a, b, aspect_type)
                if pair in _PAIRS_WITHOUT_EXTENDED_ENTRIES:
                    assert result.citation != "", f"{a}-{b} {aspect_type} should fall back to cited base text"
                else:
                    assert result.citation == "", f"{a}-{b} {aspect_type} should have a specific un-cited entry"


def test_every_planet_angle_pair_has_all_three_specific_entries():
    for planet in ALL_PLANETS:
        for angle in ALL_ANGLES:
            for aspect_type in ("square", "trine", "opposition"):
                result = interpretations.get_aspect_interpretation(planet, angle, aspect_type)
                assert result is not None, f"missing {planet}-{angle} {aspect_type}"
                assert result.body
                assert result.citation == ""


def test_endpoint_returns_specific_text_for_square_trine_opposition():
    response = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Venus", "planet_b": "Saturn", "aspect_type": "trine"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["citation"] == ""
    assert "trine between Venus and Saturn" in body["body"]


def test_endpoint_falls_back_to_base_for_sun_mercury_square():
    response = client.get(
        "/api/v1/interpretations/aspect",
        params={"planet_a": "Sun", "planet_b": "Mercury", "aspect_type": "square"},
    )
    assert response.status_code == 200
    assert response.json()["citation"] != ""
