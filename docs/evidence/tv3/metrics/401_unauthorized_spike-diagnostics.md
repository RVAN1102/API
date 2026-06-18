
## Attack Traffic

- attack_start: `2026-06-18T13:55:43Z`
- attack_statuses: `401 401 401 401 401 401 401 401 401 401 429 429`
- detection_threshold: `5`
# MTTD Candidate Query Diagnostics: 401

**Generated:** 2026-06-18T13:55:43Z
**Loki:** `http://localhost:3100`

## Label Evidence

- Labels API: `docs/evidence/tv3/metrics/loki-labels.json`
- Label values: `docs/evidence/tv3/metrics/loki-label-values.json`

## Candidate Results

| Selector | Pattern | Count | Selected |
|---|---|---:|---|
| `{service="user-service"}` | `auth_failure` | `10.0` | no |

## Selected Query

- selector: `{service="user-service"}`
- pattern: `auth_failure`
- initial_count: `10.0`
- raw_response: `docs/evidence/tv3/metrics/401_unauthorized_spike-diagnostics-selected-raw.json`

```logql
sum(count_over_time({service="user-service"} |= "auth_failure" [5m]))
```

## Sample Matched Log Lines

- sample_source: `/loki/api/v1/query_range`
- sample_selector: `{service="user-service"}`
- sample_pattern: `auth_failure`
- sample_query: `{service="user-service"} |= "auth_failure"`
- raw_sample_response: `docs/evidence/tv3/metrics/401_unauthorized_spike-diagnostics-matched-samples.json`

```json
[
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-10\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-9\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-8\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-7\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-6\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-5\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-4\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-3\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-2\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}",
  "{\"timestamp\": \"2026-06-18T13:53:17Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.28.0.3\", \"correlation_id\": \"mttd-401-1\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}"
]
```

## Detection Polling

- selected_selector: `{service="user-service"}`
- selected_pattern: `auth_failure`
- selected_query: `sum(count_over_time({service="user-service"} |= "auth_failure" [5m]))`
- threshold: `5`
- raw_response_file: `docs/evidence/tv3/metrics/401_unauthorized_spike-selected-query-response.json`

- poll_time=2026-06-18T13:55:43Z count=10.0 threshold=5
