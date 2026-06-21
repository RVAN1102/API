# Testing Guide – Capstone API Security (Topic 10)

## Prerequisites

1. **Docker Desktop** running
2. **Git Bash** (for running `.sh` scripts on Windows)
3. Project cloned from GitHub

---

## 1. Start the Stack

```bash
bash scripts/bootstrap-lab-env.sh
bash demo/mtls/ensure-gateway-backend-certs.sh

docker compose -f infra/docker-compose.yml up -d --build

# If Keycloak fails or you encounter Network Errors, use the clean restart script:
# bash fix-and-restart.sh

docker compose -f infra/docker-compose.yml ps
```

Expected services (all must show `healthy` or `running`):
```
infra-kong-1
infra-user-mtls-proxy-1
infra-order-mtls-proxy-1
infra-billing-mtls-proxy-1
infra-admin-mtls-proxy-1
infra-user-service-1
infra-order-service-1
infra-billing-service-1
infra-admin-service-1
infra-keycloak-1
infra-vault-1
infra-redis-1
infra-loki-1
infra-promtail-1
infra-grafana-1
infra-webhook-demo-1
```

> [!NOTE]
> Keycloak takes ~60 seconds to start. Kong waits for real services to be healthy before starting.
> If Kong fails to start, wait 30 seconds and run `docker compose -f infra/docker-compose.yml restart kong`.

---


## 1b. Gateway-to-Backend mTLS Default Runtime

The default Compose stack is the stable final-regression baseline and now
enforces Gateway-to-Backend mTLS. Kong acts as a TLS client and backend
sidecars require Kong's internal client certificate.
Billing-to-Order ownership verification also uses the Order mTLS sidecar with a
Billing client certificate, plus the short-lived `billing-service-client` token
for application authorization.

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
bash tests/security/gateway-backend-mtls-tests.sh
```

Expected result: Kong health routes return HTTP 200 through the mTLS sidecars;
direct TLS probes without a client certificate and with a rogue client
certificate fail. Evidence is written to
`docs/evidence/tv1/gateway-backend-mtls/gateway-backend-mtls-runtime.txt`.
Billing-to-Order ownership verification uses `https://order-mtls-proxy:8443`
with lab CA verification and a Billing client certificate by default.

---

## 2. Health Checks

The legacy plaintext gateway port is disabled and not exposed. The lab gateway
certificate is local/self-signed, so use `-k` or `CURL_TLS_OPTS=--insecure`
for local curl commands. Production should use CA-trusted certificates without
disabling verification.

```bash
curl -k https://localhost:8443/api/v1/users/health
curl -k https://localhost:8443/api/v1/orders/health
curl -k https://localhost:8443/api/v1/billing/health
curl -k https://localhost:8443/api/v1/admin/health
```

Expected response for each:
```json
{"status": "ok", "service": "<service-name>"}
```

---

## 3. Get Access Tokens

> [!IMPORTANT]
> Wait for Keycloak to be fully up (`http://localhost:8080` accessible) before running these.

```bash
# Get Alice token (role: user)
bash demo/auth/get-user-token.sh alice
ALICE_TOKEN=$(cat /tmp/user-token.txt)

# Get Bob token (role: user)
bash demo/auth/get-user-token.sh bob
BOB_TOKEN=$(cat /tmp/user-token.txt)

# Get Admin token (role: user + admin)
bash demo/auth/get-user-token.sh admin01
ADMIN_TOKEN=$(cat /tmp/user-token.txt)
```

---

## 4. Test User API

```bash
# Run automated tests
bash tests/auth/test-user-profile.sh

# With token
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/auth/test-user-profile.sh
```

Manual tests:
```bash
# Public endpoint
curl -k https://localhost:8443/api/v1/users/health

# Protected /me (with token)
curl -k https://localhost:8443/api/v1/users/me \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "X-Correlation-ID: test-me-001"

# No token → 401
curl -k https://localhost:8443/api/v1/users/me
```

---

## 5. Test Order API

```bash
# Run automated tests
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/auth/test-order-access.sh
```

Manual tests:
```bash
# Health
curl -k https://localhost:8443/api/v1/orders/health

# List orders (alice sees her orders)
curl -k https://localhost:8443/api/v1/orders \
  -H "Authorization: Bearer ${ALICE_TOKEN}"

# Get alice's order
curl "https://localhost:8443/api/v1/orders/ord-alice-1001" \
  -H "Authorization: Bearer ${ALICE_TOKEN}"
```

