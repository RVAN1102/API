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

import logging
import os
from typing import Any, Dict, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse

from auth import extract_identity, get_current_token_payload
from authz import require_user_or_admin

# ---------------------------------------------------------------------------
# Logging setup – structured JSON compatible with Promtail/Loki
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","level":"%(levelname)s","service":"user-service","message":"%(message)s"}',
)
logger = logging.getLogger("user-service")

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
# Middleware: structured request logging + correlation-id propagation
# ---------------------------------------------------------------------------

@app.middleware("http")
async def log_requests(request: Request, call_next):
    correlation_id: str = request.headers.get("X-Correlation-ID", "")
    response: Response = await call_next(request)
    logger.info(
        '{"service":"user-service","method":"%s","path":"%s","status_code":%d,'
        '"client_ip":"%s","correlation_id":"%s","event_type":"api_request"}',
        request.method,
        request.url.path,
        response.status_code,
        request.client.host if request.client else "unknown",
        correlation_id,
    )
    # Echo correlation-id back in response
    if correlation_id:
        response.headers["X-Correlation-ID"] = correlation_id
    return response


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/v1/users/health", tags=["Users"])
async def health_check():
    """
    Public health check endpoint.
    No authentication required.
    """
    return {"status": "ok", "service": "user-service"}


@app.get("/api/v1/users/me", tags=["Users"])
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


@app.get("/api/v1/users/profile", tags=["Users"])
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
