"""Tests for the shared daily AI-call rate limit (services/rate_limit.py).
Each test runs against a fresh, isolated test database (see conftest.py's
test_db fixture) so runs never interact with the real database or with each
other."""
from app.services import rate_limit


def test_missing_user_id_is_never_rate_limited(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT + 5):
        assert rate_limit.check_and_consume(None) is True


def test_allows_up_to_the_daily_limit(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        assert rate_limit.check_and_consume("user-1") is True


def test_rejects_the_call_after_the_daily_limit(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.check_and_consume("user-1") is False


def test_users_are_tracked_independently(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.check_and_consume("user-1") is False
    assert rate_limit.check_and_consume("user-2") is True


def test_rejected_call_is_not_counted_again(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    assert rate_limit.remaining("user-1") == 0


def test_a_new_day_resets_the_count(test_db, monkeypatch):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.check_and_consume("user-1") is False

    from datetime import date

    monkeypatch.setattr(rate_limit, "_today", lambda: date(2999, 1, 1))
    assert rate_limit.check_and_consume("user-1") is True


# ---------------------------------------------------------------------------
# remaining() -- read-only, must never consume a unit
# ---------------------------------------------------------------------------


def test_remaining_is_the_full_limit_for_a_user_with_no_calls_yet(test_db):
    assert rate_limit.remaining("fresh-user") == rate_limit.FREE_DAILY_LIMIT


def test_remaining_is_the_full_limit_for_a_missing_user_id(test_db):
    assert rate_limit.remaining(None) == rate_limit.FREE_DAILY_LIMIT


def test_remaining_decreases_as_calls_are_consumed(test_db):
    rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")
    assert rate_limit.remaining("user-1") == rate_limit.FREE_DAILY_LIMIT - 3


def test_remaining_never_goes_below_zero(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    rate_limit.check_and_consume("user-1")  # rejected, shouldn't push the count past the limit anyway
    assert rate_limit.remaining("user-1") == 0


def test_remaining_does_not_itself_consume_a_unit(test_db):
    rate_limit.remaining("user-1")
    rate_limit.remaining("user-1")
    rate_limit.remaining("user-1")
    assert rate_limit.remaining("user-1") == rate_limit.FREE_DAILY_LIMIT


def test_remaining_resets_on_a_new_day(test_db, monkeypatch):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        rate_limit.check_and_consume("user-1")
    assert rate_limit.remaining("user-1") == 0

    from datetime import date

    monkeypatch.setattr(rate_limit, "_today", lambda: date(2999, 1, 1))
    assert rate_limit.remaining("user-1") == rate_limit.FREE_DAILY_LIMIT


# ---------------------------------------------------------------------------
# Plan-aware limits -- 5/day free, 50/day Pro
# ---------------------------------------------------------------------------


def test_daily_limit_is_5_for_free_and_50_for_pro():
    assert rate_limit.FREE_DAILY_LIMIT == 5
    assert rate_limit.PRO_DAILY_LIMIT == 50
    assert rate_limit.daily_limit(is_pro=False) == 5
    assert rate_limit.daily_limit(is_pro=True) == 50


def test_pro_caller_gets_the_pro_ceiling_not_the_free_one(test_db):
    for _ in range(rate_limit.FREE_DAILY_LIMIT):
        assert rate_limit.check_and_consume("pro-user", is_pro=True) is True
    # A free caller would be rejected by now -- a Pro one keeps going.
    assert rate_limit.check_and_consume("pro-user", is_pro=True) is True


def test_pro_caller_is_rejected_after_50(test_db):
    for _ in range(rate_limit.PRO_DAILY_LIMIT):
        assert rate_limit.check_and_consume("pro-user", is_pro=True) is True
    assert rate_limit.check_and_consume("pro-user", is_pro=True) is False


def test_free_and_pro_counts_for_the_same_subject_id_are_not_isolated(test_db):
    # is_pro only changes which ceiling applies -- the count itself is keyed
    # by subject_id alone, so a caller's usage carries over if their plan
    # status changes mid-day (e.g. right after upgrading).
    for _ in range(3):
        rate_limit.check_and_consume("user-1", is_pro=False)
    assert rate_limit.remaining("user-1", is_pro=True) == rate_limit.PRO_DAILY_LIMIT - 3


def test_remaining_reflects_the_pro_ceiling(test_db):
    assert rate_limit.remaining("fresh-pro-user", is_pro=True) == rate_limit.PRO_DAILY_LIMIT


def test_limit_message_mentions_upgrade_for_free_but_not_pro():
    free_message = rate_limit.limit_message(is_pro=False)
    pro_message = rate_limit.limit_message(is_pro=True)
    assert "Upgrade" in free_message
    assert "Upgrade" not in pro_message
    assert str(rate_limit.FREE_DAILY_LIMIT) in free_message
    assert str(rate_limit.PRO_DAILY_LIMIT) in pro_message