---

## 6. Test BOLA Demo

```bash
# Run BOLA attack simulation
ALICE_TOKEN="${ALICE_TOKEN}" BOB_TOKEN="${BOB_TOKEN}" bash tests/attack/bola-object-access.sh
```

Expected results:
| Test | Expected |
|------|----------|
| Alice → Bob's order `/vulnerable` | **200** (BOLA flaw) |
| Alice → Bob's order `/fixed` | **403** (blocked) |
| Bob → Bob's order `/fixed` | **200** (owner allowed) |
| No token → `/fixed` | **401** |

---

## 7. Test Billing Service

```bash
# Health
curl -k https://localhost:8443/api/v1/billing/health

# Checkout
curl -X POST https://localhost:8443/api/v1/billing/checkout \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: manual-alice-1001" \
  -H "X-Correlation-ID: billing-test-001" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'
```

Billing verifies ownership through the Order service and treats Order data as
canonical. If the request amount or currency does not match the Order service,
Billing returns `409`. Reusing the same `Idempotency-Key` with the same payload
is a safe retry; reusing it with a different payload or using another key for
the same caller/order after an idempotent checkout returns `409`.

Billing-to-Order ownership verification uses both controls: mTLS transport to
`order-mtls-proxy:8443` with the local lab CA/client certificate, and the
least-privilege `billing-service-client` token for Order authorization.

---

## 8. Test Admin Service + SSRF

```bash
# Run SSRF attack simulation
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/attack/ssrf-attack.sh
```

Manual tests:
```bash
# SSRF vulnerable → 200 (fetches anything)
curl -X POST https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}'

# SSRF fixed → 403 (blocked)
curl -X POST https://localhost:8443/api/v1/admin/metadata-fetch/fixed \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}'
```

---

## 9. Test Webhook Security

```bash
# Token replay and webhook forgery
set -a
source infra/.env
set +a
bash tests/attack/token-replay.sh

# Webhook forgery
bash tests/attack/webhook-forgery.sh

# Redis-backed nonce persistence across billing-service restart
bash tests/security/webhook-nonce-persistence-tests.sh
```

Expected:
- Wrong signature → **401**
- Expired timestamp → **403**
- Replayed nonce → **403**
- Replayed nonce after Billing restart → **403** while within TTL
- Valid webhook → **200**

Lab Docker Compose uses Redis for webhook replay nonces:
`WEBHOOK_NONCE_STORE=redis`, `WEBHOOK_NONCE_REDIS_URL=redis://redis:6379/0`,
and `WEBHOOK_NONCE_TTL_SECONDS=300`. If Redis is unavailable, the webhook
handler fails closed and does not accept otherwise valid webhooks.

---

## 10. Test Rate Limiting

```bash
bash tests/attack/rate-limit-trigger.sh
```

Expected: HTTP **429** after 10+ requests to `/api/v1/users`.

---

## 11. View Grafana Dashboard

1. Open **http://localhost:3001**
2. Login: `admin` / `admin`
3. Navigate: **Dashboards → API Security → API Security Overview**
4. Run attack scripts and watch security events appear in real time

---

## 12. Initialize Vault

```bash
bash vault/scripts/init-dev-vault.sh
```

Access Vault UI: **http://localhost:8200**  
Token: `dev-root-token` (dev mode only)

For Topic 10 reporting, `infra/.env` is an ignored lab bootstrap artifact for
Docker Compose. Vault OSS local demonstrates central secret management, but this
prototype does not claim every runtime secret is fetched from Vault. Production
should use Vault HA, cloud KMS, Secrets Manager, or equivalent managed secret
storage. See `docs/evidence/tv2/vault-lab-secret-bootstrap.md`.

---

## 13. PKCE Flow Demo

```bash
# Generate authorization URL
bash demo/auth/pkce-token-request.sh url
```

Follow the printed URL in a browser to complete the PKCE flow.

---

## 14. CI Security Scan

```bash
# Install bandit first
pip install bandit

# Run local scan (gitleaks and trivy optional)
bash ci/run-local-security-scan.sh
```

Results saved to `docs/evidence/tv3/security-scan-local.txt`.

---

## 14b. Production-Oriented Hardening Checks

```bash
bash tests/security/container-runtime-hardening-tests.sh
bash tests/security/openapi-contract-tests.sh
```

