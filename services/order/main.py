"""
main.py – Order Service (TV2)

FastAPI application providing:
  GET  /api/v1/orders/health              – public
  GET  /api/v1/orders                     – protected: list caller's orders
  GET  /api/v1/orders/{orderId}           – protected: get order (caller must own it or be admin)
  GET  /api/v1/orders/{orderId}/vulnerable – BOLA vulnerable: only checks token validity
  GET  /api/v1/orders/{orderId}/fixed      – BOLA fixed: checks token + ownership

Sample data (contract-defined):
  ord-alice-1001  owner: alice
  ord-alice-1002  owner: alice
  ord-bob-2001    owner: bob
  ord-bob-2002    owner: bob
"""

from __future__ import annotations

import json
import logging
import os
import time
from typing import Any, Dict, List, Optional

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from auth import extract_identity, get_current_introspected_token_payload, get_current_token_payload
from authz import (
    ROLE_ORDER_OWNERSHIP_READ,
    check_order_ownership,
    get_effective_subject,
    get_token_client_id,
    require_service_client_role,
    require_user_or_admin,
)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger("order-service")


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
        "service": "order-service",
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
    title="Order Service",
    description="Order management API with BOLA demo (TV2 – Capstone Topic 10)",
    version="1.0.0",
)

# ---------------------------------------------------------------------------
# Sample data (agreed contract from TV2 work plan)
# ---------------------------------------------------------------------------
ORDERS: Dict[str, Dict[str, Any]] = {
    "ord-alice-1001": {"order_id": "ord-alice-1001", "owner_id": "alice", "amount": 150000, "status": "created", "currency": "VND"},
    "ord-alice-1002": {"order_id": "ord-alice-1002", "owner_id": "alice", "amount": 250000, "status": "paid",    "currency": "VND"},
    "ord-bob-2001":   {"order_id": "ord-bob-2001",   "owner_id": "bob",   "amount": 80000,  "status": "created", "currency": "VND"},
    "ord-bob-2002":   {"order_id": "ord-bob-2002",   "owner_id": "bob",   "amount": 310000, "status": "shipped", "currency": "VND"},
}

BILLING_SERVICE_CLIENT_ID = os.environ.get("BILLING_SERVICE_CLIENT_ID", "billing-service-client")
OPA_URL = os.environ.get("OPA_URL", "http://opa:8181").rstrip("/")
OPA_ALLOW_URL = f"{OPA_URL}/v1/data/topic10/authz/allow"


class OwnershipVerificationRequest(BaseModel):
    order_id: str
    subject: str


class HealthResponse(BaseModel):
    status: str
    service: str


class OrderResponse(BaseModel):
    order_id: str
    owner_id: str
    amount: float
    status: str
    currency: str
    correlation_id: Optional[str] = None
    note: Optional[str] = None


class OrderListResponse(BaseModel):
    caller: str
    orders: List[OrderResponse]
    count: int
    correlation_id: str


class OwnershipVerificationResponse(BaseModel):
    order_id: str
    allowed: bool
    owner_id: str
    amount: float
    currency: str
    status: str
    correlation_id: str


async def require_order_ownership_read(
    payload: Dict[str, Any] = Depends(get_current_introspected_token_payload),
) -> Dict[str, Any]:
    require_service_client_role(
        payload,
        BILLING_SERVICE_CLIENT_ID,
        ROLE_ORDER_OWNERSHIP_READ,
    )
    return payload


def _roles(payload: Dict[str, Any]) -> List[str]:
    roles = payload.get("realm_access", {}).get("roles", [])
    return roles if isinstance(roles, list) else []


