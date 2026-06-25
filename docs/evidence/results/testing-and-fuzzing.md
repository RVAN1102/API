# Testing And Fuzzing

## Requirement Proven

The repository has runnable regression, negative testing, deterministic
malformed-input testing, and authenticated RESTler runner support.

## Command Or Evidence Source

```bash
bash tests/final/main-regression.sh
bash tests/security/fuzz-negative-tests.sh
bash tests/security/run-fuzzing.sh
RESTLER_AUTH_PASSWORD='<redacted>' bash tests/restler/run-restler-check.sh
```

## Observed Result

| Area | Observed result |
|---|---|
| final regression script | configured to run 12 suites and fail on any failed suite |
| negative tests | recorded `8/8` checks passed |
| deterministic malformed-input run | generated summary records 20 requests, 18 HTTP 4xx responses, and 0 5xx/crashes |
| RESTler operation rendering | all 16 OpenAPI operations were rendered |
| RESTler protected-edge reachability | network evidence records all 16 operation paths through HTTPS Kong, including HTTP `200`/`202` responses beyond pure authentication rejection |
| RESTler-native valid-status coverage | `8/16`; this is not full business-flow success |
| RESTler fail-closed behavior | HTTP `401` and `403` responses were observed for protected cases |
| RESTler crash indicators | 0 observed 5xx/crash indicators and no RESTler bug bucket |
| Fuzzapi | no curated result is recorded |

## Scope And Limitation

The RESTler runner uses Keycloak Direct Grant through
`tests/restler/fetch-restler-auth.sh`, with the password supplied only through
`RESTLER_AUTH_PASSWORD`. The generated RESTler summary distinguishes operation
rendering, network-observed reachability, and RESTler-native valid-status
coverage. Full successful business-flow coverage is not claimed; `401`/`403`
remain valid fail-closed outcomes only for cases that are intentionally
unauthenticated or unauthorized.