Container hardening checks render `infra/docker-compose.yml` and verify the
intended `no-new-privileges`, `cap_drop`, `read_only`, and `tmpfs` settings
without writing tracked evidence files. The OpenAPI contract test reuses the
existing `ci-alice` token helper and verifies selected Kong-routed responses do
not expose sensitive or debug/internal fields.

For image supply-chain evidence in CI, `.github/workflows/security-scan.yml`
builds local service images, scans them with Trivy, emits CycloneDX image SBOM
artifacts, and runs a Cosign keyless-signing readiness dry-run. Dry-run mode
does not create a signature; real production signing should use a published
image digest and GitHub Actions OIDC identity pinned during verification. Local
commands:

```bash
SBOM_IMAGES="topic10-user-service:local" bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-placeholder
```

Evidence note: `docs/evidence/final/production-hardening-bundle-1.md`.

---

## Final Regression Gate

Run this before review or merge:

```bash
bash tests/final/main-regression.sh
```

If `infra/.env` is missing or still has placeholders, the regression preflight
calls `bash scripts/bootstrap-lab-env.sh` and reloads the file without printing
secret values.

Expected result: `Suites passed: 12`, `Suites failed: 0`. The final
regression includes Redis-backed webhook nonce persistence across Billing
restart and Redis fail-closed behavior.

---

## 15. MTTD/MTTR Measurement

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/metrics/measure-mttd-mttr.sh
```

Results saved to:
- `docs/evidence/tv3/secops-metrics/secops-mttd-mttr-summary.md`
- Authoritative summary: `docs/evidence/tv3/secops-metrics/secops-mttd-mttr-summary.md`

## 15b. Latency And Cost Metrics

```bash
BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh

# Optional HTTPS lab path:
HTTPS_BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh
```

Transient output is written to `.artifacts/test-runs/metrics/`. Read the p50/p95 method and SME cost/trade-off summary at `docs/evidence/tv3/secops-metrics/latency-cost-tradeoff-summary.md`.

---

## 16. Gateway Tests

```bash
# Test all routes
bash demo/curl/test-gateway-routes.sh

# Test CORS
bash demo/curl/test-cors.sh

# Test rate limiting
bash demo/curl/test-rate-limit.sh

# Test WAF edge filter
bash demo/curl/test-waf-filter.sh

# Test HTTPS + HSTS (requires Docker curl)
docker run --rm curlimages/curl:latest --insecure --include \
  https://host.docker.internal:8443/api/v1/users/health
```

---

## 16b. Gateway-to-Backend mTLS Default Runtime

Default Compose now enforces Gateway-to-Backend mTLS through Nginx sidecars.
Run the test with:

```bash
bash tests/security/gateway-backend-mtls-tests.sh
```

By default, transient runtime output is written to `.artifacts/test-runs/` so
re-running tests does not dirty the committed official evidence. To intentionally
refresh the official evidence snapshot, run:

```bash
UPDATE_OFFICIAL_EVIDENCE=1 bash tests/security/gateway-backend-mtls-tests.sh
```

Expected result: Kong-to-User/Order/Billing/Admin health routes return `200`;
no-client and wrong-certificate probes are rejected; Kong's client certificate is
accepted by each backend sidecar.

---

## 17. Stop Stack

```bash
docker compose -f infra/docker-compose.yml down
```

---

## Troubleshooting

### Kong fails to start
Kong depends on all 4 services being healthy. If a service fails to build:
```bash
docker compose -f infra/docker-compose.yml logs user-service
docker compose -f infra/docker-compose.yml logs order-service
```

### Keycloak not ready / Network Error / Failed to fetch
If you get a "Failed to fetch" error on the frontend or `exit 1` when getting a token, Keycloak is down or its database is out of sync.
Run the clean restart script:
```bash
bash fix-and-restart.sh
```

### Token verification fails (503 idp_unavailable)
The user/order services try to reach `http://keycloak:8080` (internal Docker name).
If Keycloak is not up yet, wait and retry. The JWKS cache will be populated on the next request.

### Rate limit resets
Rate limits reset each minute. If you want to trigger 429 again, wait 60 seconds.

### Windows: Python path issue for webhook scripts
```bash
export PYTHON_BIN=/c/Users/duynh/AppData/Local/Programs/Python/Python313/python.exe
```
