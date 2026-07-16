"""Tests for the shared daily AI-call rate limit (services/rate_limit.py),
used by /chart/analysis, /chart/synastry, and /interpretations/synthesis.
Each test points the store at a fresh tmp_path file so runs never interact
with the real backend/data/ai_rate_limits.json or with each other."""
from app.services import rate_limit


def _use_tmp_store(monkeypatch, tmp_path):
    monkeypatch.setattr(rate_limit, "_STORE_PATH", tmp_path / "ai_rate_limits.json")


def test_missing_user_id_is_never_rate_limited(monkeypatch, tmp_path):
    _use_tmp_store(monkeypatch, tmp_path)
    for _ in range(rate_limit.DAILY_LIMIT + 5):
        assert rate_limit.check_and_consume(None) is True


def test_allows_up_to_the_daily_limit(monkeypatch, tmp_path):
    _use_tmp_store(monkeypatch, tmp_path)
    for _ in range(rate_limit.DAILY_LIMIT):
        assert rate_limit.check_and_consume("user-1") is True


def test_rejects_the_call_after_the_daily_limit(monkeypatch, tmp_path):
    _use_tmp_store(monkeypatch, tmp_path)
    for _ in range(rate_limit.DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.check_and_consume("user-1") is False


def test_users_are_tracked_independently(monkeypatch, tmp_path):
    _use_tmp_store(monkeypatch, tmp_path)
    for _ in range(rate_limit.DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.check_and_consume("user-1") is False
    assert rate_limit.check_and_consume("user-2") is True


def test_rejected_call_is_not_counted_again(monkeypatch, tmp_path):
    _use_tmp_store(monkeypatch, tmp_path)
    for _ in range(rate_limit.DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    data = rate_limit._read_all()
    assert data["user-1"]["count"] == rate_limit.DAILY_LIMIT


def test_a_new_day_resets_the_count(monkeypatch, tmp_path):
    _use_tmp_store(monkeypatch, tmp_path)
    for _ in range(rate_limit.DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.check_and_consume("user-1") is False

    monkeypatch.setattr(rate_limit, "_today", lambda: "2999-01-01")
    assert rate_limit.check_and_consume("user-1") is True
