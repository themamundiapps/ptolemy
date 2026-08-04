"""Temporary diagnostic endpoint for the INTERNAL_AUTH_SECRET rollout.
Reveals no secret values -- only which branch of auth.resolve_user_id a
request would hit. Remove once the Railway env var issue is confirmed
fixed."""
from fastapi import APIRouter, Header

from app.services import auth

router = APIRouter(prefix="/_debug", tags=["debug"])


@router.get("/auth")
def debug_auth(authorization: str | None = Header(None)) -> dict:
    result = {
        "secret_configured": bool(auth.INTERNAL_AUTH_SECRET),
        "authorization_header_present": authorization is not None,
        "scheme_is_bearer": False,
        "decode_error": None,
        "verified_sub": None,
    }
    if authorization:
        scheme, _, token = authorization.partition(" ")
        result["scheme_is_bearer"] = scheme.lower() == "bearer" and bool(token)
        if result["scheme_is_bearer"] and auth.INTERNAL_AUTH_SECRET:
            import jwt

            try:
                payload = jwt.decode(token, auth.INTERNAL_AUTH_SECRET, algorithms=["HS256"])
                result["verified_sub"] = payload.get("sub")
            except jwt.PyJWTError as e:
                result["decode_error"] = type(e).__name__
    return result
