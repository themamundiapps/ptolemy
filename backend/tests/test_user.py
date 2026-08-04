"""Tests for the /api/v1/user/chart save+load endpoints backing Session 9's
onboarding/persistence feature -- a returning Google sign-in pulls its last
saved birth data back down from here to recompute the chart. Also covers
/api/v1/user/ai-quota, the read-only lookup of the shared daily AI budget,
and the newer /api/v1/user/charts (create) + /api/v1/user/charts/claim
guest-chart-persistence endpoints.

Each test runs against a fresh, isolated test database (see conftest.py's
test_db fixture)."""
import jwt
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import auth, rate_limit

client = TestClient(app)

_PAYLOAD = {
    "google_id": "test-user-session9",
    "city_name": "Curitiba, Brazil",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "date": "1990-06-15",
    "time": "14:30",
    "tz_offset": -3.0,
}


def test_get_chart_404_when_nothing_saved(test_db):
    response = client.get("/api/v1/user/chart/no-such-user")
    assert response.status_code == 404


def test_save_then_get_roundtrips_the_birth_data(test_db):
    save_response = client.post("/api/v1/user/chart", json=_PAYLOAD)
    assert save_response.status_code == 200

    get_response = client.get(f"/api/v1/user/chart/{_PAYLOAD['google_id']}")
    assert get_response.status_code == 200
    body = get_response.json()
    assert body["city_name"] == _PAYLOAD["city_name"]
    assert body["latitude"] == _PAYLOAD["latitude"]
    assert body["longitude"] == _PAYLOAD["longitude"]
    assert body["date"] == _PAYLOAD["date"]
    assert body["time"] == _PAYLOAD["time"]
    assert body["tz_offset"] == _PAYLOAD["tz_offset"]
    assert "google_id" not in body


def test_saving_again_overwrites_the_previous_entry(test_db):
    client.post("/api/v1/user/chart", json=_PAYLOAD)
    updated = {**_PAYLOAD, "city_name": "Rome, Italy", "latitude": 41.9028, "longitude": 12.4964}
    client.post("/api/v1/user/chart", json=updated)

    get_response = client.get(f"/api/v1/user/chart/{_PAYLOAD['google_id']}")
    assert get_response.json()["city_name"] == "Rome, Italy"


def test_works_with_a_real_shaped_google_account_id(test_db):
    # A real Google account "sub" claim is a long numeric string (commonly
    # ~21 digits) -- distinct in shape from the short hand-written mock id
    # ("mock-google-user-001") this endpoint was originally exercised with.
    # google_id is just an opaque str key end to end, so no backend change
    # was needed for this to already work -- this test pins that.
    real_id = "108234982374928374023"
    payload = {**_PAYLOAD, "google_id": real_id}
    save_response = client.post("/api/v1/user/chart", json=payload)
    assert save_response.status_code == 200

    get_response = client.get(f"/api/v1/user/chart/{real_id}")
    assert get_response.status_code == 200
    assert get_response.json()["city_name"] == payload["city_name"]


# ---------------------------------------------------------------------------
# /api/v1/user/ai-quota
# ---------------------------------------------------------------------------


def test_ai_quota_reports_the_full_limit_for_a_fresh_user(test_db):
    response = client.get("/api/v1/user/ai-quota", params={"user_id": "fresh-user"})
    assert response.status_code == 200
    body = response.json()
    assert body == {"remaining": rate_limit.DAILY_LIMIT, "limit": rate_limit.DAILY_LIMIT, "resets_at": "midnight UTC"}


def test_ai_quota_reflects_calls_already_made(test_db):
    rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    response = client.get("/api/v1/user/ai-quota", params={"user_id": "user-1"})
    assert response.json()["remaining"] == rate_limit.DAILY_LIMIT - 2


def test_ai_quota_works_without_a_user_id(test_db):
    response = client.get("/api/v1/user/ai-quota")
    assert response.status_code == 200
    assert response.json()["remaining"] == rate_limit.DAILY_LIMIT


def test_ai_quota_does_not_consume_a_unit(test_db):
    for _ in range(5):
        client.get("/api/v1/user/ai-quota", params={"user_id": "user-1"})
    assert rate_limit.remaining("user-1") == rate_limit.DAILY_LIMIT


# ---------------------------------------------------------------------------
# /api/v1/user/charts (create) + /api/v1/user/charts/claim
# ---------------------------------------------------------------------------

_CHART_PAYLOAD = {
    "city_name": "Curitiba, Brazil",
    "latitude": -25.4284,
    "longitude": -49.2733,
    "date": "1990-06-15",
    "time": "14:30",
    "tz_offset": -3.0,
}

_JWT_SECRET = "test-internal-secret"


@pytest.fixture(autouse=True)
def _internal_auth_secret(monkeypatch):
    monkeypatch.setattr(auth, "INTERNAL_AUTH_SECRET", _JWT_SECRET)


def _bearer(sub: str = "google-42", **claims) -> str:
    return "Bearer " + jwt.encode({"sub": sub, **claims}, _JWT_SECRET, algorithm="HS256")


def test_create_guest_chart_succeeds_without_auth(test_db):
    response = client.post("/api/v1/user/charts", json={**_CHART_PAYLOAD, "guest_id": "device-1"})
    assert response.status_code == 200
    assert isinstance(response.json()["id"], int)


def test_create_chart_while_signed_in_does_not_require_guest_id(test_db):
    response = client.post(
        "/api/v1/user/charts", json=_CHART_PAYLOAD, headers={"Authorization": _bearer()}
    )
    assert response.status_code == 200


def test_claim_without_auth_is_rejected(test_db):
    response = client.post("/api/v1/user/charts/claim", json={"guest_id": "device-1"})
    assert response.status_code == 401


def test_claim_reassigns_guest_charts_to_the_signed_in_account(test_db):
    client.post("/api/v1/user/charts", json={**_CHART_PAYLOAD, "guest_id": "device-1"})
    client.post("/api/v1/user/charts", json={**_CHART_PAYLOAD, "guest_id": "device-1"})

    response = client.post(
        "/api/v1/user/charts/claim",
        json={"guest_id": "device-1"},
        headers={"Authorization": _bearer(sub="google-99", email="a@example.com", name="A")},
    )
    assert response.status_code == 200
    assert response.json()["claimed"] == 2


def test_claim_does_not_touch_a_different_guest_id(test_db):
    client.post("/api/v1/user/charts", json={**_CHART_PAYLOAD, "guest_id": "device-1"})
    client.post("/api/v1/user/charts", json={**_CHART_PAYLOAD, "guest_id": "device-2"})

    response = client.post(
        "/api/v1/user/charts/claim",
        json={"guest_id": "device-1"},
        headers={"Authorization": _bearer(sub="google-99")},
    )
    assert response.json()["claimed"] == 1


def test_claim_is_idempotent(test_db):
    client.post("/api/v1/user/charts", json={**_CHART_PAYLOAD, "guest_id": "device-1"})
    headers = {"Authorization": _bearer(sub="google-99")}
    first = client.post("/api/v1/user/charts/claim", json={"guest_id": "device-1"}, headers=headers)
    second = client.post("/api/v1/user/charts/claim", json={"guest_id": "device-1"}, headers=headers)
    assert first.json()["claimed"] == 1
    assert second.json()["claimed"] == 0
