"""Shared daily rate limit for AI-backed endpoints (Chart Analysis, Synastry,
Chat, Personal Synthesis), tracked by whatever identifier the client sends
(Google account id, or a locally-generated device id for guests). The limit
itself varies by plan (see services/subscription.py) -- FREE_DAILY_LIMIT for
everyone else, PRO_DAILY_LIMIT for a verified Pro account. Backed by the
`ai_usage` table (one row per subject/day, see models/orm.py).
"""
from datetime import date, datetime, timezone

from sqlalchemy.exc import IntegrityError

from app.db import session_scope
from app.models.orm import AiUsage

FREE_DAILY_LIMIT = 5
PRO_DAILY_LIMIT = 50


def daily_limit(is_pro: bool) -> int:
    return PRO_DAILY_LIMIT if is_pro else FREE_DAILY_LIMIT


def limit_message(is_pro: bool) -> str:
    """Free users get an upgrade nudge alongside the reset time; a Pro user
    hitting their (much higher) ceiling just needs the reset time -- they're
    already on the plan there is to upgrade to."""
    if is_pro:
        return f"Daily limit reached ({PRO_DAILY_LIMIT}/day). Your limit resets at midnight UTC."
    return (
        f"Daily limit reached ({FREE_DAILY_LIMIT}/day on the free plan). "
        f"Upgrade to Pro for {PRO_DAILY_LIMIT}/day. Your limit resets at midnight UTC."
    )


def _today() -> date:
    return datetime.now(timezone.utc).date()


def check_and_consume(user_id: str | None, is_pro: bool = False) -> bool:
    """Returns True (and records the call) if [user_id] is under its plan's
    daily limit, False if the limit is already reached. A missing user_id
    skips rate limiting entirely -- every real client call supplies one
    (Google id or device id); this only covers callers, like tests, that
    don't identify a user."""
    if not user_id:
        return True

    limit = daily_limit(is_pro)
    today = _today()
    with session_scope() as db:
        row = (
            db.query(AiUsage)
            .filter(AiUsage.subject_id == user_id, AiUsage.window_date == today)
            .with_for_update(read=False)
            .one_or_none()
        )
        if row is None:
            try:
                row = AiUsage(subject_id=user_id, window_date=today, call_count=0)
                db.add(row)
                db.flush()
            except IntegrityError:
                # Lost a race with a concurrent request for the same
                # subject/day -- fetch the row it just created instead.
                db.rollback()
                row = (
                    db.query(AiUsage)
                    .filter(AiUsage.subject_id == user_id, AiUsage.window_date == today)
                    .one()
                )

        if row.call_count >= limit:
            db.rollback()
            return False

        row.call_count += 1
        db.commit()
        return True


def remaining(user_id: str | None, is_pro: bool = False) -> int:
    """Read-only lookup of how many AI calls [user_id] has left today under
    its plan's limit -- unlike check_and_consume, this never records a call.
    A missing user_id (same convention as check_and_consume) reports the
    full limit, since no identifier means no per-user count is tracked for
    it."""
    limit = daily_limit(is_pro)
    if not user_id:
        return limit

    with session_scope() as db:
        row = (
            db.query(AiUsage)
            .filter(AiUsage.subject_id == user_id, AiUsage.window_date == _today())
            .one_or_none()
        )
        if row is None:
            return limit
        return max(limit - row.call_count, 0)
