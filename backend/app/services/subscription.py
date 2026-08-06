"""Single source of truth for "is this user Pro?" Every Pro-gated surface
(Electional's 4 non-free themes, Temperament's Traditional Recommendations,
Chart Analysis, Synastry) calls is_pro() here rather than re-deriving plan
status locally -- see auth.resolve_plan, which is how routers actually reach
this.

Plan status is manual_override OR a Stripe subscription in "active" status.
The only writer of Stripe-derived status is services/billing.py, driven
exclusively by verified webhook events (see billing.handle_event) -- never
by the Checkout success-page redirect, which only means "the browser got
sent back", not "the payment succeeded". manual_override remains the way to
grant Pro without Stripe at all (testing, off-platform sales -- see
scripts/grant_pro.py).
"""
from datetime import datetime

from app.db import session_scope
from app.models.orm import Subscription, User


def _stripe_says_pro(subscription: Subscription) -> bool:
    return subscription.status == "active"


def is_pro(google_id: str | None) -> bool:
    """Pro status only ever applies to a known, verified account -- a
    missing google_id (guest, or an unverified caller) is never Pro."""
    if not google_id:
        return False
    with session_scope() as db:
        user = db.query(User).filter(User.google_id == google_id).one_or_none()
        if user is None:
            return False
        sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
        if sub is None:
            return False
        return bool(sub.manual_override) or _stripe_says_pro(sub)


def _get_or_create_user(db, google_id: str, *, email: str | None, name: str | None) -> User:
    user = db.query(User).filter(User.google_id == google_id).one_or_none()
    if user is None:
        user = User(google_id=google_id, email=email, name=name)
        db.add(user)
        db.flush()
    return user


def grant_manual_override(google_id: str, *, email: str | None = None, name: str | None = None) -> None:
    """Grants Pro without Stripe. Creates the user row if this is their
    first appearance in the database (e.g. granting Pro to someone who
    hasn't signed into ptolemy-web yet)."""
    with session_scope() as db:
        user = _get_or_create_user(db, google_id, email=email, name=name)
        sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
        if sub is None:
            db.add(Subscription(user_id=user.id, manual_override=True))
        else:
            sub.manual_override = True
        db.commit()


def revoke_manual_override(google_id: str) -> None:
    with session_scope() as db:
        user = db.query(User).filter(User.google_id == google_id).one_or_none()
        if user is None:
            return
        sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
        if sub is not None:
            sub.manual_override = False
            db.commit()


def get_stripe_customer_id(google_id: str) -> str | None:
    """Looks up the Stripe customer id for an account that's completed a
    checkout before, if any -- used to build a Billing Portal session. None
    means they've never subscribed (nothing to manage yet)."""
    with session_scope() as db:
        user = db.query(User).filter(User.google_id == google_id).one_or_none()
        if user is None:
            return None
        sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
        return sub.stripe_customer_id if sub else None


def sync_subscription(
    *,
    google_id: str | None,
    stripe_customer_id: str,
    stripe_subscription_id: str | None,
    status: str,
    current_period_end: datetime | None,
    email: str | None = None,
    name: str | None = None,
) -> None:
    """Upserts the Subscription row driven by a verified Stripe webhook
    event -- the only place billing.py writes subscription state, so
    is_pro() never has to reconcile two sources of truth for what "Pro"
    means. Resolves the account primarily by [google_id] (the Checkout
    Session's client_reference_id, or the Subscription object's own
    metadata -- see billing.create_checkout_session); falls back to matching
    an existing row by [stripe_customer_id] for events that carry only the
    customer id (invoice.* events), since a Subscription row already exists
    from the checkout/subscription event that necessarily preceded it.
    """
    with session_scope() as db:
        user = None
        if google_id:
            user = db.query(User).filter(User.google_id == google_id).one_or_none()
            if user is None:
                user = User(google_id=google_id, email=email, name=name)
                db.add(user)
                db.flush()
        if user is None:
            existing = (
                db.query(Subscription).filter(Subscription.stripe_customer_id == stripe_customer_id).one_or_none()
            )
            if existing is None:
                # No verified google_id on this event and no known account
                # for this Stripe customer yet -- nothing to attach to.
                return
            user = db.query(User).filter(User.id == existing.user_id).one()

        sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
        if sub is None:
            sub = Subscription(user_id=user.id)
            db.add(sub)

        sub.stripe_customer_id = stripe_customer_id
        if stripe_subscription_id:
            sub.stripe_subscription_id = stripe_subscription_id
        sub.status = status
        sub.current_period_end = current_period_end
        db.commit()


def mark_status_by_customer(stripe_customer_id: str, status: str) -> None:
    """Updates just the status of an existing subscription row, keyed by
    Stripe customer id -- used for invoice.payment_failed/succeeded events,
    which carry a customer id but not a full Subscription object. A no-op if
    no row exists yet for that customer (shouldn't happen in practice: an
    invoice event always follows an earlier subscription event that created
    the row)."""
    with session_scope() as db:
        sub = db.query(Subscription).filter(Subscription.stripe_customer_id == stripe_customer_id).one_or_none()
        if sub is None:
            return
        sub.status = status
        db.commit()
