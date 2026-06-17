"""
auth.py – JWT validation for Order Service (TV2)

Identical contract to services/user/auth.py.
Validates Bearer tokens issued by Keycloak, fetches JWKS, verifies sig/exp/iss.
"""

from __future__ import annotations

import os
import logging
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt

KEYCLOAK_URL: str = os.environ.get("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM: str = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
KEYCLOAK_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
EXPECTED_ISSUER: str = KEYCLOAK_ISSUER
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
INTROSPECTION_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token/introspect"
TOKEN_INTROSPECTION_ENABLED: bool = (
    os.environ.get("TOKEN_INTROSPECTION_ENABLED", "false").lower() == "true"
)
TOKEN_INTROSPECTION_CLIENT_ID: str = os.environ.get(
    "ORDER_TOKEN_INTROSPECTION_CLIENT_ID",
    os.environ.get("TOKEN_INTROSPECTION_CLIENT_ID", ""),
)
TOKEN_INTROSPECTION_CLIENT_SECRET: str = os.environ.get(
    "ORDER_TOKEN_INTROSPECTION_CLIENT_SECRET",
    os.environ.get("TOKEN_INTROSPECTION_CLIENT_SECRET", ""),
)

_jwks_cache: Optional[Dict[str, Any]] = None

logger = logging.getLogger("order-service")

security = HTTPBearer(auto_error=True)


async def _fetch_jwks() -> Dict[str, Any]:
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
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")
    jwks = await _fetch_jwks()
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            return jwk.construct(key_data)
    _invalidate_jwks_cache()
    jwks = await _fetch_jwks()
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            return jwk.construct(key_data)
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"error": "invalid_token", "message": "Unknown signing key"},
    )


async def validate_token(token: str) -> Dict[str, Any]:
    try:
        signing_key = await _get_signing_key(token)
        payload = jwt.decode(
            token,
            signing_key,
            algorithms=["RS256"],
            options={"verify_aud": False, "verify_exp": True},
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "invalid_token", "message": str(exc)},
        )

    if payload.get("iss") != EXPECTED_ISSUER:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": "invalid_token",
                "message": f"Unexpected issuer: {payload.get('iss')}",
            },
        )
    return payload


def _introspection_failed_exception() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={
            "error": "invalid_token",
            "message": "Token introspection failed or token is inactive",
        },
    )


def _introspection_headers() -> Dict[str, str]:
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    issuer_netloc = urlparse(KEYCLOAK_ISSUER).netloc
    if issuer_netloc:
        headers["Host"] = issuer_netloc
    return headers


async def require_introspection_active(token: str) -> None:
    if not TOKEN_INTROSPECTION_ENABLED:
        return

    if not TOKEN_INTROSPECTION_CLIENT_ID or not TOKEN_INTROSPECTION_CLIENT_SECRET:
        raise _introspection_failed_exception()

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                INTROSPECTION_URL,
                data={
                    "token": token,
                    "client_id": TOKEN_INTROSPECTION_CLIENT_ID,
                    "client_secret": TOKEN_INTROSPECTION_CLIENT_SECRET,
                },
                headers=_introspection_headers(),
            )
    except httpx.HTTPError:
        raise _introspection_failed_exception()

    if response.status_code != 200:
        raise _introspection_failed_exception()

    try:
        body = response.json()
        active = isinstance(body, dict) and body.get("active") is True
    except ValueError:
        active = False

    if not active:
        raise _introspection_failed_exception()


async def validate_token_with_introspection(token: str) -> Dict[str, Any]:
    payload = await validate_token(token)
    await require_introspection_active(token)
    return payload


async def get_current_token_payload(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    return await validate_token(credentials.credentials)


async def get_current_introspected_token_payload(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    return await validate_token_with_introspection(credentials.credentials)


def extract_identity(payload: Dict[str, Any]) -> Dict[str, Any]:
    realm_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    return {
        "sub": payload.get("sub", ""),
        "preferred_username": payload.get("preferred_username", ""),
        "email": payload.get("email", ""),
        "roles": realm_roles,
        "azp": payload.get("azp", ""),
        "scope": payload.get("scope", ""),
    }


def get_roles(payload: Dict[str, Any]) -> List[str]:
    return payload.get("realm_access", {}).get("roles", [])
