"""Tests for services/subscription.py -- the single source of truth for
"is this user Pro?" Stripe billing isn't wired up yet (is_pro is always
False unless the manual override is set), so these tests exercise the
override mechanism directly: it's the only real path to Pro today, used for
testing and manual/off-platform sales (see scripts/grant_pro.py)."""
from app.models.orm import User
from app.services import subscription


def test_unknown_account_is_not_pro(test_db):
    assert subscription.is_pro("no-such-google-id") is False


def test_missing_google_id_is_not_pro(test_db):
    assert subscription.is_pro(None) is False
    assert subscription.is_pro("") is False


def test_grant_manual_override_makes_the_account_pro(test_db):
    subscription.grant_manual_override("google-1")
    assert subscription.is_pro("google-1") is True


def test_grant_creates_the_user_row_if_it_does_not_exist(test_db):
    subscription.grant_manual_override("google-new", email="a@example.com", name="A")
    from app.db import session_scope

    with session_scope() as db:
        user = db.query(User).filter(User.google_id == "google-new").one()
        assert user.email == "a@example.com"
        assert user.name == "A"


def test_grant_is_idempotent(test_db):
    subscription.grant_manual_override("google-1")
    subscription.grant_manual_override("google-1")
    assert subscription.is_pro("google-1") is True


def test_revoke_manual_override_makes_the_account_free_again(test_db):
    subscription.grant_manual_override("google-1")
    assert subscription.is_pro("google-1") is True
    subscription.revoke_manual_override("google-1")
    assert subscription.is_pro("google-1") is False


def test_revoke_on_an_account_with_no_subscription_row_is_a_harmless_no_op(test_db):
    subscription.revoke_manual_override("never-granted")
    assert subscription.is_pro("never-granted") is False


def test_revoke_on_an_unknown_account_is_a_harmless_no_op(test_db):
    subscription.revoke_manual_override("no-such-account-at-all")
