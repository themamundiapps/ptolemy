"""Resolves the identity behind a request.

For signed-in users, ptolemy-web's NextAuth layer verifies the Google
identity and mints a short-lived internal JWT (HS256, INTERNAL_AUTH_SECRET)
carrying the Google account id as `sub` (plus `email`/`name` from the same
verified session, added alongside the guest-chart-claim feature). This
module verifies that JWT so the backend trusts a signed assertion instead of
a client-suppliable `user_id` field -- which remains the identifier for
guests, who were never authenticated to begin with and whose device id was
always self-reported.
"""
import os

import jwt

INTERNAL_AUTH_SECRET = os.environ.get("INTERNAL_AUTH_SECRET")


def resolve_verified_identity(authorization: str | None) -> dict | None:
    """Decodes a verified internal JWT into {"google_id", "email", "name"},
    or None if the header is missing, malformed, or the signature doesn't
    check out. Unlike resolve_user_id, this never falls back to a
    client-supplied guest id -- callers that need a real account (e.g.
    claiming guest charts on login) should treat None as "reject", not
    "treat as guest"."""
    if not (authorization and INTERNAL_AUTH_SECRET):
        return None
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return None
    try:
        payload = jwt.decode(token, INTERNAL_AUTH_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    sub = payload.get("sub")
    if not sub:
        return None
    return {"google_id": sub, "email": payload.get("email"), "name": payload.get("name")}


def resolve_user_id(authorization: str | None, fallback_user_id: str | None) -> str | None:
    """Prefers the verified `sub` from a Bearer JWT over [fallback_user_id]
    (the client-supplied device id for guests). Any missing/malformed/
    invalid-signature token falls back rather than erroring -- an
    unauthenticated caller is just treated as a guest, not rejected."""
    identity = resolve_verified_identity(authorization)
    return identity["google_id"] if identity else fallback_user_id
