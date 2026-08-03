"""Tests for services/auth.py -- verification of the internal JWT that
ptolemy-web mints for signed-in users, replacing the raw client-supplied
user_id for rate-limit purposes."""
import jwt
import pytest

from app.services import auth

SECRET = "test-secret"


@pytest.fixture(autouse=True)
def _use_test_secret(monkeypatch):
    monkeypatch.setattr(auth, "INTERNAL_AUTH_SECRET", SECRET)


def _token(sub: str = "google-123", secret: str = SECRET, **claims) -> str:
    return jwt.encode({"sub": sub, **claims}, secret, algorithm="HS256")


def test_valid_bearer_token_wins_over_fallback():
    assert auth.resolve_user_id(f"Bearer {_token()}", "device-abc") == "google-123"


def test_no_authorization_header_uses_fallback():
    assert auth.resolve_user_id(None, "device-abc") == "device-abc"


def test_malformed_scheme_uses_fallback():
    assert auth.resolve_user_id(f"Basic {_token()}", "device-abc") == "device-abc"


def test_wrong_signature_uses_fallback():
    assert auth.resolve_user_id(f"Bearer {_token(secret='wrong-secret')}", "device-abc") == "device-abc"


def test_expired_token_uses_fallback():
    token = _token(exp=0)
    assert auth.resolve_user_id(f"Bearer {token}", "device-abc") == "device-abc"


def test_token_without_sub_uses_fallback():
    token = jwt.encode({}, SECRET, algorithm="HS256")
    assert auth.resolve_user_id(f"Bearer {token}", "device-abc") == "device-abc"


def test_no_secret_configured_uses_fallback(monkeypatch):
    monkeypatch.setattr(auth, "INTERNAL_AUTH_SECRET", None)
    assert auth.resolve_user_id(f"Bearer {_token()}", "device-abc") == "device-abc"
