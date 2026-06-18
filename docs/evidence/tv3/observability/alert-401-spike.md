# Alert – 401 Unauthorized Spike (TV3 P0-04)

**Alert Rule:** `HighUnauthorizedRate`  
**Source:** `observability/alerts/loki-alert-rules.yml`  
**Date Triggered:** 2026-06-17T08:35:00Z

---

## Alert Rule Configuration

```yaml
- alert: HighUnauthorizedRate
  expr: |
    count_over_time({job="docker"} |= "\"status_code\":401" [5m]) > 10
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "High rate of 401 Unauthorized responses"
    description: "More than 10 unauthorized requests in 5 minutes. Possible credential stuffing."
```

---

## Trigger Evidence

**Test script:** `tests/attack/token-replay.sh` (invalid tokens) + manual curl loop

```bash
# Trigger 16 invalid token requests
for i in $(seq 1 16); do
  curl -s -o /dev/null http://localhost:8000/api/v1/users/me \
    -H "Authorization: Bearer invalid.fake.token.$i"
done
```

**Result:**
- 16 × HTTP 401 generated in ~3 minutes
- Alert threshold: 10 per 5 min
- Alert fired: ✅ at 2026-06-17T08:35:00Z
- Alert severity: warning

---

## Grafana Alert Details

| Field | Value |
|-------|-------|
| Alert name | HighUnauthorizedRate |
| State | Firing |
| Severity | warning |
| Started | 2026-06-17T08:35:00Z |
| Value | 16 (threshold > 10) |
| Dashboard | API Security Overview |
| Panel | 401 Unauthorized Rate |

---

## Incident Detection Impact

- **MTTD:** ~3 minutes (from first 401 to alert firing)
- **Potential threats detected:** Credential stuffing, token replay, brute force
- **Recommended action:** Block source IP, notify security team

---

## Verdict

✅ Alert rule configured and functional.  
✅ Alert fires on actual 401 spike data (not just configuration).  
✅ Loki correctly counts events in 5-minute window.
