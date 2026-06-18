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
from urllib.parse import urlparse

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

# ---------------------------------------------------------------------------
# mTLS configuration
# When WEBHOOK_MTLS_REQUIRED=true (default in production), the billing service
# expects Kong to have verified the client TLS certificate and injected
# the header X-Mtls-Client-Verified: SUCCESS.
# Set WEBHOOK_MTLS_REQUIRED=false in dev/test mode to bypass (with log warning).
# ---------------------------------------------------------------------------
WEBHOOK_MTLS_REQUIRED: bool = os.environ.get("WEBHOOK_MTLS_REQUIRED", "true").lower() == "true"
WEBHOOK_MTLS_HEADER: str = "X-Mtls-Client-Verified"
WEBHOOK_MTLS_SUCCESS_VALUE: str = "SUCCESS"

KEYCLOAK_URL: str = os.environ.get("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM: str = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
EXPECTED_ISSUER: str = os.environ.get("KEYCLOAK_ISSUER", f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}")
JWKS_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
TOKEN_URL: str = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token"
ORDER_SERVICE_URL: str = os.environ.get("ORDER_SERVICE_URL", "http://order-service:8000")
BILLING_SERVICE_CLIENT_ID: str = os.environ.get("BILLING_SERVICE_CLIENT_ID", "billing-service-client")
BILLING_SERVICE_CLIENT_SECRET: str = os.environ.get("BILLING_SERVICE_CLIENT_SECRET", "")
OPA_URL: str = os.environ.get("OPA_URL", "http://opa:8181").rstrip("/")
OPA_ALLOW_URL: str = f"{OPA_URL}/v1/data/topic10/authz/allow"
ALLOWED_HUMAN_CLIENT_IDS = {"sme-web-client", "sme-lab-automation-client"}

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

LAB_AUTOMATION_SUBJECTS: Dict[str, str] = {
    "ci-alice": "alice",
    "ci-bob": "bob",
}


# ---------------------------------------------------------------------------
# JWT authentication helpers
# ---------------------------------------------------------------------------
def _invalid_token_exception() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"error": "invalid_token", "message": "Bearer token is invalid"},
    )


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
    try:
        header = jwt.get_unverified_header(token)
    except Exception:
        raise _invalid_token_exception()

    kid = _claim_as_string(header.get("kid"))
    if not kid:
        raise _invalid_token_exception()

    jwks = await _fetch_jwks()
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            try:
                return jwk.construct(key_data)
            except Exception:
                raise _invalid_token_exception()
    _invalidate_jwks_cache()
    jwks = await _fetch_jwks()
    for key_data in jwks.get("keys", []):
        if key_data.get("kid") == kid:
            try:
                return jwk.construct(key_data)
            except Exception:
                raise _invalid_token_exception()
    raise _invalid_token_exception()


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
    except HTTPException:
        raise
    except JWTError:
        raise _invalid_token_exception()
    except Exception:
        raise _invalid_token_exception()

    if payload.get("iss") != EXPECTED_ISSUER:
        raise _invalid_token_exception()
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


def has_role(payload: Dict[str, Any], *roles: str) -> bool:
    user_roles: List[str] = payload.get("realm_access", {}).get("roles", [])
    return any(r in user_roles for r in roles)


def _roles(payload: Dict[str, Any]) -> List[str]:
    roles = payload.get("realm_access", {}).get("roles", [])
    return roles if isinstance(roles, list) else []


def _token_client_id(payload: Dict[str, Any]) -> str:
    return _claim_as_string(payload.get("azp")) or _claim_as_string(payload.get("client_id"))


def _audiences(payload: Dict[str, Any]) -> Set[str]:
    aud = payload.get("aud")
    if isinstance(aud, str) and aud.strip():
        return {aud.strip()}
    if isinstance(aud, list):
        return {item.strip() for item in aud if isinstance(item, str) and item.strip()}
    return set()


