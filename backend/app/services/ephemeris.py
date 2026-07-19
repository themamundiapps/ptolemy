"""Swiss Ephemeris calculations: planetary positions, Ascendant, and Arabic lots."""
from datetime import datetime
from pathlib import Path

import swisseph as swe

ZODIAC_SIGNS = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
]

# The 7 classical (visible) planets only, mapped to swisseph body IDs.
CLASSICAL_PLANETS = {
    "Sun": swe.SUN,
    "Moon": swe.MOON,
    "Mercury": swe.MERCURY,
    "Venus": swe.VENUS,
    "Mars": swe.MARS,
    "Jupiter": swe.JUPITER,
    "Saturn": swe.SATURN,
}

# Use the built-in Moshier analytical ephemeris so no external .se1 data
# files are required to get the test endpoint running. If a Swiss Ephemeris
# data directory is present at backend/ephe, prefer the higher-precision
# SWIEPH files instead.
_EPHE_DIR = Path(__file__).resolve().parent.parent.parent / "ephe"
if _EPHE_DIR.is_dir():
    swe.set_ephe_path(str(_EPHE_DIR))
    _CALC_FLAG = swe.FLG_SWIEPH
else:
    _CALC_FLAG = swe.FLG_MOSEPH

# SEFLG_SPEED must be requested explicitly or swisseph leaves the speed
# fields at 0.0 — without it, retrograde detection (lon_speed < 0) silently
# always returns False.
_CALC_FLAG |= swe.FLG_SPEED


def julian_day_ut(date: str, time: str, tz_offset: float) -> float:
    """Convert a local date/time + UTC offset into a Julian Day (UT)."""
    dt = datetime.strptime(f"{date} {time}", "%Y-%m-%d %H:%M")
    decimal_hour = dt.hour + dt.minute / 60.0 - tz_offset
    return swe.julday(dt.year, dt.month, dt.day, decimal_hour)