def _claim_as_string(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item.strip():
                return item.strip()
    return ""


def _subject_type(payload: Dict[str, Any]) -> str:
    return "service" if get_token_client_id(payload) == BILLING_SERVICE_CLIENT_ID else "human"


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
        reason = "ownership_denied" if input_data.get("action") == "order_verify_ownership" else "opa_denied"
        log_event(
            level="WARNING",
            event_type="auth_failure",
            method=_claim_as_string(input_data.get("method")) or "POST",
            path=_claim_as_string(input_data.get("path")) or "/api/v1/orders/internal/verify-ownership",
            status_code=status.HTTP_403_FORBIDDEN,
            client_ip=_claim_as_string(input_data.get("client_ip")) or "unknown",
            correlation_id=_claim_as_string(input_data.get("correlation_id")),
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


def _auth_failure_reason(status_code: int, detail: Any, path: str) -> Optional[str]:
    if status_code not in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN):
        return None
    if not path.startswith("/api/v1/orders"):
        return None

    detail_text = json.dumps(detail, default=str).lower()
    if "not authenticated" in detail_text:
        return "missing_token"
    if "expired" in detail_text:
        return "expired_token"
    if status_code == status.HTTP_401_UNAUTHORIZED or "invalid_token" in detail_text:
        return "invalid_token"
    if "required service client" in detail_text:
        return "service_client_forbidden"
    if "permission to access this order" in detail_text or "bola_attempt" in detail_text:
        return "ownership_denied"
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
    )
    if correlation_id:
        response.headers["X-Correlation-ID"] = correlation_id
    return response


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/v1/orders/health", tags=["Orders"], response_model=HealthResponse)
async def health_check():
    """Public health check. No authentication required."""
    return {"status": "ok", "service": "order-service"}


@app.get(
    "/api/v1/orders",
    tags=["Orders"],
    response_model=OrderListResponse,
    response_model_exclude_none=True,
)
async def list_orders(
    request: Request,
    payload: Dict[str, Any] = Depends(get_current_token_payload),
):
    """
    List orders belonging to the authenticated user.
    Admin can see all orders.
    """
    require_user_or_admin(payload)
    identity = extract_identity(payload)
    caller = identity["preferred_username"] or identity["sub"]
    correlation_id = request.headers.get("X-Correlation-ID", "")

    if "admin" in identity["roles"]:
        orders = list(ORDERS.values())
    else:
        orders = [o for o in ORDERS.values() if o["owner_id"] == caller]

    return {
        "caller": caller,
        "orders": orders,
        "count": len(orders),
        "correlation_id": correlation_id,
    }


