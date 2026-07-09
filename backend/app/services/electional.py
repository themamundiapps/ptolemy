"""Traditional electional astrology — checklist-based system.

Rather than reducing a moment to a single numerical score, each day in the
requested period is judged against a traditional checklist specific to the
chosen theme, in three tiers:

  ESSENTIAL conditions — things that must ALL hold for a day to be usable at
  all (e.g. the relevant planet not retrograde or combust, the Moon not void
  of course or via combusta, no malefic square/opposition to the theme's
  houses). A day that fails any essential condition is excluded from the
  results entirely.

  IMPORTANT conditions — a day that passes all essentials additionally needs
  at least one of these (a significator forming an applying trine, sextile,
  or conjunction with a priority house) to be called "Favorable" rather than
  merely "Best Available". This is the only path to "Favorable" — there is
  no fallback, so a day dominated by tense aspects can never qualify no
  matter how favorable its other circumstances are.

  DESIRABLE conditions — bonus conditions (the Moon waxing, favorable
  planetary day-of-week, Moon applying to a benefic by a harmonious aspect,
  any of the theme's significators in domicile/exaltation) that lift a
  "Favorable" day to "Auspicious" when at least one is present, provided the
  AUSPICIOUS gate (a genuine significator harmonious aspect to the theme's
  core houses) also holds.

The whole checklist is evaluated at each day's own best-scoring hour (found
via the scoring matrix below) rather than a fixed reference time, so a day's
label always matches what's actually true at the moment it recommends — this
matters most for the Moon, whose phase, void-of-course status, and applying
aspect can genuinely change within a single day.

Once the qualifying days are chosen, the traditional benefic/neutral/malefic
x aspect-type scoring matrix is used again, at minute resolution within the
day's best hour, purely to find the exact peak minute and the planetary
"hits" shown in the synthesis paragraph and planetary-details display — it
no longer decides which days appear or their quality label.

The important/auspicious/desirable checks each return a list of plain-
language reasons rather than a bare bool (see _important_reasons,
_auspicious_reasons, _desirable_reasons) — a day's classification is only
as trustworthy as the user's ability to see *why* it earned that label, so
scan() carries those reasons through to the response. Each hit is likewise
tagged 'is_supporting': True only if it's a harmonious aspect from a
(planet, house) pair the theme's rules actually recognize — everything
else (squares/oppositions from any planet, or a nice aspect from a planet
the theme doesn't track) is real astronomy but didn't contribute to the
label, and is presented as such rather than left unexplained.

Two further refinements on top of that:

  APPLICATION vs SEPARATION — an aspect only counts (for the essential
  malefic exclusion, and for the important/auspicious harmonious checks) if
  it is *applying* (the orb to exact is shrinking) rather than *separating*
  (already past peak and fading). This is checked numerically — sample the
  planet's position now and a short time later, compare which side of exact
  it's moving toward — the same forward-difference technique already used
  for void-of-course detection.

  DYNAMIC SIGNIFICATORS — each theme's important/auspicious/desirable
  checks consider not just its fixed *natural* significators (e.g. Venus
  for Love, which governs romance regardless of anyone's chart) but also
  this native's actual *accidental* significators: the traditional ruler of
  the theme's primary house (from the native's own natal Whole Sign houses)
  and the ruler of the native's Ascendant (representing the person
  undertaking the action, checked universally across every theme). Natural
  and accidental rulership are both traditionally considered — the dynamic
  rulers augment the fixed list, they don't replace it.
"""
from datetime import date as date_cls
from datetime import datetime, timedelta

import swisseph as swe

from app.services import ephemeris

