
## Attack Traffic

- attack_start: `2026-06-18T10:53:28Z`
- attack_statuses: `404 404 404 404 404 404 404 404 404 404 429 429 429 429 429 429 429 429 429 429`
- detection_threshold: `3`
# MTTD Candidate Query Diagnostics: 429

**Generated:** 2026-06-18T10:53:28Z
**Loki:** `http://localhost:3100`

## Label Evidence

- Labels API: `docs/evidence/tv3/metrics/loki-labels.json`
- Label values: `docs/evidence/tv3/metrics/loki-label-values.json`

## Candidate Results

| Selector | Pattern | Count | Selected |
|---|---|---:|---|
| `{job="docker"}` | `"status_code":429` | `0` | no |
| `{job="docker"}` | `"status":429` | `0` | no |
| `{job="docker"}` | ` 429 ` | `2.0` | no |

## Selected Query

- selector: `{job="docker"}`
- pattern: ` 429 `
- initial_count: `2.0`
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
  "172.20.0.1 - - [18/Jun/2026:10:53:26 +0000] \"GET /api/v1/users/me HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"85040621be507c25525079457ad14218\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:53:26 +0000] \"GET /api/v1/users/me HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"0f2e9c6c9e7b4c7a2d694d3639df263b\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"e45f17098d63256ea42ea36693b8015f\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"89a0b54aee934d57ab588a2d83d30c7b\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"893fd942c2cfe31e7db7e4277de61f76\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"5ffff47038257c3d6a107b34f3158e6f\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"1af0b749ad665d53e7c50727382cbc4d\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"2d223f5cf1713977a46b2a1bedaf2d65\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"972be86245949a7dce199d062710bd11\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:44:37 +0000] \"POST /api/v1/admin/maintenance HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"ae58ea55f2d6c90feb8d0509f656085b\"\n"
]
```

## Detection Polling

- selected_selector: `{job="docker"}`
- selected_pattern: ` 429 `
- selected_query: `sum(count_over_time({job="docker"} |= " 429 " [5m]))`
- threshold: `3`
- raw_response_file: `docs/evidence/tv3/metrics/429_rate_limit_spike-selected-query-response.json`

- poll_time=2026-06-18T10:53:28Z count=2.0 threshold=3

- poll_time=2026-06-18T10:53:33Z count=13.0 threshold=3
