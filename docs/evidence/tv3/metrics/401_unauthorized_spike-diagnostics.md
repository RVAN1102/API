
## Attack Traffic

- attack_start: `2026-06-18T10:53:26Z`
- attack_statuses: `401 401 401 401 401 401 401 401 401 401 429 429`
- detection_threshold: `5`
# MTTD Candidate Query Diagnostics: 401

**Generated:** 2026-06-18T10:53:26Z
**Loki:** `http://localhost:3100`

## Label Evidence

- Labels API: `docs/evidence/tv3/metrics/loki-labels.json`
- Label values: `docs/evidence/tv3/metrics/loki-label-values.json`

## Candidate Results

| Selector | Pattern | Count | Selected |
|---|---|---:|---|
| `{service="user-service"}` | `auth_failure` | `0` | no |
| `{service="user-service"}` | `invalid_token` | `0` | no |
| `{service="user-service"}` | `"status_code": 401` | `0` | no |
| `{service="user-service"}` | `"status_code":401` | `0` | no |
| `{service="user-service"}` | `"status": 401` | `0` | no |
| `{service="user-service"}` | `"status":401` | `0` | no |
| `{service="user-service"}` | `401` | `0` | no |
| `{service_name="user-service"}` | `auth_failure` | `0` | no |
| `{service_name="user-service"}` | `invalid_token` | `0` | no |
| `{service_name="user-service"}` | `"status_code": 401` | `0` | no |
| `{service_name="user-service"}` | `"status_code":401` | `0` | no |
| `{service_name="user-service"}` | `"status": 401` | `0` | no |
| `{service_name="user-service"}` | `"status":401` | `0` | no |
| `{service_name="user-service"}` | `401` | `30.0` | no |

## Selected Query

- selector: `{service_name="user-service"}`
- pattern: `401`
- initial_count: `30.0`
- raw_response: `docs/evidence/tv3/metrics/401_unauthorized_spike-diagnostics-selected-raw.json`

```logql
sum(count_over_time({service_name="user-service"} |= "401" [5m]))
```

## Sample Matched Log Lines

- sample_source: `/loki/api/v1/query_range`
- sample_selector: `{service_name="user-service"}`
- sample_pattern: `401`
- sample_query: `{service_name="user-service"} |= "401"`
- raw_sample_response: `docs/evidence/tv3/metrics/401_unauthorized_spike-diagnostics-matched-samples.json`

```json
[
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "INFO:     172.30.0.3:40232 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized",
  "{\"timestamp\": \"2026-06-18T10:53:26Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.30.0.3\", \"correlation_id\": \"mttd-401-10\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T10:53:26Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.30.0.3\", \"correlation_id\": \"mttd-401-9\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T10:53:26Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.30.0.3\", \"correlation_id\": \"mttd-401-8\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}"
]
```

## Detection Polling

- selected_selector: `{service_name="user-service"}`
- selected_pattern: `401`
- selected_query: `sum(count_over_time({service_name="user-service"} |= "401" [5m]))`
- threshold: `5`
- raw_response_file: `docs/evidence/tv3/metrics/401_unauthorized_spike-selected-query-response.json`

- poll_time=2026-06-18T10:53:28Z count=30.0 threshold=5
