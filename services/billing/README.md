# Billing Service (TV3)

## Overview

FastAPI-based Billing Service with checkout and webhook endpoints.

## Endpoints

| Method | Path                        | Auth Required | Description                     |
|--------|-----------------------------|---------------|---------------------------------|
| GET    | /api/v1/billing/health      | No            | Health check                    |
| POST   | /api/v1/billing/checkout    | Yes (Bearer)  | Initiate checkout               |
| POST   | /api/v1/webhooks/payment    | HMAC          | Payment webhook callback        |

## Webhook Security

Webhook uses HMAC-SHA256 (TV1 contract):

```
X-Webhook-Timestamp: <unix_timestamp>
X-Webhook-Nonce: <unique_nonce>
X-Webhook-Signature: sha256=<hex>
Message = timestamp + "." + nonce + "." + raw_body
```

Replay protection uses a Redis-backed nonce TTL store by default in lab Docker
Compose:

```text
WEBHOOK_NONCE_STORE=redis
WEBHOOK_NONCE_REDIS_URL=redis://redis:6379/0
WEBHOOK_NONCE_TTL_SECONDS=300
```

The service reserves a nonce only after mTLS, timestamp freshness, and HMAC
validation pass. Redis uses atomic `SET NX EX`, so replayed nonces are rejected
across service restarts and multiple replicas while the TTL is active. If Redis
is unavailable, webhook processing fails closed. `WEBHOOK_NONCE_STORE=memory`
is only an explicit local-dev fallback and is not the default for final
regression.

## Test

```bash
# Health
curl https://localhost:8443/api/v1/billing/health

# Checkout
curl -X POST https://localhost:8443/api/v1/billing/checkout \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: billing-001" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'
```
