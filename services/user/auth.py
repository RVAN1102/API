"""
auth.py – JWT validation for User Service (TV2)

Validates Bearer tokens issued by Keycloak.
- Fetches JWKS from Keycloak automatically.
- Verifies signature, exp, iss.
- Extracts realm_access.roles and identity claims.
"""

from __future__ import annotations

import os
import logging
from typing import Any, Dict, List, Optional

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode

# ---------------------------------------------------------------------------
# Configuration (read from environment; defaults work for Docker Compose)
# ---------------------------------------------------------------------------
KEYCLOAK_URL: str = os.environ.get("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM: str = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
EXPECTED_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"

# In-memory JWKS cache (simple; refreshed on each startup or on key-not-found)
_jwks_cache: Optional[Dict[str, Any]] = None

logger = logging.getLogger("user-service")

security = HTTPBearer(auto_error=True)


# ---------------------------------------------------------------------------
# JWKS helpers
# ---------------------------------------------------------------------------

async def _fetch_jwks() -> Dict[str, Any]:
    """Fetch JWKS from Keycloak. Cache in memory."""
    global _jwks_cache
    if _jwks_cache is not None:
        return _jwks_cache
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(JWKS_URL)
            response.raise_for_status()
            _jwks_cache = response.json()
            logger.info("JWKS fetched from %s", JWKS_URL)
            return _jwks_cache
    except Exception as exc:
        logger.error("Failed to fetch JWKS from %s: %s", JWKS_URL, exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": "idp_unavailable", "message": "Cannot reach identity provider"},
        )


def _invalidate_jwks_cache() -> None:
    global _jwks_cache
    _jwks_cache = None


async def _get_signing_key(token: str) -> Any:
    """Return the public key that matches the token's kid header."""
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")
    jwks = await _fetch_jwks()
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            return jwk.construct(key_data)
    # kid not found → refresh cache and retry once
    _invalidate_jwks_cache()
    jwks = await _fetch_jwks()
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            return jwk.construct(key_data)
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"error": "invalid_token", "message": "Unknown signing key"},
    )


# ---------------------------------------------------------------------------
# Token validation
# ---------------------------------------------------------------------------

async def validate_token(token: str) -> Dict[str, Any]:
    """
    Validate a JWT access token.

    Returns the decoded payload dict on success.
    Raises HTTP 401 on any validation failure.
    """
    try:
        signing_key = await _get_signing_key(token)
        payload = jwt.decode(
            token,
            signing_key,
            algorithms=["RS256"],
            options={
                "verify_aud": False,  # audience check is optional for this prototype
                "verify_exp": True,
            },
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "invalid_token", "message": str(exc)},
        )

    # Issuer check
    if payload.get("iss") != EXPECTED_ISSUER:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": "invalid_token",
                "message": f"Unexpected issuer: {payload.get('iss')}",
            },
        )

    return payload


# ---------------------------------------------------------------------------
# FastAPI dependency
# ---------------------------------------------------------------------------

async def get_current_token_payload(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    """FastAPI dependency: validate Bearer token and return its payload."""
    return await validate_token(credentials.credentials)


# ---------------------------------------------------------------------------
# Identity extraction helpers
# ---------------------------------------------------------------------------

def extract_identity(payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract standard identity fields from a validated JWT payload.

    Returns a dict with: sub, preferred_username, email, roles.
    """
    realm_roles: List[str] = (
        payload.get("realm_access", {}).get("roles", [])
    )
    return {
        "sub": payload.get("sub", ""),
        "preferred_username": payload.get("preferred_username", ""),
        "email": payload.get("email", ""),
        "roles": realm_roles,
        "azp": payload.get("azp", ""),
        "scope": payload.get("scope", ""),
    }


def get_roles(payload: Dict[str, Any]) -> List[str]:
    """Shortcut: return realm roles from payload."""
    return payload.get("realm_access", {}).get("roles", [])
