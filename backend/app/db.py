"""Engine/session setup. DATABASE_URL is required in production (Railway
Postgres); tests override it via the test_db fixture in conftest.py, which
points SessionLocal at an isolated SQLite file instead of touching this
module's defaults.
"""
import os
from contextlib import contextmanager
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./data/ptolemy.db")

# Railway's DATABASE_URL uses the `postgres://` scheme, which SQLAlchemy 2.x
# rejects in favor of the explicit `postgresql://` (or a driver-qualified
# variant); psycopg3 additionally wants `postgresql+psycopg://`.
_url = DATABASE_URL
if _url.startswith("postgres://"):
    _url = "postgresql+psycopg://" + _url[len("postgres://"):]
elif _url.startswith("postgresql://"):
    _url = "postgresql+psycopg://" + _url[len("postgresql://"):]

if _url.startswith("sqlite:///"):
    Path(_url[len("sqlite:///"):]).parent.mkdir(parents=True, exist_ok=True)

_connect_args = {"check_same_thread": False} if _url.startswith("sqlite") else {}
engine = create_engine(_url, connect_args=_connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def session_scope():
    """For call sites (services, not FastAPI request handlers) that need a
    session outside the `Depends(get_db)` request lifecycle."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
