import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import chart, electional, geocode, interpretations, temperament, user

app = FastAPI(title="Ptolemy API", version="0.1.0")

# The Android/iOS/Windows app talks to this API via native HTTP, which is
# never subject to browser CORS enforcement -- only a Flutter *web* build
# would hit this. Default to local dev origins; set ALLOWED_ORIGINS on
# Railway (comma-separated) once a web build is deployed somewhere.
_allowed_origins_env = os.getenv("ALLOWED_ORIGINS")
_allow_origins = (
    [origin.strip() for origin in _allowed_origins_env.split(",") if origin.strip()]
    if _allowed_origins_env
    else ["http://localhost:8000", "http://127.0.0.1:8000"]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allow_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chart.router, prefix="/api/v1")
app.include_router(geocode.router, prefix="/api/v1")
app.include_router(interpretations.router, prefix="/api/v1")
app.include_router(temperament.router, prefix="/api/v1")
app.include_router(electional.router, prefix="/api/v1")
app.include_router(user.router, prefix="/api/v1")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
