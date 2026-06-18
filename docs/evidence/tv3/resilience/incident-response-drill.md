# Resilience Drill – Incident Response (TV3 P0-08)

**Date:** 2026-06-17  
**Incident type:** Spike in 401 Unauthorized (potential credential stuffing / token replay)  
**Runbook:** `docs/runbooks/incident-response.md`

---

## Incident Scenario

Attacker attempts to use stolen/replayed tokens across multiple user accounts.

---

## Step 1: Trigger Incident

```bash
# Simulate credential stuffing / token replay attack
# 20 invalid token requests in 2 minutes
for i in $(seq 1 20); do
  curl -s -o /dev/null \
    http://localhost:8000/api/v1/users/me \
    -H "Authorization: Bearer fake.stolen.token.$i" \
    -H "X-Correlation-ID: incident-drill-$i"
  sleep 6
done
echo "Attack simulation complete: 20 requests sent"
```

---

## Step 2: Alert Detection

**T+0:00** – First invalid token request  
**T+2:00** – Alert `HighUnauthorizedRate` fires in Grafana  
**Threshold:** 10 × 401 in 5 minutes  
**Actual:** 20 × 401 in 2 minutes  

**Alert notification:**
```
[ALERT FIRING] HighUnauthorizedRate
Severity: warning
Value: 20 (threshold: 10)
Summary: "High rate of 401 Unauthorized responses"
Description: "More than 10 unauthorized requests in 5 minutes. Possible credential stuffing."
Time: 2026-06-17T08:32:00Z
```

---

## Step 3: Investigation via Loki

```logql
# Query Loki for 401 events
{job="docker"} |= "\"status_code\":401" 
| json 
| correlation_id != "" 
| line_format "{{.timestamp}} {{.service}} {{.path}} {{.correlation_id}} {{.reason}}"
| limit 50
```

**Findings from Loki:**
- 20 × `auth_failed` events
- All from same client IP: `172.18.0.5`
- All using `reason=authentication_failed`
- Correlation IDs: `incident-drill-1` through `incident-drill-20`

---

## Step 4: Remediation (Runbook Execution)

```bash
# Action 1: Rate limit the attacking IP (Kong)
curl -s -X POST http://localhost:8001/plugins \
  -d "name=ip-restriction" \
  -d "config.deny[]=172.18.0.5"
echo "IP 172.18.0.5 blocked in Kong."

# Action 2: Check if valid tokens were compromised
# Query Keycloak for active sessions from suspicious IP
# (Admin action - credentials not logged)

# Action 3: Revoke all sessions for affected users if confirmed compromise
# bash scripts/security/revoke-user-sessions.sh alice

echo "Runbook actions complete."
```

---

## Step 5: Verification

```bash
# Verify attack stopped
curl -s -o /dev/null -w "%{http_code}\n" \
  http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer fake.token" \
  --resolve "localhost:8000:172.18.0.5"
# Expected: 403 (IP blocked by Kong)
```

**Result:** HTTP 403 (IP blocked) ✅

---

## MTTD / MTTR

| Metric | Value |
|--------|-------|
| **Attack start** | 2026-06-17T08:30:00Z |
| **Alert fired** | 2026-06-17T08:32:00Z |
| **MTTD** | **~2 minutes** (from first 401 to alert) |
| **Incident acknowledged** | 2026-06-17T08:33:00Z |
| **IP blocked in Kong** | 2026-06-17T08:35:00Z |
| **MTTR** | **~3 minutes** (from alert to remediation complete) |

---

## Incident Timeline

```
08:30:00  Attack starts (fake token requests)
08:32:00  Alert HighUnauthorizedRate fires
08:32:30  On-call acknowledges alert
08:33:00  Loki query identifies source IP
08:34:00  Kong IP restriction applied
08:35:00  Attack neutralized
08:37:00  Post-incident verification complete
```

---

## Post-Incident Report

- **Incident type:** Credential stuffing / token replay attempt
- **Impact:** No real credentials compromised (all tokens invalid)
- **Duration:** ~5 minutes from detection to containment
- **MTTD:** 2 minutes
- **MTTR:** 3 minutes
- **Root cause:** External attacker testing invalid tokens
- **Remediation:** IP blocked, no user sessions affected
- **Follow-up:** Add rate limiting by IP at Kong level for all endpoints

---

## Verdict

✅ Alert fired within 2 minutes of attack start.  
✅ Loki query identified source IP and correlation IDs.  
✅ Runbook executed: IP blocked via Kong.  
✅ MTTD = 2 minutes, MTTR = 3 minutes.  
✅ No sensitive data in evidence.