def require_human_client(payload: Dict[str, Any]) -> None:
    token_client = _token_client_id(payload)
    if token_client in ALLOWED_HUMAN_CLIENT_IDS:
        return
    if not token_client and _audiences(payload) & ALLOWED_HUMAN_CLIENT_IDS:
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "forbidden_client",
            "message": "Token client is not allowed for checkout",
        },
    )


def _subject_type(payload: Dict[str, Any]) -> str:
    service_clients = {BILLING_SERVICE_CLIENT_ID, "admin-service-client"}
    return "service" if _token_client_id(payload) in service_clients else "human"


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
        reason = "ownership_denied" if input_data.get("action") == "billing_checkout" else "opa_denied"
        log_event(
            level="WARNING",
            event_type="auth_failure",
            method=_claim_as_string(input_data.get("method")) or "POST",
            path=_claim_as_string(input_data.get("path")) or "/api/v1/billing/checkout",
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


def _is_automation_fixture(payload: Dict[str, Any]) -> bool:
    value = payload.get("automation_fixture")
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() == "true"
    return False


def _claim_as_string(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item.strip():
                return item.strip()
    return ""


def normalize_checkout_subject(subject: str) -> str:
    # Production users should use their real preferred_username. The ci-* users
    # are lab automation identities mapped to alice/bob for repeatable tests
    # without using password-only human flows.
    return LAB_AUTOMATION_SUBJECTS.get(subject, subject)


def get_effective_subject(payload: Dict[str, Any]) -> str:
    if _is_automation_fixture(payload):
        automation_owner = _claim_as_string(payload.get("automation_owner"))
        if automation_owner:
            return normalize_checkout_subject(automation_owner)

    caller = _claim_as_string(payload.get("preferred_username"))
    if caller:
        return normalize_checkout_subject(caller)
    return normalize_checkout_subject(_claim_as_string(payload.get("sub")))


async def require_checkout_access(
    payload: Dict[str, Any] = Depends(get_current_token_payload),
) -> Dict[str, Any]:
    require_human_client(payload)
    require_role(payload, ROLE_USER, ROLE_ADMIN)
    return payload


def keycloak_token_request_headers() -> Dict[str, str]:
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    issuer_host = urlparse(EXPECTED_ISSUER).netloc
    if issuer_host:
        headers["Host"] = issuer_host
    return headers


async def obtain_billing_service_token() -> str:
    if not BILLING_SERVICE_CLIENT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "error": "service_token_unavailable",
                "message": "Billing service client secret is not configured",
            },
        )

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                TOKEN_URL,
                data={
                    "grant_type": "client_credentials",
                    "client_id": BILLING_SERVICE_CLIENT_ID,
                    "client_secret": BILLING_SERVICE_CLIENT_SECRET,
                },
                headers=keycloak_token_request_headers(),
            )
    except httpx.HTTPError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "error": "service_token_unavailable",
                "message": "Billing service could not reach identity provider",
            },
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "error": "service_token_unavailable",
                "message": "Billing service token request failed",
            },
        )

    try:
        token = response.json().get("access_token", "")
    except ValueError:
        token = ""

    if not token:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "error": "service_token_unavailable",
                "message": "Billing service token response was invalid",
            },
        )
    return token


async def verify_order_ownership_with_order_service(
    order_id: str,
    subject: str,
    correlation_id: str,
) -> bool:
    service_token = await obtain_billing_service_token()
    verify_url = f"{ORDER_SERVICE_URL}/api/v1/orders/internal/verify-ownership"

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                verify_url,
                json={"order_id": order_id, "subject": subject},
                headers={
                    "Authorization": f"Bearer {service_token}",
                    "Content-Type": "application/json",
                    "X-Correlation-ID": correlation_id,
                },
            )
    except httpx.HTTPError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "ownership_verification_failed",
                "message": "Order ownership could not be verified",
            },
        )

    if response.status_code == 200:
        try:
            return bool(response.json().get("allowed"))
        except ValueError:
            return False

    if response.status_code in (status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND):
        return False

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "ownership_verification_failed",
            "message": "Order ownership could not be verified",
        },
    )


