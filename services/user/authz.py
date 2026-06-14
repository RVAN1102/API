"""
authz.py – RBAC authorization helpers for User Service (TV2)

Provides role-based access control checks based on JWT realm_access.roles.
Backend-level authorization; does not rely solely on the API gateway.
"""

from __future__ import annotations

from typing import Any, Dict, List

from fastapi import HTTPException, status


# ---------------------------------------------------------------------------
# Role constants (must match Keycloak realm contract)
# ---------------------------------------------------------------------------

ROLE_USER = "user"
ROLE_ADMIN = "admin"
ROLE_BILLING_SERVICE = "billing-service"
ROLE_INTERNAL_SERVICE = "internal-service"


# ---------------------------------------------------------------------------
# Generic role checker
# ---------------------------------------------------------------------------

def require_role(payload: Dict[str, Any], *required_roles: str) -> None:
    """
    Raise HTTP 403 if the token's realm roles do not include at least one
    of the required_roles.

    Args:
        payload:        Validated JWT payload dict.
        *required_roles: One or more acceptable roles (OR logic).
    """
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
    """Return True if the token contains at least one of the given roles."""
    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    return any(r in user_roles for r in roles)


# ---------------------------------------------------------------------------
# Specific policy checks
# ---------------------------------------------------------------------------

def require_user_or_admin(payload: Dict[str, Any]) -> None:
    """Allow access to users with role 'user' or 'admin'."""
    require_role(payload, ROLE_USER, ROLE_ADMIN)


def require_admin(payload: Dict[str, Any]) -> None:
    """Allow access only to admins."""
    require_role(payload, ROLE_ADMIN)
