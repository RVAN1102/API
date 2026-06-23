# Billing Service

## Overview

FastAPI-based Billing service with checkout and payment webhook endpoints. In
the Compose runtime it listens directly with uvicorn TLS/mTLS on port `8443`.

## Endpoints

| Method | Path | Auth required | Description |
|---|---|---|---|
| GET | `/api/v1/billing/health` | No | Health check |
| POST | `/api/v1/billing/checkout` | Bearer | Initiate checkout using canonical Order data |
| POST | `/api/v1/webhooks/payment` | HMAC and mTLS | Payment webhook callback |

## Checkout Security

Billing verifies caller ownership of the order through the Order service before
accepting checkout. The Order service response is the canonical source for
amount and currency; client-supplied mismatches are rejected with HTTP `409`.

Runtime Order configuration:

```text
ORDER_SERVICE_URL=https://order-service:8443
ORDER_SERVICE_TLS_CA_CERT=/etc/internal-tls/ca.crt
ORDER_SERVICE_TLS_CLIENT_CERT=/etc/internal-tls/billing-client.crt
ORDER_SERVICE_TLS_CLIENT_KEY=/etc/internal-tls/billing-client.key
```

`Idempotency-Key` is optional for compatibility, but should be sent by clients.
When present, the key is scoped to caller and operation. The same caller, key,
and payload is a safe retry; the same key with a different payload or a second
checkout for the same caller/order with a different key returns HTTP `409`.

## Webhook Security

Webhook requests require:

```text
X-Webhook-Timestamp: <unix_timestamp>
X-Webhook-Nonce: <unique_nonce>
X-Webhook-Signature: sha256=<hex>
Message = timestamp + "." + nonce + "." + raw_body
```

The service reserves a nonce only after mTLS, timestamp freshness, and HMAC
validation pass. Replay protection uses a TTL nonce store. If the configured
store is unavailable, webhook processing fails closed.

## Authorization

Billing validates user JWTs issued by
`https://localhost:8446/realms/topic10-sme-api`, reaches Keycloak through
`https://keycloak:8443`, and calls OPA through `https://opa:8181` for selected
authorization decisions.

## Runtime

Compose starts the service with:

```text
uvicorn main:app --host 0.0.0.0 --port 8443 --ssl-certfile ... --ssl-keyfile ... --ssl-ca-certs ... --ssl-cert-reqs 2
```

Public checks should go through Kong:

```bash
curl -k https://localhost:8443/api/v1/billing/health

curl -k -X POST https://localhost:8443/api/v1/billing/checkout \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: manual-alice-1001" \
  -H "X-Correlation-ID: billing-001" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'
```
