"""Stripe integration: hosted Checkout session creation, Billing Portal
session creation, and webhook event processing. Card data and payment UI
never touch this codebase -- Checkout and the Portal are both Stripe-hosted
pages this module only ever redirects the browser to; it talks to the
Stripe API server-to-server and never sees a card number.

Requires three env vars, all unset until Enzo creates the Stripe account and
fills them in (see PRODUCT_STATE.md for exactly where):
  STRIPE_SECRET_KEY     -- Developers -> API keys (use a *test* key first)
  STRIPE_PRICE_ID       -- the recurring $5/month USD Price, created under
                           Product catalog (there is deliberately only one
                           plan -- no annual tier)
  STRIPE_WEBHOOK_SECRET -- Developers -> Webhooks -> (this endpoint) ->
                           Signing secret
"""
import os
from datetime import datetime, timezone

import stripe

from app.services import subscription

FRONTEND_URL = os.environ.get("FRONTEND_URL", "https://ptolemy-web.vercel.app")


class BillingError(Exception):
    pass


class WebhookVerificationError(Exception):
    pass


def _api_key() -> str:
    key = os.environ.get("STRIPE_SECRET_KEY")
    if not key:
        raise BillingError("STRIPE_SECRET_KEY is not configured")
    return key


def create_checkout_session(google_id: str, email: str | None) -> str:
    """Creates a hosted Stripe Checkout session for the one Pro plan and
    returns its URL -- the frontend just redirects the browser there, never
    rendering a card form itself. [google_id] rides on both the session
    (client_reference_id, read by the checkout.session.completed handler)
    and the resulting Subscription object (subscription_data.metadata, read
    by the customer.subscription.* handlers) so the webhook can attach the
    result to the right account without trusting anything the client sends
    at webhook time -- only the signed-in identity captured here, before
    Stripe is ever involved."""
    price_id = os.environ.get("STRIPE_PRICE_ID")
    if not price_id:
        raise BillingError("STRIPE_PRICE_ID is not configured")

    stripe.api_key = _api_key()
    session = stripe.checkout.Session.create(
        mode="subscription",
        line_items=[{"price": price_id, "quantity": 1}],
        client_reference_id=google_id,
        customer_email=email or None,
        subscription_data={"metadata": {"google_id": google_id}},
        success_url=f"{FRONTEND_URL}/account?checkout=success",
        cancel_url=f"{FRONTEND_URL}/pricing?checkout=cancelled",
        # International customers means digital-services tax obligations
        # across multiple jurisdictions (EU VAT MOSS, UK VAT, etc.) --
        # automatic_tax calculates and collects the right one per customer.
        # Requires Stripe Tax turned on and an origin address set in the
        # Dashboard (Settings -> Tax); billing_address_collection is
        # required for Stripe to know which jurisdiction applies.
        automatic_tax={"enabled": True},
        billing_address_collection="required",
    )
    return session.url


def create_portal_session(google_id: str) -> str:
    """Creates a Billing Portal session -- Stripe's hosted UI for
    cancellation and payment-method management, not something this app
    builds itself. Raises if this account has never completed a checkout
    (no Stripe customer exists yet to manage)."""
    customer_id = subscription.get_stripe_customer_id(google_id)
    if not customer_id:
        raise BillingError("No billing account yet -- subscribe to Pro first.")

    stripe.api_key = _api_key()
    session = stripe.billing_portal.Session.create(
        customer=customer_id,
        return_url=f"{FRONTEND_URL}/account",
    )
    return session.url


def construct_event(payload: bytes, sig_header: str | None) -> stripe.Event:
    """Verifies the Stripe-Signature header against STRIPE_WEBHOOK_SECRET --
    the only thing standing between "a real Stripe event" and "anyone's raw
    POST". An endpoint that trusted an unverified payload would let anyone
    grant themselves Pro for free by forging a checkout.session.completed
    body, so every failure mode here (missing secret, missing header, bad
    signature, malformed payload) raises rather than falling back to
    trusting the body anyway."""
    secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
    if not secret or not sig_header:
        raise WebhookVerificationError("Webhook secret or signature header missing")
    try:
        return stripe.Webhook.construct_event(payload, sig_header, secret)
    except (ValueError, stripe.SignatureVerificationError) as e:
        raise WebhookVerificationError(str(e)) from e


def _epoch_to_datetime(epoch: int | None) -> datetime | None:
    return datetime.fromtimestamp(epoch, tz=timezone.utc) if epoch is not None else None


def _field(obj, key: str, default=None):
    """Stripe's newer typed SDK objects (stripe.Subscription,
    stripe.checkout.Session, ...) support `in` and `[]` like a dict, but
    unlike the older generic StripeObject, don't implement `.get()` --
    calling it raises AttributeError instead of returning the method. This
    is the dict-like `.get()` these objects are missing."""
    return obj[key] if key in obj else default


def _sync_from_stripe_subscription(stripe_sub) -> None:
    metadata = _field(stripe_sub, "metadata") or {}
    subscription.sync_subscription(
        google_id=metadata["google_id"] if "google_id" in metadata else None,
        stripe_customer_id=stripe_sub["customer"],
        stripe_subscription_id=stripe_sub["id"],
        status=stripe_sub["status"],
        current_period_end=_epoch_to_datetime(_field(stripe_sub, "current_period_end")),
    )


def handle_event(event: stripe.Event) -> None:
    """Dispatches a verified webhook event to the subscription sync it
    implies. Plan status (is_pro) is driven entirely by what lands here --
    never by the Checkout success-page redirect, which only tells the
    browser "you were sent back", not "the payment succeeded"."""
    event_type = event["type"]
    data = event["data"]["object"]

    if event_type == "checkout.session.completed":
        if _field(data, "mode") != "subscription":
            return
        customer_details = _field(data, "customer_details") or {}
        subscription.sync_subscription(
            google_id=_field(data, "client_reference_id"),
            stripe_customer_id=data["customer"],
            stripe_subscription_id=_field(data, "subscription"),
            status="active" if _field(data, "payment_status") == "paid" else "incomplete",
            current_period_end=None,
            email=_field(customer_details, "email"),
        )

    elif event_type in ("customer.subscription.created", "customer.subscription.updated"):
        _sync_from_stripe_subscription(data)

    elif event_type == "customer.subscription.deleted":
        metadata = _field(data, "metadata") or {}
        subscription.sync_subscription(
            google_id=metadata["google_id"] if "google_id" in metadata else None,
            stripe_customer_id=data["customer"],
            stripe_subscription_id=data["id"],
            status="canceled",
            current_period_end=_epoch_to_datetime(_field(data, "current_period_end")),
        )

    elif event_type == "invoice.payment_failed":
        subscription.mark_status_by_customer(data["customer"], "past_due")

    elif event_type == "invoice.payment_succeeded":
        # A renewal, or a recovered payment after an earlier failure --
        # flip back to active. Skipped for the invoice that pays for the
        # very first period: customer.subscription.created already set
        # status=active moments earlier from the fuller Subscription object,
        # and Stripe doesn't guarantee event delivery order, so this could
        # otherwise race a later "incomplete" write on a brand-new sub.
        if _field(data, "billing_reason") != "subscription_create":
            subscription.mark_status_by_customer(data["customer"], "active")
