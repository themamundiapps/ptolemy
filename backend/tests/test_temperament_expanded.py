"""Tests for the expanded Temperament feature: the ptolemy-temperament-expanded.md
content parser and the /temperament/expanded endpoint that serves it."""
from fastapi.testclient import TestClient

from app.main import app
from app.services import interpretations

client = TestClient(app)

_ALL_TEMPERAMENTS = [
    "Sanguine",
    "Choleric",
    "Phlegmatic",
    "Melancholic",
    "Sanguine-Choleric",
    "Sanguine-Phlegmatic",
    "Sanguine-Melancholic",
    "Choleric-Phlegmatic",
    "Choleric-Melancholic",
    "Phlegmatic-Melancholic",
]


# ---------------------------------------------------------------------------
# Content parsing (ptolemy-temperament-expanded.md)
# ---------------------------------------------------------------------------


def test_parses_exactly_10_entries():
    assert len(interpretations._temperament_expanded_entries()) == 10


def test_every_temperament_has_both_sections():
    for name in _ALL_TEMPERAMENTS:
        entry = interpretations.get_temperament_expanded(name)
        assert entry is not None, f"missing entry for {name}"
        assert entry.health_text
        assert entry.recommendations_text


def test_lookup_is_case_insensitive():
    assert interpretations.get_temperament_expanded("sanguine") is not None
    assert interpretations.get_temperament_expanded("SANGUINE") is not None
    assert interpretations.get_temperament_expanded("Sanguine") is not None


def test_unknown_temperament_returns_none():
    assert interpretations.get_temperament_expanded("Aquatic") is None


def test_most_entries_have_a_citation_but_two_do_not():
    # Documented in the parser's own docstring: only 8 of 10 entries carry a
    # quote/citation on their Health Tendencies section -- Sanguine-Phlegmatic
    # and Choleric-Phlegmatic have none. Pins the ratio so a future content
    # edit that silently drops a citation gets caught.
    entries = [interpretations.get_temperament_expanded(name) for name in _ALL_TEMPERAMENTS]
    with_citation = [e for e in entries if e.health_citation]
    assert len(with_citation) == 8


def test_entry_with_citation_includes_quote_and_attribution():
    entry = interpretations.get_temperament_expanded("Sanguine")
    assert entry.health_citation.startswith('"')
    assert "—" in entry.health_citation
    assert "Ptolemy" in entry.health_citation


def test_entry_without_citation_still_has_full_health_text():
    entry = interpretations.get_temperament_expanded("Sanguine-Phlegmatic")
    assert entry.health_citation == ""
    assert entry.health_text.startswith("The Sanguine-Phlegmatic temperament")


def test_recommendations_text_preserves_all_labeled_subsections():
    # Pure temperaments have 5 "**Label:**" paragraphs (governing principle,
    # climate, diet, exercise, cautions); mixed temperaments have 5 as well
    # but under slightly different labels -- either way each is its own
    # paragraph, separated by a blank line, for the frontend to split on.
    entry = interpretations.get_temperament_expanded("Choleric")
    paragraphs = entry.recommendations_text.split("\n\n")
    assert len(paragraphs) == 5
    assert all(p.startswith("**") for p in paragraphs)


def test_mixed_temperament_recommendations_also_parse():
    entry = interpretations.get_temperament_expanded("Phlegmatic-Melancholic")
    paragraphs = entry.recommendations_text.split("\n\n")
    assert len(paragraphs) == 5
    assert paragraphs[0].startswith("**Governing principle:**")


# ---------------------------------------------------------------------------
# /temperament/expanded endpoint
# ---------------------------------------------------------------------------


def test_endpoint_returns_both_sections_for_pure_temperament():
    response = client.get("/api/v1/temperament/expanded", params={"temperament": "Sanguine"})
    assert response.status_code == 200
    body = response.json()
    assert body["temperament"] == "Sanguine"
    assert body["health_tendencies"]["text"]
    assert body["health_tendencies"]["citation"]
    assert body["traditional_recommendations"]["text"]


def test_endpoint_returns_both_sections_for_mixed_temperament():
    response = client.get("/api/v1/temperament/expanded", params={"temperament": "Sanguine-Melancholic"})
    assert response.status_code == 200
    body = response.json()
    assert body["temperament"] == "Sanguine-Melancholic"
    assert body["health_tendencies"]["text"]
    assert body["traditional_recommendations"]["text"]


def test_endpoint_empty_citation_for_temperament_with_none():
    response = client.get("/api/v1/temperament/expanded", params={"temperament": "Choleric-Phlegmatic"})
    assert response.status_code == 200
    assert response.json()["health_tendencies"]["citation"] == ""


def test_endpoint_404s_for_unknown_temperament():
    response = client.get("/api/v1/temperament/expanded", params={"temperament": "NotATemperament"})
    assert response.status_code == 404


def test_endpoint_422s_when_temperament_param_missing():
    response = client.get("/api/v1/temperament/expanded")
    assert response.status_code == 422
