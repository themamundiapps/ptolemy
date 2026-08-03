"""Resolves the user id used to key the AI rate limit (see rate_limit.py).

For signed-in users, ptolemy-web's NextAuth layer verifies the Google
identity and mints a short-lived internal JWT (HS256, INTERNAL_AUTH_SECRET)
carrying the Google account id as `sub`. This module verifies that JWT so
the backend trusts a signed assertion instead of the raw, client-suppliable
`user_id` field -- which remains the identifier for guests, who were never
authenticated to begin with and whose device id was always self-reported.
"""
import os

import jwt

INTERNAL_AUTH_SECRET = os.environ.get("INTERNAL_AUTH_SECRET")


def resolve_user_id(authorization: str | None, fallback_user_id: str | None) -> str | None:
    """Prefers the verified `sub` from a Bearer JWT over [fallback_user_id]
    (the client-supplied device id for guests). Any missing/malformed/
    invalid-signature token falls back rather than erroring -- an
    unauthenticated caller is just treated as a guest, not rejected."""
    if authorization and INTERNAL_AUTH_SECRET:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() == "bearer" and token:
            try:
                payload = jwt.decode(token, INTERNAL_AUTH_SECRET, algorithms=["HS256"])
            except jwt.PyJWTError:
                return fallback_user_id
            sub = payload.get("sub")
            if sub:
                return sub
    return fallback_user_id
