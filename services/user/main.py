"""
main.py – User Service (TV2)

FastAPI application providing:
  GET  /api/v1/users/health   – public health check
  GET  /api/v1/users/me       – protected: return identity from JWT
  GET  /api/v1/users/profile  – protected: return user profile from JWT

Authorization:
  - /health  → public
  - /me      → any authenticated user (role: user or admin)
  - /profile → any authenticated user (role: user or admin)

Headers propagated:
  - X-Correlation-ID is echoed back in all responses.
"""

from __future__ import annotations

import json
import logging
import os
import time
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from auth import extract_identity, get_current_token_payload
from authz import require_user_or_admin

# ---------------------------------------------------------------------------
# Logging setup – structured JSON compatible with Promtail/Loki
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger("user-service")


def log_event(
    level: str,
    event_type: str,
    method: str,
    path: str,
    status_code: int,
    client_ip: str,
    correlation_id: str,
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    record: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": level,
        "service": "user-service",
        "method": method,
        "path": path,
        "status_code": status_code,
        "client_ip": client_ip,
        "correlation_id": correlation_id,
        "event_type": event_type,
    }
    if extra:
        record.update(extra)
    getattr(logger, level.lower(), logger.info)(json.dumps(record))

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="User Service",
    description="Identity-aware user profile API (TV2 – Capstone Topic 10)",
    version="1.0.0",
    openapi_url="/openapi.json",
)


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------

class HealthResponse(BaseModel):
    status: str
    service: str


class UserMeResponse(BaseModel):
    user_id: str
    username: str
    email: str
    roles: List[str]
    correlation_id: str


class UserProfileResponse(UserMeResponse):
    azp: str
    scope: str


def _auth_failure_reason(status_code: int, detail: Any, path: str) -> Optional[str]:
    if status_code not in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN):
        return None
    if not path.startswith("/api/v1/users/"):
        return None

    detail_text = json.dumps(detail, default=str).lower()
    if "not authenticated" in detail_text:
        return "missing_token"
    if "expired" in detail_text:
        return "expired_token"
    if status_code == status.HTTP_401_UNAUTHORIZED or "invalid_token" in detail_text:
        return "invalid_token"
    if "required role" in detail_text:
        return "user_required"
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
# Middleware: structured request logging + correlation-id propagation
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
    )
    # Echo correlation-id back in response
    if correlation_id:
        response.headers["X-Correlation-ID"] = correlation_id
    return response


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/v1/users/health", tags=["Users"], response_model=HealthResponse)
async def health_check():
    """
    Public health check endpoint.
    No authentication required.
    """
    return {"status": "ok", "service": "user-service"}


@app.get("/api/v1/users/me", tags=["Users"], response_model=UserMeResponse)
async def get_me(
    request: Request,
    payload: Dict[str, Any] = Depends(get_current_token_payload),
):
    """
    Return identity information extracted from the validated JWT.

    Requires: valid Bearer token with role 'user' or 'admin'.
    Returns 401 if no/invalid token, 403 if wrong role.
    """
    require_user_or_admin(payload)
    identity = extract_identity(payload)
    correlation_id = request.headers.get("X-Correlation-ID", "")
    return {
        "user_id": identity["sub"],
        "username": identity["preferred_username"],
        "email": identity["email"],
        "roles": identity["roles"],
        "correlation_id": correlation_id,
    }


@app.get("/api/v1/users/profile", tags=["Users"], response_model=UserProfileResponse)
async def get_profile(
    request: Request,
    payload: Dict[str, Any] = Depends(get_current_token_payload),
):
    """
    Return a user profile view.

    Requires: valid Bearer token with role 'user' or 'admin'.
    Returns 401 if no/invalid token, 403 if wrong role.
    """
    require_user_or_admin(payload)
    identity = extract_identity(payload)
    correlation_id = request.headers.get("X-Correlation-ID", "")
    return {
        "user_id": identity["sub"],
        "username": identity["preferred_username"],
        "email": identity["email"],
        "roles": identity["roles"],
        "azp": identity["azp"],
        "scope": identity["scope"],
        "correlation_id": correlation_id,
    }
