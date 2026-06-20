# Webhook HMAC and Replay Protection

## Canonical format

Required headers:

- `X-Webhook-Timestamp`: Unix timestamp in seconds.
- `X-Webhook-Nonce`: cryptographically random unique value.
- `X-Webhook-Signature`: `sha256=<lowercase hex digest>`.

The exact bytes signed are:

```text
timestamp + "." + nonce + "." + raw_body
```

The signature is `HMAC-SHA256(secret, signed_bytes)`. Verification must use the
raw body before JSON parsing and a constant-time comparison.

## Receiver decision order

1. Reject missing timestamp, nonce, or signature with `HTTP 401`.
2. Parse the timestamp and reject values outside a 300-second window with
   `HTTP 403`.
3. Compute HMAC over the exact raw body and reject invalid signatures with
   `HTTP 401`.
4. Atomically store nonce with TTL greater than the timestamp window; reject
   an existing nonce with `HTTP 403`.
5. Parse and validate the event schema, then process idempotently by event ID.

Nonce state must be shared (for example Redis) when multiple backend replicas
receive webhooks. The secret must come from Vault/KMS or a secret manager and
support overlap during rotation.

## Responsibility boundary

Kong checks required header presence, enforces the webhook mTLS channel, and
limits/filters requests. The default Compose stack routes the production-shaped
lab path to Billing's `/api/v1/webhooks/payment` receiver, which verifies HMAC,
timestamp age, event schema, and Redis-backed nonce replay protection.

The `demo/webhook/receiver.py` service remains a small standalone PoC for local
experiments, not the authoritative final regression path. Production should use
a managed/shared TTL store such as Redis/ElastiCache/Cloud Memorystore or a
database table with TTL semantics.

```bash
bash demo/webhook/send-valid-webhook.sh
bash demo/webhook/send-invalid-signature.sh
bash demo/webhook/send-replay-webhook.sh
```

Load `WEBHOOK_SECRET` from the ignored lab `infra/.env` or from a real secret
manager before running valid webhook sender scripts. The sender scripts do not
embed a usable shared secret.
