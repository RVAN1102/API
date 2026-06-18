# Red Team – Token Replay Evidence (TV3 P0-05)

**Date:** 2026-06-17  
**Script:** `tests/attack/token-replay.sh`  
**Scenarios:** JWT token replay + Webhook nonce replay

---

## Part A: JWT Token Replay

### Context

JWT tokens in this system have **TTL = 300 seconds (5 minutes)**. Token replay within the TTL window relies on:
1. **Short TTL** to minimize the replay window.
2. **Token revocation / introspection** (TV2 implementation) to actively block revoked tokens.

### Scenario A-1: Replay of Valid (Non-Expired) Token

```bash
# Step 1: Get a token
ALICE_TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "grant_type=password&client_id=kong-client&username=alice&password=alice123" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
TOKEN_LEN=${#ALICE_TOKEN}
echo "Token obtained (length=${TOKEN_LEN})"

# Step 2: Use token (should succeed)
curl -s -o /dev/null -w "First use: %{http_code}\n" \
  http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Correlation-ID: token-replay-001"

# Step 3: Replay the same token immediately (should succeed while valid)
curl -s -o /dev/null -w "Replay (valid): %{http_code}\n" \
  http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Correlation-ID: token-replay-002"
```

**Expected:** Both 200 (token still valid within TTL)  
**Actual:** HTTP 200, HTTP 200  
**Defense:** TTL=300s limits replay window. For stronger defense, token introspection (TV2) checks revocation.

---

### Scenario A-2: Replay of Expired Token

```bash
# After token expires (> 300 seconds):
sleep 305

curl -s -o /dev/null -w "Expired token replay: %{http_code}\n" \
  http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer $OLD_ALICE_TOKEN" \
  -H "X-Correlation-ID: token-replay-003"
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Expired token rejected by Keycloak/Kong JWT verification  

**Log entry:**
```json
{
  "event_type": "auth_failed",
  "reason": "token_expired",
  "correlation_id": "token-replay-003",
  "security_event": true
}
```

---

### Scenario A-3: Replay of Deliberately Fake Token

```bash
curl -s -o /dev/null -w "Fake token: %{http_code}\n" \
  http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.ZmFrZS5wYXlsb2Fk.ZmFrZXNpZ25hdHVyZQ" \
  -H "X-Correlation-ID: token-replay-fake"
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Malformed/fake token rejected  

---

## Part B: Webhook Replay

### Scenario B-1: Replayed Nonce (Exact Same Webhook)

```bash
# Send valid webhook
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"payment.completed","order_id":"ord-alice-5001","amount":100.00}'
SIGNATURE=$(echo -n "${TIMESTAMP}.${PAYLOAD}" | openssl dgst -sha256 -hmac "test-secret" -hex | cut -d' ' -f2)

curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${SIGNATURE}" \
  -H "X-Webhook-Nonce: nonce-replay-001" \
  -d "${PAYLOAD}"
# Expected: 200 OK

# Replay the exact same request (same nonce)
curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${SIGNATURE}" \
  -H "X-Webhook-Nonce: nonce-replay-001" \
  -d "${PAYLOAD}"
# Expected: 401 (replayed nonce)
```

**First request:** HTTP 200 ✅  
**Replay (same nonce):** HTTP 401 ✅ – **Webhook replay blocked**  

**Log entry:**
```json
{
  "event_type": "webhook_replay_detected",
  "nonce": "nonce-replay-001",
  "decision": "blocked",
  "reason": "nonce_already_used",
  "security_event": true
}
```

---

### Scenario B-2: Expired Timestamp Replay

```bash
OLD_TIMESTAMP=$(($(date +%s) - 400))  # 400 seconds ago (> 300s window)
PAYLOAD='{"event":"payment.completed","order_id":"ord-alice-5001"}'
OLD_SIG=$(echo -n "${OLD_TIMESTAMP}.${PAYLOAD}" | openssl dgst -sha256 -hmac "test-secret" -hex | cut -d' ' -f2)

curl -v -X POST http://localhost:8000/api/v1/auth/webhook \
  -H "X-Webhook-Timestamp: ${OLD_TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${OLD_SIG}" \
  -H "X-Webhook-Nonce: nonce-old-002" \
  -d "${PAYLOAD}"
```

**Expected:** HTTP 401 (timestamp too old)  
**Actual:** HTTP 401  
**Result:** ✅ Old timestamp replay blocked  

---

## Summary

| Scenario | Expected | Actual | Result |
|---------|---------|--------|--------|
| Valid token – first use | 200 | 200 | ✅ Accepted |
| Valid token – replay (in TTL) | 200 | 200 | ℹ️ Accepted (TTL defense) |
| Expired token replay | 401 | 401 | ✅ Blocked |
| Fake/malformed token | 401 | 401 | ✅ Blocked |
| Webhook – replayed nonce | 401 | 401 | ✅ Blocked |
| Webhook – expired timestamp | 401 | 401 | ✅ Blocked |

---

## Defense Layers

| Defense | Implementation |
|---------|---------------|
| Short JWT TTL | 300s (Kong JWT plugin) |
| JWT signature verification | Kong JWT plugin + Keycloak public key |
| Token revocation | Keycloak session disable + introspection (TV2) |
| Webhook nonce | In-memory nonce store (TTL > 300s) |
| Webhook timestamp | ±300s window check |
| Webhook HMAC | SHA-256 HMAC verification |

---

## Verdict

✅ JWT replay: expired tokens blocked.  
✅ Fake tokens: malformed JWT rejected.  
✅ Webhook nonce replay: blocked.  
✅ Webhook timestamp replay: blocked.  
✅ No full token in evidence (length only).
