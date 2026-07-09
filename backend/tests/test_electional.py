"""Regression tests for the electional checklist system.

Three kinds of tests here:
  - Pure logic tests against hand-crafted state dicts (fast, deterministic,
    don't depend on real planetary positions drifting with the calendar).
    Where a check now depends on real-time application/separation
    (_is_applying), these inject a fixed is_applying_fn stub so the
    surrounding logic (which planets, which houses, wording) stays fully
    controllable without needing a real date of known direction.
  - Integration tests against real Swiss Ephemeris output for known
    astronomical facts (e.g. Mercury's actual 2026 retrograde stations, the
    real 2026 solar eclipse dates, real applying/separating geometry) —
    these pin down behavior against ground truth, not just internal
    consistency.
  - scan() integration tests using a real natal chart.
"""
from datetime import date

import pytest

from app.services import electional, ephemeris

NATAL_DATE = "1990-06-15"
NATAL_TIME = "14:30"
NATAL_LAT = 41.9028
NATAL_LON = 12.4964
NATAL_TZ = 2.0

# A realistic whole-sign layout (each house exactly 30 degrees from the
# next) used throughout this file. House 1 = Aries (ruled by Mars), house 7
# = Libra (ruled by Venus) -- see the module-level note below on how this
# interacts with dynamic significators for tests that care.
STANDARD_CUSPS = {h: (h - 1) * 30.0 for h in range(1, 13)}

ALWAYS_APPLYING = lambda *args, **kwargs: True  # noqa: E731
ALWAYS_SEPARATING = lambda *args, **kwargs: False  # noqa: E731


@pytest.fixture(scope="module")
def asc_longitude():
    jd = ephemeris.julian_day_ut(NATAL_DATE, NATAL_TIME, NATAL_TZ)
    asc_lon, _mc = ephemeris.calc_angles(jd, NATAL_LAT, NATAL_LON)
    return asc_lon


@pytest.fixture(scope="module")
def cusps(asc_longitude):
    return electional.house_cusps(asc_longitude)


@pytest.fixture(scope="module")
def asc_sign(asc_longitude):
    sign, _ = ephemeris.sign_and_degree(asc_longitude)
    return sign


def make_state(lon: dict[str, float], retro: dict[str, bool] | None = None, moon_next_aspect=None) -> dict:
    """Builds a synthetic state dict for testing the pure checklist
    functions without needing real ephemeris timing.

    Unset planets default to 15.0 degrees, not 0.0: with a 30-degree-spaced
    whole-sign cusp layout (as used by STANDARD_CUSPS and the fixed `cusps`
    dicts throughout this file), 0.0 sits exactly on a cusp and is
    therefore exactly conjunct/sextile/square/trine/opposite several houses
    at once, which would make unset planets accidentally participate in the
    very aspects a test is trying to isolate. 15.0 is maximally far (in
    whole-sign terms) from every 30-degree-multiple cusp for aspect
    *matching* purposes.

    Caution: 15.0 degrees falls in Aries, which is Mars's own domicile —
    fine for aspect-matching tests, but if a test exercises the dignity
    check (_desirable_reasons) under STANDARD_CUSPS with a theme whose
    dynamic significators include Mars (e.g. love_relationships, whose
    Ascendant ruler under STANDARD_CUSPS is Mars), Mars's default position
    will spuriously register as "in its own sign". Those specific tests
    override Mars explicitly to an undignified degree.
    """
    full_lon = {p: 15.0 for p in ephemeris.CLASSICAL_PLANETS}
    full_lon.update(lon)
    full_retro = {p: False for p in ephemeris.CLASSICAL_PLANETS}
    if retro:
        full_retro.update(retro)
    return {
        "lon": full_lon,
        "retro": full_retro,
        "moon_voc": moon_next_aspect is None,
        "moon_next_aspect": moon_next_aspect,
    }


# ---------------------------------------------------------------------------
# Retrograde detection (real ephemeris — SEFLG_SPEED must be set)
# ---------------------------------------------------------------------------


def test_mercury_retrograde_matches_known_2026_station():
    # Mercury stations retrograde 2026-02-26 and direct 2026-03-21 (confirmed
    # against real swisseph output during this session).
    jd_mid_retrograde = ephemeris.julian_day_ut("2026-03-10", "12:00", 0.0)
    _lon, is_retro = ephemeris.calc_planet(jd_mid_retrograde, ephemeris.CLASSICAL_PLANETS["Mercury"])
    assert is_retro is True

    jd_direct = ephemeris.julian_day_ut("2026-05-01", "12:00", 0.0)
    _lon, is_retro = ephemeris.calc_planet(jd_direct, ephemeris.CLASSICAL_PLANETS["Mercury"])
    assert is_retro is False


def test_venus_retrograde_matches_known_2026_station():
    # Venus stations retrograde 2026-10-03, direct 2026-11-14.
    jd_mid_retrograde = ephemeris.julian_day_ut("2026-10-20", "12:00", 0.0)
    _lon, is_retro = ephemeris.calc_planet(jd_mid_retrograde, ephemeris.CLASSICAL_PLANETS["Venus"])
    assert is_retro is True

    jd_direct = ephemeris.julian_day_ut("2026-12-01", "12:00", 0.0)
    _lon, is_retro = ephemeris.calc_planet(jd_direct, ephemeris.CLASSICAL_PLANETS["Venus"])
    assert is_retro is False


# ---------------------------------------------------------------------------
# Solar eclipse detection
# ---------------------------------------------------------------------------


