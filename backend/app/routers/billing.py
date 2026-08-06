from fastapi import APIRouter, Header, HTTPException, Request

from app.models.schemas import CheckoutSessionResponse, PortalSessionResponse
from app.services import auth, billing

router = APIRouter(prefix="/billing", tags=["billing"])


@router.post("/checkout-session", response_model=CheckoutSessionResponse)
def create_checkout_session(authorization: str | None = Header(None)) -> CheckoutSessionResponse:
    identity = auth.resolve_verified_identity(authorization)
    if identity is None:
        raise HTTPException(status_code=401, detail="Sign in to subscribe to Ptolemy Pro")
    try:
        url = billing.create_checkout_session(identity["google_id"], identity["email"])
    except billing.BillingError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    return CheckoutSessionResponse(url=url)


@router.post("/portal-session", response_model=PortalSessionResponse)
def create_portal_session(authorization: str | None = Header(None)) -> PortalSessionResponse:
    identity = auth.resolve_verified_identity(authorization)
    if identity is None:
        raise HTTPException(status_code=401, detail="Sign in to manage your subscription")
    try:
        url = billing.create_portal_session(identity["google_id"])
    except billing.BillingError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return PortalSessionResponse(url=url)


@router.post("/webhook")
async def stripe_webhook(request: Request, stripe_signature: str | None = Header(None, alias="Stripe-Signature")):
    """Stripe calls this directly (never the frontend) -- authenticated by
    the Stripe-Signature header, not a session or JWT, since the caller is
    Stripe's servers. The raw body is read as bytes because signature
    verification is over the exact bytes Stripe sent; re-serializing a
    parsed dict would produce a different byte sequence and always fail."""
    payload = await request.body()
    try:
        event = billing.construct_event(payload, stripe_signature)
    except billing.WebhookVerificationError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    billing.handle_event(event)
    return {"received": True}
