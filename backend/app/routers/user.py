from fastapi import APIRouter, HTTPException

from app.models.schemas import AiQuotaResponse, UserChartResponse, UserChartSaveRequest
from app.services import rate_limit, user_store

router = APIRouter(prefix="/user", tags=["user"])


@router.post("/chart", response_model=UserChartResponse)
def save_chart(request: UserChartSaveRequest) -> UserChartResponse:
    data = request.model_dump(exclude={"google_id"})
    user_store.save_chart(request.google_id, data)
    return UserChartResponse(**data)


@router.get("/chart/{google_id}", response_model=UserChartResponse)
def get_chart(google_id: str) -> UserChartResponse:
    data = user_store.get_chart(google_id)
    if data is None:
        raise HTTPException(status_code=404, detail="No saved chart for this account")
    return UserChartResponse(**data)


@router.get("/ai-quota", response_model=AiQuotaResponse)
def get_ai_quota(user_id: str | None = None) -> AiQuotaResponse:
    """Read-only lookup of the shared daily AI-call budget (Chart Analysis +
    Synastry + Personal Synthesis combined) -- unlike those endpoints, never
    consumes a unit itself."""
    return AiQuotaResponse(
        remaining=rate_limit.remaining(user_id),
        limit=rate_limit.DAILY_LIMIT,
        resets_at="midnight UTC",
    )
