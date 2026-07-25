"""Shared natal-chart computation (positions, dignities, temperament) used by
every endpoint that needs a full nativity rather than just the raw /positions
response -- /chart/analysis, /chart/synastry, and /chat/astrologer.
"""
from app.models.schemas import ZodiacPosition
from app.services import ephemeris, temperament
from app.services import timezone as tz_resolver


def resolve_tz_offset(birth) -> float:
    """birth: any object with .tz_offset/.latitude/.longitude/.date/.time
    attributes -- ChartRequest, SynastryPersonRequest, and ChatAstrologerRequest
    all satisfy this structurally, so this works for any of them without a
    shared base class."""
    if birth.tz_offset is not None:
        return birth.tz_offset
    try:
        _timezone_id, tz_offset = tz_resolver.resolve_utc_offset(birth.latitude, birth.longitude, birth.date, birth.time)
    except tz_resolver.TimezoneLookupError as e:
        raise ValueError(str(e)) from e
    return tz_offset


def compute_natal(date: str, time: str, latitude: float, longitude: float, tz_offset: float) -> dict:
    jd_ut = ephemeris.julian_day_ut(date, time, tz_offset)
    asc_lon, mc_lon = ephemeris.calc_angles(jd_ut, latitude, longitude)
    asc_sign, _asc_deg = ephemeris.sign_and_degree(asc_lon)
    mc_sign, _mc_deg = ephemeris.sign_and_degree(mc_lon)

    planets: dict[str, ZodiacPosition] = {}
    planet_dicts: dict[str, dict] = {}
    for name, body_id in ephemeris.CLASSICAL_PLANETS.items():
        lon, retrograde = ephemeris.calc_planet(jd_ut, body_id)
        sign, deg = ephemeris.sign_and_degree(lon)
        house = ephemeris.whole_sign_house(lon, asc_lon)
        planets[name] = ZodiacPosition(
            longitude=lon,
            sign=sign,
            sign_longitude=deg,
            house=house,
            retrograde=retrograde,
            dignities=ephemeris.essential_dignities(name, sign),
        )
        planet_dicts[name] = {"longitude": lon, "sign": sign, "house": house}

    diurnal = ephemeris.is_diurnal(planets["Sun"].house)
    sun_lon = planets["Sun"].longitude
    moon_lon = planets["Moon"].longitude

    temperament_result = temperament.calculate(
        asc_sign=asc_sign,
        planets=planet_dicts,
        sun_longitude=sun_lon,
        moon_longitude=moon_lon,
    )

    return {
        "jd_ut": jd_ut,
        "asc_lon": asc_lon,
        "asc_sign": asc_sign,
        "mc_lon": mc_lon,
        "mc_sign": mc_sign,
        "planets": planets,
        "diurnal": diurnal,
        "sun_lon": sun_lon,
        "moon_lon": moon_lon,
        "temperament_label": temperament_result["temperament"],
    }
