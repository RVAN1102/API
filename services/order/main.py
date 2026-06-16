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
import time
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, Response, status

from auth import extract_identity, get_current_token_payload
from authz import check_order_ownership, get_effective_subject, require_user_or_admin

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

@app.get("/api/v1/orders/health", tags=["Orders"])
async def health_check():
    """Public health check. No authentication required."""
    return {"status": "ok", "service": "order-service"}


@app.get("/api/v1/orders", tags=["Orders"])
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


@app.get("/api/v1/orders/{order_id}", tags=["Orders"])
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


@app.get("/api/v1/orders/{order_id}/vulnerable", tags=["Orders", "BOLA"])
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


@app.get("/api/v1/orders/{order_id}/fixed", tags=["Orders", "BOLA"])
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
