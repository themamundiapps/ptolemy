from fastapi import APIRouter, Query

from app.models.schemas import CityResult, GeocodeResponse
from app.services import geocoding

router = APIRouter(prefix="/geocode", tags=["geocode"])


@router.get("/search", response_model=GeocodeResponse)
def search(q: str = Query(..., min_length=2)) -> GeocodeResponse:
    results = geocoding.search_cities(q)
    return GeocodeResponse(results=[CityResult(**r) for r in results])