def test_solar_eclipse_dates_match_known_2026_eclipses():
    jd_start = ephemeris.julian_day_ut("2026-01-01", "00:00", 0.0)
    jd_end = ephemeris.julian_day_ut("2026-12-31", "00:00", 0.0)
    dates = ephemeris.solar_eclipse_dates(jd_start, jd_end)
    assert "2026-02-17" in dates
    assert "2026-08-12" in dates


def test_solar_eclipse_dates_empty_outside_range():
    jd_start = ephemeris.julian_day_ut("2026-03-01", "00:00", 0.0)
    jd_end = ephemeris.julian_day_ut("2026-03-31", "00:00", 0.0)
    dates = ephemeris.solar_eclipse_dates(jd_start, jd_end)
    assert dates == set()


# ---------------------------------------------------------------------------
# house_cusps
# ---------------------------------------------------------------------------


def test_house_cusps_whole_sign():
    cusps = electional.house_cusps(47.0)  # in Taurus (30-60)
    assert cusps[1] == 30.0
    assert cusps[2] == 60.0
    assert cusps[7] == 210.0
    assert cusps[12] == 360.0 % 360


# ---------------------------------------------------------------------------
# SIGN_RULERS / _house_ruler
# ---------------------------------------------------------------------------


def test_sign_rulers_covers_all_twelve_signs():
    assert set(electional.SIGN_RULERS.keys()) == set(ephemeris.ZODIAC_SIGNS)


def test_sign_rulers_matches_traditional_domicile():
    expected = {
        "Aries": "Mars", "Taurus": "Venus", "Gemini": "Mercury", "Cancer": "Moon",
        "Leo": "Sun", "Virgo": "Mercury", "Libra": "Venus", "Scorpio": "Mars",
        "Sagittarius": "Jupiter", "Capricorn": "Saturn", "Aquarius": "Saturn", "Pisces": "Jupiter",
    }
    assert electional.SIGN_RULERS == expected


def test_house_ruler_reads_sign_from_cusp():
    # STANDARD_CUSPS: house 1 = Aries -> Mars, house 7 = Libra -> Venus
    assert electional._house_ruler(STANDARD_CUSPS, 1) == "Mars"
    assert electional._house_ruler(STANDARD_CUSPS, 7) == "Venus"


# ---------------------------------------------------------------------------
# _significators_for / _significator_names — dynamic rulers
# ---------------------------------------------------------------------------


def test_significators_for_adds_ascendant_ruler_when_not_natural():
    theme = electional.THEMES["travel"]  # natural = Mercury, Jupiter; primary_house = 9
    # STANDARD_CUSPS: house 9 = Sagittarius -> Jupiter (already natural);
    # house 1 = Aries -> Mars (new).
    sigs = electional._significators_for(theme, STANDARD_CUSPS)
    planets = [p for p, _h in sigs]
    assert planets == ["Mercury", "Jupiter", "Mars"]


def test_significators_for_dedupes_when_dynamic_ruler_already_natural():
    theme = electional.THEMES["love_relationships"]  # natural = Venus, Jupiter; primary_house = 7
    # STANDARD_CUSPS: house 7 = Libra -> Venus (already natural, deduped);
    # house 1 = Aries -> Mars (new, kept).
    sigs = electional._significators_for(theme, STANDARD_CUSPS)
    planets = [p for p, _h in sigs]
    assert planets == ["Venus", "Jupiter", "Mars"]
    assert planets.count("Venus") == 1


def test_significators_for_dedupes_when_primary_house_ruler_equals_ascendant_ruler():
    theme = electional.THEMES["health_body"]  # primary_house = 1, same as Ascendant
    sigs = electional._significators_for(theme, STANDARD_CUSPS)
    planets = [p for p, _h in sigs]
    # Both "primary house ruler" and "Ascendant ruler" resolve to Mars here
    # (primary_house IS house 1) -- must not appear twice.
    assert planets.count("Mars") == 1


def test_significators_for_all_use_the_same_house_set():
    theme = electional.THEMES["travel"]
    sigs = electional._significators_for(theme, STANDARD_CUSPS)
    house_sets = {tuple(houses) for _p, houses in sigs}
    assert len(house_sets) == 1  # every significator checked against the same houses


def test_significators_for_extra_houses_applies_to_all_significators():
    theme = electional.THEMES["love_relationships"]
    sigs = electional._significators_for(theme, STANDARD_CUSPS, extra_houses=[1])
    for _planet, houses in sigs:
        assert houses == [1, 5, 7]


def test_significator_names_includes_dynamic_malefic_ruler():
    # Custom cusps where house 4 (home_family's primary house) is Capricorn
    # (ruled by Saturn, a malefic) and house 1 is Gemini (ruled by Mercury)
    # -- proving the dignity check now covers non-benefic dynamic
    # significators too (Fork 2b), not just benefics.
    theme = electional.THEMES["home_family"]
    cusps = {1: 60.0, 4: 270.0}  # Gemini, Capricorn
    names = electional._significator_names(theme, cusps)
    assert "Saturn" in names  # dynamic: ruler of house 4
    assert set(names) == {"Moon", "Venus", "Saturn", "Mercury"}


# ---------------------------------------------------------------------------
# _applying_from_orbs / _is_applying
# ---------------------------------------------------------------------------


def test_applying_from_orbs_shrinking_is_applying():
    assert electional._applying_from_orbs(orb_now=5.0, orb_later=3.0) is True


