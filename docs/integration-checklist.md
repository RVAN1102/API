# Integration Checklist

## TV1 ↔ TV2

- [x] Gateway routes `/api/v1/users` → user-service:8000
- [x] Gateway routes `/api/v1/orders` → order-service:8000
- [x] `Authorization` header passes through Kong
- [x] `X-Correlation-ID` header passes through Kong
- [x] CORS allows Authorization header
- [x] Rate limit 10/min on /users and /orders routes
- [x] Webhook HMAC contract documented in `gateway/webhook-security.md`

## TV2 ↔ TV3

- [x] JWT realm/roles contract defined in `idp/jwt-claims.md`
- [x] Test user alice/bob/admin01 defined in Keycloak realm
- [x] Order sample data: ord-alice-1001, ord-alice-1002, ord-bob-2001, ord-bob-2002
- [x] BOLA vulnerable endpoint: GET /api/v1/orders/{orderId}/vulnerable
- [x] BOLA fixed endpoint: GET /api/v1/orders/{orderId}/fixed
- [x] Vault webhook secret path: secret/data/api/webhook
- [x] Service client ID: sme-service-client

## TV1 ↔ TV3

- [x] Gateway routes `/api/v1/billing` → billing-service:8000
- [x] Gateway routes `/api/v1/admin` → admin-service:8000
- [x] Gateway routes `/api/v1/webhooks` → webhook-demo:8080
- [x] Webhook HMAC format: `timestamp.nonce.raw_body` HMAC-SHA256
- [x] Webhook secret env var: WEBHOOK_SECRET
- [x] Rate limit on /admin route: 10/min

## TV3 Observability

- [x] Log schema defined in `observability/log-schema.md`
- [x] Event types: bola_attempt, ssrf_blocked, ssrf_attempt, webhook_invalid_signature, webhook_replay_detected
- [x] Loki/Promtail/Grafana stack configured in Docker Compose
- [x] Alert rules defined in `observability/alerts/`
