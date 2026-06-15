"""
main.py – Billing Service (TV3)

FastAPI application providing:
  GET  /api/v1/billing/health     – public
  POST /api/v1/billing/checkout   – protected (Bearer JWT)
  POST /api/v1/webhooks/payment   – webhook with HMAC-SHA256 verification

Webhook HMAC contract (from TV1):
  Headers: X-Webhook-Timestamp, X-Webhook-Nonce, X-Webhook-Signature
  Message: timestamp + "." + nonce + "." + raw_body
  Algorithm: HMAC-SHA256
  Reject: old timestamp (>300s), replayed nonce, bad signature

Structured JSON logging compatible with Promtail/Loki.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import time
from typing import Any, Dict, List, Optional, Set

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
WEBHOOK_SECRET: str = os.environ.get("WEBHOOK_SECRET", "dev-webhook-secret-change-me")
WEBHOOK_MAX_AGE_SECONDS: int = int(os.environ.get("WEBHOOK_MAX_AGE_SECONDS", "300"))

KEYCLOAK_URL: str = os.environ.get("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM: str = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
EXPECTED_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"

# ---------------------------------------------------------------------------
# Logging – structured JSON
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger("billing-service")


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
    """Emit a structured JSON log line."""
    record: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": level,
        "service": "billing-service",
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
    title="Billing Service",
    description="Checkout and payment webhook handler (TV3 – Capstone Topic 10)",
    version="1.0.0",
)

# Nonce replay store (in-memory; sufficient for demo)
_used_nonces: Set[str] = set()

security = HTTPBearer(auto_error=True)
_jwks_cache: Optional[Dict[str, Any]] = None

ROLE_USER = "user"
ROLE_ADMIN = "admin"


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


async def require_checkout_access(
    payload: Dict[str, Any] = Depends(get_current_token_payload),
) -> Dict[str, Any]:
    require_role(payload, ROLE_USER, ROLE_ADMIN)
    return payload


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

class CheckoutRequest(BaseModel):
    order_id: str
    amount: float
    currency: str = "VND"


class PaymentWebhookPayload(BaseModel):
    event_id: str
    event_type: str
    checkout_id: str
    amount: Optional[float] = None


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/v1/billing/health", tags=["Billing"])
async def health_check():
    """Public health check. No authentication required."""
    return {"status": "ok", "service": "billing-service"}


@app.post("/api/v1/billing/checkout", tags=["Billing"], status_code=202)
async def create_checkout(
    body: CheckoutRequest,
    request: Request,
    _payload: Dict[str, Any] = Depends(require_checkout_access),
):
    """
    Initiate a checkout/payment session.

    Protected: requires valid Bearer token.
    Returns 202 Accepted with a generated payment_id.

    Requires a valid Keycloak JWT with role 'user' or 'admin'.
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    import uuid
    payment_id = f"pay-{uuid.uuid4().hex[:8]}"

    log_event(
        level="INFO",
        event_type="api_request",
        method="POST",
        path="/api/v1/billing/checkout",
        status_code=202,
        client_ip=request.client.host if request.client else "unknown",
        correlation_id=correlation_id,
        message=f"Checkout accepted for order {body.order_id}",
        extra={"order_id": body.order_id, "amount": body.amount, "currency": body.currency},
    )

    return {
        "payment_id": payment_id,
        "order_id": body.order_id,
        "status": "accepted",
        "amount": body.amount,
        "currency": body.currency,
        "correlation_id": correlation_id,
    }


@app.post("/api/v1/webhooks/payment", tags=["Webhooks"])
async def receive_payment_webhook(request: Request):
    """
    Receive a payment webhook with HMAC-SHA256 signature verification.

    Required headers (TV1 contract):
      X-Webhook-Timestamp  – Unix timestamp (string)
      X-Webhook-Nonce      – Random string (replay prevention)
      X-Webhook-Signature  – sha256=<hex_digest>

    Message format: timestamp + "." + nonce + "." + raw_body
    Algorithm: HMAC-SHA256

    Returns:
      200  – webhook accepted
      401  – missing or invalid signature
      403  – expired timestamp or replayed nonce
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    client_ip = request.client.host if request.client else "unknown"

    # --- Read headers ---
    timestamp_str = request.headers.get("X-Webhook-Timestamp", "")
    nonce = request.headers.get("X-Webhook-Nonce", "")
    signature_header = request.headers.get("X-Webhook-Signature", "")

    if not timestamp_str or not nonce or not signature_header:
        log_event("WARNING", "webhook_invalid_signature", "POST",
                  "/api/v1/webhooks/payment", 401, client_ip, correlation_id,
                  "Missing required webhook headers",
                  {"security_event": True, "decision": "rejected", "reason": "missing_headers"})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "missing_webhook_header", "message": "X-Webhook-Timestamp, X-Webhook-Nonce, and X-Webhook-Signature are required"},
        )

    # --- Timestamp freshness check ---
    try:
        timestamp = int(timestamp_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail={"error": "invalid_timestamp", "message": "Timestamp must be an integer"})

    now = int(time.time())
    age = abs(now - timestamp)
    if age > WEBHOOK_MAX_AGE_SECONDS:
        log_event("WARNING", "webhook_replay_detected", "POST",
                  "/api/v1/webhooks/payment", 403, client_ip, correlation_id,
                  f"Webhook timestamp too old: age={age}s",
                  {"security_event": True, "decision": "rejected", "reason": "timestamp_expired", "age_seconds": age})
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "timestamp_expired", "message": f"Webhook timestamp is {age}s old (max {WEBHOOK_MAX_AGE_SECONDS}s)"},
        )

    # --- Nonce replay check ---
    if nonce in _used_nonces:
        log_event("WARNING", "webhook_replay_detected", "POST",
                  "/api/v1/webhooks/payment", 403, client_ip, correlation_id,
                  f"Replay nonce detected: {nonce}",
                  {"security_event": True, "decision": "rejected", "reason": "replayed_nonce", "nonce": nonce})
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": "replayed_nonce", "message": "This nonce has already been used"},
        )

    # --- Read raw body ---
    raw_body = await request.body()

    # --- Compute expected HMAC ---
    message = f"{timestamp_str}.{nonce}.{raw_body.decode('utf-8', errors='replace')}"
    expected_sig = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        message.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()

    # Signature header format: "sha256=<hex>"
    provided_sig = signature_header.replace("sha256=", "").strip()
    if not hmac.compare_digest(expected_sig, provided_sig):
        log_event("WARNING", "webhook_invalid_signature", "POST",
                  "/api/v1/webhooks/payment", 401, client_ip, correlation_id,
                  "Webhook signature mismatch",
                  {"security_event": True, "decision": "rejected", "reason": "invalid_signature"})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "invalid_signature", "message": "HMAC-SHA256 signature verification failed"},
        )

    # --- Accept nonce ---
    _used_nonces.add(nonce)

    # --- Parse body ---
    try:
        body_json = json.loads(raw_body)
    except json.JSONDecodeError:
        body_json = {}

    log_event("INFO", "api_request", "POST",
              "/api/v1/webhooks/payment", 200, client_ip, correlation_id,
              f"Webhook accepted: event_type={body_json.get('event_type', 'unknown')}",
              {"event_id": body_json.get("event_id"), "checkout_id": body_json.get("checkout_id")})

    return {
        "status": "accepted",
        "event_id": body_json.get("event_id"),
        "correlation_id": correlation_id,
    }