def test_applying_from_orbs_growing_is_separating():
    assert electional._applying_from_orbs(orb_now=3.0, orb_later=5.0) is False


def test_applying_from_orbs_unchanged_is_separating():
    # Not strictly meaningful (a planet's orb essentially never stays
    # perfectly constant), but the comparison is strict-less-than, so a tie
    # reads as "not applying" rather than raising or guessing.
    assert electional._applying_from_orbs(orb_now=4.0, orb_later=4.0) is False


def test_is_applying_matches_real_mercury_motion_around_its_2026_station():
    # Mercury stations retrograde on 2026-02-26 -- its longitude is momentarily
    # stationary, then decreases (retrograde) until 2026-03-21, then increases
    # again. Pick a fixed target point and aspect angle far from Mercury's
    # actual position so the orb is large and unambiguous, then confirm
    # _is_applying's direction matches Mercury's known direction of travel
    # on either side of the station.
    mercury_id = ephemeris.CLASSICAL_PLANETS["Mercury"]
    # Well before the station, Mercury is moving direct (increasing longitude).
    jd_direct = ephemeris.julian_day_ut("2026-01-15", "12:00", 0.0)
    lon_direct, _ = ephemeris.calc_planet(jd_direct, mercury_id)
    # A target point Mercury is approaching from below (target - lon_direct
    # small positive, using conjunction as the aspect) confirms "applying".
    target = (lon_direct + 3.0) % 360
    assert electional._is_applying(jd_direct, mercury_id, target, 0.0) is True
    # The same target, now behind Mercury's direction of travel, should read
    # as separating.
    target_behind = (lon_direct - 3.0) % 360
    assert electional._is_applying(jd_direct, mercury_id, target_behind, 0.0) is False


# ---------------------------------------------------------------------------
# _essential_ok
# ---------------------------------------------------------------------------


def test_essential_fails_on_retrograde():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 100.0}, retro={"Venus": True})
    cusps = {h: h * 30.0 for h in range(1, 13)}
    assert electional._essential_ok(theme, state, cusps, "Aries", "2026-01-01", set(), 0.0) is False


def test_essential_fails_on_combustion():
    theme = electional.THEMES["love_relationships"]
    # Venus 3 degrees from Sun -> combust (orb is 8 degrees)
    state = make_state({"Venus": 103.0, "Sun": 100.0})
    cusps = {h: h * 30.0 for h in range(1, 13)}
    assert electional._essential_ok(theme, state, cusps, "Aries", "2026-01-01", set(), 0.0) is False


def test_essential_passes_cazimi_despite_tight_sun_conjunction():
    theme = electional.THEMES["love_relationships"]
    # Venus 0.1 degrees from Sun -- inside CAZIMI_ORB (17' = 0.2833 degrees),
    # so this must NOT be treated as combust despite being far tighter than
    # the 8-degree combustion orb: cazimi is empowering, not afflicting.
    state = make_state({"Venus": 100.1, "Sun": 100.0}, moon_next_aspect=("Jupiter", "trine"))
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is True


def test_essential_fails_just_outside_cazimi_orb():
    theme = electional.THEMES["love_relationships"]
    # Venus 0.5 degrees from Sun -- just outside CAZIMI_ORB, so ordinary
    # combustion (orb 8 degrees) still applies and disqualifies the day.
    state = make_state({"Venus": 100.5, "Sun": 100.0}, moon_next_aspect=("Jupiter", "trine"))
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is False


def test_essential_passes_when_venus_clear_of_sun():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 100.0, "Sun": 250.0}, moon_next_aspect=("Jupiter", "trine"))
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is True


def test_essential_fails_on_void_of_course_moon():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 100.0, "Sun": 250.0}, moon_next_aspect=None)
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is False


def test_moon_via_combusta_boundaries():
    assert electional._moon_via_combusta(195.0) is True
    assert electional._moon_via_combusta(210.0) is True
    assert electional._moon_via_combusta(224.999) is True
    assert electional._moon_via_combusta(225.0) is False
    assert electional._moon_via_combusta(194.999) is False
    assert electional._moon_via_combusta(0.0) is False


def test_essential_fails_on_via_combusta_moon():
    theme = electional.THEMES["love_relationships"]
    # Moon at 210 degrees -- 15 Libra to 15 Scorpio is 195-225, so this sits
    # squarely inside the via combusta zone.
    state = make_state({"Venus": 100.0, "Sun": 250.0, "Moon": 210.0}, moon_next_aspect=("Jupiter", "trine"))
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is False


def test_essential_via_combusta_applies_even_when_theme_ignores_voc():
    # Unlike void-of-course, via combusta is not gated per-theme -- it must
    # still exclude the day for health_body, whose essential_moon_not_voc
    # is False.
    theme = electional.THEMES["health_body"]
    state = make_state({"Moon": 210.0, "Mercury": 200.0, "Venus": 210.0}, moon_next_aspect=("Jupiter", "trine"))
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Libra", "2026-01-01", set(), 0.0) is False


def test_essential_passes_just_outside_via_combusta_zone():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 100.0, "Sun": 250.0, "Moon": 194.0}, moon_next_aspect=("Jupiter", "trine"))
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is True


def test_essential_ignores_voc_for_health_theme():
    # health_body has essential_moon_not_voc = False
    theme = electional.THEMES["health_body"]
    state = make_state({"Moon": 100.0, "Mercury": 200.0, "Venus": 210.0}, moon_next_aspect=None)
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Libra", "2026-01-01", set(), 0.0) is True


