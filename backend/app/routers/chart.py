from fastapi import APIRouter, HTTPException

from app.models.schemas import (
    Aspect,
    ChartAnalysisRequest,
    ChartAnalysisResponse,
    ChartRequest,
    ChartResponse,
    HouseLordEntry,
    HouseLordsResponse,
    MoonPosition,
    SynastryAspect,
    SynastryHouseOverlay,
    SynastryRequest,
    SynastryResponse,
    Transit,
    TransitsRequest,
    TransitsResponse,
    ZodiacPosition,
)
from app.services import analysis, ephemeris, rate_limit, synastry as synastry_service, temperament
from app.services import transits as transits_service
from app.services import timezone as tz_resolver

router = APIRouter(prefix="/chart", tags=["chart"])


def _resolve_tz_offset(birth) -> float:
    """birth: any object with .tz_offset/.latitude/.longitude/.date/.time
    attributes -- ChartRequest and SynastryPersonRequest both satisfy this
    structurally, so this works for either without a shared base class."""
    if birth.tz_offset is not None:
        return birth.tz_offset
    try:
        _timezone_id, tz_offset = tz_resolver.resolve_utc_offset(birth.latitude, birth.longitude, birth.date, birth.time)
    except tz_resolver.TimezoneLookupError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return tz_offset


def _compute_natal(date: str, time: str, latitude: float, longitude: float, tz_offset: float) -> dict:
    """Shared natal-chart computation (positions, dignities, temperament)
    used by both /chart/analysis (one nativity) and /chart/synastry (two)."""
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
def get_chart_analysis(request: ChartAnalysisRequest) -> ChartAnalysisResponse:
    if not rate_limit.check_and_consume(request.user_id):
        raise HTTPException(status_code=429, detail=rate_limit.LIMIT_MESSAGE)

    tz_offset = _resolve_tz_offset(request)
    native = _compute_natal(request.date, request.time, request.latitude, request.longitude, tz_offset)

    asc_lon = native["asc_lon"]
    asc_sign = native["asc_sign"]
    mc_sign = native["mc_sign"]
    planets = native["planets"]
    diurnal = native["diurnal"]
    sun_lon = native["sun_lon"]
    moon_lon = native["moon_lon"]

    season_name, _season_qualities = temperament.season(sun_lon)

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
        temperament_label=native["temperament_label"],
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


