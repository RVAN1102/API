# Structured JSON Log Schema (TV3)

## Base Fields (All API Events)

All services emit JSON logs to stdout in this format:

```json
{
  "timestamp": "2024-06-14T10:30:00Z",
  "level": "INFO",
  "service": "billing-service",
  "method": "POST",
  "path": "/api/v1/billing/checkout",
  "status_code": 202,
  "client_ip": "172.18.0.1",
  "correlation_id": "req-abc-123",
  "event_type": "api_request",
  "message": "POST /api/v1/billing/checkout → 202"
}
```

## Field Definitions

| Field          | Type   | Description                              |
|----------------|--------|------------------------------------------|
| timestamp      | string | ISO 8601 UTC timestamp                   |
| level          | string | INFO / WARNING / ERROR                   |
| service        | string | Service name (e.g., billing-service)     |
| method         | string | HTTP method                              |
| path           | string | Request path                             |
| status_code    | int    | HTTP response status code                |
| client_ip      | string | Client IP address                        |
| correlation_id | string | X-Correlation-ID header value            |
| event_type     | string | Event classification (see below)         |
| message        | string | Human-readable log message               |

## Security Event Fields (Additional)

When `security_event: true`:

```json
{
  "security_event": true,
  "actor": "alice",
  "target": "ord-bob-2001",
  "decision": "blocked",
  "reason": "invalid_signature"
}
```

## Event Types

| event_type                  | Description                              |
|-----------------------------|------------------------------------------|
| `api_request`               | Normal API request log                   |
| `auth_failed`               | JWT validation failed                    |
| `authz_forbidden`           | Authorization check failed               |
| `rate_limit_triggered`      | Request rejected by rate limiter         |
| `ssrf_attempt`              | SSRF via vulnerable endpoint             |
| `ssrf_blocked`              | SSRF blocked by fixed endpoint           |
| `webhook_invalid_signature` | Webhook HMAC verification failed         |
| `webhook_replay_detected`   | Webhook nonce/timestamp replay detected  |
| `bola_attempt`              | Cross-user order access attempted        |
| `zap_scan_finding`          | ZAP scan finding logged                  |
| `ci_security_finding`       | CI security tool finding                 |

## Security Note

**Never log**:
- Full JWT access tokens
- Passwords
- client_secret
- private keys
- webhook_secret value
