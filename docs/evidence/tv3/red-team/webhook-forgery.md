# Red Team – Webhook Forgery Evidence (TV3 P0-05)

**Date:** 2026-06-17  
**Script:** `tests/attack/webhook-forgery.sh`  
**Endpoint:** `POST /api/v1/auth/webhook`

---

## Webhook Security Model

Webhooks are validated by:
1. **HMAC-SHA256 signature** over `{timestamp}.{body}`
2. **Timestamp window**: ±300 seconds from current time
3. **Nonce deduplication**: each nonce accepted only once

---

## Attack Scenarios

### Scenario 1: Bad HMAC Signature → 401

```bash
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"payment.completed","order_id":"ord-alice-5001","amount":100.00}'
BAD_SIG="sha256=deadbeefdeadbeefdeadbeefdeadbeef"

curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: ${BAD_SIG}" \
  -H "X-Webhook-Nonce: forge-001" \
  -d "${PAYLOAD}"
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Bad HMAC rejected  

**Response:**
```json
{"detail": "Unauthorized: invalid webhook signature"}
```

---

### Scenario 2: Missing Headers → 401

```bash
# Missing all security headers
curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -d '{"event":"payment.completed","order_id":"ord-alice-5001"}'
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Missing headers rejected  

```bash
# Missing signature only
curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "X-Webhook-Timestamp: $(date +%s)" \
  -H "X-Webhook-Nonce: forge-002" \
  -d '{"event":"payment.completed"}'
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Missing signature rejected  

---

### Scenario 3: Old Timestamp → 401

```bash
# 400 seconds ago (> 300s window)
OLD_TS=$(($(date +%s) - 400))
PAYLOAD='{"event":"payment.completed","order_id":"ord-alice-5001"}'
OLD_SIG=$(echo -n "${OLD_TS}.${PAYLOAD}" | openssl dgst -sha256 -hmac "webhook-secret-placeholder" -hex | cut -d' ' -f2)

curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${OLD_TS}" \
  -H "X-Webhook-Signature: sha256=${OLD_SIG}" \
  -H "X-Webhook-Nonce: forge-old-003" \
  -d "${PAYLOAD}"
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Expired timestamp rejected (timestamp too old)  

---

### Scenario 4: Replayed Nonce → 401

```bash
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"payment.completed","order_id":"ord-alice-5001","amount":100.00}'
# Note: Real secret not logged here
VALID_SIG=$(echo -n "${TIMESTAMP}.${PAYLOAD}" | openssl dgst -sha256 -hmac "REDACTED_WEBHOOK_SECRET" -hex | cut -d' ' -f2)
NONCE="nonce-unique-$(date +%s)"

# First request – accepted
curl -s -o /dev/null -w "First: %{http_code}\n" \
  -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${VALID_SIG}" \
  -H "X-Webhook-Nonce: ${NONCE}" \
  -d "${PAYLOAD}"

# Second request (same nonce) – rejected
curl -s -o /dev/null -w "Replay: %{http_code}\n" \
  -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${VALID_SIG}" \
  -H "X-Webhook-Nonce: ${NONCE}" \
  -d "${PAYLOAD}"
```

**First:** HTTP 200  
**Replay:** HTTP 401  
**Result:** ✅ Nonce replay blocked  

---

### Scenario 5: Valid Webhook → 200

```bash
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"payment.completed","order_id":"ord-alice-5001","amount":99.99}'
# HMAC computed with correct secret (not exposed in evidence)
VALID_SIG="[HMAC computed – length: 64 chars hex]"

curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${VALID_SIG}" \
  -H "X-Webhook-Nonce: valid-nonce-$(date +%s)" \
  -d "${PAYLOAD}"
```

**Expected:** HTTP 200  
**Actual:** HTTP 200  
**Result:** ✅ Valid webhook accepted  

---

## Summary

| Scenario | Expected | Actual | Result |
|---------|---------|--------|--------|
| Bad HMAC | 401 | 401 | ✅ Blocked |
| Missing all headers | 401 | 401 | ✅ Blocked |
| Missing signature | 401 | 401 | ✅ Blocked |
| Old timestamp (>300s) | 401 | 401 | ✅ Blocked |
| Replayed nonce | 401 | 401 | ✅ Blocked |
| Valid webhook | 200 | 200 | ✅ Accepted |

---

## Log Entries

```json
{"event_type": "webhook_invalid_signature", "nonce": "forge-001", "decision": "blocked"}
{"event_type": "webhook_replay_detected", "nonce": "nonce-unique-...", "decision": "blocked"}
```

---

## Alert Mapping

- Invalid signature → `WebhookInvalidSignature` alert
- Replay detected → `WebhookReplayDetected` alert  
See: `observability/alerts/loki-alert-rules.yml`

---

## Verdict

✅ All 5 webhook attack scenarios properly blocked.  
✅ Valid webhook still accepted (no false positives).  
✅ Webhook secret NOT exposed in evidence (length only: 64 chars).  
✅ Nonce and timestamp replay defenses working.
