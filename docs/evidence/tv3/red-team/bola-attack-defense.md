# Red Team – BOLA Attack & Defense Evidence (TV3 P0-05)

**Date:** 2026-06-17  
**Script:** `tests/attack/bola-object-access.sh`  
**Scenario:** Alice attempts to access Bob's orders (cross-user access)

---

## Attack Scenarios

### Prerequisites

```bash
# Get tokens (length only logged – no full tokens)
ALICE_TOKEN=$(bash demo/auth/get-user-token.sh alice 2>/dev/null)
BOB_TOKEN=$(bash demo/auth/get-user-token.sh bob 2>/dev/null)
echo "Alice token length: ${#ALICE_TOKEN}"
echo "Bob token length:   ${#BOB_TOKEN}"
```

---

### Scenario 1: BOLA – Vulnerable Endpoint (Demo of Flaw)

**Command:**
```bash
curl -v http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable \
  -H "Authorization: Bearer [ALICE_TOKEN]" \
  -H "X-Correlation-ID: bola-demo-001"
```

**Expected:** HTTP 200 (intentional BOLA flaw for demonstration)  
**Actual:** HTTP 200  
**Result:** ✅ BOLA flaw confirmed on vulnerable endpoint  

**Log entry (BOLA attempt logged):**
```json
{
  "event_type": "bola_attempt",
  "actor": "alice",
  "target": "ord-bob-2001",
  "endpoint": "/api/v1/orders/ord-bob-2001/vulnerable",
  "decision": "allowed (vulnerable endpoint - demo only)",
  "security_event": true
}
```

---

### Scenario 2: BOLA – Fixed Endpoint (Defense)

**Command:**
```bash
curl -v http://localhost:8000/api/v1/orders/ord-bob-2001/fixed \
  -H "Authorization: Bearer [ALICE_TOKEN]" \
  -H "X-Correlation-ID: bola-defense-001"
```

**Expected:** HTTP 403  
**Actual:** HTTP 403  
**Result:** ✅ BOLA BLOCKED by ownership check  

**Response body:**
```json
{
  "detail": "Forbidden: you do not own this order",
  "correlation_id": "bola-defense-001"
}
```

**Log entry:**
```json
{
  "event_type": "authz_forbidden",
  "actor": "alice",
  "target": "ord-bob-2001",
  "decision": "blocked",
  "reason": "authorization_failed – owner mismatch",
  "security_event": true,
  "correlation_id": "bola-defense-001"
}
```

---

### Scenario 3: Legitimate Access (Owner Allowed)

**Command:**
```bash
curl -v http://localhost:8000/api/v1/orders/ord-bob-2001/fixed \
  -H "Authorization: Bearer [BOB_TOKEN]" \
  -H "X-Correlation-ID: bola-legit-001"
```

**Expected:** HTTP 200  
**Actual:** HTTP 200  
**Result:** ✅ Legitimate owner allowed  

---

### Scenario 4: BOLA via Billing Checkout

**Command:**
```bash
curl -v -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Authorization: Bearer [ALICE_TOKEN]" \
  -H "X-Correlation-ID: bola-billing-001" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"ord-bob-2001"}'
```

**Expected:** HTTP 403  
**Actual:** HTTP 403  
**Result:** ✅ Billing BOLA blocked (Billing calls Order ownership verification)  

---

### Scenario 5: No Token

**Command:**
```bash
curl -v http://localhost:8000/api/v1/orders/ord-bob-2001/fixed \
  -H "X-Correlation-ID: bola-noauth-001"
```

**Expected:** HTTP 401  
**Actual:** HTTP 401  
**Result:** ✅ Unauthenticated blocked  

---

## Summary

| Scenario | Expected | Actual | Result |
|---------|---------|--------|--------|
| Alice → Bob's order (vulnerable) | 200 | 200 | ✅ Flaw demonstrated |
| Alice → Bob's order (fixed) | 403 | 403 | ✅ BOLA blocked |
| Bob → Bob's order (fixed) | 200 | 200 | ✅ Owner allowed |
| Alice → Bob's order via Billing | 403 | 403 | ✅ S2S BOLA blocked |
| No token → fixed endpoint | 401 | 401 | ✅ Unauthenticated blocked |

---

## Alert Mapping

BOLA attempts → `HighForbiddenRate` alert fires after 10+ 403s in 5 min.  
See: `docs/evidence/tv3/observability/alert-403-spike.md`

---

## Verdict

✅ BOLA defense working on Order fixed endpoint.  
✅ Billing-to-Order S2S ownership check prevents cross-user checkout.  
✅ All BOLA attempts logged with actor/target/correlation_id.  
✅ No sensitive data (token, secret) in evidence.  
**Script:** `ALICE_TOKEN=<token> BOB_TOKEN=<token> bash tests/attack/bola-object-access.sh`
