# Alert Evidence – SSRF Attempt / 403 Spike (TV3 P0-06)

**Date:** 2026-06-18  
**Source:** Grafana Loki Alert Rule + Red Team Script  
**Link:** `docs/evidence/tv3/red-team/ssrf-egress-defense.md`

---

## Alert Rule Configuration

**File:** `observability/alerts/loki-alert-rules.yml`

```yaml
- alert: SSRFAttemptDetected
  expr: |
    count_over_time({job=~"docker|containers"} |~ "169\\.254|metadata\\.google|ssrf|blocked_url" [5m]) > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "SSRF attempt or blocked URL fetch detected"
    description: "Admin service logged a blocked SSRF attempt targeting metadata endpoint"
```

---

## Trigger Script

```bash
# Run SSRF attack script to trigger alert
bash tests/attack/ssrf-attack.sh
```

### SSRF Attack Requests & Results

| # | Request (`fetch_url`) | Expected | Actual | Verdict |
|---|----------------------|----------|--------|---------|
| 1 | `http://169.254.169.254/latest/meta-data/` | 403 | 403 | ✅ Blocked |
| 2 | `http://metadata.google.internal/` | 403 | 403 | ✅ Blocked |
| 3 | `http://localhost:8200/v1/sys/health` | 403 | 403 | ✅ Blocked |
| 4 | `http://127.0.0.1:8200/` | 403 | 403 | ✅ Blocked |
| 5 | `http://[::1]:8200/` | 403 | 403 | ✅ Blocked |
| 6 | `https://httpbin.org/get` (allowlisted test) | 200 | 200 | ✅ Allowed |

---

## Loki Query Evidence

```logql
{job=~"docker|containers"} |~ "169\\.254|ssrf|blocked_url|metadata" | json
```

### Sample Log Entry (from Admin Service)

```json
{
  "timestamp": "2026-06-18T02:15:33Z",
  "service": "admin-service",
  "level": "WARNING",
  "method": "POST",
  "path": "/api/v1/admin/maintenance",
  "status_code": 403,
  "reason": "ssrf_blocked",
  "blocked_url": "http://169.254.169.254/latest/meta-data/",
  "correlation_id": "ssrf-test-001",
  "user_id": "[REDACTED]",
  "latency_ms": 2
}
```

---

## Alert Timeline

| Time | Event |
|------|-------|
| T+0s | SSRF attack script starts |
| T+1s | Admin service rejects 5 SSRF attempts (403) |
| T+2s | Structured JSON logs written with `reason=ssrf_blocked` |
| T+60s | Loki alert rule evaluates → fires `SSRFAttemptDetected` |
| T+65s | Grafana notification sent |

**MTTD (detection):** ~60 seconds (Loki evaluation interval)  
**MTTR (response):** Immediate – requests blocked at application layer

---

## Verdict

✅ SSRF attack attempts are blocked by Admin fixed endpoint (403).  
✅ Admin vulnerable endpoint demonstrates risk (200) for comparison.  
✅ 403 responses logged in structured JSON format with `reason=ssrf_blocked`.  
✅ Loki alert rule configured to detect SSRF patterns within 1-minute window.  
✅ Egress control blocks metadata IPs: `169.254.169.254`, `metadata.google.internal`, localhost.  
✅ No sensitive data (tokens, secrets) exposed in alert or log evidence.
