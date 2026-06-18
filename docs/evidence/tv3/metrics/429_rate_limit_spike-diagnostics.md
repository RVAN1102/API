
## Attack Traffic

- attack_start: `2026-06-18T13:55:50Z`
- attack_statuses: `404 404 404 404 404 404 404 404 404 404 429 429 429 429 429 429 429 429 429 429`
- detection_threshold: `3`
# MTTD Candidate Query Diagnostics: 429

**Generated:** 2026-06-18T13:55:50Z
**Loki:** `http://localhost:3100`

## Label Evidence

- Labels API: `docs/evidence/tv3/metrics/loki-labels.json`
- Label values: `docs/evidence/tv3/metrics/loki-label-values.json`

## Candidate Results

| Selector | Pattern | Count | Selected |
|---|---|---:|---|
| `{job="docker"}` | `"status_code":429` | `0` | no |
| `{job="docker"}` | `"status":429` | `0` | no |
| `{job="docker"}` | ` 429 ` | `27.0` | no |

## Selected Query

- selector: `{job="docker"}`
- pattern: ` 429 `
- initial_count: `27.0`
- raw_response: `docs/evidence/tv3/metrics/429_rate_limit_spike-diagnostics-selected-raw.json`

```logql
sum(count_over_time({job="docker"} |= " 429 " [5m]))
```

## Sample Matched Log Lines

- sample_source: `/loki/api/v1/query_range`
- sample_selector: `{job="docker"}`
- sample_pattern: ` 429 `
- sample_query: `{job="docker"} |= " 429 "`
- raw_sample_response: `docs/evidence/tv3/metrics/429_rate_limit_spike-diagnostics-matched-samples.json`

```json
[
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"d503ea4d4348744a9fa47a6f71ecde6e\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"6f67564282ed5408b2925653decca74f\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"51edfc6d981cb62dcd59b30afcc6d55d\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"df7dd146b60852296ec0616b0395a76d\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"6c383677da15dc19d5ac29389e863374\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"5d89bf601cb0fe36c1f3930472631c6d\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"de4dc21444a3df2b2aba137d1766bc6c\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"9ce8f42093375f5300e1622168712830\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"6f65510d5316954591b51d77c1d7d21f\"\n",
  "192.168.16.1 - - [18/Jun/2026:13:55:50 +0000] \"GET /api/v1/users HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"aad9d86fd74aa014b493a17db6cb8075\"\n"
]
```

## Detection Polling

- selected_selector: `{job="docker"}`
- selected_pattern: ` 429 `
- selected_query: `sum(count_over_time({job="docker"} |= " 429 " [5m]))`
- threshold: `3`
- raw_response_file: `docs/evidence/tv3/metrics/429_rate_limit_spike-selected-query-response.json`

- poll_time=2026-06-18T13:55:51Z count=27.0 threshold=3