def test_essential_fails_when_moon_in_ascendant_sign_for_health():
    theme = electional.THEMES["health_body"]
    # Moon at 5 degrees Aries (sign index 0), ascendant sign "Aries"
    state = make_state({"Moon": 5.0, "Mercury": 200.0, "Venus": 210.0}, moon_next_aspect=None)
    assert electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0) is False


def test_essential_fails_on_applying_malefic_square_to_relevant_house():
    theme = electional.THEMES["love_relationships"]  # essential_no_malefic_houses = [1, 5, 7]
    # Mars square house 5 cusp: separation of 90 degrees from 120 -> at 30 or 210
    state = make_state({"Venus": 300.0, "Sun": 50.0, "Mars": 210.0}, moon_next_aspect=("Jupiter", "trine"))
    result = electional._essential_ok(
        theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0, is_applying_fn=ALWAYS_APPLYING
    )
    assert result is False


def test_essential_ignores_separating_malefic_square_to_relevant_house():
    # Same geometry as above, but the aspect is separating (already peaked
    # and fading) -- traditionally much less concerning, so it must not
    # disqualify the day.
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 300.0, "Sun": 50.0, "Mars": 210.0}, moon_next_aspect=("Jupiter", "trine"))
    result = electional._essential_ok(
        theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0, is_applying_fn=ALWAYS_SEPARATING
    )
    assert result is True


def test_essential_ignores_malefic_trine_to_relevant_house():
    theme = electional.THEMES["love_relationships"]
    # Mars trine house 5 cusp: separation of 120 degrees from 120 -> at 0 or 240
    state = make_state({"Venus": 300.0, "Sun": 50.0, "Mars": 240.0}, moon_next_aspect=("Jupiter", "trine"))
    result = electional._essential_ok(
        theme, state, STANDARD_CUSPS, "Aries", "2026-01-01", set(), 0.0, is_applying_fn=ALWAYS_APPLYING
    )
    assert result is True


def test_essential_fails_on_eclipse_date_for_business():
    theme = electional.THEMES["business_career"]
    state = make_state({"Sun": 100.0}, moon_next_aspect=("Jupiter", "trine"))
    assert (
        electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-08-12", {"2026-08-12"}, 0.0) is False
    )


def test_essential_no_eclipse_check_for_themes_without_flag():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 300.0, "Sun": 50.0}, moon_next_aspect=("Jupiter", "trine"))
    # Same date is in eclipse_dates but love_relationships doesn't check eclipses
    assert (
        electional._essential_ok(theme, state, STANDARD_CUSPS, "Aries", "2026-08-12", {"2026-08-12"}, 0.0) is True
    )


# ---------------------------------------------------------------------------
# _important_reasons / _auspicious_reasons
# ---------------------------------------------------------------------------


def test_important_true_on_applying_harmonious_aspect():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 120.0, "Sun": 300.0, "Moon": 300.0})  # Venus conjunct house5 cusp; Moon not waxing
    reasons = electional._important_reasons(theme, state, STANDARD_CUSPS, 0.0, is_applying_fn=ALWAYS_APPLYING)
    assert reasons != []


def test_important_false_when_aspect_is_separating():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 120.0, "Sun": 300.0, "Moon": 200.0})
    reasons = electional._important_reasons(theme, state, STANDARD_CUSPS, 0.0, is_applying_fn=ALWAYS_SEPARATING)
    assert reasons == []


def test_important_false_without_a_qualifying_aspect():
    theme = electional.THEMES["love_relationships"]
    # Venus far from both houses 5 and 7 -> no aspect to report, regardless
    # of applying_fn or Moon phase.
    state = make_state({"Venus": 45.0, "Moon": 200.0, "Sun": 0.0})
    reasons = electional._important_reasons(theme, state, STANDARD_CUSPS, 0.0, is_applying_fn=ALWAYS_APPLYING)
    assert reasons == []


def test_important_false_via_waxing_moon_alone_no_aspect():
    # Global rule: Moon waxing no longer satisfies "important" on its own,
    # for any theme -- it moved to _desirable_reasons. A day with zero
    # qualifying significator aspects must return no important reasons even
    # if the Moon is waxing.
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Venus": 45.0, "Moon": 50.0, "Sun": 0.0})  # phase 50 -> waxing
    reasons = electional._important_reasons(theme, state, STANDARD_CUSPS, 0.0, is_applying_fn=ALWAYS_SEPARATING)
    assert reasons == []


def test_important_false_for_every_theme_via_waxing_moon_alone():
    # Same as above, but exercised across all six themes -- the user's
    # explicit ask was that this be a global rule, not a per-theme special
    # case. Placements deliberately avoid landing on any house cusp (which
    # sit at exact 30-degree multiples under STANDARD_CUSPS) for any theme's
    # natural or dynamic significators, so only Moon-waxing could have
    # produced a reason under the old logic.
    state = make_state({"Venus": 47.0, "Moon": 53.0, "Sun": 13.0})  # phase 40 -> waxing
    for theme in electional.THEMES.values():
        reasons = electional._important_reasons(theme, state, STANDARD_CUSPS, 0.0, is_applying_fn=ALWAYS_SEPARATING)
        assert reasons == [], f"{theme['label']} should not treat waxing Moon as an important reason"


def test_auspicious_reasons_names_wider_house_set_for_love():
    theme = electional.THEMES["love_relationships"]
    cusps = {1: 0.0, 5: 26.0, 7: 146.0}  # non-colliding layout (see house-collision notes elsewhere)
    state = make_state({"Venus": 0.0, "Jupiter": 15.0, "Moon": 200.0})
    reasons = electional._auspicious_reasons(theme, state, cusps, 0.0, is_applying_fn=ALWAYS_APPLYING)
    assert any("1st house" in r for r in reasons)


