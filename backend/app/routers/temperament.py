from fastapi import APIRouter, HTTPException, Query

from app.models.schemas import (
    ChartRequest,
    TemperamentExpandedRecommendations,
    TemperamentExpandedResponse,
    TemperamentExpandedSection,
    TemperamentResponse,
)
from app.services import ephemeris, interpretations, temperament
from app.services import timezone as tz_resolver

router = APIRouter(tags=["temperament"])


@router.post("/temperament", response_model=TemperamentResponse)
def get_temperament(request: ChartRequest) -> TemperamentResponse:
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
    asc_sign, _asc_deg = ephemeris.sign_and_degree(asc_lon)

    planets: dict[str, dict] = {}
    for name, body_id in ephemeris.CLASSICAL_PLANETS.items():
        lon, _retrograde = ephemeris.calc_planet(jd_ut, body_id)
        sign, _deg = ephemeris.sign_and_degree(lon)
        house = ephemeris.whole_sign_house(lon, asc_lon)
        planets[name] = {"longitude": lon, "sign": sign, "house": house}

    result = temperament.calculate(
        asc_sign=asc_sign,
        planets=planets,
        sun_longitude=planets["Sun"]["longitude"],
        moon_longitude=planets["Moon"]["longitude"],
    )
    return TemperamentResponse(**result)


@router.get("/temperament/expanded", response_model=TemperamentExpandedResponse)
def get_temperament_expanded(temperament: str = Query(...)) -> TemperamentExpandedResponse:
    entry = interpretations.get_temperament_expanded(temperament)
    if entry is None:
        raise HTTPException(status_code=404, detail=f"No expanded content for temperament '{temperament}'")
    return TemperamentExpandedResponse(
        temperament=temperament,
        health_tendencies=TemperamentExpandedSection(text=entry.health_text, citation=entry.health_citation),
        traditional_recommendations=TemperamentExpandedRecommendations(text=entry.recommendations_text),
    )
