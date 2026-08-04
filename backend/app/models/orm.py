"""SQLAlchemy table definitions. See alembic/versions/0001_initial.py for
the migration that creates these; this module is the source of truth for
`alembic revision --autogenerate` going forward.
"""
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    google_id: Mapped[str] = mapped_column(Text, unique=True, nullable=False, index=True)
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    name: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    charts: Mapped[list["Chart"]] = relationship(back_populates="user")
    subscription: Mapped["Subscription | None"] = relationship(back_populates="user", uselist=False)


class Chart(Base):
    """A cast chart. `user_id` is nullable so a chart cast by a guest (no
    account yet) can exist before login and be claimed afterward via
    `guest_id` -- see services/chart_store.py:claim_charts_for_guest.

    `source` distinguishes the legacy Flutter single-slot sync ('legacy')
    from charts created through this table's normal multi-row use ('web').
    The legacy /user/chart endpoint (services/user_store.py) upserts the one
    'legacy' row per user instead of ever accumulating rows, preserving the
    frozen Flutter app's overwrite-on-save contract.
    """
    __tablename__ = "charts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    guest_id: Mapped[str | None] = mapped_column(Text, nullable=True, index=True)
    source: Mapped[str] = mapped_column(Text, nullable=False, default="web")

    city_name: Mapped[str] = mapped_column(Text, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    birth_date: Mapped[date] = mapped_column(Date, nullable=False)
    birth_time: Mapped[str] = mapped_column(Text, nullable=False)
    tz_offset: Mapped[float | None] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped["User | None"] = relationship(back_populates="charts")


class AiUsage(Base):
    """Daily AI-call counter, one row per (subject, day). `subject_id` is
    opaque -- a Google account id for signed-in users or a locally-generated
    device id for guests, same convention the old JSON store used.
    """
    __tablename__ = "ai_usage"
    __table_args__ = (UniqueConstraint("subject_id", "window_date", name="uq_ai_usage_subject_date"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    subject_id: Mapped[str] = mapped_column(Text, nullable=False, index=True)
    window_date: Mapped[date] = mapped_column(Date, nullable=False)
    call_count: Mapped[int] = mapped_column(default=0, nullable=False)


class Subscription(Base):
    """The billing/entitlement row for a user. Stripe fields are still a
    placeholder -- no billing logic reads or writes them yet, see
    services/subscription.py:_stripe_says_pro. `manual_override` is live now:
    it's the only way to grant Pro before Stripe checkout exists, used for
    testing and for manual/off-platform sales (see scripts/grant_pro.py)."""
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, nullable=False)
    stripe_customer_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    stripe_subscription_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str | None] = mapped_column(Text, nullable=True)
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    manual_override: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped["User"] = relationship(back_populates="subscription")
