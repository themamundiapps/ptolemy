"""Tests for the House Lords feature: the /chart/house-lords calculation
endpoint, the ptolemy-house-lords.md content parser, and the
/interpretations/house-lord endpoint that serves it."""
from fastapi.testclient import TestClient

from app.main import app
from app.services import ephemeris, interpretations

client = TestClient(app)

_NATAL_PAYLOAD = {
    "date": "1990-06-15",
    "time": "14:30",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "tz_offset": -3.0,
}

ALL_PLANETS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn"]


# ---------------------------------------------------------------------------
# Calculation (ephemeris.SIGN_RULERS + /chart/house-lords)
# ---------------------------------------------------------------------------


def test_every_sign_has_exactly_one_of_the_seven_classical_rulers():
    assert len(ephemeris.SIGN_RULERS) == 12
    assert set(ephemeris.SIGN_RULERS.values()) == set(ALL_PLANETS)


def test_house_sign_is_the_inverse_of_whole_sign_house():
    # Whatever sign the Ascendant is in, house 1 must report that same sign.
    for asc_lon in (0.0, 47.3, 289.9):
        asc_sign, _ = ephemeris.sign_and_degree(asc_lon)
        assert ephemeris.house_sign(1, asc_lon) == asc_sign


def test_house_lords_endpoint_returns_12_entries():
    response = client.post("/api/v1/chart/house-lords", json=_NATAL_PAYLOAD)
    assert response.status_code == 200
    entries = response.json()["entries"]
    assert len(entries) == 12
    assert [e["house_number"] for e in entries] == list(range(1, 13))


def test_house_lords_entries_are_internally_consistent():
    response = client.post("/api/v1/chart/house-lords", json=_NATAL_PAYLOAD)
    entries = response.json()["entries"]
    for entry in entries:
        assert entry["lord"] == ephemeris.SIGN_RULERS[entry["sign"]]
        assert entry["interpretation_key"] == f"lord_{entry['house_number']}_in_{entry['lord_house']}"
        if entry["lord_dignity"] is not None:
            assert entry["lord_dignity"] in {"domicile", "exaltation", "detriment", "fall"}


def test_house_lords_matches_positions_endpoint_for_same_chart():
    # Cross-check against the already-trusted /chart/positions calculation
    # rather than trusting the new endpoint in isolation.
    positions = client.post("/api/v1/chart/positions", json=_NATAL_PAYLOAD).json()
    house_lords = client.post("/api/v1/chart/house-lords", json=_NATAL_PAYLOAD).json()["entries"]

    house_1 = next(e for e in house_lords if e["house_number"] == 1)
    assert house_1["sign"] == positions["ascendant"]["sign"]

    for entry in house_lords:
        lord_position = positions["planets"][entry["lord"]]
        assert entry["lord_house"] == lord_position["house"]
        assert entry["lord_sign"] == lord_position["sign"]


def test_house_lords_endpoint_uses_manual_tz_offset_when_given():
    auto = client.post("/api/v1/chart/house-lords", json={**_NATAL_PAYLOAD, "tz_offset": None}).json()
    manual = client.post("/api/v1/chart/house-lords", json=_NATAL_PAYLOAD).json()
    assert auto == manual  # -3.0 is also what auto-resolution finds for this date/place


# ---------------------------------------------------------------------------
# Content parsing (ptolemy-house-lords.md)
# ---------------------------------------------------------------------------


def test_parses_exactly_144_entries():
    assert len(interpretations._house_lord_interpretations()) == 144


def test_every_combination_is_present_with_a_body():
    for from_house in range(1, 13):
        for to_house in range(1, 13):
            result = interpretations.get_house_lord_interpretation(from_house, to_house)
            assert result is not None, f"missing lord of house {from_house} in house {to_house}"
            assert result.body


def test_unknown_house_pair_returns_none():
    assert interpretations.get_house_lord_interpretation(13, 1) is None
    assert interpretations.get_house_lord_interpretation(0, 1) is None


def test_most_entries_have_no_citation_but_some_do():
    # Documented in the parser's own docstring: only 37 of 144 entries carry
    # a quote/citation -- this pins that ratio so a future content-file edit
    # that silently drops citations (or the parser regressing to expect one
    # everywhere) gets caught.
    all_entries = [
        interpretations.get_house_lord_interpretation(a, b) for a in range(1, 13) for b in range(1, 13)
    ]
    with_citation = [e for e in all_entries if e.citation]
    assert len(with_citation) == 37


def test_entry_with_citation_includes_quote_and_attribution():
    result = interpretations.get_house_lord_interpretation(1, 1)
    assert result.citation.startswith('"')
    assert "—" in result.citation
    assert "Valens" in result.citation or "Ptolemy" in result.citation


def test_entry_without_citation_still_has_full_body():
    result = interpretations.get_house_lord_interpretation(3, 4)
    assert result.citation == ""
    assert result.body.startswith("The lord of the third house in the fourth")


# ---------------------------------------------------------------------------
# /interpretations/house-lord endpoint
# ---------------------------------------------------------------------------


def test_endpoint_returns_interpretation_for_known_pair():
    response = client.get("/api/v1/interpretations/house-lord", params={"from_house": 1, "to_house": 1})
    assert response.status_code == 200
    body = response.json()
    assert body["body"]
    assert body["citation"]


def test_endpoint_returns_empty_citation_for_uncited_pair():
    response = client.get("/api/v1/interpretations/house-lord", params={"from_house": 3, "to_house": 4})
    assert response.status_code == 200
    assert response.json()["citation"] == ""


def test_endpoint_422s_for_out_of_range_house():
    response = client.get("/api/v1/interpretations/house-lord", params={"from_house": 13, "to_house": 1})
    assert response.status_code == 422