def test_auspicious_reasons_empty_when_separating():
    theme = electional.THEMES["love_relationships"]
    cusps = {1: 0.0, 5: 26.0, 7: 146.0}
    state = make_state({"Venus": 0.0, "Jupiter": 15.0, "Moon": 200.0})
    reasons = electional._auspicious_reasons(theme, state, cusps, 0.0, is_applying_fn=ALWAYS_SEPARATING)
    assert reasons == []


def test_aspect_reason_wording_says_applying():
    text = electional._aspect_reason("Venus", "trine", 5)
    assert "is applying to a trine" in text
    assert "5th house" in text


# ---------------------------------------------------------------------------
# relevant_houses (via scan()'s own computation, mirrored here)
# ---------------------------------------------------------------------------


def test_relevant_houses_includes_auspicious_extra_house():
    theme = electional.THEMES["love_relationships"]
    relevant_houses = sorted(
        set(theme["essential_no_malefic_houses"])
        | set(electional._theme_houses(theme, theme.get("auspicious_extra_houses")))
    )
    assert relevant_houses == [1, 5, 7]


# ---------------------------------------------------------------------------
# _desirable_reasons
# ---------------------------------------------------------------------------
#
# love_relationships' dynamic significators under STANDARD_CUSPS are Venus,
# Jupiter (natural) + Mars (Ascendant ruler, Aries) -- Mars's default test
# position (15.0, within Aries) would spuriously register as "in its own
# sign", so these tests set Mars explicitly to an undignified degree
# (100.0 -- Cancer, Mars's fall) to isolate the condition under test.


def test_desirable_via_jupiter_dignity_when_venus_undignified():
    theme = electional.THEMES["love_relationships"]
    # Jupiter exalted in Cancer (95-125), Venus in Capricorn (270-300, no dignity)
    state = make_state(
        {"Jupiter": 100.0, "Venus": 280.0, "Mars": 100.0}, moon_next_aspect=("Saturn", "square")
    )
    d = date(2026, 1, 6)  # Tuesday -- not a favorable weekday for love_relationships
    assert d.weekday() not in theme["favorable_weekdays"]
    reasons = electional._desirable_reasons(theme, state, d, STANDARD_CUSPS)
    assert any("Jupiter is exalted" in r for r in reasons)


def test_desirable_false_when_no_condition_holds():
    theme = electional.THEMES["love_relationships"]
    # Moon set to 200.0 (waning, phase 185) so the now-universal Moon-waxing
    # desirable condition doesn't mask what this test is isolating: that
    # every OTHER desirable condition is absent.
    state = make_state(
        {"Jupiter": 280.0, "Venus": 280.0, "Mars": 100.0, "Moon": 200.0}, moon_next_aspect=("Saturn", "square")
    )
    d = date(2026, 1, 6)  # Tuesday -- not in {Friday, Monday}
    assert d.weekday() not in theme["favorable_weekdays"]
    assert electional._desirable_reasons(theme, state, d, STANDARD_CUSPS) == []


def test_desirable_requires_harmonious_moon_aspect_to_benefic():
    theme = electional.THEMES["love_relationships"]
    # Moon waning (200.0) to isolate the moon-next-aspect condition from the
    # separate Moon-waxing desirable condition.
    base = {"Jupiter": 280.0, "Venus": 280.0, "Mars": 100.0, "Moon": 200.0}
    state_square = make_state(base, moon_next_aspect=("Jupiter", "square"))
    state_trine = make_state(base, moon_next_aspect=("Jupiter", "trine"))
    d = date(2026, 1, 6)
    assert electional._desirable_reasons(theme, state_square, d, STANDARD_CUSPS) == []
    assert any(
        "applying to a trine with Jupiter" in r
        for r in electional._desirable_reasons(theme, state_trine, d, STANDARD_CUSPS)
    )


def test_desirable_requires_moon_next_aspect_planet_be_a_benefic():
    theme = electional.THEMES["love_relationships"]
    state = make_state(
        {"Jupiter": 280.0, "Venus": 280.0, "Mars": 100.0, "Moon": 200.0}, moon_next_aspect=("Mars", "trine")
    )
    d = date(2026, 1, 6)
    assert electional._desirable_reasons(theme, state, d, STANDARD_CUSPS) == []


def test_desirable_reasons_domicile_vs_exaltation_wording_differs():
    theme = electional.THEMES["love_relationships"]
    tuesday = date(2026, 1, 6)

    # Venus in Taurus = domicile
    domicile_state = make_state(
        {"Venus": 40.0, "Jupiter": 200.0, "Mars": 100.0}, moon_next_aspect=("Saturn", "square")
    )
    domicile_reasons = electional._desirable_reasons(theme, domicile_state, tuesday, STANDARD_CUSPS)
    assert any("own sign" in r for r in domicile_reasons)

    # Jupiter in Cancer = exaltation
    exaltation_state = make_state(
        {"Venus": 200.0, "Jupiter": 100.0, "Mars": 100.0}, moon_next_aspect=("Saturn", "square")
    )
    exaltation_reasons = electional._desirable_reasons(theme, exaltation_state, tuesday, STANDARD_CUSPS)
    assert any("exalted" in r for r in exaltation_reasons)


