from fastapi import APIRouter, HTTPException

from app.models.schemas import UserChartResponse, UserChartSaveRequest
from app.services import user_store

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
