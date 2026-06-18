
## Attack Traffic

- attack_start: `2026-06-18T13:55:43Z`
- attack_statuses: `[INFO] Resetting Kong before 403 scenario to avoid rate-limit contamination
403 403 403 403 403`
- detection_threshold: `3`
# MTTD Candidate Query Diagnostics: 403

**Generated:** 2026-06-18T13:55:49Z
**Loki:** `http://localhost:3100`

## Label Evidence

- Labels API: `docs/evidence/tv3/metrics/loki-labels.json`
- Label values: `docs/evidence/tv3/metrics/loki-label-values.json`

## Candidate Results

| Selector | Pattern | Count | Selected |
|---|---|---:|---|
| `{service="order-service"}` | `"event_type": "bola_attempt"` | `0` | no |
| `{service="order-service"}` | `"event_type": "authz_forbidden"` | `0` | no |
| `{service="order-service"}` | `event_type":"bola_attempt` | `0` | no |
| `{service="order-service"}` | `event_type":"authz_forbidden` | `0` | no |
| `{service="order-service"}` | `bola_attempt` | `0` | no |
| `{service="order-service"}` | `authz_forbidden` | `0` | no |
| `{service="order-service"}` | `"status_code": 403` | `10.0` | no |

## Selected Query

- selector: `{service="order-service"}`
- pattern: `"status_code": 403`
- initial_count: `10.0`
- raw_response: `docs/evidence/tv3/metrics/403_forbidden_bola_spike-diagnostics-selected-raw.json`

```logql
sum(count_over_time({service="order-service"} |= "\"status_code\": 403" [5m]))
```

## Sample Matched Log Lines

- sample_source: `/loki/api/v1/query_range`
- sample_selector: `{service="order-service"}`
- sample_pattern: `"status_code": 403`
- sample_query: `{service="order-service"} |= "\"status_code\": 403"`
- raw_sample_response: `docs/evidence/tv3/metrics/403_forbidden_bola_spike-diagnostics-matched-samples.json`

```json
[
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"WARNING\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-5\", \"event_type\": \"auth_failure\", \"reason\": \"ownership_denied\", \"category\": \"ownership_denied\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"WARNING\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-4\", \"event_type\": \"auth_failure\", \"reason\": \"ownership_denied\", \"category\": \"ownership_denied\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"WARNING\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-3\", \"event_type\": \"auth_failure\", \"reason\": \"ownership_denied\", \"category\": \"ownership_denied\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"WARNING\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-2\", \"event_type\": \"auth_failure\", \"reason\": \"ownership_denied\", \"category\": \"ownership_denied\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"WARNING\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-1\", \"event_type\": \"auth_failure\", \"reason\": \"ownership_denied\", \"category\": \"ownership_denied\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"INFO\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-5\", \"event_type\": \"api_request\"}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"INFO\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-4\", \"event_type\": \"api_request\"}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"INFO\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-3\", \"event_type\": \"api_request\"}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"INFO\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-2\", \"event_type\": \"api_request\"}",
  "{\"timestamp\": \"2026-06-18T13:55:49Z\", \"level\": \"INFO\", \"service\": \"order-service\", \"method\": \"GET\", \"path\": \"/api/v1/orders/ord-bob-2001/fixed\", \"status_code\": 403, \"client_ip\": \"172.31.0.3\", \"correlation_id\": \"mttd-403-bola-1\", \"event_type\": \"api_request\"}"
]
```

## Detection Polling

- selected_selector: `{service="order-service"}`
- selected_pattern: `"status_code": 403`
- selected_query: `sum(count_over_time({service="order-service"} |= "\"status_code\": 403" [5m]))`
- threshold: `3`
- raw_response_file: `docs/evidence/tv3/metrics/403_forbidden_bola_spike-selected-query-response.json`

- poll_time=2026-06-18T13:55:50Z count=10.0 threshold=3
