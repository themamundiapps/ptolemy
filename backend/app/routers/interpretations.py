from fastapi import APIRouter, HTTPException, Query

from app.models.schemas import InterpretationResponse, SynthesisRequest, SynthesisResponse
from app.services import interpretations, synthesis

router = APIRouter(prefix="/interpretations", tags=["interpretations"])


@router.get("/planet-sign", response_model=InterpretationResponse)
def planet_sign(planet: str = Query(...), sign: str = Query(...)) -> InterpretationResponse:
    result = interpretations.get_planet_in_sign(planet, sign)
    if result is None:
        raise HTTPException(status_code=404, detail=f"No interpretation for {planet} in {sign}")
    return InterpretationResponse(body=result.body, citation=result.citation)


@router.get("/planet-house", response_model=InterpretationResponse)
def planet_house(planet: str = Query(...), house: int = Query(..., ge=1, le=12)) -> InterpretationResponse:
    result = interpretations.get_planet_in_house(planet, house)
    if result is None:
        raise HTTPException(status_code=404, detail=f"No interpretation for {planet} in house {house}")
    return InterpretationResponse(body=result.body, citation=result.citation)


@router.get("/lot", response_model=InterpretationResponse)
def lot(
    lot: str = Query(..., pattern="^(fortune|spirit)$"),
    sign: str = Query(...),
    house: int = Query(..., ge=1, le=12),
) -> InterpretationResponse:
    result = interpretations.get_lot_interpretation(lot, sign, house)
    return InterpretationResponse(body=result.body, citation=result.citation)


@router.get("/aspect", response_model=InterpretationResponse)
def aspect(
    planet_a: str = Query(...),
    planet_b: str = Query(...),
    aspect_type: str = Query(..., pattern="^(conjunction|sextile|square|trine|opposition)$"),
) -> InterpretationResponse:
    result = interpretations.get_aspect_interpretation(planet_a, planet_b, aspect_type)
    if result is None:
        raise HTTPException(status_code=404, detail=f"No interpretation for {planet_a} — {planet_b}")
    return InterpretationResponse(body=result.body, citation=result.citation)


@router.post("/synthesis", response_model=SynthesisResponse)
def generate_synthesis(request: SynthesisRequest) -> SynthesisResponse:
    try:
        text = synthesis.generate_synthesis(
            planet=request.planet,
            sign=request.sign,
            house=request.house,
            sect=request.sect,
            dignities=request.dignities,
            aspects=request.aspects,
        )
    except synthesis.SynthesisError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    return SynthesisResponse(synthesis=text)
