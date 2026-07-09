from fastapi import APIRouter, HTTPException

from app.models.schemas import Aspect, ChartRequest, ChartResponse, ZodiacPosition
from app.services import ephemeris, timezone as tz_resolver

router = APIRouter(prefix="/chart", tags=["chart"])


@router.post("/positions", response_model=ChartResponse)
def get_positions(request: ChartRequest) -> ChartResponse:
    if request.tz_offset is not None:
        timezone_id = None
        tz_offset = request.tz_offset
        tz_source = "manual"
    else:
        try:
            timezone_id, tz_offset = tz_resolver.resolve_utc_offset(
                request.latitude, request.longitude, request.date, request.time
            )
        except tz_resolver.TimezoneLookupError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        tz_source = "auto"

    jd_ut = ephemeris.julian_day_ut(request.date, request.time, tz_offset)

    asc_lon, mc_lon = ephemeris.calc_angles(jd_ut, request.latitude, request.longitude)
    asc_sign, asc_deg = ephemeris.sign_and_degree(asc_lon)
    ascendant = ZodiacPosition(
        longitude=asc_lon,
        sign=asc_sign,
        sign_longitude=asc_deg,
        house=1,
    )

    mc_sign, mc_deg = ephemeris.sign_and_degree(mc_lon)
    midheaven = ZodiacPosition(
        longitude=mc_lon,
        sign=mc_sign,
        sign_longitude=mc_deg,
        house=ephemeris.whole_sign_house(mc_lon, asc_lon),
    )

    planets: dict[str, ZodiacPosition] = {}
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

    diurnal = ephemeris.is_diurnal(planets["Sun"].house)
    sun_lon = planets["Sun"].longitude
    moon_lon = planets["Moon"].longitude

    fortune_lon = ephemeris.lot_of_fortune(asc_lon, sun_lon, moon_lon, diurnal)
    fortune_sign, fortune_deg = ephemeris.sign_and_degree(fortune_lon)
    lot_of_fortune = ZodiacPosition(
        longitude=fortune_lon,
        sign=fortune_sign,
        sign_longitude=fortune_deg,
        house=ephemeris.whole_sign_house(fortune_lon, asc_lon),
    )

    spirit_lon = ephemeris.lot_of_spirit(asc_lon, sun_lon, moon_lon, diurnal)
    spirit_sign, spirit_deg = ephemeris.sign_and_degree(spirit_lon)
    lot_of_spirit = ZodiacPosition(
        longitude=spirit_lon,
        sign=spirit_sign,
        sign_longitude=spirit_deg,
        house=ephemeris.whole_sign_house(spirit_lon, asc_lon),
    )

    planet_longitudes = {name: pos.longitude for name, pos in planets.items()}
    angle_longitudes = {
        "ASC": asc_lon,
        "DSC": (asc_lon + 180) % 360,
        "MC": mc_lon,
        "IC": (mc_lon + 180) % 360,
    }
    aspects = [Aspect(**a) for a in ephemeris.find_aspects(planet_longitudes)]
    aspects += [Aspect(**a) for a in ephemeris.find_planet_angle_aspects(planet_longitudes, angle_longitudes)]
    aspects.sort(key=lambda a: a.orb)

    return ChartResponse(
        julian_day_ut=jd_ut,
        sect="diurnal" if diurnal else "nocturnal",
        timezone_id=timezone_id,
        utc_offset_used=tz_offset,
        tz_source=tz_source,
        ascendant=ascendant,
        midheaven=midheaven,
        planets=planets,
        lot_of_fortune=lot_of_fortune,
        lot_of_spirit=lot_of_spirit,
        aspects=aspects,
    )
