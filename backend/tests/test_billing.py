"""Tests for services/billing.py -- Stripe Checkout/Portal session creation
and webhook event processing. Uses Stripe's real (offline) signature
verification for construct_event (see _signed_payload below, hand-rolled per
Stripe's documented v1 scheme -- HMAC-SHA256 over "{timestamp}.{payload}"),
so the invalid-signature case is a genuine rejection, not a mocked one.
Checkout/Portal session *creation* mocks the Stripe SDK calls themselves --
those need a real network call to a real Stripe account, which this suite
deliberately never makes (test mode or not)."""
import hashlib
import hmac
import json
import time
from types import SimpleNamespace

import pytest
import stripe

from app.services import billing, subscription

_WEBHOOK_SECRET = "whsec_test_secret"


@pytest.fixture(autouse=True)
def _stripe_env(monkeypatch):
    monkeypatch.setenv("STRIPE_SECRET_KEY", "sk_test_fake")
    monkeypatch.setenv("STRIPE_PRICE_ID", "price_fake")
    monkeypatch.setenv("STRIPE_WEBHOOK_SECRET", _WEBHOOK_SECRET)


def _signed_payload(event: dict) -> tuple[bytes, str]:
    payload = json.dumps(event).encode()
    ts = int(time.time())
    signed = f"{ts}.{payload.decode()}".encode()
    sig = hmac.new(_WEBHOOK_SECRET.encode(), signed, hashlib.sha256).hexdigest()
    return payload, f"t={ts},v1={sig}"


def _event(event_type: str, data_object: dict) -> dict:
    return {
        "id": "evt_test",
        "object": "event",
        "type": event_type,
        "data": {"object": {"object": "", **data_object}},
    }


# ---------------------------------------------------------------------------
# construct_event -- signature verification
# ---------------------------------------------------------------------------


def test_valid_signature_is_accepted():
    payload, sig_header = _signed_payload(_event("checkout.session.completed", {"mode": "subscription"}))
    event = billing.construct_event(payload, sig_header)
    assert event["type"] == "checkout.session.completed"


def test_invalid_signature_is_rejected():
    payload, _ = _signed_payload(_event("checkout.session.completed", {"mode": "subscription"}))
    with pytest.raises(billing.WebhookVerificationError):
        billing.construct_event(payload, "t=123,v1=not_a_real_signature")


def test_missing_signature_header_is_rejected():
    payload, _ = _signed_payload(_event("checkout.session.completed", {"mode": "subscription"}))
    with pytest.raises(billing.WebhookVerificationError):
        billing.construct_event(payload, None)


def test_missing_webhook_secret_is_rejected(monkeypatch):
    monkeypatch.delenv("STRIPE_WEBHOOK_SECRET", raising=False)
    payload, sig_header = _signed_payload(_event("checkout.session.completed", {"mode": "subscription"}))
    with pytest.raises(billing.WebhookVerificationError):
        billing.construct_event(payload, sig_header)


def test_signature_from_a_different_secret_is_rejected():
    payload = json.dumps(_event("checkout.session.completed", {"mode": "subscription"})).encode()
    ts = int(time.time())
    wrong_sig = hmac.new(b"whsec_wrong", f"{ts}.{payload.decode()}".encode(), hashlib.sha256).hexdigest()
    with pytest.raises(billing.WebhookVerificationError):
        billing.construct_event(payload, f"t={ts},v1={wrong_sig}")


# ---------------------------------------------------------------------------
# handle_event -- the four required scenarios
# ---------------------------------------------------------------------------


def test_checkout_completed_grants_pro(test_db):
    event = _event(
        "checkout.session.completed",
        {
            "mode": "subscription",
            "payment_status": "paid",
            "customer": "cus_1",
            "subscription": "sub_1",
            "client_reference_id": "google-1",
            "customer_details": {"email": "a@example.com"},
        },
    )
    billing.handle_event(event)
    assert subscription.is_pro("google-1") is True


def test_subscription_created_grants_pro(test_db):
    event = _event(
        "customer.subscription.created",
        {"id": "sub_1", "customer": "cus_1", "status": "active", "current_period_end": int(time.time()) + 2592000, "metadata": {"google_id": "google-2"}},
    )
    billing.handle_event(event)
    assert subscription.is_pro("google-2") is True


def test_cancellation_revokes_pro(test_db):
    billing.handle_event(
        _event(
            "customer.subscription.created",
            {"id": "sub_1", "customer": "cus_1", "status": "active", "current_period_end": None, "metadata": {"google_id": "google-3"}},
        )
    )
    assert subscription.is_pro("google-3") is True

    billing.handle_event(
        _event(
            "customer.subscription.deleted",
            {"id": "sub_1", "customer": "cus_1", "current_period_end": None, "metadata": {"google_id": "google-3"}},
        )
    )
    assert subscription.is_pro("google-3") is False


