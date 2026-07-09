from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import chart, electional, geocode, interpretations, temperament, user

app = FastAPI(title="Ptolemy API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
