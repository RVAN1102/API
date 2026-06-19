# KMS / Vault Call Overhead (TV3 P1-01)

**Date:** 2026-06-17  
**Tool:** `time` command + curl + Python timing  
**Target:** Vault OSS (local Docker) – `http://localhost:8200`  
**Note:** Lab uses Vault OSS; production would use AWS KMS / GCP KMS / Azure Key Vault

---

## Measurement Commands

### 1. Vault Secret Read Latency

```bash
# Measure time to read a secret from Vault
VAULT_TOKEN="[VAULT_TOKEN_REDACTED]"
VAULT_ADDR="http://localhost:8200"

for i in $(seq 1 10); do
  START=$(python3 -c "import time; print(int(time.time()*1000))")
  curl -s -o /dev/null \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/secret/data/webhook"
  END=$(python3 -c "import time; print(int(time.time()*1000))")
  echo "Run $i: $((END - START))ms"
done
```

**Results (10 runs):**
```
Run 1:  12ms
Run 2:  8ms
Run 3:  9ms
Run 4:  11ms
Run 5:  8ms
Run 6:  10ms
Run 7:  9ms
Run 8:  12ms
Run 9:  8ms
Run 10: 10ms
```

| Metric | Value |
|--------|-------|
| Min | 8ms |
| Max | 12ms |
| **Average** | **9.7ms** |
| **p50** | **9.5ms** |
| **p95** | **12ms** |

---

### 2. Prototype Startup And Proposed Secret-Fetch Budget

```bash
# Measure service restart time in the lab Compose stack
time docker compose -f infra/docker-compose.yml restart billing-service
```

**Result:**
```
real    0m4.831s
user    0m0.215s
sys     0m0.089s
```

Interpretation:
- Docker container restart and readiness dominate this lab measurement.
- The Vault read latency above is a separate manual measurement that estimates
  the budget for a production startup secret read.
- Current lab services receive runtime secrets from Docker Compose environment
  variables generated in ignored `infra/.env`; this file does not claim Billing
  or Webhook currently fetches `WEBHOOK_SECRET` directly from Vault.
- Keycloak public key fetch/caching remains part of runtime token validation.

---

### 3. Per-Request Secret Access (Token Validation)

JWT validation via Keycloak/Kong does NOT call Vault per-request. The JWT is validated locally using the cached Keycloak public key.

In this prototype, Vault is not on the hot request path. Runtime secrets are
injected by Docker Compose from the local lab environment file. Vault dev mode
is used to demonstrate secret paths, rotation workflow, and the production
architecture.

Per-request Vault overhead: **~0ms** (keys cached in memory)

---

## KMS Overhead Summary

| Operation | Tool (Lab) | Latency | Frequency |
|-----------|-----------|---------|-----------|
| Manual secret read | Vault OSS | ~9.7ms avg | Production startup/rotation budget |
| Service restart | Docker Compose | ~4.8s total | On restart |
| JWT validation | Keycloak (cached) | ~5-15ms | Per-request |
| HMAC verify | In-memory | < 1ms | Per-request |
| Per-request Vault | Not called | 0ms | — |

---

## Production KMS Comparison

| Service | Latency (typical) | Cost |
|---------|------------------|------|
| AWS KMS (Decrypt) | ~5-30ms | ~$0.03/10K calls |
| GCP Cloud KMS | ~10-50ms | ~$0.03/10K ops |
| Azure Key Vault | ~10-30ms | ~$0.03/10K ops |
| HashiCorp Vault OSS (lab) | ~8-12ms | $0 (self-hosted) |
| HashiCorp Vault Enterprise | ~8-15ms | ~$10K+/year |

---

## Performance Impact Assessment

- ✅ Manual Vault read latency: **~10ms** in lab, useful as a production startup/rotation budget.
- ✅ No per-request KMS calls (JWT validated locally).
- ✅ Webhook HMAC verified in-memory (< 1ms).
- ℹ️ If production moves to Cloud KMS per-request signing: expect +5-30ms per request.
- **Recommendation:** For production, use Vault HA or cloud KMS/Secrets Manager,
  inject or fetch secrets with least-privilege workload identity, cache public
  keys/secrets outside the hot path, and refresh on rotation signal.

---

## How to Reproduce

```bash
# Measure Vault latency:
for i in $(seq 1 10); do
  time curl -s -o /dev/null \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    http://localhost:8200/v1/secret/data/webhook
done
```
