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


def check_order_ownership(payload: Dict[str, Any], order_owner: str) -> None:
    """
    BOLA fixed-endpoint ownership check.

    Raises 403 if the caller is not the owner AND not an admin.

    This is the core control that separates the 'fixed' endpoint
    from the 'vulnerable' one: the vulnerable endpoint skips this call.
    """
    caller = payload.get("preferred_username", "")
    if not caller:
        caller = payload.get("sub", "")

    if has_role(payload, ROLE_ADMIN):
        # Admins are allowed to view any order (policy: admin sees all)
        return

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
