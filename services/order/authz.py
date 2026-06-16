"""
authz.py – Authorization helpers for Order Service (TV2)

Provides:
  - Role-based access control (RBAC).
  - Ownership check for BOLA demonstration.
"""

from __future__ import annotations

from typing import Any, Dict, List

from fastapi import HTTPException, status

ROLE_USER = "user"
ROLE_ADMIN = "admin"
ROLE_BILLING_SERVICE = "billing-service"
ROLE_INTERNAL_SERVICE = "internal-service"


def _is_automation_fixture(payload: Dict[str, Any]) -> bool:
    value = payload.get("automation_fixture")
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() == "true"
    return False


def _claim_as_string(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item.strip():
                return item.strip()
    return ""


def get_effective_subject(
    payload: Dict[str, Any],
    allow_automation_owner: bool = False,
) -> str:
    """
    Return the subject used for ownership checks.

    automation_owner is honored only for explicit automation fixtures and only
    when the caller opts into fixture ownership behavior.
    """
    if allow_automation_owner and _is_automation_fixture(payload):
        automation_owner = _claim_as_string(payload.get("automation_owner"))
        if automation_owner:
            return automation_owner

    caller = _claim_as_string(payload.get("preferred_username"))
    if caller:
        return caller
    return _claim_as_string(payload.get("sub"))


def require_role(payload: Dict[str, Any], *required_roles: str) -> None:
    """Raise 403 if none of the required roles are present in the token."""
    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    if not any(r in user_roles for r in required_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "forbidden",
                "message": (
                    f"Required role(s): {list(required_roles)}. "
                    f"Token roles: {user_roles}"
                ),
            },
        )


def has_role(payload: Dict[str, Any], *roles: str) -> bool:
    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    return any(r in user_roles for r in roles)


def require_user_or_admin(payload: Dict[str, Any]) -> None:
    require_role(payload, ROLE_USER, ROLE_ADMIN)


def require_admin(payload: Dict[str, Any]) -> None:
    require_role(payload, ROLE_ADMIN)


def check_order_ownership(
    payload: Dict[str, Any],
    order_owner: str,
    allow_automation_owner: bool = False,
) -> None:
    """
    BOLA fixed-endpoint ownership check.

    Raises 403 if the caller is not the owner AND not an admin.

    This is the core control that separates the 'fixed' endpoint
    from the 'vulnerable' one: the vulnerable endpoint skips this call.
    """
    if has_role(payload, ROLE_ADMIN):
        # Admins are allowed to view any order (policy: admin sees all)
        return

    caller = get_effective_subject(
        payload,
        allow_automation_owner=allow_automation_owner,
    )

    if caller != order_owner:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "forbidden",
                "message": (
                    f"You do not have permission to access this order. "
                    f"Owner: {order_owner}, caller: {caller}"
                ),
                "event_type": "bola_attempt",
            },
        )
