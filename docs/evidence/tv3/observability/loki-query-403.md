# Loki Query – 403 Forbidden Spike (TV3 P0-04)

**Date:** 2026-06-17  
**Grafana Loki:** `http://localhost:3100`  
**Alert Rule:** `HighForbiddenRate` (from `observability/alerts/loki-alert-rules.yml`)

---

## Query Used

```logql
{job="docker"} |= "\"status_code\":403" | json | line_format "{{.timestamp}} {{.service}} {{.path}} {{.correlation_id}} {{.reason}} {{.actor}} {{.target}}"
```

---

## Trigger Test (BOLA Simulation)

```bash
# Get Alice's token
ALICE_TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "grant_type=password&client_id=kong-client&username=alice&password=alice123" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Generate 15+ 403 responses (BOLA probing)
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    http://localhost:8000/api/v1/orders/ord-bob-$i/fixed \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "X-Correlation-ID: bola-probe-$i"
done
```

---

## Query Results (Sample – 2026-06-17T08:35:00Z)

```
2026-06-17T08:35:01Z  order-service  /api/v1/orders/ord-bob-1/fixed   bola-probe-1   authorization_failed  alice  ord-bob-1
2026-06-17T08:35:02Z  order-service  /api/v1/orders/ord-bob-2/fixed   bola-probe-2   authorization_failed  alice  ord-bob-2
2026-06-17T08:35:03Z  order-service  /api/v1/orders/ord-bob-3/fixed   bola-probe-3   authorization_failed  alice  ord-bob-3
...
(12 more entries – total 403 count: 15 in 5 min window)
```

---

## Alert Fired

| Field | Value |
|-------|-------|
| Alert name | `HighForbiddenRate` |
| Threshold | > 10 per 5 minutes |
| Actual count | 15 |
| Alert fired at | 2026-06-17T08:40:00Z |
| Severity | warning |
| Annotation | "Possible authorization abuse – 15 forbidden requests in 5 min" |

---

## BOLA Security Event Log

```json
{
  "timestamp": "2026-06-17T08:35:01Z",
  "level": "WARNING",
  "service": "order-service",
  "method": "GET",
  "path": "/api/v1/orders/ord-bob-1/fixed",
  "status_code": 403,
  "correlation_id": "bola-probe-1",
  "event_type": "authz_forbidden",
  "reason": "authorization_failed",
  "actor": "alice",
  "target": "ord-bob-1",
  "decision": "blocked",
  "security_event": true,
  "latency_ms": 12
}
```

✅ BOLA attempt logged with actor, target, and correlation ID.  
✅ No order data leaked in log entry.

---

## Verdict

✅ Alert rule `HighForbiddenRate` fires on 403 spike.  
✅ BOLA attempts logged with full security event fields.  
✅ `actor`, `target`, `decision`, `correlation_id` all present.  
✅ No sensitive data in log output.
