# Testing And Fuzzing

## Requirement

The repository must provide reproducible security regression checks, negative
tests, deterministic malformed-input checks, and ZAP support.

## Regression

`tests/final/main-regression.sh` runs 12 suites and exits non-zero on failure:

1. Container Runtime Hardening
2. Smoke Test
3. OpenAPI Contract
4. Client Credentials
5. Token Lifecycle
6. Real S2S Ownership
7. Authz Negative
8. OPA Authz
9. Edge Hardening
10. Webhook Security
11. Webhook Nonce Persistence
12. Fuzz/Negative

## Negative Tests

`tests/security/fuzz-negative-tests.sh` checks malformed bodies, missing fields,
invalid JSON, SQLi/XSS probes, and webhook missing headers. Curated evidence
records `8/8` checks passed.

## Deterministic Malformed-Input Checks

`tests/security/run-fuzzing.sh` sends deterministic malformed inputs against
`https://localhost:8443`. Unexpected 5xx responses are treated as crashes. This
is not RESTler or Fuzzapi.

The recorded deterministic run attempted 20 requests and counted no 5xx
crashes, but returned HTTP `000` statuses in that run. It is not used as proof
of live fail-closed HTTP statuses.

## RESTler And Fuzzapi Status

`tests/restler/run-restler-check.sh` exists and exits successfully only when
RESTler is available and its run finishes. Curated evidence does not record a
RESTler or Fuzzapi result.

## ZAP

`tests/security/zap-active-scan.sh` runs ZAP against the HTTPS gateway. Curated
evidence records `0` High, `0` Medium, `0` Low, and `8` Informational alerts in
the recorded summary.
