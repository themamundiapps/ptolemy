"""Router-level tests for routers/billing.py -- auth requirements on the
authenticated endpoints, and the webhook endpoint end-to-end (real signature
verification through to a DB write), rather than re-testing billing.py's own
logic (see test_billing.py for that)."""
import hashlib
import hmac
import json
import time

import jwt
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import auth, subscription

client = TestClient(app)

_JWT_SECRET = "test-billing-secret"
_WEBHOOK_SECRET = "whsec_test_secret"


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setattr(auth, "INTERNAL_AUTH_SECRET", _JWT_SECRET)
    monkeypatch.setenv("STRIPE_SECRET_KEY", "sk_test_fake")
    monkeypatch.setenv("STRIPE_PRICE_ID", "price_fake")
    monkeypatch.setenv("STRIPE_WEBHOOK_SECRET", _WEBHOOK_SECRET)


def _bearer(sub: str, **claims) -> str:
    return "Bearer " + jwt.encode({"sub": sub, **claims}, _JWT_SECRET, algorithm="HS256")


def _signed_webhook_body(event: dict) -> tuple[bytes, str]:
    payload = json.dumps(event).encode()
    ts = int(time.time())
    signed = f"{ts}.{payload.decode()}".encode()
    sig = hmac.new(_WEBHOOK_SECRET.encode(), signed, hashlib.sha256).hexdigest()
    return payload, f"t={ts},v1={sig}"


# ---------------------------------------------------------------------------
# /billing/checkout-session
# ---------------------------------------------------------------------------


def test_checkout_session_requires_sign_in():
    response = client.post("/api/v1/billing/checkout-session")
    assert response.status_code == 401


def test_checkout_session_503s_when_stripe_is_not_configured(monkeypatch):
    monkeypatch.delenv("STRIPE_PRICE_ID", raising=False)
    response = client.post(
        "/api/v1/billing/checkout-session", headers={"Authorization": _bearer("google-1")}
    )
    assert response.status_code == 503


def test_checkout_session_returns_a_url_when_signed_in(monkeypatch):
    import stripe
    from types import SimpleNamespace

    monkeypatch.setattr(
        stripe.checkout.Session, "create", staticmethod(lambda **kwargs: SimpleNamespace(url="https://checkout.stripe.com/xyz"))
    )
    response = client.post(
        "/api/v1/billing/checkout-session", headers={"Authorization": _bearer("google-1", email="a@example.com")}
    )
    assert response.status_code == 200
    assert response.json()["url"] == "https://checkout.stripe.com/xyz"


# ---------------------------------------------------------------------------
# /billing/portal-session
# ---------------------------------------------------------------------------


def test_portal_session_requires_sign_in():
    response = client.post("/api/v1/billing/portal-session")
    assert response.status_code == 401


def test_portal_session_400s_with_no_stripe_customer_yet(test_db):
    response = client.post(
        "/api/v1/billing/portal-session", headers={"Authorization": _bearer("google-no-sub")}
    )
    assert response.status_code == 400


# ---------------------------------------------------------------------------
# /billing/webhook
# ---------------------------------------------------------------------------


def test_webhook_with_invalid_signature_is_rejected(test_db):
    payload = json.dumps(
        {
            "id": "evt_1",
            "object": "event",
            "type": "checkout.session.completed",
            "data": {"object": {"object": "checkout.session", "mode": "subscription"}},
        }
    ).encode()
    response = client.post(
        "/api/v1/billing/webhook",
        content=payload,
        headers={"Stripe-Signature": "t=1,v1=not_a_real_signature", "Content-Type": "application/json"},
    )
    assert response.status_code == 400


def test_webhook_with_no_signature_header_is_rejected(test_db):
    response = client.post("/api/v1/billing/webhook", content=b"{}")
    assert response.status_code == 400


def test_webhook_with_valid_signature_updates_subscription_state(test_db):
    event = {
        "id": "evt_2",
        "object": "event",
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "object": "checkout.session",
                "mode": "subscription",
                "payment_status": "paid",
                "customer": "cus_web_1",
                "subscription": "sub_web_1",
                "client_reference_id": "google-web-1",
            }
        },
    }
    payload, sig_header = _signed_webhook_body(event)
    response = client.post(
        "/api/v1/billing/webhook",
        content=payload,
        headers={"Stripe-Signature": sig_header, "Content-Type": "application/json"},
    )
    assert response.status_code == 200
    assert subscription.is_pro("google-web-1") is True


def test_webhook_cancellation_revokes_pro_end_to_end(test_db):
    created = {
        "id": "evt_3",
        "object": "event",
        "type": "customer.subscription.created",
        "data": {
            "object": {
                "object": "subscription",
                "id": "sub_web_2",
                "customer": "cus_web_2",
                "status": "active",
                "current_period_end": None,
                "metadata": {"google_id": "google-web-2"},
            }
        },
    }
    payload, sig_header = _signed_webhook_body(created)
    client.post("/api/v1/billing/webhook", content=payload, headers={"Stripe-Signature": sig_header})
    assert subscription.is_pro("google-web-2") is True

    deleted = {
        "id": "evt_4",
        "object": "event",
        "type": "customer.subscription.deleted",
        "data": {
            "object": {
                "object": "subscription",
                "id": "sub_web_2",
                "customer": "cus_web_2",
                "current_period_end": None,
                "metadata": {"google_id": "google-web-2"},
            }
        },
    }
    payload, sig_header = _signed_webhook_body(deleted)
    response = client.post("/api/v1/billing/webhook", content=payload, headers={"Stripe-Signature": sig_header})
    assert response.status_code == 200
    assert subscription.is_pro("google-web-2") is False
