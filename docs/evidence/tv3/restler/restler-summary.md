# RESTler Execution Summary

**Date:** 2026-06-25T03:08:09Z
**RESTler:** Docker image: mcr.microsoft.com/restlerfuzzer/restler:v8.5.0
**OpenAPI path:** `services/openapi.yaml`
**Target URL:** `https://kong:8443`
**Auth/token handling:** RESTler test and fuzz-lean use an external token refresh command. The password is read from `RESTLER_AUTH_PASSWORD` by `tests/restler/fetch-restler-auth.sh`; no password or token is written intentionally to evidence.

## Results

| Metric | Value |
|---|---:|
| Compile succeeded | yes |
| Test succeeded | yes |
| Fuzz-lean succeeded | yes |
| OpenAPI operations count | 16 |
| Rendered/sent request count | 16 / 16 |
| Requests actually sent or status evidence parsed | yes |
| Status-code observations parsed | 290 |
| Bug bucket count | 0 |
| 5xx/crash indicator count in logs | 0 |
| Evidence validity | valid request/status evidence present |

## Status-Code Evidence

Status-code evidence: see RESTler logs; no compact status-code sample was parsed.

| Status | Count |
|---|---:|
| 200 | 14 |
| 202 | 2 |
| 401 | 51 |
| 403 | 77 |
| 404 | 6 |
| 422 | 60 |
| 429 | 80 |

RESTler evidence is valid only when the final output proves requests were sent beyond pure 401/403 gateway rejection. Protected-route 401 or 403 responses can still be valid fail-closed behavior when RESTler intentionally exercises unauthenticated or unauthorized cases.

## Raw Artifact Handling

The runner sanitizes raw logs and machine-readable outputs into ignored `.artifacts/test-runs/tv3/restler/`; the compact summary is the tracked evidence.
