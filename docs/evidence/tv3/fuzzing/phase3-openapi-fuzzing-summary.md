# Phase 3 OpenAPI And Negative Fuzzing Summary

## Scope

The API contract source is `services/openapi.yaml`. Current repo support covers
deterministic OpenAPI/negative-input testing against the public HTTPS gateway at
`https://localhost:8443`.

This is not claimed as completed RESTler or Fuzzapi coverage unless those tools
are run and their outputs are preserved as current evidence.

## Current Rerunnable Evidence

| Area | Command | Output |
|---|---|---|
| OpenAPI contract checks | `bash tests/security/openapi-contract-tests.sh` | Console/runtime regression output |
| Deterministic negative fuzzing | `bash tests/security/run-fuzzing.sh` | `.artifacts/test-runs/tv3/fuzzing/` |
| Final regression inclusion | `bash tests/final/main-regression.sh` | Current final gate summary |

`tests/security/run-fuzzing.sh` sends malformed payloads, type-confusion
payloads, auth bypass attempts, path traversal/SSRF-shaped paths, SQLi-shaped
inputs, and oversized payloads. Expected 4xx responses are fail-closed behavior.
Unexpected 5xx responses are treated as crashes/findings.

## Optional Extensions

RESTler and Fuzzapi remain optional extensions for broader grammar-based or
coverage-guided fuzzing:

- RESTler support path: `tests/restler/run-restler-check.sh`
- Fuzzapi: optional future extension; not used as a Phase 3 evidence source in this repo

Only mark RESTler/Fuzzapi as complete when a fresh run against
`https://localhost:8443` has timestamped evidence and the result is linked from
the authoritative evidence index.

## Evidence Fields

| Field | Value |
|---|---|
| Run timestamp UTC | `<YYYY-MM-DDTHH:MM:SSZ>` |
| Target | `https://localhost:8443` |
| OpenAPI spec | `services/openapi.yaml` |
| Total requests | `<count from run-fuzzing output>` |
| Expected 4xx responses | `<count>` |
| Unexpected 5xx/crashes | `<count>` |
| Result | `<PASS/FAIL>` |

Do not commit access tokens, generated logs containing secrets, or large raw
tool output. Prefer summarized evidence plus ignored transient artifacts.

