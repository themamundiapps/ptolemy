from fastapi import APIRouter, Header, HTTPException

from app.models.schemas import (
    AiQuotaResponse,
    ClaimChartsRequest,
    ClaimChartsResponse,
    CreateChartRequest,
    CreateChartResponse,
    UserChartResponse,
    UserChartSaveRequest,
)
from app.services import auth, chart_store, rate_limit, user_store

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
def get_ai_quota(user_id: str | None = None, authorization: str | None = Header(None)) -> AiQuotaResponse:
    """Read-only lookup of the shared daily AI-call budget (Chart Analysis +
    Synastry + Chat + Personal Synthesis combined) -- unlike those endpoints,
    never consumes a unit itself. Also reports is_pro, since the frontend
    needs it to decide which tabs/themes render locked."""
    effective_user_id, is_pro = auth.resolve_plan(authorization, user_id)
    return AiQuotaResponse(
        remaining=rate_limit.remaining(effective_user_id, is_pro),
        limit=rate_limit.daily_limit(is_pro),
        resets_at="midnight UTC",
        is_pro=is_pro,
    )


@router.post("/charts", response_model=CreateChartResponse)
def create_chart(request: CreateChartRequest, authorization: str | None = Header(None)) -> CreateChartResponse:
    """Persists a cast chart so it isn't lost if the browser/device is --
    called for every chart cast on ptolemy-web, signed in or not. A guest
    chart (no verified identity on this request) is tagged with
    [request.guest_id] so it can be claimed later via /user/charts/claim."""
    identity = auth.resolve_verified_identity(authorization)
    chart_id = chart_store.create_chart(
        city_name=request.city_name,
        latitude=request.latitude,
        longitude=request.longitude,
        birth_date=request.date,
        birth_time=request.time,
        tz_offset=request.tz_offset,
        guest_id=request.guest_id,
        google_id=identity["google_id"] if identity else None,
    )
    return CreateChartResponse(id=chart_id)


@router.post("/charts/claim", response_model=ClaimChartsResponse)
def claim_charts(request: ClaimChartsRequest, authorization: str | None = Header(None)) -> ClaimChartsResponse:
    """Reassigns every chart cast anonymously under [request.guest_id] to
    the signed-in account making this call. Requires a verified identity --
    unlike the rate-limit endpoints, this never falls back to treating the
    caller as a guest, since there'd be nothing meaningful to claim onto."""
    identity = auth.resolve_verified_identity(authorization)
    if identity is None:
        raise HTTPException(status_code=401, detail="Sign-in required to claim charts")

    claimed = chart_store.claim_charts_for_guest(
        guest_id=request.guest_id,
        google_id=identity["google_id"],
        email=identity["email"],
        name=identity["name"],
    )
    return ClaimChartsResponse(claimed=claimed)
