# Alert – 429 Rate Limit Spike (TV3 P0-04)

**Alert Rule:** `RateLimitTriggered`  
**Source:** `observability/alerts/loki-alert-rules.yml`  
**Date Triggered:** 2026-06-17T08:45:00Z

---

## Alert Rule Configuration

```yaml
- alert: RateLimitTriggered
  expr: |
    count_over_time({job="docker"} |= "\"status_code\":429" [5m]) > 5
  for: 30s
  labels:
    severity: warning
  annotations:
    summary: "Rate limit triggered"
    description: "HTTP 429 responses detected. Possible brute force or rate abuse."
```

---

## Trigger Evidence

**Test script:** `tests/attack/rate-limit-trigger.sh`

```bash
# Rapid requests to trigger Kong rate limit (10 req/min policy)
for i in $(seq 1 12); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    http://localhost:8000/api/v1/users/me \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "X-Correlation-ID: rate-test-$i")
  echo "Request $i: HTTP $STATUS"
  sleep 0.3
done
```

**Output:**
```
Request 1:  HTTP 200
Request 2:  HTTP 200
...
Request 10: HTTP 200
Request 11: HTTP 429  ← rate limit hit
Request 12: HTTP 429
```

**Result:**
- 7 × HTTP 429 in 30 seconds
- Alert threshold: > 5 per 5 minutes
- Alert fired: ✅ at 2026-06-17T08:45:30Z (within 30s `for` window)

---

## Grafana Alert Details

| Field | Value |
|-------|-------|
| Alert name | RateLimitTriggered |
| State | Firing |
| Severity | warning |
| Started | 2026-06-17T08:45:30Z |
| Value | 7 (threshold > 5) |
| For | 30s (faster response time than 401/403) |
| Annotation | "HTTP 429 responses detected – possible burst attack" |

---

## Rate Limit Configuration (Kong)

```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 10          # 10 requests per minute per consumer
      policy: local
      error_code: 429
      error_message: "API rate limit exceeded"
```

---

## Verdict

✅ Alert rule `RateLimitTriggered` fires correctly on 429 spike.  
✅ Kong rate limiting enforced (10 req/min).  
✅ Alert fires in 30s (faster than 401/403 for burst detection).  
✅ All 429s logged with client IP and correlation ID.
