"""
auth.py – JWT validation for Order Service (TV2)

Identical contract to services/user/auth.py.
Validates Bearer tokens issued by Keycloak, fetches JWKS, verifies sig/exp/iss.
"""

from __future__ import annotations

import os
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
from urllib.parse import urlparse

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt

KEYCLOAK_URL: str = os.environ.get("KEYCLOAK_URL", "https://keycloak:8443")
KEYCLOAK_REALM: str = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
KEYCLOAK_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
EXPECTED_ISSUER: str = KEYCLOAK_ISSUER
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
INTROSPECTION_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token/introspect"
INTERNAL_TLS_CA_CERT: str = os.environ.get("INTERNAL_TLS_CA_CERT", "/etc/internal-tls/ca.crt")
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
ALLOWED_TOKEN_CLIENT_IDS = {
    "sme-web-client",
    "sme-lab-automation-client",
    "billing-service-client",
    "admin-service-client",
}

_jwks_cache: Optional[Dict[str, Any]] = None

logger = logging.getLogger("order-service")

security = HTTPBearer(auto_error=True)

def _internal_tls_verify(url: str):
    parsed = urlparse(url)
    if parsed.scheme == "https" and Path(INTERNAL_TLS_CA_CERT).is_file():
        return INTERNAL_TLS_CA_CERT
    return True


async def _fetch_jwks() -> Dict[str, Any]:
    global _jwks_cache
    if _jwks_cache is not None:
        return _jwks_cache
    try:
        async with httpx.AsyncClient(timeout=5.0, verify=_internal_tls_verify(JWKS_URL)) as client:
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


def _claim_as_string(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item.strip():
                return item.strip()
    return ""


def _audiences(payload: Dict[str, Any]) -> Set[str]:
    aud = payload.get("aud")
    if isinstance(aud, str) and aud.strip():
        return {aud.strip()}
    if isinstance(aud, list):
        return {item.strip() for item in aud if isinstance(item, str) and item.strip()}
    return set()


def _token_client_id(payload: Dict[str, Any]) -> str:
    return _claim_as_string(payload.get("azp")) or _claim_as_string(payload.get("client_id"))


def _require_known_token_client(payload: Dict[str, Any]) -> None:
    token_client = _token_client_id(payload)
    if token_client in ALLOWED_TOKEN_CLIENT_IDS:
        return
    if not token_client and _audiences(payload) & ALLOWED_TOKEN_CLIENT_IDS:
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "forbidden_client",
            "message": "Token client is not allowed for order endpoints",
        },
    )


async def validate_token(token: str) -> Dict[str, Any]:
    try:
        signing_key = await _get_signing_key(token)
        payload = jwt.decode(
            token,
            signing_key,
            algorithms=["RS256"],
            # Client binding is enforced below with azp/client_id and audience
            # fallback against ALLOWED_TOKEN_CLIENT_IDS.
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
    _require_known_token_client(payload)
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
        async with httpx.AsyncClient(timeout=5.0, verify=_internal_tls_verify(INTROSPECTION_URL)) as client:
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
