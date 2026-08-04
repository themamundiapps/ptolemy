"""Shared DB-test fixture: points app.db.SessionLocal at a fresh, isolated
SQLite database for the duration of a test, so DB-backed services
(user_store, rate_limit, chart_store) never touch the real database or leak
state between tests -- the same isolation the old JSON-file tests got from
pointing _STORE_PATH at tmp_path.
"""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db import Base
import app.db as db_module
from app.models import orm  # noqa: F401  -- registers tables on Base.metadata


@pytest.fixture
def test_db(tmp_path, monkeypatch):
    engine = create_engine(f"sqlite:///{tmp_path}/test.db", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    session_local = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    monkeypatch.setattr(db_module, "SessionLocal", session_local)
    yield
    engine.dispose()
