import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import chart, electional, geocode, interpretations, temperament, user

app = FastAPI(title="Ptolemy API", version="0.1.0")

# The Android/iOS/Windows app talks to this API via native HTTP, which is
# never subject to browser CORS enforcement -- only the Flutter *web* build
# (hosted on Vercel) hits this. Default list covers the production domain
# and local web dev; set ALLOWED_ORIGINS on Railway (comma-separated) to
# override/extend it, e.g. once a custom domain is added.
_allowed_origins_env = os.getenv("ALLOWED_ORIGINS")
_allow_origins = (
    [origin.strip() for origin in _allowed_origins_env.split(",") if origin.strip()]
    if _allowed_origins_env
    else [
        "https://ptolemy.vercel.app",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]
)

# Vercel preview deployments get a unique *.vercel.app subdomain per branch/
# PR, so they can't be listed as fixed origins. CORSMiddleware's allow_origins
# only does exact string matches -- a literal "https://*.vercel.app" entry
# would never match a real Origin header -- so preview subdomains need the
# regex parameter instead. Overridable via ALLOWED_ORIGIN_REGEX on Railway.
_allow_origin_regex = os.getenv("ALLOWED_ORIGIN_REGEX", r"https://.*\.vercel\.app")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allow_origins,
    allow_origin_regex=_allow_origin_regex,
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
