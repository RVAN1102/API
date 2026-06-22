# Testing Guide

This guide lists current runnable commands for the local repository. Public API
checks use only:

```text
https://localhost:8443
```

HTTP URLs for Kong Admin, Keycloak, Vault, and Grafana are local
control-plane or observability surfaces only.

## Prerequisites

- Docker with Compose support.
- Bash.
- `curl`.
- Python available as `python3` or through the repository compatibility shim.
- Optional tools for selected checks: `k6`, ZAP Docker image, Trivy, Gitleaks,
  Bandit, Cosign.

## 1. Validate Compose

```bash
docker compose -f infra/docker-compose.yml config --quiet
```

Expected result: exit `0`.

To list services:

```bash
docker compose -f infra/docker-compose.yml config --services
```

Expected result: includes Kong, Keycloak, Vault, Redis, Loki, Promtail,
Grafana, Jaeger, OTel collector, OPA, four application services, and four mTLS
sidecars.

## 2. Start The Stack

```bash
bash scripts/bootstrap-lab-env.sh
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
```

Expected result: services are running, with health checks becoming healthy after
startup. Keycloak may take about a minute to become ready.

## 3. Public Gateway Health Checks

```bash
curl -k https://localhost:8443/api/v1/users/health
curl -k https://localhost:8443/api/v1/orders/health
curl -k https://localhost:8443/api/v1/billing/health
curl -k https://localhost:8443/api/v1/admin/health
```

Expected result: each command returns HTTP `200` and a JSON health response.

## 4. Auth Token Helpers

```bash
bash demo/auth/get-user-token.sh ci-alice
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

bash demo/auth/get-user-token.sh ci-bob
BOB_TOKEN="$(cat /tmp/user-token.txt)"
```

Expected result: helper scripts exit `0` and write an access token to
`/tmp/user-token.txt`. Do not print or commit token values.

## 5. Smoke And Main Regression

```bash
bash tests/smoke/main-smoke.sh
```

Expected result: public health checks pass and authenticated user checks pass
when the helper token flow succeeds.

```bash
bash tests/final/main-regression.sh
```

Expected result: the script exits `0` only when all 12 configured suites pass.
It requires the local stack, local lab secret values, Keycloak readiness, and
local certificate material.

## 6. Authorization And Service-To-Service Tests

```bash
bash tests/security/client-credentials-tests.sh
bash tests/security/authz-negative-tests.sh
bash tests/security/opa-authz-tests.sh
bash tests/security/token-lifecycle-tests.sh
bash tests/security/s2s-ownership-tests.sh
```

Expected result: each script exits `0`. The current curated S2S evidence records
Billing-to-Order ownership checks, least-privilege service-client behavior, and
`25/25` S2S assertions passing.

## 7. Edge Security Tests

```bash
bash tests/security/edge-hardening-tests.sh
```

Expected result: TLS/HSTS, CORS, request-size, rate-limit, and SQLi/XSS probe
checks pass. Curated evidence records TLS 1.3 success, TLS 1.2 rejection, HSTS
present, hostile origin rejection, HTTP `429` rate limit, and HTTP `403` SQLi/XSS
blocks.

## 8. mTLS And Webhook Tests

```bash
bash tests/security/gateway-backend-mtls-tests.sh
bash tests/security/webhook-tests.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

Expected result:

- Kong reaches User, Order, Billing, and Admin through mTLS sidecars.
- Sidecars reject missing or wrong client certificates.
- Webhook valid HMAC is accepted.
- Invalid signature, old timestamp, replay nonce, missing headers, and missing
  client certificate are rejected.

## 9. SSRF And Egress Tests

```bash
bash tests/security/network-egress-control-tests.sh
```

Expected result: backend networks are internal, Admin cannot directly reach the
metadata and public Internet targets used by the test, and Billing reaches Order
only through the approved mTLS sidecar path.

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/attack/ssrf-attack.sh
```

Expected result: the fixed metadata-fetch endpoint blocks metadata access with
HTTP `403`. The attack script is a runtime exercise; keep generated output out
of final curated evidence unless reviewed and summarized.

## 10. Negative And Fuzzing Tests

```bash
bash tests/security/fuzz-negative-tests.sh
```

Expected result: malformed input, missing fields, invalid JSON, SQLi/XSS probe,
and missing webhook header checks pass.

```bash
bash tests/security/run-fuzzing.sh
```

Expected result: deterministic malformed-input checks run against
`https://localhost:8443`; unexpected 5xx responses are treated as crashes.
This is deterministic negative testing, not RESTler or Fuzzapi.

RESTler runner:

