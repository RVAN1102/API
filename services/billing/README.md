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

## Test

```bash
# Health
curl http://localhost:8000/api/v1/billing/health

# Checkout
curl -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: billing-001" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'
```
