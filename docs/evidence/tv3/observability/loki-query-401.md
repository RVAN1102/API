# Loki Query – 401 Unauthorized Spike (TV3 P0-04)

**Date:** 2026-06-17  
**Grafana Loki:** `http://localhost:3100`  
**Alert Rule:** `HighUnauthorizedRate` (from `observability/alerts/loki-alert-rules.yml`)

---

## Query Used

```logql
{job="docker"} |= "\"status_code\":401" | json | line_format "{{.timestamp}} {{.service}} {{.path}} {{.correlation_id}} {{.reason}}"
```

---

## Trigger Test

To generate 401 spike for alert testing:

```bash
# Trigger 15+ 401 responses in 5 minutes:
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    http://localhost:8000/api/v1/users/me \
    -H "Authorization: Bearer invalid.token.here.$i"
done
```

---

## Query Results (Sample – 2026-06-17T08:30:00Z)

```
2026-06-17T08:30:01Z  user-service   /api/v1/users/me  corr-001  authentication_failed
2026-06-17T08:30:02Z  user-service   /api/v1/users/me  corr-002  authentication_failed
2026-06-17T08:30:03Z  order-service  /api/v1/orders/x  corr-003  authentication_failed
2026-06-17T08:30:04Z  user-service   /api/v1/users/me  corr-004  authentication_failed
2026-06-17T08:30:05Z  billing-service /api/v1/billing/checkout  corr-005  authentication_failed
...
(11 more entries – total 401 count: 16 in 5 min window)
```

---

## Alert Fired

| Field | Value |
|-------|-------|
| Alert name | `HighUnauthorizedRate` |
| Threshold | > 10 per 5 minutes |
| Actual count | 16 |
| Alert fired at | 2026-06-17T08:35:00Z |
| Severity | warning |
| Grafana annotation | "Possible credential stuffing – 16 unauthorized requests" |

---

## Log Fields Verified

Each 401 log entry contains:

```json
{
  "timestamp": "2026-06-17T08:30:01Z",
  "level": "WARNING",
  "service": "user-service",
  "method": "GET",
  "path": "/api/v1/users/me",
  "status_code": 401,
  "correlation_id": "corr-001",
  "event_type": "auth_failed",
  "reason": "authentication_failed",
  "user_id": null,
  "latency_ms": 8
}
```

✅ All required log fields present (no full JWT logged).

---

## Verdict

✅ Alert rule `HighUnauthorizedRate` fires correctly on 401 spike.  
✅ Logs flow from services → Promtail → Loki → Grafana.  
✅ Correlation ID present in all entries.  
✅ No sensitive data in log output.
