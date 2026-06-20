# Runbook – Incident Response

**Version:** 1.0  
**Maintainer:** Security/operations reviewer
**Last updated:** 2026-06-17  
**Purpose:** Step-by-step incident response for API security events

---

## Scope

This runbook covers:
1. Spike in 401 Unauthorized (credential stuffing, token replay)
2. Spike in 403 Forbidden (BOLA probing, unauthorized access)
3. SSRF attempt
4. Webhook forgery / replay
5. Leaked token simulation

---

## Incident Types & Signs

| Type | Alert | Signs |
|------|-------|-------|
| Credential stuffing | `HighUnauthorizedRate` | >10 × 401/5min, same endpoint, multiple IPs |
| Token replay | `HighUnauthorizedRate` | >10 × 401/5min, `reason=token_expired` or `reason=token_revoked` |
| BOLA probe | `HighForbiddenRate` | >10 × 403/5min, pattern: different `target` order IDs |
| Rate limit abuse | `RateLimitTriggered` | >5 × 429/5min, same IP |
| SSRF attempt | `SSRFAttempt` | `event_type=ssrf_blocked` or `ssrf_attempt` in logs |
| Webhook forgery | `WebhookInvalidSignature` | `event_type=webhook_invalid_signature` |
| Webhook replay | `WebhookReplayDetected` | `event_type=webhook_replay_detected` |

---

## Response Procedure

### Step 1: Acknowledge Alert

```bash
# Check Grafana alerts (http://localhost:3000/alerting/list)
# Or Loki:
{job="docker"} |= "security_event" | json | line_format "{{.timestamp}} {{.event_type}} {{.actor}} {{.correlation_id}}"
```

Record: alert type, time fired, current count.

---

### Step 2: Identify Source

```bash
# Find source IP and correlation IDs for the incident:
{job="docker"} |= "\"status_code\":401" | json 
| line_format "{{.timestamp}} {{.client_ip}} {{.correlation_id}} {{.reason}}"

# For BOLA – find actor:
{job="docker"} |= "authz_forbidden" | json 
| line_format "{{.timestamp}} {{.actor}} {{.target}} {{.correlation_id}}"

# For rate limit – find IP:
{job="docker"} |= "\"status_code\":429" | json 
| line_format "{{.timestamp}} {{.client_ip}} {{.correlation_id}}"
```

---

### Step 3: Isolate / Contain

#### Block IP (Rate limit / credential stuffing):
```bash
# Block attacking IP in Kong
ATTACK_IP="<source_ip>"
curl -s -X POST http://localhost:8001/plugins \
  -d "name=ip-restriction" \
  -d "config.deny[]=${ATTACK_IP}"
echo "IP ${ATTACK_IP} blocked."
```

#### Revoke compromised user session (BOLA / leaked token):
```bash
# Get user UUID from Keycloak
# Revoke all sessions for that user
curl -s -X DELETE \
  "http://localhost:8080/admin/realms/myrealm/users/[USER_UUID]/sessions" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
echo "All sessions revoked for user [USER_UUID]."
```

#### Rotate webhook secret (webhook forgery):
```bash
# See: docs/runbooks/key-rotation.md
bash scripts/security/cosign-sign.sh evidence
```

---

### Step 4: Verify Mitigation

```bash
# Verify no more 401 from attack IP:
{job="docker"} |= "172.18.0.5" |= "401" | count_over_time [2m]
# Expected: 0 after IP block

# Verify legitimate users still work:
curl -s -o /dev/null -w "%{http_code}\n" \
  https://localhost:8443/api/v1/users/me \
  -H "Authorization: Bearer $LEGIT_USER_TOKEN"
# Expected: 200
```

---

### Step 5: Record MTTD and MTTR

```bash
ATTACK_START="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"  # from alert timestamp
ALERT_FIRED="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"    # from Grafana
REMEDIATION_DONE="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

MTTD_SEC=$(( $(date -d "$ALERT_FIRED" +%s) - $(date -d "$ATTACK_START" +%s) ))
MTTR_SEC=$(( $(date -d "$REMEDIATION_DONE" +%s) - $(date -d "$ALERT_FIRED" +%s) ))

echo "MTTD: ${MTTD_SEC}s (${MTTD_SEC}/60 min)"
echo "MTTR: ${MTTR_SEC}s (${MTTR_SEC}/60 min)"
```

---

### Step 6: Post-Incident Report

Create a markdown file: `docs/evidence/post-incident/YYYY-MM-DD-<type>.md`

Template:
```markdown
# Post-Incident Report – <Type> – <Date>

## Incident Summary
- Type:
- Start time:
- Detection time:
- Resolution time:
- MTTD:
- MTTR:

## What Happened
...

## Root Cause
...

## Impact
...

## Remediation
...

## Follow-up Actions
- [ ] Action 1
- [ ] Action 2
```

---

## Dashboards & Log Queries

| Dashboard | URL |
|-----------|-----|
| Grafana main | `http://localhost:3000` |
| Alert list | `http://localhost:3000/alerting/list` |
| Loki Explorer | `http://localhost:3000/explore` |
| Jaeger traces | `http://localhost:16686` |

---

## Contact

| Role | Contact |
|------|---------|
| Security Lead | Assigned during demo/review |
| Identity/Auth Lead | Assigned during demo/review |
| Edge/Infrastructure Lead | Assigned during demo/review |
| GVHD | [Lecturer] |

---

## Checklist

- [ ] Alert acknowledged within 5 minutes
- [ ] Source IP/actor identified
- [ ] Isolation action taken (IP block / session revoke)
- [ ] Legitimate users verified unaffected
- [ ] MTTD recorded
- [ ] MTTR recorded
- [ ] Post-incident report filed
- [ ] Follow-up actions assigned
