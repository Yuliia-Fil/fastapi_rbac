import uuid

from fastapi import HTTPException

from app.models import Capability, User, UserRole

ROLE_CAPABILITIES: dict[UserRole, frozenset[Capability]] = {
    UserRole.ADMIN: frozenset(
        {
            Capability.LIST_USERS,
            Capability.CREATE_USER,
            Capability.READ_ANY_USER,
            Capability.UPDATE_ANY_USER,
            Capability.DELETE_ANY_USER,
            Capability.VIEW_METRICS,
            Capability.ACCESS_ANY_ITEM,
            Capability.MANAGE_EMAIL,
        }
    ),
    UserRole.MANAGER: frozenset(
        {
            Capability.LIST_USERS,
            Capability.VIEW_METRICS,
            Capability.DELETE_OWN_ACCOUNT,
        }
    ),
    UserRole.MEMBER: frozenset({Capability.DELETE_OWN_ACCOUNT}),
}


def has_capability(user: User, capability: Capability) -> bool:
    return capability in ROLE_CAPABILITIES[user.role]


def check_permission(
    user: User,
    capability: Capability,
    *,
    owner_id: uuid.UUID | None = None,
) -> None:
    if user.id != owner_id and not has_capability(user, capability):
        raise HTTPException(status_code=403, detail="Not enough permissions")


def check_user_deletion(actor: User, target_id: uuid.UUID) -> None:
    if actor.id == target_id:
        check_permission(actor, Capability.DELETE_OWN_ACCOUNT)
    else:
        check_permission(actor, Capability.DELETE_ANY_USER)
