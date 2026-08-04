"""Shared daily rate limit for AI-backed endpoints (Chart Analysis, Synastry,
Chat, Personal Synthesis) -- 10 calls per user per day, tracked by whatever
identifier the client sends (Google account id, or a locally-generated
device id for guests). Backed by the `ai_usage` table (one row per
subject/day, see models/orm.py); previously a JSON file for the same reason
-- a single lookup-by-key with no query needs beyond that.
"""
from datetime import date, datetime, timezone

from sqlalchemy.exc import IntegrityError

from app.db import session_scope
from app.models.orm import AiUsage

DAILY_LIMIT = 10
LIMIT_MESSAGE = "Daily analysis limit reached. Your limit resets at midnight."


def _today() -> date:
    return datetime.now(timezone.utc).date()


def check_and_consume(user_id: str | None) -> bool:
    """Returns True (and records the call) if [user_id] is under the daily
    limit, False if the limit is already reached. A missing user_id skips
    rate limiting entirely -- every real client call supplies one (Google id
    or device id); this only covers callers, like tests, that don't identify
    a user."""
    if not user_id:
        return True

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

        if row.call_count >= DAILY_LIMIT:
            db.rollback()
            return False

        row.call_count += 1
        db.commit()
        return True


def remaining(user_id: str | None) -> int:
    """Read-only lookup of how many AI calls [user_id] has left today --
    unlike check_and_consume, this never records a call. A missing user_id
    (same convention as check_and_consume) reports the full limit, since no
    identifier means no per-user count is tracked for it."""
    if not user_id:
        return DAILY_LIMIT

    with session_scope() as db:
        row = (
            db.query(AiUsage)
            .filter(AiUsage.subject_id == user_id, AiUsage.window_date == _today())
            .one_or_none()
        )
        if row is None:
            return DAILY_LIMIT
        return max(DAILY_LIMIT - row.call_count, 0)