@router.post("/synastry", response_model=SynastryResponse)
def get_synastry(request: SynastryRequest) -> SynastryResponse:
    if not rate_limit.check_and_consume(request.user_id):
        raise HTTPException(status_code=429, detail=rate_limit.LIMIT_MESSAGE)

    tz_offset_a = _resolve_tz_offset(request.person_a)
    tz_offset_b = _resolve_tz_offset(request.person_b)

    native_a = _compute_natal(
        request.person_a.date, request.person_a.time, request.person_a.latitude, request.person_a.longitude, tz_offset_a
    )
    native_b = _compute_natal(
        request.person_b.date, request.person_b.time, request.person_b.latitude, request.person_b.longitude, tz_offset_b
    )

    name_a = request.person_a.name or "Native 1"
    name_b = request.person_b.name or "Native 2"

    # House overlays: each of A's planets in B's whole-sign houses, and each
    # of B's planets in A's -- 14 placements total for the 7 classical planets.
    house_overlays: list[SynastryHouseOverlay] = []
    for name, pos in native_a["planets"].items():
        house_overlays.append(
            SynastryHouseOverlay(
                planet=name, from_chart="A", sign=pos.sign, house=ephemeris.whole_sign_house(pos.longitude, native_b["asc_lon"])
            )
        )
    for name, pos in native_b["planets"].items():
        house_overlays.append(
            SynastryHouseOverlay(
                planet=name, from_chart="B", sign=pos.sign, house=ephemeris.whole_sign_house(pos.longitude, native_a["asc_lon"])
            )
        )

    longitudes_a = {name: pos.longitude for name, pos in native_a["planets"].items()}
    longitudes_b = {name: pos.longitude for name, pos in native_b["planets"].items()}
    raw_aspects = ephemeris.find_synastry_aspects(longitudes_a, longitudes_b)
    planet_aspects = [SynastryAspect(**a, from_chart="A", is_angle=False) for a in raw_aspects]

    # Angle inter-aspects: each native's planets against the *other* native's
    # Ascendant and Midheaven -- traditionally among the most significant
    # synastry indicators, so checked in both directions.
    angles_a = {"ASC": native_a["asc_lon"], "MC": native_a["mc_lon"]}
    angles_b = {"ASC": native_b["asc_lon"], "MC": native_b["mc_lon"]}
    raw_angle_a_to_b = ephemeris.find_synastry_angle_aspects(longitudes_a, angles_b)
    raw_angle_b_to_a = ephemeris.find_synastry_angle_aspects(longitudes_b, angles_a)
    angle_aspects = [
        SynastryAspect(
            planet_a=d["planet"], from_chart="A", planet_b=d["angle_name"], is_angle=True, aspect=d["aspect"], angle=d["angle"], orb=d["orb"]
        )
        for d in raw_angle_a_to_b
    ] + [
        SynastryAspect(
            planet_a=d["planet"], from_chart="B", planet_b=d["angle_name"], is_angle=True, aspect=d["aspect"], angle=d["angle"], orb=d["orb"]
        )
        for d in raw_angle_b_to_a
    ]

    inter_aspects = sorted(planet_aspects + angle_aspects, key=lambda a: a.orb)

    def _planet_prompt_entries(native: dict) -> list[dict]:
        return [{"name": n, "sign": p.sign, "house": p.house, "dignities": p.dignities} for n, p in native["planets"].items()]

    prompt = synastry_service.build_synastry_prompt(
        name_a=name_a,
        asc_sign_a=native_a["asc_sign"],
        temperament_a=native_a["temperament_label"],
        planets_a=_planet_prompt_entries(native_a),
        name_b=name_b,
        asc_sign_b=native_b["asc_sign"],
        temperament_b=native_b["temperament_label"],
        planets_b=_planet_prompt_entries(native_b),
        house_overlays=[{"planet": o.planet, "from_chart": o.from_chart, "house": o.house} for o in house_overlays],
        inter_aspects=[{"planet_a": a.planet_a, "planet_b": a.planet_b, "aspect": a.aspect, "orb": a.orb} for a in planet_aspects],
        angle_aspects=[
            {"planet": a.planet_a, "from_chart": a.from_chart, "angle_name": a.planet_b, "aspect": a.aspect, "orb": a.orb}
            for a in angle_aspects
        ],
    )

    try:
        text = synastry_service.generate_synastry_analysis(prompt)
    except synastry_service.SynastryError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e

    return SynastryResponse(
        person_a_name=name_a,
        person_b_name=name_b,
        house_overlays=house_overlays,
        aspects=inter_aspects,
        analysis=text,
    )


@router.post("/transits", response_model=TransitsResponse)
def get_transits(request: TransitsRequest) -> TransitsResponse:
    if request.tz_offset is not None:
        tz_offset = request.tz_offset
    else:
        try:
            _timezone_id, tz_offset = tz_resolver.resolve_utc_offset(
                request.latitude, request.longitude, request.date, request.time
            )
        except tz_resolver.TimezoneLookupError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e

    natal_jd_ut = ephemeris.julian_day_ut(request.date, request.time, tz_offset)
    asc_lon, _mc_lon = ephemeris.calc_angles(natal_jd_ut, request.latitude, request.longitude)

    natal_longitudes: dict[str, float] = {}
    for name, body_id in ephemeris.CLASSICAL_PLANETS.items():
        lon, _retrograde = ephemeris.calc_planet(natal_jd_ut, body_id)
        natal_longitudes[name] = lon

    transit_jd_ut = transits_service.current_julian_day_ut()
    hits = transits_service.find_transits(natal_longitudes, transit_jd_ut)
    transit_list = [Transit(**h) for h in hits]

    sun_id = ephemeris.CLASSICAL_PLANETS["Sun"]
    moon_id = ephemeris.CLASSICAL_PLANETS["Moon"]
    sun_lon, _ = ephemeris.calc_planet(transit_jd_ut, sun_id)
    moon_lon, _ = ephemeris.calc_planet(transit_jd_ut, moon_id)
    moon_sign, _moon_deg = ephemeris.sign_and_degree(moon_lon)
    phase_angle = (moon_lon - sun_lon) % 360.0

    moon_position = MoonPosition(
        sign=moon_sign,
        house=ephemeris.whole_sign_house(moon_lon, asc_lon),
        phase_name=transits_service.moon_phase_name(phase_angle),
        phase_angle=round(phase_angle, 2),
    )

    moon_hits = [t for t in transit_list if t.transiting_planet == "Moon"]
    moon_natal_aspect = moon_hits[0] if moon_hits else None

    return TransitsResponse(transits=transit_list, moon_position=moon_position, moon_natal_aspect=moon_natal_aspect)
