"""Tests for the /api/v1/user/chart save+load endpoints backing Session 9's
onboarding/persistence feature -- a returning Google sign-in pulls its last
saved birth data back down from here to recompute the chart."""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import user_store

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


@pytest.fixture(autouse=True)
def _isolate_store(tmp_path, monkeypatch):
    monkeypatch.setattr(user_store, "_STORE_PATH", tmp_path / "user_charts.json")
    yield


def test_get_chart_404_when_nothing_saved():
    response = client.get("/api/v1/user/chart/no-such-user")
    assert response.status_code == 404


def test_save_then_get_roundtrips_the_birth_data():
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


def test_saving_again_overwrites_the_previous_entry():
    client.post("/api/v1/user/chart", json=_PAYLOAD)
    updated = {**_PAYLOAD, "city_name": "Rome, Italy", "latitude": 41.9028, "longitude": 12.4964}
    client.post("/api/v1/user/chart", json=updated)

    get_response = client.get(f"/api/v1/user/chart/{_PAYLOAD['google_id']}")
    assert get_response.json()["city_name"] == "Rome, Italy"


def test_works_with_a_real_shaped_google_account_id():
    # A real Google account "sub" claim is a long numeric string (commonly
    # ~21 digits) -- distinct in shape from the short hand-written mock id
    # ("mock-google-user-001") this endpoint was originally exercised with.
    # google_id is just an opaque str key end to end (schemas.py has no
    # length/format constraint, and user_store.py is a plain dict keyed by
    # whatever string it's given), so no backend change was needed for this
    # to already work -- this test pins that.
    real_id = "108234982374928374023"
    payload = {**_PAYLOAD, "google_id": real_id}
    save_response = client.post("/api/v1/user/chart", json=payload)
    assert save_response.status_code == 200

    get_response = client.get(f"/api/v1/user/chart/{real_id}")
    assert get_response.status_code == 200
    assert get_response.json()["city_name"] == payload["city_name"]
