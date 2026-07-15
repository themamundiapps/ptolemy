"""Daily transits: current planetary positions compared against a natal chart."""
from datetime import datetime, timezone

import swisseph as swe

from . import ephemeris

# Orb allowed for a transiting planet's aspect to any natal point. Unlike
# natal-to-natal aspects (ephemeris.ASPECT_ORBS, averaged between both
# bodies), a transit orb is tighter and keyed only by the transiting body --
# it's the transiting planet's speed and current exactness that determines
# how long a transit lasts, not the natal planet's own orb allowance.
TRANSIT_ORBS = {
    "Sun": 2,
    "Moon": 1,
    "Mercury": 2,
    "Venus": 2,
    "Mars": 3,
    "Jupiter": 5,
    "Saturn": 5,
}

ASPECT_SYMBOLS = {
    "conjunction": "☌",
    "sextile": "⚹",
    "square": "□",
    "trine": "△",
    "opposition": "☍",
}

HARMONIOUS_ASPECTS = {"conjunction", "sextile", "trine"}


def current_julian_day_ut() -> float:
    now = datetime.now(timezone.utc)
    decimal_hour = now.hour + now.minute / 60.0 + now.second / 3600.0
    return swe.julday(now.year, now.month, now.day, decimal_hour)


def moon_phase_name(phase_angle: float) -> str:
    """8-phase name from the Moon-Sun angle (0 = new, 180 = full).

    Deliberately distinct from temperament.moon_phase(), which buckets into
    only 4 coarse quarters for elemental-quality purposes -- this is the
    familiar everyday 8-phase name meant for display to users.
    """
    boundaries = [
        (45, "New Moon"),
        (90, "Waxing Crescent"),
        (135, "First Quarter"),
        (180, "Waxing Gibbous"),
        (225, "Full Moon"),
        (270, "Waning Gibbous"),
        (315, "Last Quarter"),
    ]
    for limit, name in boundaries:
        if phase_angle < limit:
            return name
    return "Waning Crescent"


def _is_applying(jd_ut: float, transiting_body_id: int, natal_lon: float, aspect_angle: float) -> bool:
    """An aspect is applying if its orb to this same aspect angle is smaller
    one hour from now than it is right now -- i.e. the transiting body is
    moving toward exactness rather than away from it. Only the transiting
    body moves in this comparison; the natal point is fixed."""
    now_lon, _ = ephemeris.calc_planet(jd_ut, transiting_body_id)
    later_lon, _ = ephemeris.calc_planet(jd_ut + 1 / 24, transiting_body_id)
    now_orb = abs(ephemeris.angular_separation(now_lon, natal_lon) - aspect_angle)
    later_orb = abs(ephemeris.angular_separation(later_lon, natal_lon) - aspect_angle)
    return later_orb < now_orb


def find_transits(natal_longitudes: dict[str, float], jd_ut: float) -> list[dict]:
    """Every transiting classical planet's major aspects to every natal
    classical planet, within TRANSIT_ORBS, sorted by exactness (smallest
    orb first)."""
    hits = []
    for transiting_name, transiting_id in ephemeris.CLASSICAL_PLANETS.items():
        transiting_lon, _ = ephemeris.calc_planet(jd_ut, transiting_id)
        allowed_orb = TRANSIT_ORBS[transiting_name]
        for natal_name, natal_lon in natal_longitudes.items():
            separation = ephemeris.angular_separation(transiting_lon, natal_lon)
            match = ephemeris.best_aspect_match(separation, allowed_orb)
            if match is None:
                continue
            aspect_name, orb = match
            aspect_angle = ephemeris.MAJOR_ASPECTS[aspect_name]
            hits.append(
                {
                    "transiting_planet": transiting_name,
                    "natal_planet": natal_name,
                    "aspect": aspect_name,
                    "aspect_symbol": ASPECT_SYMBOLS[aspect_name],
                    "orb": round(orb, 2),
                    "is_applying": _is_applying(jd_ut, transiting_id, natal_lon, aspect_angle),
                    "interpretation_key": f"{transiting_name.lower()}_{natal_name.lower()}",
                    "is_harmonious": aspect_name in HARMONIOUS_ASPECTS,
                }
            )
    hits.sort(key=lambda h: h["orb"])
    return hits