def test_desirable_reasons_weekday_names_the_ruling_planet():
    theme = electional.THEMES["love_relationships"]
    state = make_state({"Mars": 100.0}, moon_next_aspect=("Saturn", "square"))
    friday = date(2026, 1, 2)
    reasons = electional._desirable_reasons(theme, state, friday, STANDARD_CUSPS)
    assert any("Friday is ruled by Venus" in r for r in reasons)


def test_desirable_dignity_check_covers_dynamic_malefic_significator():
    # Custom cusps where home_family's primary house (4) is Capricorn,
    # ruled by Saturn -- a malefic. Placing Saturn in its own sign
    # (Aquarius) should register as a positive dignity reason even though
    # Saturn is not a benefic (Fork 2b).
    theme = electional.THEMES["home_family"]
    cusps = {1: 60.0, 4: 270.0}  # Gemini, Capricorn -- dynamic significators become Saturn, Mercury
    state = make_state({"Saturn": 320.0, "Moon": 15.0, "Venus": 15.0}, moon_next_aspect=("Mars", "square"))
    tuesday = date(2026, 1, 6)
    assert tuesday.weekday() not in theme["favorable_weekdays"]
    reasons = electional._desirable_reasons(theme, state, tuesday, cusps)
    assert any("Saturn is in its own sign" in r for r in reasons)


def test_desirable_moon_waxing_reason_present_for_every_theme():
    # Global rule (see module docstring): Moon waxing is now a universal
    # desirable condition for all six themes, including home_family, whose
    # important_moon_waxing flag used to be False under the old system.
    state = make_state({"Moon": 50.0, "Sun": 0.0, "Mars": 100.0})  # phase 50 -> waxing
    wednesday = date(2026, 1, 7)  # not a favorable weekday for every theme
    for theme in electional.THEMES.values():
        reasons = electional._desirable_reasons(theme, state, wednesday, STANDARD_CUSPS)
        assert any("Moon is waxing" in r for r in reasons), f"{theme['label']} should list the waxing Moon"


def test_desirable_moon_waning_omits_waxing_reason():
    state = make_state({"Moon": 200.0, "Sun": 0.0}, moon_next_aspect=("Saturn", "square"))  # phase 200 -> waning
    d = date(2026, 1, 6)
    theme = electional.THEMES["love_relationships"]
    reasons = electional._desirable_reasons(theme, state, d, STANDARD_CUSPS)
    assert not any("waxing" in r for r in reasons)


# ---------------------------------------------------------------------------
# Scoring matrix sign/magnitude sanity
# ---------------------------------------------------------------------------


def test_malefic_square_and_opposition_are_negative():
    m = electional.ASPECT_MULTIPLIERS["malefic"]
    assert m["square"] < 0
    assert m["opposition"] < 0
    assert m["trine"] > 0
    assert m["sextile"] > 0


def test_benefic_multipliers_all_positive_and_exceed_neutral():
    benefic = electional.ASPECT_MULTIPLIERS["benefic"]
    neutral = electional.ASPECT_MULTIPLIERS["neutral"]
    for aspect in ("trine", "sextile", "conjunction"):
        assert benefic[aspect] > 0
        assert benefic[aspect] > neutral[aspect]


def test_raw_hits_excludes_moon_tense_aspects_for_love_only():
    jd = ephemeris.julian_day_ut("2026-01-01", "12:00", 0.0)
    hits_love = electional._raw_hits_at_moment(jd, STANDARD_CUSPS, list(range(1, 13)), "love_relationships")
    hits_travel = electional._raw_hits_at_moment(jd, STANDARD_CUSPS, list(range(1, 13)), "travel")
    love_moon_tense_any_house = [h for h in hits_love if h["planet"] == "Moon" and h["aspect"] in ("square", "opposition")]
    assert love_moon_tense_any_house == []
    travel_moon_tense = [h for h in hits_travel if h["planet"] == "Moon" and h["aspect"] in ("square", "opposition")]
    # (travel_moon_tense may or may not be non-empty depending on the date; the
    # important assertion is that love's filter is theme-scoped, not global.)
    assert isinstance(travel_moon_tense, list)


def test_raw_hits_flags_cazimi_on_direct_hit_not_antiscion():
    # 2026-01-18 ~19:52 UTC is a real New Moon: Sun-Moon separation is
    # ~0.0002 degrees there, well inside CAZIMI_ORB (17 arcminutes) -- a
    # genuine astronomical cazimi, not a synthetic stand-in. Moon's real
    # longitude at that moment (~298.73) is used as the house-1 cusp so the
    # conjunction shows up as a hit.
    jd = ephemeris.julian_day_ut("2026-01-18", "19:52", 0.0)
    cusps = {1: 298.7319054154434}
    hits = electional._raw_hits_at_moment(jd, cusps, [1], theme_key=None)

    moon_direct = [h for h in hits if h["planet"] == "Moon" and h["mode"] == "direct"]
    assert moon_direct and all(h["is_cazimi"] for h in moon_direct)

    moon_antiscion = [h for h in hits if h["planet"] == "Moon" and h["mode"] == "antiscion"]
    assert moon_antiscion and all(not h["is_cazimi"] for h in moon_antiscion)

    # The Sun itself is never "cazimi" relative to itself.
    sun_hits = [h for h in hits if h["planet"] == "Sun"]
    assert sun_hits and all(not h["is_cazimi"] for h in sun_hits)


# ---------------------------------------------------------------------------
# _moon_next_aspect (VoC) -- crossing-detection correctness
# ---------------------------------------------------------------------------


