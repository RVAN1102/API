# SME Cloud API Security

This repository is a local Docker Compose implementation of a secured
cloud-style API for small company services. It includes a Kong public gateway,
four FastAPI services, Keycloak identity, selected OPA authorization decisions,
Redis replay protection, local Vault workflow support, and local observability.

The only public application API endpoint is:

```text
https://localhost:8443
```

The local gateway certificate is self-signed, so local curl examples use `-k`.

## Architecture

```text
client or test runner
    |
    | HTTPS/TLS
    v
Kong API Gateway :8443
    |
    | gateway-backend mTLS sidecars
    v
User, Order, Billing, Admin services
```

Supporting services:

| Component | Purpose |
|---|---|
| Keycloak | OIDC realm, users, roles, service clients |
| OPA | selected authorization policy decisions |
| Redis | webhook nonce TTL store |
| Vault | lab-local dev-mode secret workflow surface |
| Loki and Promtail | log collection |
| Grafana | local dashboards and alert views |
| Jaeger and OpenTelemetry Collector | local tracing |

Lab-local control-plane and observability endpoints:

| Component | URL | Use |
|---|---|---|
| Kong Admin API | `http://127.0.0.1:8001` | local gateway administration |
| Keycloak | `http://localhost:8080` | local identity provider |
| Vault | `http://localhost:8200` | local dev-mode secret workflow |
| Grafana | `http://localhost:3001` | local dashboards and alerts |

Redis is Docker-internal only.

## Implemented Security Controls

- TLS public gateway at `https://localhost:8443`.
- Gateway CORS, HSTS/security headers, request-size limit, rate limits, and a
  basic SQLi/XSS probe filter.
- Keycloak OIDC with Authorization Code + PKCE support, realm roles, service
  clients, and TOTP required action for human demo users in the realm export.
- Backend JWT validation and role checks.
- Order ownership enforcement for protected order paths.
- Billing checkout ownership verification through Order before accepting
  checkout.
- Selected OPA-backed authorization checks.
- Scoped mTLS:
  - client to Kong uses HTTPS/TLS on the public gateway;
  - Kong to backends uses gateway-backend mTLS sidecars;
  - Billing to Order ownership verification uses `https://order-mtls-proxy:8443`;
  - webhook uses HMAC timestamp/nonce validation plus mTLS client certificate.
- Redis-backed webhook replay nonce storage.
- SSRF fixed endpoint validation and Docker network egress controls.
- Structured security logs and correlation ID propagation.
- Local source-package checks for secrets, SAST/SCA, SBOM generation, and
  Cosign readiness.

mTLS coverage is limited to the scoped paths above.

## Quick Start

```bash
bash scripts/bootstrap-lab-env.sh
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
```

Public gateway health checks:

```bash
curl -k https://localhost:8443/api/v1/users/health
curl -k https://localhost:8443/api/v1/orders/health
curl -k https://localhost:8443/api/v1/billing/health
curl -k https://localhost:8443/api/v1/admin/health
```

## Core Test Commands

| Purpose | Command |
|---|---|
| Compose validation | `docker compose -f infra/docker-compose.yml config --quiet` |
| Smoke checks | `bash tests/smoke/main-smoke.sh` |
| Final regression | `bash tests/final/main-regression.sh` |
| Edge security | `bash tests/security/edge-hardening-tests.sh` |
| Gateway-backend mTLS | `bash tests/security/gateway-backend-mtls-tests.sh` |
| S2S ownership | `bash tests/security/s2s-ownership-tests.sh` |
| Webhook security | `bash tests/security/webhook-tests.sh` |
| Webhook nonce persistence | `bash tests/security/webhook-nonce-persistence-tests.sh` |
| Network egress | `bash tests/security/network-egress-control-tests.sh` |
| Negative inputs | `bash tests/security/fuzz-negative-tests.sh` |
| Deterministic malformed input checks | `bash tests/security/run-fuzzing.sh` |
| ZAP active scan | `bash tests/security/zap-active-scan.sh` |
| k6 baseline | `docker run --rm --network host \
  --user "$(id -u):$(id -g)" \
  -e BASE_URL=https://localhost:8443 \
  -e ACCESS_TOKEN="$ALICE_TOKEN" \
  -e K6_VUS=1 \
  -e K6_DURATION=45s \
  -e K6_SLEEP_SECONDS=12 \
  -v "$PWD:/work" -w /work \
  grafana/k6 run --insecure-skip-tls-verify \
  tests/performance/k6-phase3.js` |
| Repo consistency | `bash scripts/audit/repo-consistency-audit.sh` |

See `TESTING_GUIDE.md` for expected results and setup notes.

## Evidence Map

The documentation set is intentionally small:

- `docs/README.md` maps the technical documents.
- `docs/technical/` describes current architecture and controls.
- `docs/evidence/README.md` indexes curated current evidence summaries.
- `docs/evidence/results/` contains concise evidence summaries grouped by
  requirement.

The recorded k6 result is a low-load secured baseline, not a stress test:

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

## Scope Notes

- Vault is documented only as a lab-local dev-mode secret workflow surface.
  Compose still uses ignored local environment values for local runtime secrets.
- Cosign evidence is readiness/dry-run unless real signing and verification
  output for an image digest is recorded.
- RESTler support exists as a runner script, but curated evidence does not
  record a RESTler or Fuzzapi result.
- MTTD/MTTR tooling exists, but curated evidence does not record timing values.
- Do not commit `.env`, private keys, `.p12` files, generated certificates,
  tokens, `.artifacts`, raw secrets, `__pycache__`, or `.pyc`.
