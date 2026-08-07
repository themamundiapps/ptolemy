import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

from app.routers import billing, chart, chat, electional, geocode, interpretations, temperament, user

logger = logging.getLogger(__name__)


class UnhandledErrorCORSMiddleware:
    """Makes sure an unhandled exception's 500 response still carries CORS
    headers -- otherwise the browser blocks it before JS ever sees it, and a
    real server error (e.g. the "Stripe Tax is not supported for your
    account country" 500 hit during billing testing, 2026-08-06) reads to
    the frontend as "Could not reach the server", indistinguishable from a
    genuine network failure.

    A FastAPI `@app.exception_handler(Exception)` does NOT fix this: Starlette
    special-cases handlers registered for exactly `Exception` or `500` and
    hoists them into ServerErrorMiddleware (see
    Starlette.build_middleware_stack), which sits *outside* every middleware
    added via add_middleware -- including CORSMiddleware -- so its response
    still bypasses CORS header injection no matter what handler runs there.

    This has to be a real middleware, and it has to sit *inside*
    CORSMiddleware in the stack -- add_middleware wraps in reverse
    registration order (last-added ends up outermost), so this is registered
    *before* CORSMiddleware below. Catching the exception here and returning
    a normal Response (never re-raising) means CORSMiddleware -- which wraps
    around this middleware -- sees a completed response like any other and
    adds its headers as usual."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        try:
            await self.app(scope, receive, send)
        except Exception:
            logger.exception("Unhandled exception on %s %s", scope.get("method"), scope.get("path"))
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})
            await response(scope, receive, send)

# RAILWAY_ENVIRONMENT is injected automatically for every Railway deployment
# (any environment -- production, staging, PR previews) and is absent when
# running locally, so this needs no separate config var to opt in. With
# Stripe integration coming, /docs, /redoc and /openapi.json publishing the
# full API schema (including billing-adjacent endpoints) is surface worth
# closing off outside local dev.
_is_local_dev = os.getenv("RAILWAY_ENVIRONMENT") is None

app = FastAPI(
    title="Ptolemy API",
    version="0.1.0",
    docs_url="/docs" if _is_local_dev else None,
    redoc_url="/redoc" if _is_local_dev else None,
    openapi_url="/openapi.json" if _is_local_dev else None,
)

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

# Registered *before* CORSMiddleware so it ends up *inside* it in the
# middleware stack -- see UnhandledErrorCORSMiddleware's docstring.
app.add_middleware(UnhandledErrorCORSMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allow_origins,
    allow_origin_regex=_allow_origin_regex,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chart.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")
app.include_router(geocode.router, prefix="/api/v1")
app.include_router(interpretations.router, prefix="/api/v1")
app.include_router(temperament.router, prefix="/api/v1")
app.include_router(electional.router, prefix="/api/v1")
app.include_router(user.router, prefix="/api/v1")
app.include_router(billing.router, prefix="/api/v1")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