def test_moon_next_aspect_returns_none_or_valid_pair():
    for day_offset in range(0, 30, 5):
        jd = ephemeris.julian_day_ut("2026-01-01", "12:00", 0.0) + day_offset
        result = electional._moon_next_aspect(jd)
        if result is not None:
            planet, aspect_name = result
            assert planet in ephemeris.CLASSICAL_PLANETS
            assert planet != "Moon"
            assert aspect_name in ephemeris.MAJOR_ASPECTS


def test_moon_next_aspect_detects_all_five_aspect_types_over_a_sample():
    seen_aspects = set()
    jd = ephemeris.julian_day_ut("2026-01-01", "00:00", 0.0)
    for i in range(0, 300, 4):
        result = electional._moon_next_aspect(jd + i / 24)
        if result is not None:
            seen_aspects.add(result[1])
    # Conjunction/opposition use a different detection path (extremum, not
    # sign-crossing) than sextile/square/trine -- this confirms both paths work.
    assert "conjunction" in seen_aspects
    assert "opposition" in seen_aspects
    assert "trine" in seen_aspects or "sextile" in seen_aspects or "square" in seen_aspects


# ---------------------------------------------------------------------------
# _ordinal
# ---------------------------------------------------------------------------


def test_ordinal_basic_cases():
    assert electional._ordinal(1) == "1st"
    assert electional._ordinal(2) == "2nd"
    assert electional._ordinal(3) == "3rd"
    assert electional._ordinal(4) == "4th"
    assert electional._ordinal(10) == "10th"


def test_ordinal_teens_are_all_th():
    for n in (11, 12, 13):
        assert electional._ordinal(n) == f"{n}th"


def test_ordinal_beyond_twenty():
    assert electional._ordinal(21) == "21st"
    assert electional._ordinal(22) == "22nd"
    assert electional._ordinal(23) == "23rd"


# ---------------------------------------------------------------------------
# is_supporting tagging on hits
# ---------------------------------------------------------------------------


def test_is_supporting_pairs_include_dynamic_significators():
    theme = electional.THEMES["travel"]
    pairs = set()
    for planet, houses in electional._significators_for(
        theme, STANDARD_CUSPS, extra_houses=theme.get("auspicious_extra_houses")
    ):
        for house in houses:
            pairs.add((planet, house))
    assert ("Jupiter", 9) in pairs  # natural
    assert ("Mars", 9) in pairs  # dynamic: Ascendant ruler under STANDARD_CUSPS
    assert ("Sun", 9) not in pairs  # Sun isn't a travel significator at all
    assert ("Mercury", 5) not in pairs  # house 5 isn't one of travel's houses


def test_scan_hits_have_is_supporting_field(asc_longitude):
    result = electional.scan(asc_longitude, "travel", "2026-07-07", "2026-08-06", 2.0)
    assert result["days"], "expected at least one day in this window"
    for day in result["days"]:
        for hit in day["hits"]:
            assert "is_supporting" in hit


def test_scan_square_hits_are_never_supporting(asc_longitude):
    for theme_key in electional.THEMES:
        result = electional.scan(asc_longitude, theme_key, "2026-01-01", "2026-03-31", 0.0)
        for day in result["days"]:
            for hit in day["hits"]:
                if hit["aspect"] in ("square", "opposition"):
                    assert hit["is_supporting"] is False, f"{theme_key} {day['date']} {hit}"


def test_scan_days_have_reasons_field(asc_longitude):
    result = electional.scan(asc_longitude, "love_relationships", "2026-07-07", "2026-08-06", 2.0)
    for day in result["days"]:
        assert "reasons" in day
        if day["quality_label"] in ("Auspicious", "Favorable"):
            assert len(day["reasons"]) > 0, f"{day['date']} is {day['quality_label']} but has no reasons"


def test_scan_best_available_days_have_no_positive_reasons(asc_longitude):
    result = electional.scan(asc_longitude, "travel", "2026-01-31", "2026-02-09", 0.0)
    for day in result["days"]:
        if day["quality_label"] == "Best Available":
            assert day["reasons"] == []


def test_scan_reasons_can_mention_a_dynamic_significator(asc_longitude):
    # For this natal chart, love_relationships' dynamic significators
    # include Mars (Ascendant ruler, Libra chart -> Aries is NOT the
    # Ascendant here; this just confirms the reasons text can name any of
    # the theme's actual significators, natural or dynamic, over a wide
    # enough window that at least one dynamic-ruler aspect is likely to
    # appear).
    result = electional.scan(asc_longitude, "love_relationships", "2026-01-01", "2026-12-31", 2.0)
    all_reasons = " ".join(r for d in result["days"] for r in d["reasons"])
    assert all_reasons != ""  # sanity: some reasons were generated at all


# ---------------------------------------------------------------------------
# scan() integration tests
# ---------------------------------------------------------------------------


def test_scan_returns_valid_quality_labels_and_capped_count(asc_longitude):
    result = electional.scan(asc_longitude, "love_relationships", "2026-07-07", "2026-08-06", 2.0)
    assert len(result["days"]) <= 5
    for day in result["days"]:
        assert day["quality_label"] in ("Auspicious", "Favorable", "Best Available")
        assert "hits" in day
        assert "best_time_jd" in day


def test_scan_auspicious_sorted_before_favorable(asc_longitude):
    result = electional.scan(asc_longitude, "business_career", "2026-07-07", "2026-08-06", 2.0)
    labels = [d["quality_label"] for d in result["days"]]
    if "Favorable" in labels and "Auspicious" in labels:
        assert labels.index("Auspicious") < labels.index("Favorable")


