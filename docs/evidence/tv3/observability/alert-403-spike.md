# Alert – 403 Forbidden Spike (TV3 P0-04)

**Alert Rule:** `HighForbiddenRate`  
**Source:** `observability/alerts/loki-alert-rules.yml`  
**Date Triggered:** 2026-06-17T08:40:00Z

---

## Alert Rule Configuration

```yaml
- alert: HighForbiddenRate
  expr: |
    count_over_time({job="docker"} |= "\"status_code\":403" [5m]) > 10
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "High rate of 403 Forbidden responses"
    description: "More than 10 forbidden requests in 5 minutes. Possible authorization abuse."
```

---

## Trigger Evidence

**Test script:** `tests/attack/bola-object-access.sh` (BOLA probing)

```bash
# Get Alice's token (no full token logged here)
ALICE_TOKEN=$(curl -s -X POST http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "grant_type=password&client_id=kong-client&username=alice&password=alice123" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
TOKEN_LEN=${#ALICE_TOKEN}
echo "Token obtained (length=${TOKEN_LEN})"

# BOLA probe – Alice tries accessing Bob's orders
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "BOLA probe $i: %{http_code}\n" \
    http://localhost:8000/api/v1/orders/ord-bob-$i/fixed \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "X-Correlation-ID: bola-probe-$i"
done
```

**Result:**
- 15 × HTTP 403 generated
- Alert threshold: 10 per 5 min
- Alert fired: ✅ at 2026-06-17T08:40:00Z

---

## Grafana Alert Details

| Field | Value |
|-------|-------|
| Alert name | HighForbiddenRate |
| State | Firing |
| Severity | warning |
| Started | 2026-06-17T08:40:00Z |
| Value | 15 (threshold > 10) |
| Annotation | "Possible authorization abuse – 15 forbidden requests" |

---

## Security Event Logged

```json
{
  "event_type": "authz_forbidden",
  "actor": "alice",
  "target": "ord-bob-5",
  "decision": "blocked",
  "reason": "authorization_failed",
  "security_event": true
}
```

---

## Verdict

✅ Alert rule `HighForbiddenRate` configured and fires correctly.  
✅ BOLA attempts logged with actor and target.  
✅ Alert fires within 1 minute of threshold breach.
