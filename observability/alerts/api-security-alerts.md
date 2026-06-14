# API Security Alert Rules (TV3)

## Alert Conditions

### Spike in HTTP 401 Unauthorized

**Trigger**: More than 10 HTTP 401 responses in a 5-minute window.  
**Cause**: Credential stuffing, brute force, or token replay.  
**Response**: Review Loki logs for source IP. Consider temporary IP block.

**LogQL Query**:
```logql
count_over_time({job="docker"} |= "\"status_code\":401" [5m]) > 10
```

---

### Spike in HTTP 403 Forbidden

**Trigger**: More than 10 HTTP 403 responses in 5 minutes.  
**Cause**: Authorization abuse, BOLA attempts, privilege escalation.

**LogQL Query**:
```logql
count_over_time({job="docker"} |= "\"status_code\":403" [5m]) > 10
```

---

### Rate Limit 429 Triggered

**Trigger**: More than 5 HTTP 429 responses in 5 minutes.  
**Cause**: DoS attempt, rate abuse, fuzzing tool.

**LogQL Query**:
```logql
count_over_time({job="docker"} |= "\"status_code\":429" [5m]) > 5
```

---

### BOLA Attempt

**Trigger**: Any log entry with `event_type: bola_attempt`.  
**Severity**: Critical.  
**Cause**: User attempting to access another user's resource via the vulnerable endpoint.

**LogQL Query**:
```logql
count_over_time({event_type="bola_attempt"} [5m]) > 0
```

---

### SSRF Blocked

**Trigger**: Any log entry with `event_type: ssrf_blocked`.  
**Severity**: Critical.  
**Cause**: Server-Side Request Forgery attempt targeting internal metadata.

**LogQL Query**:
```logql
count_over_time({event_type="ssrf_blocked"} [5m]) > 0
```

---

### Webhook Invalid Signature

**Trigger**: Any log entry with `event_type: webhook_invalid_signature`.  
**Cause**: Forged webhook or misconfigured sender.

**LogQL Query**:
```logql
count_over_time({event_type="webhook_invalid_signature"} [5m]) > 0
```

---

### Webhook Replay Detected

**Trigger**: Any log entry with `event_type: webhook_replay_detected`.  
**Cause**: Replay attack using previously seen nonce or expired timestamp.

**LogQL Query**:
```logql
count_over_time({event_type="webhook_replay_detected"} [5m]) > 0
```

---

## Implementation Status

| Alert | LogQL Defined | Grafana Alert Configured | Status |
|-------|--------------|--------------------------|--------|
| HTTP 401 spike | ✅ | Requires Grafana alerting setup | Design |
| HTTP 403 spike | ✅ | Requires Grafana alerting setup | Design |
| Rate limit 429 | ✅ | Requires Grafana alerting setup | Design |
| BOLA attempt   | ✅ | Requires Grafana alerting setup | Design |
| SSRF blocked   | ✅ | Requires Grafana alerting setup | Design |
| Webhook invalid | ✅ | Requires Grafana alerting setup | Design |
| Webhook replay  | ✅ | Requires Grafana alerting setup | Design |

Full Grafana alert provisioning requires Alertmanager configuration (beyond prototype scope).
LogQL queries are ready for dashboard panels and manual alerting.