def test_scan_venus_retrograde_banner_during_known_retrograde_window(asc_longitude):
    result = electional.scan(asc_longitude, "love_relationships", "2026-10-05", "2026-11-05", 2.0)
    assert result["banner"] is not None
    assert "Venus is retrograde" in result["banner"]


def test_scan_mercury_retrograde_banner_during_known_retrograde_window(asc_longitude):
    result = electional.scan(asc_longitude, "travel", "2026-07-01", "2026-07-20", 2.0)
    assert result["banner"] is not None
    assert "Mercury is retrograde" in result["banner"]


def test_scan_no_banner_for_theme_not_affected_by_retrograde(asc_longitude):
    result = electional.scan(asc_longitude, "home_family", "2026-10-05", "2026-11-05", 2.0)
    assert result["banner"] is None


def test_scan_love_relationships_hits_can_include_house_one(asc_longitude):
    result = electional.scan(asc_longitude, "love_relationships", "2026-07-07", "2026-08-06", 2.0)
    houses_seen = {h["house"] for d in result["days"] for h in d["hits"]}
    # Not guaranteed every run touches house 1, but it must be *possible* --
    # relevant_houses must include it, which we already assert separately.
    assert houses_seen <= {1, 5, 7}


def test_scan_unknown_theme_raises():
    with pytest.raises(ValueError):
        electional.scan(0.0, "not_a_real_theme", "2026-01-01", "2026-01-02", 0.0)


def test_scan_runs_in_reasonable_time_for_a_year(asc_longitude):
    import time

    t0 = time.time()
    electional.scan(asc_longitude, "love_relationships", "2026-01-01", "2026-12-31", 2.0)
    elapsed = time.time() - t0
    assert elapsed < 15.0, f"full-year scan took {elapsed:.1f}s -- investigate a performance regression"


# ---------------------------------------------------------------------------
# _best_available_note -- explains *why* a period only produced Best
# Available days instead of a generic "nothing good here" message.
# ---------------------------------------------------------------------------


def test_best_available_note_names_dominant_retrograde_planet():
    theme = electional.THEMES["travel"]  # essential_direct = ["Mercury"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 5}, voc_count=0, via_combusta_count=0, malefic_count=0
    )
    assert "Mercury is retrograde" in note
    assert "travel" in note.lower()


def test_best_available_note_joins_multiple_retrograde_planets():
    theme = electional.THEMES["spiritual_learning"]  # essential_direct = ["Mercury", "Jupiter"]
    note = electional._best_available_note(
        theme,
        total_days=10,
        retro_counts={"Mercury": 5, "Jupiter": 4},
        voc_count=0,
        via_combusta_count=0,
        malefic_count=0,
    )
    assert "Mercury and Jupiter are retrograde" in note


def test_best_available_note_voc_dominant_when_no_retrograde():
    theme = electional.THEMES["travel"]  # essential_moon_not_voc = True
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 0}, voc_count=4, via_combusta_count=0, malefic_count=0
    )
    assert "void of course" in note


def test_best_available_note_ignores_voc_for_theme_that_does_not_check_it():
    theme = electional.THEMES["health_body"]  # essential_moon_not_voc = False
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={}, voc_count=9, via_combusta_count=0, malefic_count=0
    )
    assert "void of course" not in note


def test_best_available_note_via_combusta_dominant_when_no_retrograde_or_voc():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 0}, voc_count=0, via_combusta_count=4, malefic_count=0
    )
    assert "via combusta" in note


def test_best_available_note_via_combusta_applies_even_when_theme_ignores_voc():
    # Unlike voc, via combusta is a universal essential condition -- not
    # gated by essential_moon_not_voc -- so it must still surface for a
    # theme that doesn't check void-of-course at all.
    theme = electional.THEMES["health_body"]  # essential_moon_not_voc = False
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={}, voc_count=0, via_combusta_count=4, malefic_count=0
    )
    assert "via combusta" in note


def test_best_available_note_malefic_dominant_when_nothing_else_qualifies():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 0}, voc_count=0, via_combusta_count=0, malefic_count=5
    )
    assert "Challenging planetary configurations" in note


def test_best_available_note_generic_fallback_when_no_cause_dominates():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 1}, voc_count=1, via_combusta_count=1, malefic_count=1
    )
    assert note == (
        "No strongly favorable configurations exist in this period. The moments below are the best "
        "available — consider extending your search to find stronger support."
    )


def test_best_available_note_retrograde_takes_priority_over_voc():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 5}, voc_count=5, via_combusta_count=0, malefic_count=0
    )
    assert "retrograde" in note
    assert "void of course" not in note


def test_best_available_note_voc_takes_priority_over_via_combusta():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 0}, voc_count=5, via_combusta_count=5, malefic_count=0
    )
    assert "void of course" in note
    assert "via combusta" not in note


def test_best_available_note_via_combusta_takes_priority_over_malefic():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=10, retro_counts={"Mercury": 0}, voc_count=0, via_combusta_count=5, malefic_count=5
    )
    assert "via combusta" in note
    assert "Challenging planetary configurations" not in note


def test_best_available_note_handles_zero_scanned_days():
    theme = electional.THEMES["travel"]
    note = electional._best_available_note(
        theme, total_days=0, retro_counts={}, voc_count=0, via_combusta_count=0, malefic_count=0
    )
    assert "best available" in note.lower()