THEMES = {
    "love_relationships": {
        "label": "Love & Relationships",
        "essential_direct": ["Venus"],
        "essential_not_combust": ["Venus"],
        "essential_moon_not_voc": True,
        "essential_moon_not_asc_sign": False,
        "essential_no_malefic_houses": [1, 5, 7],
        "essential_no_eclipse": False,
        "important_aspects": [("Venus", [5, 7]), ("Jupiter", [5, 7])],
        "auspicious_extra_houses": [1],
        "primary_house": 7,  # partnership/marriage — the classical house of committed relationships
        "favorable_weekdays": {4, 0},  # Friday, Monday
    },
    "travel": {
        "label": "Travel",
        "essential_direct": ["Mercury"],
        "essential_not_combust": ["Mercury"],
        "essential_moon_not_voc": True,
        "essential_moon_not_asc_sign": False,
        "essential_no_malefic_houses": [3, 9],
        "essential_no_eclipse": False,
        "important_aspects": [("Mercury", [3, 9]), ("Jupiter", [3, 9])],
        "primary_house": 9,  # long journeys — the classical "travel" house
        "favorable_weekdays": {2, 3},  # Wednesday, Thursday
    },
    "business_career": {
        "label": "Business & Career",
        "essential_direct": ["Mercury"],
        "essential_not_combust": [],
        "essential_moon_not_voc": True,
        "essential_moon_not_asc_sign": False,
        "essential_no_malefic_houses": [10, 2],
        "essential_no_eclipse": True,
        "important_aspects": [("Sun", [10, 2]), ("Jupiter", [10, 2])],
        "primary_house": 10,  # career/reputation
        "favorable_weekdays": {3, 6},  # Thursday, Sunday
    },
    "health_body": {
        "label": "Health & Body",
        "essential_direct": [],
        "essential_not_combust": ["Mercury", "Venus"],
        "essential_moon_not_voc": False,
        "essential_moon_not_asc_sign": True,
        "essential_no_malefic_houses": [1, 6],
        "essential_no_eclipse": False,
        "important_aspects": [("Sun", [1, 6]), ("Jupiter", [1, 6])],
        "primary_house": 1,  # the body/self
        "favorable_weekdays": {6, 3},  # Sunday, Thursday
    },
    "spiritual_learning": {
        "label": "Spiritual & Learning",
        "essential_direct": ["Mercury", "Jupiter"],
        "essential_not_combust": [],
        "essential_moon_not_voc": True,
        "essential_moon_not_asc_sign": False,
        "essential_no_malefic_houses": [9, 3],
        "essential_no_eclipse": False,
        "important_aspects": [("Jupiter", [9, 3])],
        "primary_house": 9,  # higher learning, philosophy, wisdom
        "favorable_weekdays": {3, 0},  # Thursday, Monday
    },
    "home_family": {
        "label": "Home & Family",
        "essential_direct": [],
        "essential_not_combust": [],
        "essential_moon_not_voc": True,
        "essential_moon_not_asc_sign": False,
        "essential_no_malefic_houses": [4, 1],
        "essential_no_eclipse": False,
        "important_aspects": [("Moon", [4, 1]), ("Venus", [4, 1])],
        "primary_house": 4,  # home, family, roots
        "favorable_weekdays": {0, 4},  # Monday, Friday
    },
}

PLANET_CATEGORY = {
    "Venus": "benefic",
    "Jupiter": "benefic",
    "Sun": "neutral",
    "Moon": "neutral",
    "Mercury": "neutral",
    "Saturn": "malefic",
    "Mars": "malefic",
}

# Sign -> traditional domicile ruler, derived by inverting
# ephemeris.ESSENTIAL_DIGNITIES rather than hand-writing a second table that
# could drift out of sync with it.
SIGN_RULERS: dict[str, str] = {
    sign: planet for planet, table in ephemeris.ESSENTIAL_DIGNITIES.items() for sign in table["domicile"]
}

# Score multiplier by planet nature and aspect type, used only to pick a
# qualifying day's best hour/minute and to populate its planetary "hits" for
# display/synthesis — no longer what decides which days qualify or their
# quality label (see module docstring). Malefic squares and oppositions are
# deliberately negative so a moment dominated by tense malefic aspects still
# reads as weaker within an already-qualifying day.
ASPECT_MULTIPLIERS = {
    "benefic": {"trine": 3.0, "sextile": 3.0, "conjunction": 2.5, "square": 0.5, "opposition": 0.3},
    "neutral": {"trine": 1.5, "sextile": 1.5, "conjunction": 1.2, "square": 0.4, "opposition": 0.3},
    "malefic": {"trine": 0.5, "sextile": 0.5, "conjunction": 0.2, "square": -1.0, "opposition": -1.5},
}

ANTISCION_FACTOR = 0.8
PRIORITY_HOUSE_MULTIPLIER = 2.0

# Tighter than natal orbs — standard practice in traditional electional work,
# and necessary since Whole Sign cusps sit exactly on 30° multiples, same as
# the major aspects, so wide orbs make almost every planet hit many cusps.
ELECTIONAL_ORBS = {
    "Sun": 7,
    "Moon": 6,
    "Mercury": 3,
    "Venus": 3,
    "Mars": 4,
    "Jupiter": 4,
    "Saturn": 4,
}

# Orbs for the checklist's "important"/"auspicious" harmonious-aspect
# conditions — deliberately wider than ELECTIONAL_ORBS above, which is for
# the separate hits/display/scoring pipeline.
IMPORTANT_ORBS = {
    "Sun": 8,
    "Moon": 8,
    "Mercury": 7,
    "Venus": 7,
    "Mars": 7,
    "Jupiter": 9,
    "Saturn": 7,
}

COMBUSTION_ORB = 8.0
ESSENTIAL_MALEFIC_ORB = 3.0

# Cazimi: a planet within 17 arcminutes of exact conjunction with the Sun is
# traditionally "in the heart of the Sun" — exceptionally empowered, the
# opposite of ordinary combustion, not a milder version of it.
CAZIMI_ORB = 17 / 60

# Via combusta ("the burnt path"): the Moon between 15 Libra and 15 Scorpio,
# a classical caution zone traditionally considered to weaken or corrupt her
# significations — checked as an essential condition for every theme, not
# gated per-theme the way void-of-course is.
VIA_COMBUSTA_START = 195.0
VIA_COMBUSTA_END = 225.0

_WEEKDAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
# Traditional planetary rulers of the days of the week (Chaldean order),
# indexed the same way as Python's date.weekday() (Monday=0 .. Sunday=6) —
# matching the indices already used in each theme's favorable_weekdays set.
_DAY_RULERS = {0: "Moon", 1: "Mars", 2: "Mercury", 3: "Jupiter", 4: "Venus", 5: "Saturn", 6: "Sun"}

HOUSE_NAMES = {
    1: "The Self",
    2: "Wealth & Resources",
    3: "Communication & Travel",
    4: "Home & Family",
    5: "Love & Pleasure",
    6: "Health & Service",
    7: "Partnership & Marriage",
    8: "Death & Inheritance",
    9: "Philosophy & Long Journeys",
    10: "Career & Reputation",
    11: "Friends & Hopes",
    12: "Hidden Matters",
}

_HOUR = 1 / 24
_MINUTE = 1 / 1440
_TOP_DAYS = 5

# Forward-stepping resolution used to determine whether the Moon is void of
# course: does it perfect a major aspect with any classical planet before it
# changes sign, checked in 30-minute increments up to 3 days ahead.
_VOC_STEP = 0.5 / 24
_VOC_MAX_STEPS = 144

# Sextile/square/trine are detected by a genuine sign-crossing of
# (separation - aspect_angle) — the aspect actually became exact somewhere
# in the interval, not merely "close" at one sampled instant. Conjunction
# (0°) and opposition (180°) sit at the boundary of the folded [0, 180]
# separation range, so they can never numerically "cross" the way an
# interior aspect can; they're detected instead as a local closest-approach
# (a trend reversal) landing within this tight orb.
_VOC_BOUNDARY_ORB = 1.0

# Forward-stepping resolution used to determine whether a planet-to-house
# aspect is applying (orb shrinking) or separating (orb growing): sample the
# orb now and again after this many days, and compare.
_APPLICATION_STEP = 0.25  # 6 hours


