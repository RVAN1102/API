# Testing And Fuzzing

## Requirement Proven

The repository has runnable regression, negative testing, deterministic
malformed-input testing, and optional RESTler runner support.

## Command Or Evidence Source

```bash
bash tests/final/main-regression.sh
bash tests/security/fuzz-negative-tests.sh
bash tests/security/run-fuzzing.sh
bash tests/restler/run-restler-check.sh
```

## Observed Result

| Area | Observed result |
|---|---|
| final regression script | configured to run 12 suites and fail on any failed suite |
| negative tests | recorded `8/8` checks passed |
| deterministic malformed-input run | 20 requests attempted, no 5xx crashes counted |
| RESTler | runner exists; no curated result is recorded |
| Fuzzapi | no curated result is recorded |

## Scope And Limitation

The recorded deterministic malformed-input run returned HTTP `000` statuses, so
it is not used as evidence of live 4xx fail-closed behavior. Use
`fuzz-negative-tests.sh` for the curated live negative-test pass result.
