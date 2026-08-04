"""Grant or revoke the manual Pro override for an account -- for testing and
for manual/off-platform sales, since there's no Stripe checkout yet (see
app/services/subscription.py).

Run against whatever DATABASE_URL is in the environment, so point this at
the right database explicitly rather than relying on a default:

    DATABASE_URL=postgresql://... python scripts/grant_pro.py --email a@b.com
    DATABASE_URL=postgresql://... python scripts/grant_pro.py --google-id 108234982374928374023 --revoke

--email only works for someone who has already signed into ptolemy-web at
least once (there needs to be a users row to look up) -- use --google-id
directly to grant Pro to a brand-new account before their first sign-in.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db import session_scope  # noqa: E402
from app.models.orm import User  # noqa: E402
from app.services import subscription  # noqa: E402


def _resolve_google_id(google_id: str | None, email: str | None) -> str:
    if google_id:
        return google_id
    with session_scope() as db:
        user = db.query(User).filter(User.email == email).one_or_none()
        if user is None:
            raise SystemExit(
                f"No user found with email {email!r} -- they need to have signed into ptolemy-web at least "
                "once first, or pass --google-id directly."
            )
        return user.google_id


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    identity = parser.add_mutually_exclusive_group(required=True)
    identity.add_argument("--google-id", help="The account's Google id (JWT 'sub' claim)")
    identity.add_argument("--email", help="The account's email -- requires they've already signed in once")
    parser.add_argument("--revoke", action="store_true", help="Revoke Pro instead of granting it")
    parser.add_argument("--name", default=None, help="Only used when granting to a brand-new google-id")
    args = parser.parse_args()

    google_id = _resolve_google_id(args.google_id, args.email)

    if args.revoke:
        subscription.revoke_manual_override(google_id)
        print(f"Revoked manual Pro override for {google_id}")
    else:
        subscription.grant_manual_override(google_id, email=args.email, name=args.name)
        print(f"Granted manual Pro override to {google_id}")


if __name__ == "__main__":
    main()
