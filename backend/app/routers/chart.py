from fastapi import APIRouter, HTTPException

from app.models.schemas import (
    Aspect,
    ChartAnalysisResponse,
    ChartRequest,
    ChartResponse,
    HouseLordEntry,
    HouseLordsResponse,
    ZodiacPosition,
)
from app.services import analysis, ephemeris, temperament
from app.services import timezone as tz_resolver

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


@router.post("/house-lords", response_model=HouseLordsResponse)
def get_house_lords(request: ChartRequest) -> HouseLordsResponse:
    if request.tz_offset is not None:
        tz_offset = request.tz_offset
    else:
        try:
            _timezone_id, tz_offset = tz_resolver.resolve_utc_offset(
                request.latitude, request.longitude, request.date, request.time
            )
        except tz_resolver.TimezoneLookupError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e

    jd_ut = ephemeris.julian_day_ut(request.date, request.time, tz_offset)
    asc_lon, _mc_lon = ephemeris.calc_angles(jd_ut, request.latitude, request.longitude)

    planet_houses: dict[str, int] = {}
    planet_signs: dict[str, str] = {}
    for name, body_id in ephemeris.CLASSICAL_PLANETS.items():
        lon, _retrograde = ephemeris.calc_planet(jd_ut, body_id)
        sign, _deg = ephemeris.sign_and_degree(lon)
        planet_signs[name] = sign
        planet_houses[name] = ephemeris.whole_sign_house(lon, asc_lon)

    entries = []
    for house_number in range(1, 13):
        sign = ephemeris.house_sign(house_number, asc_lon)
        lord = ephemeris.sign_ruler(sign)
        lord_house = planet_houses[lord]
        lord_sign = planet_signs[lord]
        dignities = ephemeris.essential_dignities(lord, lord_sign)
        entries.append(
            HouseLordEntry(
                house_number=house_number,
                sign=sign,
                lord=lord,
                lord_house=lord_house,
                lord_sign=lord_sign,
                lord_dignity=dignities[0] if dignities else None,
                interpretation_key=f"lord_{house_number}_in_{lord_house}",
            )
        )

    return HouseLordsResponse(entries=entries)


@router.post("/analysis", response_model=ChartAnalysisResponse)
def get_chart_analysis(request: ChartRequest) -> ChartAnalysisResponse:
    if request.tz_offset is not None:
        tz_offset = request.tz_offset
    else:
        try:
            _timezone_id, tz_offset = tz_resolver.resolve_utc_offset(
                request.latitude, request.longitude, request.date, request.time
            )
        except tz_resolver.TimezoneLookupError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e

    jd_ut = ephemeris.julian_day_ut(request.date, request.time, tz_offset)
    asc_lon, mc_lon = ephemeris.calc_angles(jd_ut, request.latitude, request.longitude)
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

    season_name, _season_qualities = temperament.season(sun_lon)

    temperament_result = temperament.calculate(
        asc_sign=asc_sign,
        planets=planet_dicts,
        sun_longitude=sun_lon,
        moon_longitude=moon_lon,
    )

    planet_prompt_entries = []
    for name, pos in planets.items():
        # Orientality (rising before/after the Sun) is meaningless for the
        # Sun itself; every other planet reuses the same convention already
        # established by the temperament calculation, rather than a second,
        # possibly-inconsistent definition.
        orientation = "—" if name == "Sun" else ("Oriental" if temperament.is_oriental(pos.longitude, sun_lon) else "Occidental")
        planet_prompt_entries.append(
            {"name": name, "sign": pos.sign, "house": pos.house, "dignities": pos.dignities, "orientation": orientation}
        )

    house_lord_lines = []
    for house_number in range(1, 13):
        sign = ephemeris.house_sign(house_number, asc_lon)
        lord = ephemeris.sign_ruler(sign)
        house_lord_lines.append(f"House {house_number} — Lord: {lord} — in House {planets[lord].house}")

    planet_longitudes = {name: pos.longitude for name, pos in planets.items()}
    aspects = sorted(ephemeris.find_aspects(planet_longitudes), key=lambda a: a["orb"])

    fortune_lon = ephemeris.lot_of_fortune(asc_lon, sun_lon, moon_lon, diurnal)
    fortune_sign, _fortune_deg = ephemeris.sign_and_degree(fortune_lon)
    fortune_house = ephemeris.whole_sign_house(fortune_lon, asc_lon)

    spirit_lon = ephemeris.lot_of_spirit(asc_lon, sun_lon, moon_lon, diurnal)
    spirit_sign, _spirit_deg = ephemeris.sign_and_degree(spirit_lon)
    spirit_house = ephemeris.whole_sign_house(spirit_lon, asc_lon)

    prompt = analysis.build_analysis_prompt(
        ascendant_sign=asc_sign,
        midheaven_sign=mc_sign,
        season=season_name,
        sect="Diurnal" if diurnal else "Nocturnal",
        temperament_label=temperament_result["temperament"],
        planets=planet_prompt_entries,
        house_lord_lines=house_lord_lines,
        aspects=aspects,
        fortune_sign=fortune_sign,
        fortune_house=fortune_house,
        spirit_sign=spirit_sign,
        spirit_house=spirit_house,
    )

    try:
        text = analysis.generate_analysis(prompt)
    except analysis.AnalysisError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    return ChartAnalysisResponse(analysis=text)