```bash
RESTLER_AUTH_PASSWORD='<redacted>' bash tests/restler/run-restler-check.sh
```

Expected result: exits `0` only if RESTler is available, Keycloak is running,
the supplied password is valid for the configured user, and compile/test/fuzz-lean
complete. The runner passes an authenticated RESTler settings file to both
`test` and `fuzz-lean`; evidence is valid only when the generated summary proves
requests were sent beyond pure 401/403 gateway rejection.

## 11. ZAP Active Scan

```bash
bash tests/security/zap-active-scan.sh
```

Expected result: ZAP runs against the HTTPS gateway and writes runtime output.
Curated evidence records `0` High, `0` Medium, `0` Low, and `8` Informational
alerts for the recorded summary.

## 12. k6 Low-Load Baseline

```bash
docker run --rm --network host \
  --user "$(id -u):$(id -g)" \
  -e BASE_URL=https://localhost:8443 \
  -e ACCESS_TOKEN="$ALICE_TOKEN" \
  -e K6_VUS=1 \
  -e K6_DURATION=45s \
  -e K6_SLEEP_SECONDS=12 \
  -v "$PWD:/work" -w /work \
  grafana/k6 run --insecure-skip-tls-verify \
  tests/performance/k6-phase3.js
```

Expected result: k6 exits `0` if thresholds pass. The command above reproduces the recorded low-load secured baseline profile.

Recorded secured low-load baseline:

| Metric | Value |
|---|---:|
| target | `https://localhost:8443` |
| authenticated `/users/me` | included |
| health p50 | `5.03 ms` |
| health p95 | `73.96 ms` |
| authenticated p50 | `5.23 ms` |
| authenticated p95 | `8.14 ms` |
| failed request rate | `0.00%` |
| total requests | `20` |

This is not a stress test.

## 13. k6 Direct-Vs-Edge Overhead

```bash
bash tests/metrics/run-k6-overhead.sh
```

Expected result: the script exits `0`, writes baseline and edge k6 summaries
under `docs/evidence/tv3/metrics/`, and writes
`k6-users-me-overhead-analysis.md` with edge minus baseline p50 and p95 latency.
The baseline run uses the Docker internal network attached to `user-service` and
does not expose backend ports to the host. The edge run defaults to Linux Docker
host networking and calls `https://localhost:8443`; Docker Desktop users must
provide a reachable `EDGE_BASE_URL` with `EDGE_DOCKER_NETWORK` if needed, or run
the edge k6 command from the host.

This measures edge path overhead for `/api/v1/users/me`; it does not isolate
mTLS overhead.

## 14. SecOps MTTD/MTTR Scenario

```bash
bash tests/metrics/execute-mttd-scenario.sh
```

Expected result: the wrapper runs the existing Loki LogQL threshold-based
measurement, writes console output to
`docs/evidence/tv3/metrics/mttd-mttr-run-console.txt`, and writes one matching
correlation-ID sample to
`docs/evidence/tv3/metrics/correlation-id-log-sample.json`. If Loki has no
matching sample, the wrapper fails rather than creating fake evidence. Do not
interpret this as Grafana alert firing evidence unless a separate Grafana firing
state is captured.

## 15. Vault/KMS-Style Secret Retrieval Overhead

```bash
bash tests/metrics/measure-kms-overhead.sh
```

Expected result: the script performs 30 local Vault dev-mode KV reads against
`/v1/secret/data/api/webhook`, writes
`docs/evidence/tv3/metrics/vault-kms-overhead.csv`, and writes
`docs/evidence/tv3/metrics/vault-kms-overhead-summary.md` with p50, p95,
average latency, and successful sample count. It writes only status and timing
data, not secret values. This is a Vault secret-read overhead lab proxy, not an
AWS KMS measurement.

## 16. Supply Chain And Secret Checks

```bash
bash tests/security/verify-no-tracked-secrets.sh
bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-example
```

Expected result: tracked secret check passes, SBOM files are generated, and
Cosign dry-run documents readiness without creating a signature.

## 17. Repo Consistency Audit

```bash
bash scripts/audit/repo-consistency-audit.sh
```

Expected result: `FAIL=0`. A warning requires review before staging.

## 18. Local Cleanup

To stop the stack:

```bash
docker compose -f infra/docker-compose.yml down
```

To remove local generated certificate and runtime artifacts before packaging:

```bash
find infra/certs -type f \( -name '*.key' -o -name '*.p12' -o -name '*.srl' -o -name '*.csr' -o -name '*.ext' \) -delete
rm -rf .artifacts
```

Expected result: generated local-only artifacts are removed. Do not remove
tracked safe certificate documentation files.