def test_payment_failure_does_not_grant_pro_on_a_brand_new_account(test_db):
    # No prior subscription event -- mark_status_by_customer is a no-op with
    # no existing row, so there's nothing for is_pro to find either way, but
    # this pins down that a payment_failed event alone never grants Pro.
    billing.handle_event(_event("invoice.payment_failed", {"customer": "cus_new"}))
    assert subscription.is_pro("google-never-subscribed") is False


def test_payment_failure_revokes_an_active_subscription(test_db):
    billing.handle_event(
        _event(
            "customer.subscription.created",
            {"id": "sub_1", "customer": "cus_4", "status": "active", "current_period_end": None, "metadata": {"google_id": "google-4"}},
        )
    )
    assert subscription.is_pro("google-4") is True

    billing.handle_event(_event("invoice.payment_failed", {"customer": "cus_4"}))
    assert subscription.is_pro("google-4") is False


def test_payment_succeeded_after_a_failure_restores_pro(test_db):
    billing.handle_event(
        _event(
            "customer.subscription.created",
            {"id": "sub_1", "customer": "cus_5", "status": "active", "current_period_end": None, "metadata": {"google_id": "google-5"}},
        )
    )
    billing.handle_event(_event("invoice.payment_failed", {"customer": "cus_5"}))
    assert subscription.is_pro("google-5") is False

    billing.handle_event(_event("invoice.payment_succeeded", {"customer": "cus_5", "billing_reason": "subscription_cycle"}))
    assert subscription.is_pro("google-5") is True


def test_checkout_completed_with_unpaid_status_does_not_grant_pro(test_db):
    event = _event(
        "checkout.session.completed",
        {
            "mode": "subscription",
            "payment_status": "unpaid",
            "customer": "cus_6",
            "subscription": "sub_6",
            "client_reference_id": "google-6",
        },
    )
    billing.handle_event(event)
    assert subscription.is_pro("google-6") is False


def test_non_subscription_checkout_session_is_ignored(test_db):
    event = _event(
        "checkout.session.completed",
        {"mode": "payment", "payment_status": "paid", "customer": "cus_7", "client_reference_id": "google-7"},
    )
    billing.handle_event(event)
    assert subscription.is_pro("google-7") is False


def test_invoice_event_with_no_known_customer_is_a_harmless_no_op(test_db):
    billing.handle_event(_event("invoice.payment_failed", {"customer": "cus_unknown"}))
    billing.handle_event(_event("invoice.payment_succeeded", {"customer": "cus_unknown", "billing_reason": "subscription_cycle"}))


# ---------------------------------------------------------------------------
# create_checkout_session / create_portal_session
# ---------------------------------------------------------------------------


def test_create_checkout_session_returns_the_session_url(monkeypatch):
    captured = {}

    def fake_create(**kwargs):
        captured.update(kwargs)
        return SimpleNamespace(url="https://checkout.stripe.com/test-session")

    monkeypatch.setattr(stripe.checkout.Session, "create", staticmethod(fake_create))
    url = billing.create_checkout_session("google-1", "a@example.com")
    assert url == "https://checkout.stripe.com/test-session"
    assert captured["mode"] == "subscription"
    assert captured["client_reference_id"] == "google-1"
    assert captured["subscription_data"]["metadata"]["google_id"] == "google-1"
    assert captured["automatic_tax"] == {"enabled": True}
    assert captured["billing_address_collection"] == "required"


def test_create_checkout_session_without_price_id_configured_raises(monkeypatch):
    monkeypatch.delenv("STRIPE_PRICE_ID", raising=False)
    with pytest.raises(billing.BillingError):
        billing.create_checkout_session("google-1", "a@example.com")


def test_create_checkout_session_without_secret_key_configured_raises(monkeypatch):
    monkeypatch.delenv("STRIPE_SECRET_KEY", raising=False)
    with pytest.raises(billing.BillingError):
        billing.create_checkout_session("google-1", "a@example.com")


def test_create_portal_session_without_a_stripe_customer_raises(test_db):
    with pytest.raises(billing.BillingError):
        billing.create_portal_session("google-never-subscribed")


def test_create_portal_session_returns_the_session_url(test_db, monkeypatch):
    billing.handle_event(
        _event(
            "customer.subscription.created",
            {"id": "sub_1", "customer": "cus_8", "status": "active", "current_period_end": None, "metadata": {"google_id": "google-8"}},
        )
    )

    def fake_create(**kwargs):
        assert kwargs["customer"] == "cus_8"
        return SimpleNamespace(url="https://billing.stripe.com/test-portal")

    monkeypatch.setattr(stripe.billing_portal.Session, "create", staticmethod(fake_create))
    url = billing.create_portal_session("google-8")
    assert url == "https://billing.stripe.com/test-portal"