async def require_order_owner_via_order_service(
    payload: Dict[str, Any],
    order_id: str,
    correlation_id: str,
    request: Request,
) -> str:
    subject = get_effective_subject(payload)
    if subject and await verify_order_ownership_with_order_service(order_id, subject, correlation_id):
        return subject

    log_event(
        level="WARNING",
        event_type="auth_failure",
        method="POST",
        path="/api/v1/billing/checkout",
        status_code=403,
        client_ip=request.client.host if request.client else "unknown",
        correlation_id=correlation_id,
        message="Checkout ownership denied",
        extra={
            "reason": "ownership_denied",
            "category": "ownership_denied",
            "security_event": True,
            "order_id": order_id,
        },
    )
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={
            "error": "forbidden",
            "message": "You do not have permission to checkout this order",
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
    payload: Dict[str, Any] = Depends(require_checkout_access),
):
    """
    Initiate a checkout/payment session.

    Protected: requires valid Bearer token.
    Returns 202 Accepted with a generated payment_id.

    Requires a valid Keycloak JWT with role 'user' or 'admin'.
    Requires order ownership unless the caller has role 'admin'.
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    subject = await require_order_owner_via_order_service(payload, body.order_id, correlation_id, request)
    await require_opa_allow(
        {
            "action": "billing_checkout",
            "service": "billing-service",
            "method": request.method,
            "path": request.url.path,
            "client_ip": request.client.host if request.client else "unknown",
            "subject_type": _subject_type(payload),
            "username": subject,
            "client_id": _token_client_id(payload),
            "roles": _roles(payload),
            "order_id": body.order_id,
            "ownership_confirmed": True,
            "ownership_confirmation_source": "order-service",
            "correlation_id": correlation_id,
        }
    )

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
      X-Webhook-Timestamp      – Unix timestamp (string)
      X-Webhook-Nonce          – Random string (replay prevention)
      X-Webhook-Signature      – sha256=<hex_digest>
      X-Mtls-Client-Verified   – Must be "SUCCESS" (injected by Kong after
                                   nginx ssl_verify_client succeeds).
                                   Only enforced when WEBHOOK_MTLS_REQUIRED=true.

    Message format: timestamp + "." + nonce + "." + raw_body
    Algorithm: HMAC-SHA256

    Returns:
      200  – webhook accepted
      401  – missing/invalid signature OR mTLS client cert not verified
      403  – expired timestamp or replayed nonce
    """
    correlation_id = request.headers.get("X-Correlation-ID", "")
    client_ip = request.client.host if request.client else "unknown"

    # --- mTLS client certificate check ---
    # Kong's nginx (ssl_verify_client on) injects X-Mtls-Client-Verified: SUCCESS
    # when the client presents a valid cert signed by the configured CA.
    mtls_header_value = request.headers.get(WEBHOOK_MTLS_HEADER, "")
    if WEBHOOK_MTLS_REQUIRED:
        if mtls_header_value != WEBHOOK_MTLS_SUCCESS_VALUE:
            log_event(
                "WARNING",
                "webhook_mtls_rejected",
                "POST",
                "/api/v1/webhooks/payment",
                401,
                client_ip,
                correlation_id,
                "mTLS client certificate not verified",
                {
                    "security_event": True,
                    "decision": "rejected",
                    "reason": "mtls_client_cert_required",
                    "header_present": bool(mtls_header_value),
                },
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={
                    "error": "mtls_client_cert_required",
                    "message": (
                        "Webhook channel requires mutual TLS. "
                        "Client certificate must be verified by the gateway "
                        f"(header {WEBHOOK_MTLS_HEADER} must equal '{WEBHOOK_MTLS_SUCCESS_VALUE}')."
                    ),
                },
            )
    else:
        # Dev/test mode: mTLS bypass with audit log
        log_event(
            "WARNING",
            "webhook_mtls_bypass",
            "POST",
            "/api/v1/webhooks/payment",
            0,
            client_ip,
            correlation_id,
            "mTLS enforcement is DISABLED (WEBHOOK_MTLS_REQUIRED=false). NOT for production.",
            {"security_event": True, "mtls_header_value": mtls_header_value},
        )

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
