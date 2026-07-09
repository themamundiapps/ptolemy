"""Minimal JSON-file-backed store mapping a Google account id to that user's
last-saved birth data, so a returning sign-in on any device can pull it back
down and recompute the chart. Not a real database -- there's exactly one
user-facing record type and no query needs beyond "get by id" / "put by id",
so a single JSON file is simpler than standing up SQLite for this session's
scope.
"""
import json
from pathlib import Path
from threading import Lock

_STORE_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "user_charts.json"
_lock = Lock()


def _read_all() -> dict:
    if not _STORE_PATH.exists():
        return {}
    return json.loads(_STORE_PATH.read_text(encoding="utf-8"))


def _write_all(data: dict) -> None:
    _STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    _STORE_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")


def save_chart(google_id: str, chart_data: dict) -> None:
    with _lock:
        data = _read_all()
        data[google_id] = chart_data
        _write_all(data)


def get_chart(google_id: str) -> dict | None:
    with _lock:
        return _read_all().get(google_id)
