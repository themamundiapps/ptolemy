"""Backs the ptolemy-web guest-chart-claim flow: a chart cast while signed
out is written here immediately (user_id NULL, keyed by the browser's
locally-generated device id as guest_id) so it already exists in the
database by the time the user signs in and it can be reassigned to their
account -- rather than only ever living in localStorage, unrecoverable if
that browser/device is lost.

Distinct from user_store.py's single legacy slot: charts created here
accumulate (source="web"), one row per cast, never overwritten.
"""
from datetime import date

from app.db import session_scope
from app.models.orm import Chart, User


def create_chart(
    *,
    city_name: str,
    latitude: float,
    longitude: float,
    birth_date: str,
    birth_time: str,
    tz_offset: float | None,
    guest_id: str | None,
    google_id: str | None,
) -> int:
    """Creates a chart row. If [google_id] is given (caller is signed in),
    the chart is owned immediately; otherwise it's anonymous, tagged with
    [guest_id] so claim_charts_for_guest can find it later."""
    with session_scope() as db:
        user_id = None
        if google_id:
            user = db.query(User).filter(User.google_id == google_id).one_or_none()
            if user is None:
                user = User(google_id=google_id)
                db.add(user)
                db.flush()
            user_id = user.id

        chart = Chart(
            user_id=user_id,
            guest_id=guest_id,
            source="web",
            city_name=city_name,
            latitude=latitude,
            longitude=longitude,
            birth_date=date.fromisoformat(birth_date),
            birth_time=birth_time,
            tz_offset=tz_offset,
        )
        db.add(chart)
        db.commit()
        db.refresh(chart)
        return chart.id


def claim_charts_for_guest(*, guest_id: str, google_id: str, email: str | None, name: str | None) -> int:
    """Reassigns every unclaimed chart (user_id IS NULL) tagged with
    [guest_id] to the account identified by [google_id], creating that
    account's row if this is its first appearance. Returns how many charts
    were claimed. Idempotent -- calling again with nothing left to claim
    just returns 0, so the frontend can call it on every sign-in without
    tracking whether it already ran."""
    with session_scope() as db:
        user = db.query(User).filter(User.google_id == google_id).one_or_none()
        if user is None:
            user = User(google_id=google_id, email=email, name=name)
            db.add(user)
            db.flush()
        else:
            if email and user.email != email:
                user.email = email
            if name and user.name != name:
                user.name = name

        claimed = (
            db.query(Chart)
            .filter(Chart.guest_id == guest_id, Chart.user_id.is_(None))
            .update({Chart.user_id: user.id}, synchronize_session=False)
        )
        db.commit()
        return claimed