def house_cusps(asc_longitude: float) -> dict[int, float]:
    """Whole-sign cusps: fixed at 0° of each sign starting from the Ascendant's sign."""
    sign_start = (asc_longitude // 30) * 30
    return {house: (sign_start + (house - 1) * 30) % 360 for house in range(1, 13)}


def _house_ruler(cusps: dict[int, float], house: int) -> str:
    """The traditional domicile ruler of the sign occupying this house, for
    this native's own Whole Sign chart — the "accidental" (chart-specific)
    significator, as opposed to a theme's fixed "natural" significators."""
    sign, _ = ephemeris.sign_and_degree(cusps[house])
    return SIGN_RULERS[sign]


def _theme_houses(theme: dict, extra_houses: list[int] | None = None) -> list[int]:
    houses = {h for _p, hs in theme["important_aspects"] for h in hs}
    if extra_houses:
        houses |= set(extra_houses)
    return sorted(houses)


def _significators_for(
    theme: dict, cusps: dict[int, float], extra_houses: list[int] | None = None
) -> list[tuple[str, list[int]]]:
    """The planets checked for important/auspicious support: the theme's
    fixed natural significators (topic-general, e.g. Venus for Love) PLUS
    this native's actual ruler of the theme's primary house (chart-specific
    significator) PLUS the native's Ascendant ruler (representing the
    person undertaking the action, checked universally regardless of
    theme). Both natural and accidental rulership are traditionally
    considered together — the dynamic rulers augment the fixed list, they
    don't replace it. Duplicates (a dynamic ruler that happens to already be
    a natural significator) are dropped so a day's reasons don't repeat the
    same aspect twice.
    """
    houses = _theme_houses(theme, extra_houses)
    natural_planets = [p for p, _ in theme["important_aspects"]]

    dynamic_planets: list[str] = []
    for planet in (_house_ruler(cusps, theme["primary_house"]), _house_ruler(cusps, 1)):
        if planet not in natural_planets and planet not in dynamic_planets:
            dynamic_planets.append(planet)

    return [(p, houses) for p in natural_planets] + [(p, houses) for p in dynamic_planets]


def _significator_names(theme: dict, cusps: dict[int, float]) -> list[str]:
    """All planets considered significators for this theme, for this native
    — used by the dignity-bonus desirable check. A well-dignified ruler is
    traditionally a positive sign regardless of whether that ruler happens
    to be a benefic or malefic by nature, so this covers every significator,
    not just the benefics."""
    seen: list[str] = []
    for planet, _houses in _significators_for(theme, cusps):
        if planet not in seen:
            seen.append(planet)
    return seen


def _diminishing_weight(count: int) -> float:
    if count == 1:
        return 1.0
    if count == 2:
        return 0.5
    return 0.25


def _applying_from_orbs(orb_now: float, orb_later: float) -> bool:
    """Pure comparison, split out from _is_applying so the applying/
    separating decision itself can be unit tested without needing real
    ephemeris positions: True if the orb shrank between the two samples."""
    return orb_later < orb_now


def _is_applying(jd_ut: float, body_id: int, target_lon: float, aspect_angle: float) -> bool:
    """Whether a transiting body's aspect to a fixed point (a house cusp,
    which doesn't move) is applying (orb shrinking) rather than separating
    (orb growing), found by comparing the orb now to the orb a short time
    later — the same forward-difference technique used for void-of-course
    detection above, just applied to a planet-to-cusp aspect instead of a
    planet-to-planet one."""
    lon_now, _ = ephemeris.calc_planet(jd_ut, body_id)
    orb_now = abs(ephemeris.angular_separation(lon_now, target_lon) - aspect_angle)

    lon_later, _ = ephemeris.calc_planet(jd_ut + _APPLICATION_STEP, body_id)
    orb_later = abs(ephemeris.angular_separation(lon_later, target_lon) - aspect_angle)

    return _applying_from_orbs(orb_now, orb_later)


def _raw_hits_at_moment(
    jd_ut: float, cusps: dict[int, float], relevant_houses: list[int], theme_key: str | None = None
) -> list[dict]:
    """All qualifying hits at this instant, restricted to the theme's relevant
    houses only. Each hit's 'score' here is its raw, undiminished contribution.

    For Love & Relationships, the Moon in square or opposition to a relevant
    house is excluded entirely — a Moon square/opposition isn't favorable for
    romantic matters, so it shouldn't appear in the hits used for scoring,
    synthesis, or the planetary-details display.

    Each hit is also tagged 'is_supporting': True only for a harmonious
    aspect from a (planet, house) pair that actually appears in the theme's
    important/auspicious significators (natural + dynamic) — i.e. one that
    could genuinely have contributed to this day's classification.
    Everything else (squares and oppositions from any planet, or a
    harmonious aspect from a planet the theme doesn't track) is present for
    context but didn't count, and is labeled as such in the UI rather than
    left to look like an unexplained contradiction next to a favorable
    label. This does not additionally require the aspect to be applying —
    'supporting' here just marks the (planet, house) relationship as one
    the theme cares about, matching what was used to classify the day.

    Each hit is also tagged 'is_cazimi': True if that planet is within
    CAZIMI_ORB of exact conjunction with the Sun ("in the heart of the
    Sun") — a traditionally empowering condition, the opposite of ordinary
    combustion, surfaced for display regardless of is_supporting.
    """
    longitudes = {name: ephemeris.calc_planet(jd_ut, body_id)[0] for name, body_id in ephemeris.CLASSICAL_PLANETS.items()}
    sun_lon = longitudes["Sun"]
    hits: list[dict] = []

    supporting_pairs: set[tuple[str, int]] = set()
    if theme_key is not None and theme_key in THEMES:
        theme = THEMES[theme_key]
        for planet, houses in _significators_for(theme, cusps, extra_houses=theme.get("auspicious_extra_houses")):
            for house in houses:
                supporting_pairs.add((planet, house))

    for planet, lon in longitudes.items():
        antiscion = (180 - lon + 360) % 360
        max_orb = ELECTIONAL_ORBS[planet]
        # Cazimi ("in the heart of the Sun") is a planet-to-Sun relationship,
        # not a planet-to-house one — it applies to this planet's direct
        # hits regardless of which house they involve, and never to its
        # antiscion (a mirrored point, not the planet's real body).
        is_cazimi = planet != "Sun" and ephemeris.angular_separation(lon, sun_lon) <= CAZIMI_ORB

        for mode, position in (("direct", lon), ("antiscion", antiscion)):
            for house in sorted(relevant_houses):
                separation = ephemeris.angular_separation(position, cusps[house])
                match = ephemeris.best_aspect_match(separation, max_orb)
                if match is None:
                    continue
                aspect_name, orb = match

                if (
                    theme_key == "love_relationships"
                    and planet == "Moon"
                    and aspect_name in ("square", "opposition")
                ):
                    continue

                proximity = 1 - (orb / max_orb)
                multiplier = ASPECT_MULTIPLIERS[PLANET_CATEGORY[planet]][aspect_name]
                raw_score = multiplier * proximity * PRIORITY_HOUSE_MULTIPLIER
                if mode == "antiscion":
                    raw_score *= ANTISCION_FACTOR

                is_supporting = aspect_name in ("trine", "sextile", "conjunction") and (planet, house) in supporting_pairs

                hits.append(
                    {
                        "planet": planet,
                        "house": house,
                        "house_name": HOUSE_NAMES[house],
                        "aspect": aspect_name,
                        "mode": mode,
                        "orb": orb,
                        "score": raw_score,
                        "is_supporting": is_supporting,
                        "is_cazimi": is_cazimi and mode == "direct",
                    }
                )
    return hits


def _weighted_hits(raw_hits: list[dict], counts_before: dict[str, int]) -> tuple[float, list[dict]]:
    """Applies the per-planet diminishing-returns weight to each hit, given the
    planet's hit tally from earlier in the day. Returns (total_score, hits)."""
    counts = dict(counts_before)
    weighted: list[dict] = []
    total = 0.0
    for hit in raw_hits:
        counts[hit["planet"]] = counts.get(hit["planet"], 0) + 1
        weight = _diminishing_weight(counts[hit["planet"]])
        weighted_score = hit["score"] * weight
        total += weighted_score
        weighted.append({**hit, "score": weighted_score})
    return total, weighted


def jd_to_local_datetime(jd_ut: float, tz_offset: float) -> tuple[str, str]:
    """Converts a Julian Day (UT) to a local (date, time) string pair."""
    local_jd = jd_ut + tz_offset / 24
    year, month, day, hour_decimal = swe.revjul(local_jd, swe.GREG_CAL)
    dt = datetime(year, month, day) + timedelta(hours=hour_decimal)
    return dt.strftime("%Y-%m-%d"), dt.strftime("%H:%M")


def _moon_next_aspect(jd_ut: float) -> tuple[str, str] | None:
    """The (planet, aspect_name) the Moon next perfects before changing sign,
    found by forward-stepping in 30-minute increments (see _VOC_BOUNDARY_ORB
    above for why conjunction/opposition need a different test than the
    other three aspects). Returns None if the Moon is void of course (no
    aspect completes before it leaves its current sign, within a 3-day
    safety cap)."""
    moon_id = ephemeris.CLASSICAL_PLANETS["Moon"]
    other_planets = [(p, b) for p, b in ephemeris.CLASSICAL_PLANETS.items() if p != "Moon"]

    moon_lon, _ = ephemeris.calc_planet(jd_ut, moon_id)
    sign_index = int(moon_lon // 30)

    prev_sep: dict[str, float] = {}
    prev_delta: dict[tuple[str, str], float] = {}
    prev_trend: dict[str, float] = {}
    for planet, body_id in other_planets:
        p_lon, _ = ephemeris.calc_planet(jd_ut, body_id)
        sep = ephemeris.angular_separation(moon_lon, p_lon)
        prev_sep[planet] = sep
        for aspect_name, aspect_angle in ephemeris.MAJOR_ASPECTS.items():
            prev_delta[(planet, aspect_name)] = sep - aspect_angle

    jd = jd_ut
    for _ in range(_VOC_MAX_STEPS):
        jd += _VOC_STEP
        m_lon, _ = ephemeris.calc_planet(jd, moon_id)
        if int(m_lon // 30) != sign_index:
            return None

        for planet, body_id in other_planets:
            p_lon, _ = ephemeris.calc_planet(jd, body_id)
            sep = ephemeris.angular_separation(m_lon, p_lon)
            trend = sep - prev_sep[planet]
            prior_trend = prev_trend.get(planet)

            for aspect_name, aspect_angle in ephemeris.MAJOR_ASPECTS.items():
                delta = sep - aspect_angle
                prev = prev_delta[(planet, aspect_name)]
                if aspect_angle in (0, 180):
                    if prior_trend is not None and prior_trend * trend < 0 and abs(prev) <= _VOC_BOUNDARY_ORB:
                        return planet, aspect_name
                else:
                    if prev == 0.0 or (prev > 0) != (delta > 0):
                        return planet, aspect_name
                prev_delta[(planet, aspect_name)] = delta

            prev_trend[planet] = trend
            prev_sep[planet] = sep
    return None


def _gather_state(jd_ut: float) -> dict:
    lon: dict[str, float] = {}
    retro: dict[str, bool] = {}
    for planet, body_id in ephemeris.CLASSICAL_PLANETS.items():
        l, r = ephemeris.calc_planet(jd_ut, body_id)
        lon[planet] = l
        retro[planet] = r
    next_aspect = _moon_next_aspect(jd_ut)
    return {
        "lon": lon,
        "retro": retro,
        "moon_voc": next_aspect is None,
        "moon_next_aspect": next_aspect,
    }


def _moon_via_combusta(moon_lon: float) -> bool:
    """True if the Moon is between 15 Libra and 15 Scorpio (195-225 degrees
    absolute longitude) — the classical "via combusta" caution zone."""
    return VIA_COMBUSTA_START <= moon_lon < VIA_COMBUSTA_END


def _essential_ok(
    theme: dict,
    state: dict,
    cusps: dict[int, float],
    asc_sign: str,
    date_str: str,
    eclipse_dates: set[str],
    jd_ut: float,
    is_applying_fn=_is_applying,
) -> bool:
    """is_applying_fn defaults to the real ephemeris-backed _is_applying, but
    is overridable — mainly so tests can inject a fixed True/False and
    exercise the surrounding logic deterministically without needing a real
    date where a specific aspect is known to be applying or separating."""
    lon, retro = state["lon"], state["retro"]

    for planet in theme["essential_direct"]:
        if retro[planet]:
            return False

    for planet in theme["essential_not_combust"]:
        separation = ephemeris.angular_separation(lon[planet], lon["Sun"])
        if separation <= CAZIMI_ORB:
            # Cazimi: "in the heart of the Sun" — traditionally exceptionally
            # empowered, the opposite of an affliction, so it's exempted
            # from the combustion exclusion rather than caught by it.
            continue
        if separation < COMBUSTION_ORB:
            return False

    if theme["essential_moon_not_voc"] and state["moon_voc"]:
        return False

    if _moon_via_combusta(lon["Moon"]):
        return False

    if theme["essential_moon_not_asc_sign"]:
        moon_sign, _ = ephemeris.sign_and_degree(lon["Moon"])
        if moon_sign == asc_sign:
            return False

    if _malefic_afflicts_priority_houses(theme, state, cusps, jd_ut, is_applying_fn):
        return False

    if theme["essential_no_eclipse"] and date_str in eclipse_dates:
        return False

    return True


def _malefic_afflicts_priority_houses(
    theme: dict, state: dict, cusps: dict[int, float], jd_ut: float, is_applying_fn=_is_applying
) -> bool:
    """True if an applying malefic (Mars/Saturn) square or opposition afflicts
    one of the theme's essential_no_malefic_houses. Extracted from
    _essential_ok so scan() can also use it as a diagnostic signal for why a
    period only produced Best Available days, without duplicating the
    aspect-matching logic."""
    lon = state["lon"]
    for house in theme["essential_no_malefic_houses"]:
        for malefic in ("Mars", "Saturn"):
            separation = ephemeris.angular_separation(lon[malefic], cusps[house])
            match = ephemeris.best_aspect_match(separation, ESSENTIAL_MALEFIC_ORB)
            if match is not None and match[0] in ("square", "opposition"):
                aspect_angle = ephemeris.MAJOR_ASPECTS[match[0]]
                body_id = ephemeris.CLASSICAL_PLANETS[malefic]
                # A separating malefic affliction has already peaked and is
                # fading — traditionally much less concerning than one still
                # building — so only an applying one disqualifies the day.
                if is_applying_fn(jd_ut, body_id, cusps[house], aspect_angle):
                    return True
    return False


def _ordinal(n: int) -> str:
    if 10 <= n % 100 <= 20:
        suffix = "th"
    else:
        suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suffix}"


def _aspect_reason(planet: str, aspect_name: str, house: int) -> str:
    return f"{planet} is applying to a {aspect_name} with your {_ordinal(house)} house — {HOUSE_NAMES[house]}"


def _important_reasons(
    theme: dict, state: dict, cusps: dict[int, float], jd_ut: float, is_applying_fn=_is_applying
) -> list[str]:
    """Every reason the "important" condition passes — a plain-language
    explanation, not just a bool, so the UI can tell the user what actually
    made a day qualify instead of leaving them to guess from the raw hits.
    Only applying aspects count (see _is_applying) — a separating trine has
    already done its work and isn't traditionally "building toward"
    anything. is_applying_fn is overridable for tests (see _essential_ok)."""
    lon = state["lon"]
    reasons: list[str] = []

    for planet, houses in _significators_for(theme, cusps):
        for house in houses:
            separation = ephemeris.angular_separation(lon[planet], cusps[house])
            match = ephemeris.best_aspect_match(separation, IMPORTANT_ORBS[planet])
            if match is not None and match[0] in ("trine", "sextile", "conjunction"):
                aspect_angle = ephemeris.MAJOR_ASPECTS[match[0]]
                body_id = ephemeris.CLASSICAL_PLANETS[planet]
                if is_applying_fn(jd_ut, body_id, cusps[house], aspect_angle):
                    reasons.append(_aspect_reason(planet, match[0], house))

    return reasons


def _important_ok(theme: dict, state: dict, cusps: dict[int, float], jd_ut: float) -> bool:
    return bool(_important_reasons(theme, state, cusps, jd_ut))


def _auspicious_reasons(
    theme: dict, state: dict, cusps: dict[int, float], jd_ut: float, is_applying_fn=_is_applying
) -> list[str]:
    """The hard gate for "Auspicious": a genuine significator harmonious
    aspect to one of the theme's core houses must be applying. Passing
    "desirable" alone (Moon waxing, a favorable weekday, Moon applying to a
    benefic, or essential dignity) is not enough on its own — without this,
    a day tops out at "Favorable", never "Auspicious"."""
    lon = state["lon"]
    reasons: list[str] = []
    for planet, houses in _significators_for(theme, cusps, extra_houses=theme.get("auspicious_extra_houses")):
        for house in houses:
            separation = ephemeris.angular_separation(lon[planet], cusps[house])
            match = ephemeris.best_aspect_match(separation, IMPORTANT_ORBS[planet])
            if match is not None and match[0] in ("trine", "sextile", "conjunction"):
                aspect_angle = ephemeris.MAJOR_ASPECTS[match[0]]
                body_id = ephemeris.CLASSICAL_PLANETS[planet]
                if is_applying_fn(jd_ut, body_id, cusps[house], aspect_angle):
                    reasons.append(_aspect_reason(planet, match[0], house))
    return reasons


def _auspicious_aspect_ok(theme: dict, state: dict, cusps: dict[int, float], jd_ut: float) -> bool:
    return bool(_auspicious_reasons(theme, state, cusps, jd_ut))


def _desirable_reasons(theme: dict, state: dict, day: date_cls, cusps: dict[int, float]) -> list[str]:
    lon = state["lon"]
    reasons: list[str] = []

    phase = (lon["Moon"] - lon["Sun"]) % 360
    if 0 <= phase < 180:
        reasons.append("The Moon is waxing, traditionally a time of growth and increase")

    if day.weekday() in theme["favorable_weekdays"]:
        ruler = _DAY_RULERS[day.weekday()]
        weekday_name = _WEEKDAY_NAMES[day.weekday()]
        reasons.append(f"{weekday_name} is ruled by {ruler}, traditionally favorable for {theme['label']}")

    next_aspect = state["moon_next_aspect"]
    if next_aspect is not None:
        next_planet, next_aspect_name = next_aspect
        if next_planet in ("Venus", "Jupiter") and next_aspect_name in ("trine", "sextile", "conjunction"):
            reasons.append(f"The Moon is applying to a {next_aspect_name} with {next_planet}")

    for planet in _significator_names(theme, cusps):
        sign, _ = ephemeris.sign_and_degree(lon[planet])
        dignities = ephemeris.essential_dignities(planet, sign)
        if "domicile" in dignities:
            reasons.append(f"{planet} is in its own sign ({sign})")
        elif "exaltation" in dignities:
            reasons.append(f"{planet} is exalted in {sign}")

    return reasons


def _desirable_ok(theme: dict, state: dict, day: date_cls, cusps: dict[int, float]) -> bool:
    return bool(_desirable_reasons(theme, state, day, cusps))


# Fraction-of-scanned-days thresholds above which a Best-Available-only
# result is attributed to that specific cause rather than the generic
# fallback message (see _best_available_note). Void-of-course's and via
# combusta's thresholds are lower than the others because even a "normal"
# period only has the Moon in either condition a modest fraction of the
# time, so a comparatively smaller excess is already notable.
_RETRO_DOMINANT_FRACTION = 0.4
_VOC_DOMINANT_FRACTION = 0.3
_VIA_COMBUSTA_DOMINANT_FRACTION = 0.3
_MALEFIC_DOMINANT_FRACTION = 0.4


def _best_available_note(
    theme: dict,
    total_days: int,
    retro_counts: dict[str, int],
    voc_count: int,
    via_combusta_count: int,
    malefic_count: int,
) -> str:
    """Explains, as specifically as the data allows, why a scan came back
    with only Best Available days — rather than leaving the user with a
    generic "nothing good here" message, name the astrological cause when
    one clearly dominates the scanned window."""
    if total_days == 0:
        return (
            "No strongly favorable configurations exist in this period. The moments below are the best "
            "available — consider extending your search to find stronger support."
        )

    retro_planets = [p for p, count in retro_counts.items() if count / total_days >= _RETRO_DOMINANT_FRACTION]
    if retro_planets:
        planets_str = " and ".join(retro_planets)
        verb = "is" if len(retro_planets) == 1 else "are"
        return (
            f"{planets_str} {verb} retrograde during this period — traditional astrology considers this "
            f"unfavorable for new {theme['label'].lower()} matters. These are the best available moments; "
            "consider extending your search."
        )

    if theme["essential_moon_not_voc"] and voc_count / total_days >= _VOC_DOMINANT_FRACTION:
        return "The Moon is frequently void of course in this window, limiting favorable configurations. Try a different date range."

    if via_combusta_count / total_days >= _VIA_COMBUSTA_DOMINANT_FRACTION:
        return (
            "The Moon is via combusta during much of this period — passing through a traditionally "
            "inauspicious zone of the zodiac. Consider a different date range."
        )

    if malefic_count / total_days >= _MALEFIC_DOMINANT_FRACTION:
        return "Challenging planetary configurations dominate this period. The moments below are the best available — proceed with awareness."

    return (
        "No strongly favorable configurations exist in this period. The moments below are the best "
        "available — consider extending your search to find stronger support."
    )


def scan(
    asc_longitude: float,
    theme_key: str,
    start_date: str,
    end_date: str,
    tz_offset: float,
) -> dict:
    if theme_key not in THEMES:
        raise ValueError(f"Unknown theme: {theme_key}")

    theme = THEMES[theme_key]
    cusps = house_cusps(asc_longitude)
    asc_sign, _ = ephemeris.sign_and_degree(asc_longitude)

    start_date_obj = datetime.strptime(start_date, "%Y-%m-%d").date()
    end_date_obj = datetime.strptime(end_date, "%Y-%m-%d").date()
    n_days = (end_date_obj - start_date_obj).days + 1

    eclipse_dates: set[str] = set()
    if theme["essential_no_eclipse"]:
        start_jd = ephemeris.julian_day_ut(start_date, "12:00", tz_offset)
        end_jd = ephemeris.julian_day_ut(end_date, "12:00", tz_offset)
        eclipse_dates = ephemeris.solar_eclipse_dates(start_jd - 1, end_jd + 1)

    relevant_houses = sorted(
        set(theme["essential_no_malefic_houses"]) | set(_theme_houses(theme, theme.get("auspicious_extra_houses")))
    )
    if not relevant_houses:
        relevant_houses = list(range(1, 13))

    auspicious: list[dict] = []
    favorable: list[dict] = []
    best_available: list[dict] = []
    venus_retro_all = True
    mercury_retro_all = True

    # Diagnostic tallies across every scanned day (not just qualifying
    # ones), used only to explain a Best-Available-only result (see
    # _best_available_note) — never to gate which days qualify.
    total_days_scanned = 0
    retro_counts: dict[str, int] = {p: 0 for p in theme["essential_direct"]}
    voc_count = 0
    via_combusta_count = 0
    malefic_count = 0

    for day_index in range(n_days):
        day_date = start_date_obj + timedelta(days=day_index)
        date_str = day_date.strftime("%Y-%m-%d")
        day_start_jd = ephemeris.julian_day_ut(date_str, "00:00", tz_offset)

        # Hourly scan first, to find the day's best-scoring hour — the
        # checklist below is then evaluated AT that hour (see module
        # docstring) instead of an arbitrary fixed reference time.
        planet_counts: dict[str, int] = {}
        hour_entries = []
        for hour in range(24):
            jd = day_start_jd + hour * _HOUR
            raw_hits = _raw_hits_at_moment(jd, cusps, relevant_houses, theme_key)
            counts_before_hour = dict(planet_counts)
            hour_score, _weighted = _weighted_hits(raw_hits, planet_counts)
            for hit in raw_hits:
                planet_counts[hit["planet"]] = planet_counts.get(hit["planet"], 0) + 1
            hour_entries.append((hour, hour_score, counts_before_hour))

        best_hour, _best_hour_score, baseline_counts = max(hour_entries, key=lambda e: e[1])
        hour_start_jd = day_start_jd + best_hour * _HOUR

        state = _gather_state(hour_start_jd)
        venus_retro_all = venus_retro_all and state["retro"]["Venus"]
        mercury_retro_all = mercury_retro_all and state["retro"]["Mercury"]

        total_days_scanned += 1
        for planet in theme["essential_direct"]:
            if state["retro"][planet]:
                retro_counts[planet] += 1
        if state["moon_voc"]:
            voc_count += 1
        if _moon_via_combusta(state["lon"]["Moon"]):
            via_combusta_count += 1
        if _malefic_afflicts_priority_houses(theme, state, cusps, hour_start_jd):
            malefic_count += 1

        if not _essential_ok(theme, state, cusps, asc_sign, date_str, eclipse_dates, hour_start_jd):
            continue

        important_reasons = _important_reasons(theme, state, cusps, hour_start_jd)
        desirable_reasons = _desirable_reasons(theme, state, day_date, cusps)
        auspicious_reasons = _auspicious_reasons(theme, state, cusps, hour_start_jd)

        day_record = {"date": date_str, "hour_start_jd": hour_start_jd, "baseline_counts": baseline_counts}
        if important_reasons and desirable_reasons and auspicious_reasons:
            auspicious.append({**day_record, "reasons": auspicious_reasons + desirable_reasons})
        elif important_reasons:
            favorable.append({**day_record, "reasons": important_reasons})
        else:
            best_available.append({**day_record, "reasons": []})

    if auspicious or favorable:
        selected = [(d, "Auspicious") for d in sorted(auspicious, key=lambda r: r["date"])] + [
            (d, "Favorable") for d in sorted(favorable, key=lambda r: r["date"])
        ]
        tier_used = "mixed"
    elif best_available:
        selected = [(d, "Best Available") for d in sorted(best_available, key=lambda r: r["date"])]
        tier_used = "best_available"
    else:
        selected = []
        tier_used = "empty"
    selected = selected[:_TOP_DAYS]

    final = []
    for day_record, quality_label in selected:
        hour_start_jd = day_record["hour_start_jd"]
        baseline_counts = day_record["baseline_counts"]

        best_score = float("-inf")
        best_hits: list[dict] = []
        best_jd = hour_start_jd
        for minute in range(60):
            jd = hour_start_jd + minute * _MINUTE
            raw_hits = _raw_hits_at_moment(jd, cusps, relevant_houses, theme_key)
            minute_score, weighted = _weighted_hits(raw_hits, baseline_counts)
            if minute_score > best_score:
                best_score = minute_score
                best_hits = weighted
                best_jd = jd

        final.append(
            {
                "date": day_record["date"],
                "best_time_jd": best_jd,
                "quality_label": quality_label,
                "reasons": day_record["reasons"],
                "hits": best_hits,
            }
        )

    banner = None
    if theme_key == "love_relationships" and venus_retro_all:
        banner = (
            "Venus is retrograde during this period. Traditional astrology considers this unfavorable "
            "for new romantic beginnings. The moments shown are the best available — better suited for "
            "deepening existing relationships than starting new ones."
        )
    elif theme_key in ("travel", "business_career") and mercury_retro_all:
        banner = (
            "Mercury is retrograde during this period. Traditional astrology advises caution with new "
            "journeys and contracts at this time. Consider extending your search window for stronger options."
        )

    note = None
    if tier_used == "empty":
        note = (
            "No favorable configurations found in this period. Try extending your search to 60 or 90 days — "
            "the chart may offer stronger support in a later window."
        )
    elif tier_used == "best_available":
        note = _best_available_note(
            theme, total_days_scanned, retro_counts, voc_count, via_combusta_count, malefic_count
        )

    return {"days": final, "banner": banner, "note": note}
