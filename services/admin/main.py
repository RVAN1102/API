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
from fastapi.responses import JSONResponse
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
KEYCLOAK_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
EXPECTED_ISSUER: str = KEYCLOAK_ISSUER
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
INTROSPECTION_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token/introspect"

ROLE_ADMIN = "admin"
ROLE_ADMIN_MAINTENANCE = "admin-maintenance"
ADMIN_SERVICE_CLIENT_ID = os.environ.get("ADMIN_SERVICE_CLIENT_ID", "admin-service-client")
ADMIN_SERVICE_CLIENT_SECRET = os.environ.get("ADMIN_SERVICE_CLIENT_SECRET", "")
ALLOWED_TOKEN_CLIENT_IDS = {
    "sme-web-client",
    "sme-lab-automation-client",
    "billing-service-client",
    "admin-service-client",
}
TOKEN_INTROSPECTION_ENABLED: bool = (
    os.environ.get("TOKEN_INTROSPECTION_ENABLED", "false").lower() == "true"
)
TOKEN_INTROSPECTION_CLIENT_ID: str = (
    os.environ.get("ADMIN_TOKEN_INTROSPECTION_CLIENT_ID")
    or os.environ.get("TOKEN_INTROSPECTION_CLIENT_ID")
    or ADMIN_SERVICE_CLIENT_ID
)
TOKEN_INTROSPECTION_CLIENT_SECRET: str = (
    os.environ.get("ADMIN_TOKEN_INTROSPECTION_CLIENT_SECRET")
    or os.environ.get("TOKEN_INTROSPECTION_CLIENT_SECRET")
    or ADMIN_SERVICE_CLIENT_SECRET
)
OPA_URL: str = os.environ.get("OPA_URL", "http://opa:8181").rstrip("/")
OPA_ALLOW_URL: str = f"{OPA_URL}/v1/data/topic10/authz/allow"


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
    require_known_token_client(payload)
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


def _audiences(payload: Dict[str, Any]) -> set[str]:
    aud = payload.get("aud")
    if isinstance(aud, str) and aud.strip():
        return {aud.strip()}
    if isinstance(aud, list):
        return {item.strip() for item in aud if isinstance(item, str) and item.strip()}
    return set()


def require_known_token_client(payload: Dict[str, Any]) -> None:
    token_client = _token_client_id(payload)
    if token_client in ALLOWED_TOKEN_CLIENT_IDS:
        return
    if not token_client and _audiences(payload) & ALLOWED_TOKEN_CLIENT_IDS:
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "forbidden_client",
            "message": "Token client is not allowed for admin endpoints",
        },
    )


def has_role(payload: Dict[str, Any], *roles: str) -> bool:
    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    return any(r in user_roles for r in roles)


def _roles(payload: Dict[str, Any]) -> List[str]:
    roles = payload.get("realm_access", {}).get("roles", [])
    return roles if isinstance(roles, list) else []


def _subject_type(payload: Dict[str, Any]) -> str:
    return "service" if _token_client_id(payload) == ADMIN_SERVICE_CLIENT_ID else "human"


async def require_opa_allow(input_data: Dict[str, Any]) -> None:
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.post(OPA_ALLOW_URL, json={"input": input_data})
    except httpx.HTTPError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": "opa_unavailable", "message": "Authorization policy engine unavailable"},
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": "opa_error", "message": "Authorization policy engine returned an error"},
        )

    try:
        body = response.json()
    except ValueError:
        body = {}

    if not isinstance(body, dict) or body.get("result") is not True:
        reason = "opa_denied"
        log_event(
            level="WARNING",
            event_type="auth_failure",
            method=_claim_as_string(input_data.get("method")) or "POST",
            path=_claim_as_string(input_data.get("path")) or "/api/v1/admin/maintenance",
            status_code=status.HTTP_403_FORBIDDEN,
            client_ip=_claim_as_string(input_data.get("client_ip")) or "unknown",
            correlation_id=_claim_as_string(input_data.get("correlation_id")),
            message="OPA policy denied authorization",
            extra={
                "reason": reason,
                "category": reason,
                "security_event": True,
            },
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "forbidden", "message": "OPA policy denied authorization"},
        )


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


def require_service_client_role(
    payload: Dict[str, Any],
    required_client_id: str,
    required_role: str,
) -> None:
    token_client_id = _token_client_id(payload)
    if token_client_id == required_client_id and has_role(payload, required_role):
        return

    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "forbidden",
            "message": (
                f"Required service client '{required_client_id}' with role "
                f"'{required_role}'. Token client: '{token_client_id}'. "
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
    payload: Dict[str, Any] = Depends(get_current_introspected_token_payload),
) -> Dict[str, Any]:
    require_service_client_role(
        payload,
        ADMIN_SERVICE_CLIENT_ID,
        ROLE_ADMIN_MAINTENANCE,
    )
    return payload

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


def _auth_failure_reason(status_code: int, detail: Any, path: str) -> Optional[str]:
    if status_code not in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN):
        return None
    if not path.startswith("/api/v1/admin/"):
        return None

    detail_text = json.dumps(detail, default=str).lower()
    if "ssrf_blocked" in detail_text:
        return None
    if "not authenticated" in detail_text:
        return "missing_token"
    if "expired" in detail_text:
        return "expired_token"
    if status_code == status.HTTP_401_UNAUTHORIZED or "invalid_token" in detail_text:
        return "invalid_token"
    if "required service client" in detail_text:
        return "service_client_forbidden"
    if "required role" in detail_text or "admin" in detail_text:
        return "admin_required"
    return "missing_role"


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    reason = _auth_failure_reason(exc.status_code, exc.detail, request.url.path)
    if reason:
        correlation_id = request.headers.get("X-Correlation-ID", "")
        log_event(
            level="WARNING",
            event_type="auth_failure",
            method=request.method,
            path=request.url.path,
            status_code=exc.status_code,
            client_ip=request.client.host if request.client else "unknown",
            correlation_id=correlation_id,
            message="JWT authn/authz failure",
            extra={
                "reason": reason,
                "category": reason,
                "security_event": True,
            },
        )
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
        headers=exc.headers,
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


class HealthResponse(BaseModel):
    status: str
    service: str


class MaintenanceResponse(BaseModel):
    status: str
    action: str
    correlation_id: str


class MetadataFetchRequest(BaseModel):
    fetch_url: str


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/v1/admin/health", tags=["Admin"], response_model=HealthResponse)
async def health_check():
    """Public health check."""
    return {"status": "ok", "service": "admin-service"}


@app.post("/api/v1/admin/maintenance", tags=["Admin"], response_model=MaintenanceResponse)
async def run_maintenance(
    body: MaintenanceRequest,
    request: Request,
    payload: Dict[str, Any] = Depends(require_maintenance_access),
):
    """
    Execute a maintenance action.
    Protected: requires a service-account Bearer JWT with role 'admin-maintenance'.
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    await require_opa_allow(
        {
            "action": "admin_maintenance",
            "service": "admin-service",
            "method": request.method,
            "path": request.url.path,
            "client_ip": request.client.host if request.client else "unknown",
            "subject_type": _subject_type(payload),
            "username": _claim_as_string(payload.get("preferred_username")),
            "client_id": _token_client_id(payload),
            "roles": _roles(payload),
            "correlation_id": correlation_id,
        }
    )
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
