"""
main.py – Admin Service (TV3)

FastAPI application providing:
  GET  /api/v1/admin/health                      – public
  POST /api/v1/admin/maintenance                 – protected (service Bearer JWT)
  POST /api/v1/admin/metadata-fetch/vulnerable   – SSRF vulnerable (no URL validation)
  POST /api/v1/admin/metadata-fetch/fixed        – SSRF fixed (URL blocklist)

SSRF Protection (fixed endpoint) blocks:
  - 169.254.169.254 (AWS instance metadata)
  - localhost / 127.0.0.1 / 0.0.0.0
  - ::1 (IPv6 loopback)
  - RFC-1918 private ranges: 10.x, 172.16-31.x, 192.168.x
  - file://, gopher://, ftp:// schemes
  - Any scheme other than http/https

Structured JSON logging compatible with Promtail/Loki.
"""

from __future__ import annotations

import ipaddress
import json
import logging
import os
import re
import socket
import time
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("admin-service")


def log_event(
    level: str,
    event_type: str,
    method: str,
    path: str,
    status_code: int,
    client_ip: str,
    correlation_id: str,
    message: str,
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    record: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": level,
        "service": "admin-service",
        "method": method,
        "path": path,
        "status_code": status_code,
        "client_ip": client_ip,
        "correlation_id": correlation_id,
        "event_type": event_type,
        "message": message,
    }
    if extra:
        record.update(extra)
    getattr(logger, level.lower(), logger.info)(json.dumps(record))


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Admin Service",
    description="Admin management API with SSRF demo (TV3 – Capstone Topic 10)",
    version="1.0.0",
)

security = HTTPBearer(auto_error=True)
_jwks_cache: Optional[Dict[str, Any]] = None

KEYCLOAK_URL: str = os.environ.get("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM: str = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
EXPECTED_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"

ROLE_ADMIN = "admin"
ROLE_ADMIN_MAINTENANCE = "admin-maintenance"
ADMIN_SERVICE_CLIENT_ID = os.environ.get("ADMIN_SERVICE_CLIENT_ID", "admin-service-client")


# ---------------------------------------------------------------------------
# JWT authentication helpers
# ---------------------------------------------------------------------------

async def _fetch_jwks() -> Dict[str, Any]:
    """Fetch and cache Keycloak JWKS."""
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
    """Validate a Keycloak access token and return its decoded payload."""
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


async def get_current_token_payload(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    return await validate_token(credentials.credentials)


def _claim_as_string(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item.strip():
                return item.strip()
    return ""


def _token_client_id(payload: Dict[str, Any]) -> str:
    return _claim_as_string(payload.get("azp")) or _claim_as_string(payload.get("client_id"))


def has_role(payload: Dict[str, Any], *roles: str) -> bool:
    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    return any(r in user_roles for r in roles)


def require_role(payload: Dict[str, Any], *required_roles: str) -> None:
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


async def require_admin_access(
    payload: Dict[str, Any] = Depends(get_current_token_payload),
) -> Dict[str, Any]:
    require_role(payload, ROLE_ADMIN)
    return payload


async def require_maintenance_access(
    payload: Dict[str, Any] = Depends(get_current_token_payload),
) -> Dict[str, Any]:
    token_client_id = _token_client_id(payload)
    if token_client_id == ADMIN_SERVICE_CLIENT_ID and has_role(payload, ROLE_ADMIN_MAINTENANCE):
        return payload

    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "forbidden",
            "message": (
                f"Required service client '{ADMIN_SERVICE_CLIENT_ID}' with role "
                f"'{ROLE_ADMIN_MAINTENANCE}'. Token client: '{token_client_id}'. "
                f"Token roles: {user_roles}"
            ),
        },
    )

# ---------------------------------------------------------------------------
# SSRF Protection helpers
# ---------------------------------------------------------------------------

# Private IP ranges to block
_PRIVATE_NETWORKS: List[ipaddress.IPv4Network] = [
    ipaddress.IPv4Network("10.0.0.0/8"),
    ipaddress.IPv4Network("172.16.0.0/12"),
    ipaddress.IPv4Network("192.168.0.0/16"),
    ipaddress.IPv4Network("127.0.0.0/8"),
    ipaddress.IPv4Network("169.254.0.0/16"),
    ipaddress.IPv4Network("0.0.0.0/8"),
]

_BLOCKED_HOSTNAMES: List[str] = [
    "localhost",
    "metadata.google.internal",
    "169.254.169.254",
]

_ALLOWED_SCHEMES: List[str] = ["http", "https"]


def _is_private_ip(host: str) -> bool:
    """Return True if host resolves to a private/loopback/link-local address."""
    try:
        resolved = socket.gethostbyname(host)
        ip = ipaddress.IPv4Address(resolved)
        return ip.is_loopback or ip.is_link_local or any(ip in net for net in _PRIVATE_NETWORKS)
    except (socket.gaierror, ValueError):
        # Cannot resolve – treat as blocked for safety
        return True


def validate_ssrf_url(url: str) -> None:
    """
    Raise HTTPException(403) if url is considered dangerous for SSRF.
    This is the core of the SSRF fixed endpoint.
    """
    try:
        parsed = urlparse(url)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "invalid_url", "message": "Could not parse URL"},
        )

    scheme = parsed.scheme.lower()
    host = parsed.hostname or ""

    # Check scheme
    if scheme not in _ALLOWED_SCHEMES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "ssrf_blocked",
                "message": f"Scheme '{scheme}' is not allowed. Only http/https permitted.",
                "event_type": "ssrf_blocked",
            },
        )

    # Check blocked hostnames
    if host in _BLOCKED_HOSTNAMES or host == "":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "ssrf_blocked",
                "message": f"Host '{host}' is blocked by SSRF protection policy.",
                "event_type": "ssrf_blocked",
            },
        )

    # Check IPv6 loopback
    if host == "::1" or host.startswith("[::1]"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "ssrf_blocked", "message": "IPv6 loopback is blocked."},
        )

    # DNS resolution check – block if resolves to private IP
    if _is_private_ip(host):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "ssrf_blocked",
                "message": f"Host '{host}' resolves to a private/internal IP address.",
                "event_type": "ssrf_blocked",
            },
        )


# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------

@app.middleware("http")
async def log_requests(request: Request, call_next):
    correlation_id: str = request.headers.get("X-Correlation-ID", "")
    response: Response = await call_next(request)
    log_event(
        level="INFO",
        event_type="api_request",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        client_ip=request.client.host if request.client else "unknown",
        correlation_id=correlation_id,
        message=f"{request.method} {request.url.path} → {response.status_code}",
    )
    if correlation_id:
        response.headers["X-Correlation-ID"] = correlation_id
    return response


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class MaintenanceRequest(BaseModel):
    action: str


class MetadataFetchRequest(BaseModel):
    fetch_url: str


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/v1/admin/health", tags=["Admin"])
async def health_check():
    """Public health check."""
    return {"status": "ok", "service": "admin-service"}


@app.post("/api/v1/admin/maintenance", tags=["Admin"])
async def run_maintenance(
    body: MaintenanceRequest,
    request: Request,
    _payload: Dict[str, Any] = Depends(require_maintenance_access),
):
    """
    Execute a maintenance action.
    Protected: requires a service-account Bearer JWT with role 'admin-maintenance'.
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    log_event("INFO", "api_request", "POST", "/api/v1/admin/maintenance",
              200, request.client.host if request.client else "unknown",
              correlation_id, f"Maintenance action: {body.action}")
    return {
        "status": "executed",
        "action": body.action,
        "correlation_id": correlation_id,
    }


@app.post("/api/v1/admin/metadata-fetch/vulnerable", tags=["Admin", "SSRF"])
async def metadata_fetch_vulnerable(
    body: MetadataFetchRequest,
    request: Request,
    _payload: Dict[str, Any] = Depends(require_admin_access),
):
    """
    SSRF VULNERABLE endpoint.

    Security flaw: fetches any URL without validation.
    A request to http://169.254.169.254/latest/meta-data/ will be attempted.

    Expected demo: returns whatever the backend fetches (or an error if network
    unreachable), proving the endpoint does not block dangerous targets.
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    client_ip = request.client.host if request.client else "unknown"

    log_event("WARNING", "ssrf_attempt", "POST",
              "/api/v1/admin/metadata-fetch/vulnerable",
              200, client_ip, correlation_id,
              f"SSRF vulnerable: fetching {body.fetch_url}",
              {"security_event": True, "target": body.fetch_url,
               "actor": "authenticated_user", "decision": "allowed",
               "reason": "no_ssrf_protection"})

    # Attempt the fetch with a short timeout (simulate the vulnerability)
    try:
        async with httpx.AsyncClient(timeout=3.0, follow_redirects=False) as client:
            resp = await client.get(body.fetch_url)
            result_text = resp.text[:500]  # Limit to 500 chars for demo
            fetched = True
    except Exception as exc:
        result_text = f"[fetch error: {type(exc).__name__}: {exc}]"
        fetched = False

    return {
        "fetched": fetched,
        "target": body.fetch_url,
        "result": result_text,
        "note": "SSRF VULNERABLE: no URL validation performed",
        "correlation_id": correlation_id,
    }


@app.post("/api/v1/admin/metadata-fetch/fixed", tags=["Admin", "SSRF"])
async def metadata_fetch_fixed(
    body: MetadataFetchRequest,
    request: Request,
    _payload: Dict[str, Any] = Depends(require_admin_access),
):
    """
    SSRF FIXED endpoint.

    Validates the URL against a blocklist before fetching:
    - Blocks private/loopback IPs (RFC-1918, 169.254.x.x, 127.x.x.x)
    - Blocks dangerous schemes (file://, gopher://, ftp://)
    - Blocks known metadata endpoints
    - Performs DNS resolution to catch DNS rebinding

    Expected demo:
      fetch_url=http://169.254.169.254/... → 403 ssrf_blocked
      fetch_url=https://httpbin.org/get    → 200 (if reachable)
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    client_ip = request.client.host if request.client else "unknown"

    # SSRF protection check – raises 403 if dangerous
    try:
        validate_ssrf_url(body.fetch_url)
    except HTTPException as exc:
        log_event("WARNING", "ssrf_blocked", "POST",
                  "/api/v1/admin/metadata-fetch/fixed",
                  exc.status_code, client_ip, correlation_id,
                  f"SSRF blocked: {body.fetch_url}",
                  {"security_event": True, "target": body.fetch_url,
                   "decision": "blocked", "reason": str(exc.detail)})
        raise

    log_event("INFO", "api_request", "POST",
              "/api/v1/admin/metadata-fetch/fixed",
              200, client_ip, correlation_id,
              f"SSRF fixed: allowed fetch to {body.fetch_url}")

    try:
        async with httpx.AsyncClient(timeout=5.0, follow_redirects=False) as client:
            resp = await client.get(body.fetch_url)
            result_text = resp.text[:500]
            fetched = True
    except Exception as exc:
        result_text = f"[fetch error: {type(exc).__name__}: {exc}]"
        fetched = False

    return {
        "fetched": fetched,
        "target": body.fetch_url,
        "result": result_text,
        "note": "SSRF FIXED: URL validated against blocklist",
        "correlation_id": correlation_id,
    }
