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

Kong checks required header presence and limits/filter requests. The local
Compose stack routes webhooks to `demo/webhook/receiver.py`, a stateful PoC
that verifies HMAC, timestamp age, event schema, and nonce replay protection.
It proves the contract without changing the Billing/Admin services owned by
other team members.

For team integration and production, the same verification belongs in the
real Billing/Admin receiver with shared nonce state such as Redis. The PoC's
in-memory nonce cache is intentionally single-instance and non-persistent.

```bash
bash demo/webhook/send-valid-webhook.sh
bash demo/webhook/send-invalid-signature.sh
bash demo/webhook/send-replay-webhook.sh
```

`WEBHOOK_SECRET` defaults to an explicit local demo value in the sender
scripts. Never reuse it outside the local demo.
