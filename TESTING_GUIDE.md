# Testing Guide

This guide lists the current runnable checks for the final no-plaintext
HTTPS/mTLS runtime. Public API checks use:

```text
https://localhost:8443
```

Backend application services are not a plaintext test target in the final
runtime. They listen directly with uvicorn TLS/mTLS on port `8443`.

## Prerequisites

- Docker with Compose support.
- Bash.
- `curl`.
- Python available as `python3` or through the repository compatibility shim.
- Optional tools for selected checks: `k6`, ZAP Docker image, Trivy, Gitleaks,
  Bandit, Cosign.

## Start The Stack

```bash
bash scripts/bootstrap-lab-env.sh
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
```

Expected result: Kong, Keycloak, Vault, OPA, User, Order, Billing, Admin, and
optional observability services start according to the selected Compose
profiles. Keycloak may take about a minute to become ready.

Public gateway health checks:

```bash
curl -k https://localhost:8443/api/v1/users/health
curl -k https://localhost:8443/api/v1/orders/health
curl -k https://localhost:8443/api/v1/billing/health
curl -k https://localhost:8443/api/v1/admin/health
```

Expected result: each command returns HTTP `200` and a JSON health response.

## Rate-Limit Note

Kong uses local rate-limit counters. Restart Kong between rate-limit-sensitive
suites when rerunning tests manually:

```bash
docker compose -f infra/docker-compose.yml restart kong
```

This avoids false HTTP `429` responses from a previous suite run.

## Final Security Suite

Run these checks against the final runtime:

```bash
bash tests/security/no-plaintext-transport-tests.sh
bash tests/security/gateway-backend-mtls-tests.sh
bash tests/security/s2s-ownership-tests.sh
bash tests/security/opa-authz-tests.sh
bash tests/security/webhook-tests.sh
bash tests/security/network-egress-control-tests.sh
bash tests/security/container-runtime-hardening-tests.sh
```

Expected pass results:

| Suite | Expected result |
|---|---|
| no-plaintext transport | no-plaintext transport gate passed |
| Gateway-backend mTLS | direct HTTPS/mTLS checks pass |
| S2S ownership | `25/25` |
| OPA authorization | `22/22` |
| Webhook security | `7/7` |
| Network egress control | `28/28` |
| Container runtime hardening | passed |

The no-plaintext gate statically verifies that application runtime traffic does
not reintroduce plaintext service URLs, plaintext Keycloak/OPA/Vault defaults,
or obsolete backend proxy references. The gateway-backend mTLS suite verifies
that Kong reaches each backend directly over HTTPS/mTLS and that backend
listeners reject callers without the required client certificate.

## Auth Token Helpers

```bash
bash demo/auth/get-user-token.sh ci-alice
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

bash demo/auth/get-user-token.sh ci-bob
BOB_TOKEN="$(cat /tmp/user-token.txt)"
```

Expected result: helper scripts exit `0` and write an access token to
`/tmp/user-token.txt`. Do not print or commit token values.

## Authorization And Service-To-Service Tests

```bash
bash tests/security/client-credentials-tests.sh
bash tests/security/authz-negative-tests.sh
bash tests/security/opa-authz-tests.sh
bash tests/security/token-lifecycle-tests.sh
bash tests/security/s2s-ownership-tests.sh
```

Expected result: each script exits `0`. The curated S2S result records Billing
using `https://order-service:8443` with:

```text
/etc/internal-tls/ca.crt
/etc/internal-tls/billing-client.crt
/etc/internal-tls/billing-client.key
```

## Edge Security Tests

```bash
bash tests/security/edge-hardening-tests.sh
```

Expected result: TLS/HSTS, CORS, request-size, rate-limit, and SQLi/XSS probe
checks pass. Restart Kong before or after this suite when subsequent checks
would be sensitive to local rate-limit counters.

## Webhook Tests

```bash
bash tests/security/webhook-tests.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

Expected result: valid HMAC plus mTLS is accepted. Invalid signature, old
timestamp, replay nonce, missing headers, and missing client certificate are
rejected.

## SSRF And Egress Tests

```bash
bash tests/security/network-egress-control-tests.sh
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/attack/ssrf-attack.sh
```

Expected result: backend networks are internal, Admin cannot directly reach the
metadata and public Internet targets used by the test, and Billing reaches
Order only through `billing-order-mtls-internal` over direct HTTPS/mTLS. The
fixed metadata-fetch endpoint blocks metadata access with HTTP `403`.

## Negative And Fuzzing Tests

```bash
bash tests/security/fuzz-negative-tests.sh
bash tests/security/run-fuzzing.sh
```

Expected result: malformed input, missing fields, invalid JSON, SQLi/XSS probe,
and missing webhook header checks pass. The deterministic malformed-input run
treats unexpected 5xx responses as crashes.

Authenticated RESTler runner:

```bash
RESTLER_AUTH_PASSWORD='<redacted>' bash tests/restler/run-restler-check.sh
```

Evidence is valid only when the generated summary proves requests were sent
beyond pure 401/403 gateway rejection.

## ZAP Active Scan

```bash
bash tests/security/zap-active-scan.sh
```

Expected result: ZAP runs against the HTTPS gateway and writes runtime output.
Curated evidence records `0` High, `0` Medium, `0` Low, and `8` Informational
alerts for the recorded summary.

## k6 Low-Load Baseline

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

Expected result: k6 exits `0` if thresholds pass. This is a low-load secured
gateway baseline, not a stress test.

## SecOps And Supply Chain

```bash
bash tests/metrics/execute-mttd-scenario.sh
bash tests/metrics/measure-kms-overhead.sh
bash tests/security/verify-no-tracked-secrets.sh
bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-example
```

Expected result: metrics scripts write reviewed local evidence without secrets,
tracked secret checks pass, SBOM files are generated, and Cosign dry-run
documents readiness without creating a signature.

## Cleanup

To stop the stack:

```bash
docker compose -f infra/docker-compose.yml down
```

Do not commit generated private keys, `.p12` files, `infra/.env`,
`infra/.vault-init.json`, tokens, or `.artifacts`.
