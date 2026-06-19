# Webhook Persistent Nonce Store

## Summary

The lab Docker Compose stack now uses Redis as the default webhook replay nonce
store for `POST /api/v1/webhooks/payment`.

| Item | Value |
|---|---|
| Store | Redis |
| Compose service | `redis` |
| Billing env | `WEBHOOK_NONCE_STORE=redis` |
| Redis URL | `WEBHOOK_NONCE_REDIS_URL=redis://redis:6379/0` |
| TTL | `WEBHOOK_NONCE_TTL_SECONDS=300` |
| Key namespace | `webhook:nonce:<sha256(nonce)>` |

## Security Behavior

- HMAC signature validation remains required.
- Timestamp freshness remains required.
- Nonce reservation happens only after mTLS, timestamp freshness, and HMAC
  validation pass.
- Redis uses atomic `SET key 1 NX EX <ttl>` to reserve the nonce.
- If the atomic set fails because the key already exists, the webhook is
  rejected as replay with HTTP 403.
- If Redis is unavailable or misconfigured, the webhook fails closed and is not
  accepted.
- No raw webhook body, HMAC signature, or webhook secret is stored in Redis.

## Scope And Limitation

This protects against replay within the configured timestamp freshness and nonce
TTL window. It does not claim replay prevention after both the timestamp window
and Redis TTL have expired.

`WEBHOOK_NONCE_STORE=memory` exists only as an explicit local-development
fallback. It is not the default for lab Docker Compose or final regression.

## Test Command

```bash
bash tests/security/webhook-tests.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

The persistence test sends a valid webhook, restarts `billing-service`, and then
resends the same timestamp/nonce/body/signature. The replay must still return
HTTP 403 while the Redis TTL is active. It also stops Redis temporarily and
verifies the handler fails closed instead of accepting the webhook.

## Production Recommendation

Use managed Redis/ElastiCache/Cloud Memorystore, or another shared data store
with atomic insert-if-absent and TTL semantics. Production deployments should
enable authentication/TLS where applicable, monitoring, backup/recovery for
configuration, and alerting on nonce-store errors.
