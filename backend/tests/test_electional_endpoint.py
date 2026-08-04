"""Tests for the /electional endpoint's Pro theme gate (routers/electional.py).
The scan logic itself (essential/important checklist, quality labels, etc.)
is covered exhaustively in test_electional.py against the pure scan()
function -- this file only exercises the router's plan check, so requests
here use a short date range to keep the real scan cheap."""
import jwt
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import auth, subscription

client = TestClient(app)

_JWT_SECRET = "test-electional-secret"

_BASE_PAYLOAD = {
    "date": "1990-06-15",
    "time": "14:30",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "tz_offset": -3.0,
    "start_date": "2026-01-05",
    "end_date": "2026-01-06",
}

_FREE_THEME = "love_relationships"
_PRO_THEME = "business_career"


@pytest.fixture(autouse=True)
def _internal_auth_secret(monkeypatch):
    monkeypatch.setattr(auth, "INTERNAL_AUTH_SECRET", _JWT_SECRET)


def _bearer(sub: str) -> str:
    return "Bearer " + jwt.encode({"sub": sub}, _JWT_SECRET, algorithm="HS256")


def test_unknown_theme_is_400():
    response = client.post("/api/v1/electional", json={**_BASE_PAYLOAD, "theme": "not_a_real_theme"})
    assert response.status_code == 400


def test_free_theme_works_without_any_auth():
    response = client.post("/api/v1/electional", json={**_BASE_PAYLOAD, "theme": _FREE_THEME})
    assert response.status_code == 200
    assert response.json()["theme"] == _FREE_THEME


def test_pro_theme_rejects_a_free_caller(test_db):
    response = client.post("/api/v1/electional", json={**_BASE_PAYLOAD, "theme": _PRO_THEME})
    assert response.status_code == 403
    assert "Pro" in response.json()["detail"]


def test_pro_theme_rejects_a_signed_in_caller_without_pro(test_db):
    response = client.post(
        "/api/v1/electional",
        json={**_BASE_PAYLOAD, "theme": _PRO_THEME},
        headers={"Authorization": _bearer("google-free-1")},
    )
    assert response.status_code == 403


def test_pro_theme_succeeds_for_a_manually_granted_pro_account(test_db):
    subscription.grant_manual_override("google-pro-1")
    response = client.post(
        "/api/v1/electional",
        json={**_BASE_PAYLOAD, "theme": _PRO_THEME},
        headers={"Authorization": _bearer("google-pro-1")},
    )
    assert response.status_code == 200
    assert response.json()["theme"] == _PRO_THEME


def test_all_four_pro_themes_are_gated(test_db):
    for theme in ["business_career", "health_body", "spiritual_learning", "home_family"]:
        response = client.post("/api/v1/electional", json={**_BASE_PAYLOAD, "theme": theme})
        assert response.status_code == 403, f"{theme} should be Pro-gated"


def test_both_free_themes_are_open(test_db):
    for theme in ["love_relationships", "travel"]:
        response = client.post("/api/v1/electional", json={**_BASE_PAYLOAD, "theme": theme})
        assert response.status_code == 200, f"{theme} should stay free"
