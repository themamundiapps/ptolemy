"""Single source of truth for "is this user Pro?" Every Pro-gated surface
(Electional's 4 non-free themes, Temperament's Traditional Recommendations,
Chart Analysis, Synastry) calls is_pro() here rather than re-deriving plan
status locally -- see auth.resolve_plan, which is how routers actually reach
this.

Stripe billing isn't wired up yet -- _stripe_says_pro is a placeholder that
always returns False, so today plan status is driven entirely by the
manual_override flag on the user's Subscription row. That flag is real now,
not a placeholder: it's the only way to grant Pro before checkout exists,
used for testing and for manual/off-platform sales (see scripts/grant_pro.py
or grant_manual_override directly).
"""
from app.db import session_scope
from app.models.orm import Subscription, User


def _stripe_says_pro(subscription: Subscription) -> bool:
    return False


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
