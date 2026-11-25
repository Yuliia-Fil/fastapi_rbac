import logging

from sqlmodel import Session

from app import crud
from app.core.config import settings
from app.core.db import engine
from app.core.security import get_password_hash, verify_password
from app.models import User, UserCreate, UserRole

logger = logging.getLogger(__name__)
DEVELOPMENT_PASSWORD = "rbac-local-only"
DEVELOPMENT_ACCOUNTS = {
    UserRole.ADMIN: "rbac-admin@example.com",
    UserRole.MANAGER: "rbac-manager@example.com",
    UserRole.MEMBER: "rbac-member@example.com",
}


def main() -> None:
    if settings.FASTAPI_ENV != "development":
        raise SystemExit("The RBAC demo seed requires FASTAPI_ENV=development.")

    logging.basicConfig(level=logging.INFO)
    with Session(engine) as session:
        for role, email in DEVELOPMENT_ACCOUNTS.items():
            existing = crud.get_user_by_email(session=session, email=email)
            if existing is not None:
                password_matches, _ = verify_password(
                    DEVELOPMENT_PASSWORD, existing.hashed_password
                )
                if (
                    existing.role != role
                    or not existing.is_active
                    or not password_matches
                ):
                    raise SystemExit(
                        f"Existing account conflicts with the demo seed: {email}"
                    )
                continue

            user = UserCreate(email=email, role=role, password=DEVELOPMENT_PASSWORD)
            session.add(
                User.model_validate(
                    user, update={"hashed_password": get_password_hash(user.password)}
                )
            )
        session.commit()

    logger.info("Local RBAC demo accounts are ready.")


if __name__ == "__main__":
    main()