@app.post(
    "/api/v1/orders/internal/verify-ownership",
    tags=["Orders", "Internal"],
    response_model=OwnershipVerificationResponse,
)
async def verify_order_ownership(
    body: OwnershipVerificationRequest,
    request: Request,
    payload: Dict[str, Any] = Depends(require_order_ownership_read),
):
    """
    Verify order ownership for internal service-to-service callers.

    Only the billing-service-client with role order-ownership-read may call this
    endpoint. Ownership is checked from the Order service ORDERS data.
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    order = ORDERS.get(body.order_id)
    if not order:
        log_event(
            level="WARNING",
            event_type="ownership_verification_failed",
            method="POST",
            path="/api/v1/orders/internal/verify-ownership",
            status_code=404,
            client_ip=request.client.host if request.client else "unknown",
            correlation_id=correlation_id,
            extra={"order_id": body.order_id, "decision": "not_found"},
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "not_found", "message": "Order not found"},
        )

    await require_opa_allow(
        {
            "action": "order_verify_ownership",
            "service": "order-service",
            "method": request.method,
            "path": request.url.path,
            "client_ip": request.client.host if request.client else "unknown",
            "subject_type": _subject_type(payload),
            "username": _claim_as_string(payload.get("preferred_username")),
            "client_id": get_token_client_id(payload),
            "roles": _roles(payload),
            "order_id": body.order_id,
            "order_owner": order["owner_id"],
            "requested_username": body.subject,
            "correlation_id": correlation_id,
        }
    )

    allowed = order["owner_id"] == body.subject
    log_event(
        level="INFO" if allowed else "WARNING",
        event_type="ownership_verification",
        method="POST",
        path="/api/v1/orders/internal/verify-ownership",
        status_code=200,
        client_ip=request.client.host if request.client else "unknown",
        correlation_id=correlation_id,
        extra={
            "order_id": body.order_id,
            "decision": "allowed" if allowed else "denied",
        },
    )

    return {
        "order_id": body.order_id,
        "allowed": allowed,
        "owner_id": order["owner_id"],
        "amount": order["amount"],
        "currency": order["currency"],
        "status": order["status"],
        "correlation_id": correlation_id,
    }


@app.get(
    "/api/v1/orders/{order_id}",
    tags=["Orders"],
    response_model=OrderResponse,
    response_model_exclude_none=True,
)
async def get_order(
    order_id: str,
    request: Request,
    payload: Dict[str, Any] = Depends(get_current_token_payload),
):
    """
    Get a single order.
    Caller must own the order or have admin role.
    Returns 404 if order not found, 403 if not authorized.
    """
    require_user_or_admin(payload)
    order = ORDERS.get(order_id)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "not_found", "message": f"Order {order_id} not found"},
        )
    check_order_ownership(payload, order["owner_id"])
    correlation_id = request.headers.get("X-Correlation-ID", "")
    return {**order, "correlation_id": correlation_id}


@app.get(
    "/api/v1/orders/{order_id}/vulnerable",
    tags=["Orders", "BOLA"],
    response_model=OrderResponse,
    response_model_exclude_none=True,
)
async def get_order_vulnerable(
    order_id: str,
    request: Request,
    payload: Dict[str, Any] = Depends(get_current_token_payload),
):
    """
    BOLA VULNERABLE endpoint.

    Security flaw: validates that a token exists but does NOT check
    whether the caller owns the requested order.
    Alice can access Bob's order if she knows the order ID.

    Expected demo:
      Alice token → GET /ord-bob-2001/vulnerable → 200 (WRONG: should be 403)
    """
    # Only verify token is valid; NO ownership check
    require_user_or_admin(payload)
    order = ORDERS.get(order_id)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "not_found", "message": f"Order {order_id} not found"},
        )

    identity = extract_identity(payload)
    caller = identity["preferred_username"] or identity["sub"]

    # Log BOLA attempt for observability demo (but still return 200 to show vulnerability)
    if order["owner_id"] != caller:
        log_event(
            level="WARNING",
            event_type="bola_attempt",
            method="GET",
            path=f"/api/v1/orders/{order_id}/vulnerable",
            status_code=200,
            client_ip=request.client.host if request.client else "unknown",
            correlation_id=request.headers.get("X-Correlation-ID", ""),
            extra={
                "actor": caller,
                "target": order_id,
                "decision": "allowed",
                "reason": "vulnerable_endpoint",
            },
        )

    correlation_id = request.headers.get("X-Correlation-ID", "")
    return {
        **order,
        "note": "BOLA VULNERABLE: no ownership check performed",
        "correlation_id": correlation_id,
    }


@app.get(
    "/api/v1/orders/{order_id}/fixed",
    tags=["Orders", "BOLA"],
    response_model=OrderResponse,
    response_model_exclude_none=True,
)
async def get_order_fixed(
    order_id: str,
    request: Request,
    payload: Dict[str, Any] = Depends(get_current_token_payload),
):
    """
    BOLA FIXED endpoint.

    Validates token AND enforces ownership (or admin role).
    Alice cannot access Bob's order.

    Expected demo:
      Alice token → GET /ord-bob-2001/fixed → 403
      Bob token   → GET /ord-bob-2001/fixed → 200
      Admin token → GET /ord-bob-2001/fixed → 200
    """
    require_user_or_admin(payload)
    order = ORDERS.get(order_id)
    if not order:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "not_found", "message": f"Order {order_id} not found"},
        )

    caller = get_effective_subject(payload, allow_automation_owner=True)

    # Ownership check – raises 403 if caller is not owner and not admin
    check_order_ownership(payload, order["owner_id"], allow_automation_owner=True)

    log_event(
        level="INFO",
        event_type="authz_allowed",
        method="GET",
        path=f"/api/v1/orders/{order_id}/fixed",
        status_code=200,
        client_ip=request.client.host if request.client else "unknown",
        correlation_id=request.headers.get("X-Correlation-ID", ""),
        extra={
            "actor": caller,
            "target": order_id,
            "decision": "allowed",
            "reason": "ownership_verified",
        },
    )

    correlation_id = request.headers.get("X-Correlation-ID", "")
    return {
        **order,
        "note": "BOLA FIXED: ownership verified",
        "correlation_id": correlation_id,
    }
