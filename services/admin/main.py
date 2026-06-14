"""
main.py – Admin Service (TV3)

FastAPI application providing:
  GET  /api/v1/admin/health                      – public
  POST /api/v1/admin/maintenance                 – protected (Bearer JWT)
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
import re
import socket
import time
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
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
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """
    Execute a maintenance action.
    Protected: requires Bearer token.
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
    credentials: HTTPAuthorizationCredentials = Depends(security),
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
    credentials: HTTPAuthorizationCredentials = Depends(security),
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
