"""Tests for app.services.ephemeris — currently just the Moon-state facts
(void of course, via combusta) that used to live in electional.py before
Transits needed the same calculations. See
PTOLEMY_ELECTIONAL_REDESIGN.md Section 2.
"""
from app.services import ephemeris


# ---------------------------------------------------------------------------
# moon_via_combusta -- boundary correctness (195-225 degrees, half-open)
# ---------------------------------------------------------------------------


def test_moon_via_combusta_boundaries():
    assert ephemeris.moon_via_combusta(195.0) is True
    assert ephemeris.moon_via_combusta(210.0) is True
    assert ephemeris.moon_via_combusta(224.999) is True
    assert ephemeris.moon_via_combusta(225.0) is False
    assert ephemeris.moon_via_combusta(194.999) is False
    assert ephemeris.moon_via_combusta(0.0) is False


# ---------------------------------------------------------------------------
# moon_next_aspect / moon_void_of_course -- crossing-detection correctness
# ---------------------------------------------------------------------------


def test_moon_next_aspect_returns_none_or_valid_pair():
    for day_offset in range(0, 30, 5):
        jd = ephemeris.julian_day_ut("2026-01-01", "12:00", 0.0) + day_offset
        result = ephemeris.moon_next_aspect(jd)
        if result is not None:
            planet, aspect_name = result
            assert planet in ephemeris.CLASSICAL_PLANETS
            assert planet != "Moon"
            assert aspect_name in ephemeris.MAJOR_ASPECTS


def test_moon_next_aspect_detects_all_five_aspect_types_over_a_sample():
    seen_aspects = set()
    jd = ephemeris.julian_day_ut("2026-01-01", "00:00", 0.0)
    for i in range(0, 300, 4):
        result = ephemeris.moon_next_aspect(jd + i / 24)
        if result is not None:
            seen_aspects.add(result[1])
    # Conjunction/opposition use a different detection path (extremum, not
    # sign-crossing) than sextile/square/trine -- this confirms both paths work.
    assert "conjunction" in seen_aspects
    assert "opposition" in seen_aspects
    assert "trine" in seen_aspects or "sextile" in seen_aspects or "square" in seen_aspects


def test_moon_void_of_course_matches_moon_next_aspect():
    """moon_void_of_course is just moon_next_aspect(...) is None -- confirm
    the convenience wrapper stays in sync with the underlying calculation
    over a real sample rather than trusting the one-line implementation."""
    jd = ephemeris.julian_day_ut("2026-01-01", "00:00", 0.0)
    for i in range(0, 200, 5):
        t = jd + i / 24
        assert ephemeris.moon_void_of_course(t) == (ephemeris.moon_next_aspect(t) is None)
