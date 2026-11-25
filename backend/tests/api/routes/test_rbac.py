import uuid
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app import crud
from app.core.config import settings
from app.core.security import create_access_token
from app.models import User, UserCreate, UserRole
from tests.utils.utils import random_email, random_lower_string

API = settings.API_V1_STR


def make_user(db: Session, role: UserRole, *, is_active: bool = True) -> User:
    return crud.create_user(
        session=db,
        user_create=UserCreate(
            email=random_email(),
            password=random_lower_string(),
            role=role,
            is_active=is_active,
        ),
    )


def bearer_headers(
    subject: uuid.UUID | str, *, lifetime: timedelta = timedelta(minutes=5)
) -> dict[str, str]:
    token = create_access_token(subject, expires_delta=lifetime)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def role_headers(db: Session) -> dict[UserRole, dict[str, str]]:
    return {role: bearer_headers(make_user(db, role).id) for role in UserRole}


def test_user_listing_and_metrics_permissions(
    client: TestClient, role_headers: dict[UserRole, dict[str, str]]
) -> None:
    for role, headers in role_headers.items():
        expected = 403 if role == UserRole.MEMBER else 200
        assert client.get(f"{API}/users/", headers=headers).status_code == expected
        assert client.get(f"{API}/metrics/", headers=headers).status_code == expected


def test_managed_user_creation_requires_admin(
    client: TestClient, role_headers: dict[UserRole, dict[str, str]]
) -> None:
    payload = {
        "email": random_email(),
        "password": random_lower_string(),
        "role": "manager",
    }
    for role in (UserRole.MANAGER, UserRole.MEMBER):
        assert (
            client.post(
                f"{API}/users/", headers=role_headers[role], json=payload
            ).status_code
            == 403
        )

    response = client.post(
        f"{API}/users/", headers=role_headers[UserRole.ADMIN], json=payload
    )
    assert response.status_code == 200
    assert response.json()["role"] == "manager"


def test_self_profile_allows_edits_but_rejects_privilege_fields(
    client: TestClient, role_headers: dict[UserRole, dict[str, str]]
) -> None:
    for role, headers in role_headers.items():
        response = client.patch(
            f"{API}/users/me", headers=headers, json={"full_name": "Updated name"}
        )
        assert response.status_code == 200
        assert response.json()["full_name"] == "Updated name"
        assert response.json()["role"] == role

    member = role_headers[UserRole.MEMBER]
    signup = {"email": random_email(), "password": random_lower_string()}
    for fields in ({"role": "admin"}, {"is_superuser": True}, {"is_active": True}):
        assert (
            client.patch(f"{API}/users/me", headers=member, json=fields).status_code
            == 422
        )
        assert (
            client.post(f"{API}/users/signup", json={**signup, **fields}).status_code
            == 422
        )

    assert client.get(f"{API}/users/me", headers=member).json()["role"] == "member"
    response = client.post(f"{API}/users/signup", json=signup)
    assert response.status_code == 200
    assert response.json()["role"] == "member"


def test_only_admin_can_update_another_users_role(
    client: TestClient, db: Session, role_headers: dict[UserRole, dict[str, str]]
) -> None:
    target = make_user(db, UserRole.MEMBER)
    target_headers = bearer_headers(target.id)
    path = f"{API}/users/{target.id}"
    payload = {"role": "manager"}

    for role in (UserRole.MANAGER, UserRole.MEMBER):
        headers = role_headers[role]
        assert client.get(path, headers=headers).status_code == 403
        assert client.patch(path, headers=headers, json=payload).status_code == 403

    admin = role_headers[UserRole.ADMIN]
    assert client.get(path, headers=admin).status_code == 200
    response = client.patch(path, headers=admin, json=payload)
    assert response.status_code == 200
    assert response.json()["role"] == "manager"

    me = client.get(f"{API}/users/me", headers=target_headers).json()
    assert me["role"] == "manager"
    assert "list_users" in me["capabilities"]
    assert "view_metrics" in me["capabilities"]
    assert "create_user" not in me["capabilities"]
    assert client.get(f"{API}/users/", headers=target_headers).status_code == 200


def test_unauthenticated_requests_receive_bearer_challenge(
    client: TestClient, db: Session
) -> None:
    user = make_user(db, UserRole.MEMBER)
    deleted_headers = bearer_headers(user.id)
    expired_headers = bearer_headers(user.id, lifetime=timedelta(seconds=-1))
    db.delete(user)
    db.commit()

    for headers in (
        {},
        {"Authorization": "Bearer invalid"},
        bearer_headers("not-a-uuid"),
        expired_headers,
        deleted_headers,
    ):
        response = client.get(f"{API}/metrics/", headers=headers)
        assert response.status_code == 401
        assert response.headers["WWW-Authenticate"] == "Bearer"


def test_inactive_and_underprivileged_users_receive_forbidden(
    client: TestClient, db: Session, role_headers: dict[UserRole, dict[str, str]]
) -> None:
    inactive_admin = make_user(db, UserRole.ADMIN, is_active=False)
    response = client.get(f"{API}/users/me", headers=bearer_headers(inactive_admin.id))
    assert response.status_code == 403
    assert response.json()["detail"] == "Inactive user"

    response = client.get(f"{API}/users/", headers=role_headers[UserRole.MEMBER])
    assert response.status_code == 403
    assert response.json()["detail"] == "Not enough permissions"
