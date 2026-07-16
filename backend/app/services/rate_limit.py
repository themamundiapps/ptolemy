"""Shared daily rate limit for AI-backed endpoints (Chart Analysis, Synastry,
Personal Synthesis) -- 10 calls per user per day, tracked by whatever
identifier the client sends (Google account id, or a locally-generated
device id for guests). JSON-file-backed for the same reason as
user_store.py: a single lookup-by-key with no query needs beyond that.
"""
import json
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

_STORE_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "ai_rate_limits.json"
_lock = Lock()

DAILY_LIMIT = 10
LIMIT_MESSAGE = "Daily analysis limit reached. Your limit resets at midnight."


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _read_all() -> dict:
    if not _STORE_PATH.exists():
        return {}
    return json.loads(_STORE_PATH.read_text(encoding="utf-8"))


def _write_all(data: dict) -> None:
    _STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    _STORE_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")


def check_and_consume(user_id: str | None) -> bool:
    """Returns True (and records the call) if [user_id] is under the daily
    limit, False if the limit is already reached. A missing user_id skips
    rate limiting entirely -- every real client call supplies one (Google id
    or device id); this only covers callers, like tests, that don't identify
    a user."""
    if not user_id:
        return True

    with _lock:
        data = _read_all()
        today = _today()
        entry = data.get(user_id)
        if entry is None or entry.get("date") != today:
            entry = {"date": today, "count": 0}

        if entry["count"] >= DAILY_LIMIT:
            return False

        entry["count"] += 1
        data[user_id] = entry
        _write_all(data)
        return True