def sign_and_degree(longitude: float) -> tuple[str, float]:
    longitude = longitude % 360.0
    sign_index = int(longitude // 30)
    return ZODIAC_SIGNS[sign_index], longitude - sign_index * 30


def whole_sign_house(longitude: float, asc_longitude: float) -> int:
    """Whole-sign house: house 1 = the sign the Ascendant occupies."""
    asc_sign = int((asc_longitude % 360.0) // 30)
    body_sign = int((longitude % 360.0) // 30)
    return (body_sign - asc_sign) % 12 + 1


def house_sign(house_number: int, asc_longitude: float) -> str:
    """The sign occupying a given whole-sign house -- the inverse of
    whole_sign_house(): house 1 is the Ascendant's own sign, house 2 the
    next sign along, etc."""
    asc_sign = int((asc_longitude % 360.0) // 30)
    return ZODIAC_SIGNS[(asc_sign + house_number - 1) % 12]


def calc_angles(jd_ut: float, latitude: float, longitude: float) -> tuple[float, float]:
    """Returns (Ascendant, Midheaven) ecliptic longitudes.

    Both are computed from the same swe.houses call regardless of house
    system requested ('W' for whole-sign here), since ascmc[0]/[1] are the
    Ascendant/MC proper, independent of how houses are divided. The MC is a
    separate sensitive point from the whole-sign 10th house cusp — in whole
    sign houses the two frequently don't coincide, which is expected.
    """
    _cusps, ascmc = swe.houses(jd_ut, latitude, longitude, b"W")
    return ascmc[0], ascmc[1]


def calc_planet(jd_ut: float, body_id: int) -> tuple[float, bool]:
    """Returns (ecliptic longitude, is_retrograde)."""
    (lon, _lat, _dist, lon_speed, _lat_speed, _dist_speed), _flags = swe.calc_ut(
        jd_ut, body_id, _CALC_FLAG
    )
    return lon, lon_speed < 0


# Traditional (Ptolemaic) essential dignities: sign(s) ruled by each planet
# for each dignity type. Note some planets (e.g. Mercury in Virgo) hold two
# dignities in the same sign at once.
ESSENTIAL_DIGNITIES = {
    "Sun": {
        "domicile": ["Leo"],
        "exaltation": ["Aries"],
        "detriment": ["Aquarius"],
        "fall": ["Libra"],
    },
    "Moon": {
        "domicile": ["Cancer"],
        "exaltation": ["Taurus"],
        "detriment": ["Capricorn"],
        "fall": ["Scorpio"],
    },
    "Mercury": {
        "domicile": ["Gemini", "Virgo"],
        "exaltation": ["Virgo"],
        "detriment": ["Sagittarius", "Pisces"],
        "fall": ["Pisces"],
    },
    "Venus": {
        "domicile": ["Taurus", "Libra"],
        "exaltation": ["Pisces"],
        "detriment": ["Aries", "Scorpio"],
        "fall": ["Virgo"],
    },
    "Mars": {
        "domicile": ["Aries", "Scorpio"],
        "exaltation": ["Capricorn"],
        "detriment": ["Taurus", "Libra"],
        "fall": ["Cancer"],
    },
    "Jupiter": {
        "domicile": ["Sagittarius", "Pisces"],
        "exaltation": ["Cancer"],
        "detriment": ["Gemini", "Virgo"],
        "fall": ["Capricorn"],
    },
    "Saturn": {
        "domicile": ["Capricorn", "Aquarius"],
        "exaltation": ["Libra"],
        "detriment": ["Cancer", "Leo"],
        "fall": ["Aries"],
    },
}


def essential_dignities(planet: str, sign: str) -> list[str]:
    """Returns every dignity (domicile/exaltation/detriment/fall) the planet holds in this sign."""
    table = ESSENTIAL_DIGNITIES[planet]
    return [dignity for dignity, signs in table.items() if sign in signs]


# Traditional domicile ruler of each sign (7 classical planets only -- no
# modern outer-planet rulerships). Doubles as the inverse of
# ESSENTIAL_DIGNITIES' "domicile" entries, kept as its own direct sign->planet
# table since house-lord calculation looks it up by sign far more often than
# essential_dignities() looks it up by planet.
SIGN_RULERS = {
    "Aries": "Mars",
    "Taurus": "Venus",
    "Gemini": "Mercury",
    "Cancer": "Moon",
    "Leo": "Sun",
    "Virgo": "Mercury",
    "Libra": "Venus",
    "Scorpio": "Mars",
    "Sagittarius": "Jupiter",
    "Capricorn": "Saturn",
    "Aquarius": "Saturn",
    "Pisces": "Jupiter",
}


def sign_ruler(sign: str) -> str:
    return SIGN_RULERS[sign]


# Major aspects and the angle (in degrees) each represents.
MAJOR_ASPECTS = {
    "conjunction": 0,
    "sextile": 60,
    "square": 90,
    "trine": 120,
    "opposition": 180,
}

# Traditional orb per planet; the orb allowed for an aspect between two
# planets is the average of their two individual orbs.
ASPECT_ORBS = {
    "Sun": 15,
    "Moon": 12,
    "Mercury": 7,
    "Venus": 7,
    "Mars": 8,
    "Jupiter": 9,
    "Saturn": 9,
}


def angular_separation(lon1: float, lon2: float) -> float:
    """Shortest angular distance between two ecliptic longitudes, in [0, 180]."""
    diff = abs(lon1 - lon2) % 360.0
    return min(diff, 360.0 - diff)


def best_aspect_match(separation: float, allowed_orb: float) -> tuple[str, float] | None:
    """The closest major aspect within orb for a given angular separation, if any."""
    best: tuple[str, float] | None = None
    for aspect_name, aspect_angle in MAJOR_ASPECTS.items():
        orb = abs(separation - aspect_angle)
        if orb <= allowed_orb and (best is None or orb < best[1]):
            best = (aspect_name, orb)
    return best


def find_aspects(planet_longitudes: dict[str, float]) -> list[dict]:
    """All major aspects between every pair of planets, within averaged orb."""
    names = list(planet_longitudes.keys())
    aspects = []
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = names[i], names[j]
            separation = angular_separation(planet_longitudes[a], planet_longitudes[b])
            allowed_orb = (ASPECT_ORBS[a] + ASPECT_ORBS[b]) / 2

            match = best_aspect_match(separation, allowed_orb)
            if match is not None:
                aspect_name, orb = match
                aspects.append(
                    {
                        "planet_a": a,
                        "planet_b": b,
                        "aspect": aspect_name,
                        "angle": separation,
                        "orb": orb,
                    }
                )
    return aspects


def find_planet_angle_aspects(
    planet_longitudes: dict[str, float], angle_longitudes: dict[str, float]
) -> list[dict]:
    """Aspects between each planet and each chart angle (ASC/DSC/MC/IC).

    Angles have no orb of their own in the traditional table, so each pairing
    uses only the planet's individual orb (unlike planet-to-planet aspects,
    which average both bodies' orbs).
    """
    aspects = []
    for planet_name, planet_lon in planet_longitudes.items():
        for angle_name, angle_lon in angle_longitudes.items():
            separation = angular_separation(planet_lon, angle_lon)
            allowed_orb = ASPECT_ORBS[planet_name]

            match = best_aspect_match(separation, allowed_orb)
            if match is not None:
                aspect_name, orb = match
                aspects.append(
                    {
                        "planet_a": planet_name,
                        "planet_b": angle_name,
                        "aspect": aspect_name,
                        "angle": separation,
                        "orb": orb,
                    }
                )
    return aspects


# Synastry orb table -- tighter than natal ASPECT_ORBS since these describe
# a relationship between two separate charts rather than one nativity.
SYNASTRY_ASPECT_ORBS = {
    "Sun": 8,
    "Moon": 8,
    "Mercury": 5,
    "Venus": 5,
    "Mars": 5,
    "Jupiter": 6,
    "Saturn": 6,
}


def find_synastry_aspects(
    longitudes_a: dict[str, float], longitudes_b: dict[str, float]
) -> list[dict]:
    """All major aspects between every planet of chart A and every planet of
    chart B (49 combinations for the 7 classical planets), using the
    synastry orb table, averaged per pair the same way find_aspects() does
    for a single natal chart."""
    aspects = []
    for name_a, lon_a in longitudes_a.items():
        for name_b, lon_b in longitudes_b.items():
            separation = angular_separation(lon_a, lon_b)
            allowed_orb = (SYNASTRY_ASPECT_ORBS[name_a] + SYNASTRY_ASPECT_ORBS[name_b]) / 2

            match = best_aspect_match(separation, allowed_orb)
            if match is not None:
                aspect_name, orb = match
                aspects.append(
                    {
                        "planet_a": name_a,
                        "planet_b": name_b,
                        "aspect": aspect_name,
                        "angle": separation,
                        "orb": orb,
                    }
                )
    return aspects


# Orb for a planet-to-angle synastry aspect (one native's planet against the
# other's Ascendant or Midheaven) -- tighter still than planet-to-planet
# synastry orbs, since an angle is a single sensitive point rather than a
# body with its own averaged tolerance.
SYNASTRY_ANGLE_ASPECT_ORBS = {
    "Sun": 5,
    "Moon": 5,
    "Mercury": 3,
    "Venus": 3,
    "Mars": 3,
    "Jupiter": 4,
    "Saturn": 4,
}


def find_synastry_angle_aspects(
    planet_longitudes: dict[str, float], angle_longitudes: dict[str, float]
) -> list[dict]:
    """Aspects between one native's planets and the *other* native's chart
    angles. [angle_longitudes] is expected to hold just "ASC" and "MC" --
    unlike find_planet_angle_aspects() (used for a single natal chart), DSC
    and IC are deliberately omitted here since they're just the oppositions
    of ASC/MC and would otherwise double-count the same relationship. Not
    averaged with a per-pair orb like the planet-to-planet tables -- an
    angle isn't a body with its own tolerance, so the planet's own orb
    applies directly."""
    aspects = []
    for planet_name, planet_lon in planet_longitudes.items():
        for angle_name, angle_lon in angle_longitudes.items():
            separation = angular_separation(planet_lon, angle_lon)
            allowed_orb = SYNASTRY_ANGLE_ASPECT_ORBS[planet_name]

            match = best_aspect_match(separation, allowed_orb)
            if match is not None:
                aspect_name, orb = match
                aspects.append(
                    {
                        "planet": planet_name,
                        "angle_name": angle_name,
                        "aspect": aspect_name,
                        "angle": separation,
                        "orb": orb,
                    }
                )
    return aspects


def is_diurnal(sun_house: int) -> bool:
    """Sect: Sun above the horizon (whole-sign houses 7-12) = diurnal chart."""
    return sun_house in range(7, 13)


def lot_of_fortune(asc: float, sun: float, moon: float, diurnal: bool) -> float:
    if diurnal:
        return (asc + moon - sun) % 360.0
    return (asc + sun - moon) % 360.0


def lot_of_spirit(asc: float, sun: float, moon: float, diurnal: bool) -> float:
    if diurnal:
        return (asc + sun - moon) % 360.0
    return (asc + moon - sun) % 360.0


def solar_eclipse_dates(start_jd: float, end_jd: float) -> set[str]:
    """Calendar dates (UT) of global solar eclipse maxima within [start_jd, end_jd].

    Used only as a coarse "Sun is not eclipsed" electional check — wrapped in
    a try/except since eclipse finding is a secondary, rarely-triggered
    condition and shouldn't ever break a scan if it fails for some reason.
    """
    dates: set[str] = set()
    try:
        jd = start_jd
        for _ in range(12):
            _retflags, tret = swe.sol_eclipse_when_glob(jd, _CALC_FLAG, 0, False)
            eclipse_jd = tret[0]
            if eclipse_jd > end_jd:
                break
            if eclipse_jd >= start_jd:
                year, month, day, _hour = swe.revjul(eclipse_jd, swe.GREG_CAL)
                dates.add(f"{year:04d}-{month:02d}-{day:02d}")
            jd = eclipse_jd + 1
    except Exception:
        pass
    return dates
