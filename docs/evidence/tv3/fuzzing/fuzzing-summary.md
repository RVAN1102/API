# Structured Negative API Test Evidence Summary (TV3)

**Date:** 2026-06-18T05:50:03Z
**Tool:** `tests/security/run-fuzzing.sh`
**Target:** `http://localhost:8000`
**OpenAPI Spec:** `services/openapi.yaml`
**Auth:** Token obtained; token value was not logged.
**Result:** PASS

## Runtime Result

| Metric | Value |
| --- | ---: |
| Total requests | 20 |
| 4xx responses | 18 |
| 5xx / crashes | 0 |
| Unexpected 5xx / crashes | 0 |

## Coverage

| Suite | Result | Notes |
| --- | --- | --- |
| Missing required fields | PASS | Invalid order payloads failed closed with 405; billing payloads returned 422. |
| Type confusion / invalid types | PASS | Invalid order payloads failed closed with 405; billing payload returned 422. |
| SQL injection patterns | PASS | No 5xx observed; path probes produced curl-level no-response values, body probe failed closed with 405. |
| Boundary values | PASS | Invalid order payloads failed closed with 405. |
| Auth bypass attempts | PASS | Missing or malformed auth failed closed with 400/403. |
| Path traversal / SSRF payloads | PASS | Probes failed closed with 404. |
| Oversized payload | PASS | Request was rate-limited/fail-closed with 429; no 5xx observed. |

## RESTler Status

This evidence is not RESTler fuzzing. Real RESTler execution is produced only by
`tests/restler/run-restler-check.sh`, which must compile `services/openapi.yaml`
and run RESTler `test` plus `fuzz-lean` mode. RESTler output belongs under
`docs/evidence/tv3/restler/`.

## Conclusion

The rerun completed with 20 total requests and 0 unexpected 5xx responses or crashes. All observed deviations are fail-closed responses or rate limiting for negative inputs.
