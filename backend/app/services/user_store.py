"""Backs the legacy `/user/chart` save+load endpoint the Flutter app depends
on (see api_client.dart) -- a returning Google sign-in pulls its last-saved
birth data back down from here to recompute the chart on any device.

Historically a JSON file keyed by google_id, one record each, overwritten on
every save. Now backed by the `charts` table (shared with the newer
guest-chart-claim flow in chart_store.py), but the *contract* here is
unchanged: exactly one record per user, last write wins. That single record
is distinguished from the multi-row charts a ptolemy-web guest accumulates
by `source == "legacy"` -- there is at most one such row per user at a time.
"""
from datetime import date

from sqlalchemy.orm import Session

from app.db import session_scope
from app.models.orm import Chart, User

_LEGACY_SOURCE = "legacy"


def _get_or_create_user(db: Session, google_id: str) -> User:
    user = db.query(User).filter(User.google_id == google_id).one_or_none()
    if user is None:
        user = User(google_id=google_id)
        db.add(user)
        db.flush()
    return user


def save_chart(google_id: str, chart_data: dict) -> None:
    with session_scope() as db:
        user = _get_or_create_user(db, google_id)
        row = (
            db.query(Chart)
            .filter(Chart.user_id == user.id, Chart.source == _LEGACY_SOURCE)
            .one_or_none()
        )
        if row is None:
            row = Chart(user_id=user.id, source=_LEGACY_SOURCE)
            db.add(row)

        row.city_name = chart_data["city_name"]
        row.latitude = chart_data["latitude"]
        row.longitude = chart_data["longitude"]
        row.birth_date = date.fromisoformat(chart_data["date"])
        row.birth_time = chart_data["time"]
        row.tz_offset = chart_data.get("tz_offset")
        db.commit()


def get_chart(google_id: str) -> dict | None:
    with session_scope() as db:
        user = db.query(User).filter(User.google_id == google_id).one_or_none()
        if user is None:
            return None
        row = (
            db.query(Chart)
            .filter(Chart.user_id == user.id, Chart.source == _LEGACY_SOURCE)
            .one_or_none()
        )
        if row is None:
            return None
        return {
            "city_name": row.city_name,
            "latitude": row.latitude,
            "longitude": row.longitude,
            "date": row.birth_date.isoformat(),
            "time": row.birth_time,
            "tz_offset": row.tz_offset,
        }
