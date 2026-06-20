# Capstone Project - Cloud API-Based Network Application Security

## Overview

This project is a prototype for **Cloud API-Based Network Application Security
for Small Company Services** (Topic 10). The goal is to design, implement, and
evaluate a practical API security architecture suitable for a small company.

## Architecture

```text
Browser (Frontend UI) / Test Scripts
        │
        ▼
Kong API Gateway
  - Routing, CORS, Rate limiting
  - Edge filtering (SQLi/XSS)
  - HTTPS/HSTS, Correlation ID
  - Webhook HMAC header enforcement
        │
        ├──▶ User Service    – /api/v1/users/*
        ├──▶ Order Service   – /api/v1/orders/*
        ├──▶ Billing Service – /api/v1/billing/* (and /webhooks/payment)
        ├──▶ Admin Service   – /api/v1/admin/*
        └──▶ Webhook Demo    – /api/v1/webhooks/*

Supporting Services:
  Keycloak   – OAuth2/OIDC Identity Provider
  Vault      – Lab secret-management workflow evidence
  Redis      – Webhook replay nonce TTL store
  Loki       – Log aggregation
  Promtail   – Log collector
  Grafana    – Dashboards and alerting
```

## Security Features

### Edge Gateway And Webhook Ingress
- Kong API Gateway routing
- CORS policy (origins, methods, headers)
- Rate limiting (60/min standard, 10/min sensitive routes)
- WAF/edge filter (SQLi/XSS patterns, payload size)
- HTTPS/TLS termination + HSTS header
- Webhook channel mTLS at Kong: valid client certificate accepted, missing
  client certificate rejected
- Gateway-to-backend mTLS enforced by default via Nginx sidecars; backend S2S
  ownership still uses short-lived Keycloak Client Credentials
- Webhook HMAC-SHA256 + nonce/timestamp enforcement
- Redis-backed webhook nonce TTL store for replay protection across restarts
- Correlation ID propagation

### Identity, Authorization, And Core Services
- Keycloak OAuth2/OIDC realm (`topic10-sme-api`)
- Authorization Code + PKCE for user login
- Client Credentials for service-to-service
- JWT validation with JWKS (RS256)
- RBAC backend authorization (roles: user, admin, billing-service)
- BOLA vulnerable/fixed demo (Order Service)
- Billing checkout verifies Order ownership through the Order service, rejects
  client amount/currency mismatches, and supports caller-scoped idempotency
  keys for safe retries and duplicate-checkout detection in the lab prototype
- HashiCorp Vault dev-mode secret-path and rotation workflow evidence; local
  Docker Compose injects prototype runtime secrets from ignored `infra/.env`

### Observability, Testing, And Supply Chain
- Billing Service with HMAC webhook handling
- Admin Service with SSRF vulnerable/fixed demo
- Structured JSON logging (Promtail/Loki compatible)
- Loki/Promtail/Grafana observability stack
- Security alert rules (BOLA, SSRF, webhook, rate-limit)
- Attack simulation scripts (SSRF, token replay, webhook forgery, BOLA, rate-limit)
- OWASP ZAP Active Scan
- RESTler API fuzzing plan
- CI security scan (Bandit, Gitleaks, Trivy)
- MTTD/MTTR measurement

## Quick Start

```bash
# Create the ignored local Compose lab environment file.
bash scripts/bootstrap-lab-env.sh

# Create ignored local demo certificates for Gateway-to-Backend mTLS.
bash demo/mtls/ensure-gateway-backend-certs.sh

# Start all services
docker compose -f infra/docker-compose.yml up -d --build

# If you encounter issues with Keycloak or Gateway, use the clean restart script:
bash fix-and-restart.sh

# Check status
docker compose -f infra/docker-compose.yml ps
```


### Gateway-to-Backend mTLS Default Runtime

The default Compose stack routes Kong to backend Nginx sidecars over
HTTPS/mTLS. The sidecars require Kong's internal client certificate and reject
callers without a valid client certificate.

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
bash tests/security/gateway-backend-mtls-tests.sh
```

Generated certificate material stays under `infra/certs/gateway-backend/` and
is ignored by Git. The legacy `infra/docker-compose.mtls.yml` override is kept
only for backward-compatible evidence commands and should merge cleanly with the
default compose file.

### Run the Frontend Security Dashboard
```bash
python frontend/serve.py
```
Open `http://localhost:3002` in your browser to interactively test BOLA, SSRF,
and webhook rejection paths. The dashboard does not request user passwords or
generate valid webhook signatures in browser JavaScript; obtain lab tokens with
the PKCE/helper scripts and run valid webhook signing from `demo/webhook/`.

Expected services:
- `infra-kong-1`
- `infra-user-mtls-proxy-1`
- `infra-order-mtls-proxy-1`
- `infra-billing-mtls-proxy-1`
- `infra-admin-mtls-proxy-1`
- `infra-user-service-1`
- `infra-order-service-1`
- `infra-billing-service-1`
- `infra-admin-service-1`
- `infra-keycloak-1`
- `infra-vault-1`
- `infra-redis-1`
- `infra-loki-1`
- `infra-promtail-1`
- `infra-grafana-1`
- `infra-webhook-demo-1`

## Service URLs

| Service     | URL                                  |
|-------------|--------------------------------------|
| Kong HTTPS  | https://localhost:8443              |
| Kong Admin  | http://127.0.0.1:8001              |
| Keycloak    | http://localhost:8080               |
| Vault       | http://localhost:8200               |
| Grafana     | http://localhost:3001               |

Redis is internal-only in Docker Compose and is not exposed on a host port.
The legacy plaintext gateway port is disabled and not exposed.
The lab gateway certificate is local/self-signed, so curl examples use `-k`.
Production must use a CA-trusted certificate and normal certificate validation.

## Health Checks

```bash
curl -k https://localhost:8443/api/v1/users/health
curl -k https://localhost:8443/api/v1/orders/health
curl -k https://localhost:8443/api/v1/billing/health
curl -k https://localhost:8443/api/v1/admin/health
```

## Get Tokens

```bash
# User token (alice)
bash demo/auth/get-user-token.sh alice
ALICE_TOKEN=$(cat /tmp/user-token.txt)

# User token (bob)
bash demo/auth/get-user-token.sh bob
BOB_TOKEN=$(cat /tmp/user-token.txt)
```

## Test Auth

```bash
bash tests/auth/test-user-profile.sh
bash tests/auth/test-order-access.sh
```

## Test BOLA

```bash
ALICE_TOKEN=<alice_token> BOB_TOKEN=<bob_token> bash tests/attack/bola-object-access.sh
```

## Test SSRF

```bash
ACCESS_TOKEN=<token> bash tests/attack/ssrf-attack.sh
```

## Test Webhook Security

```bash
set -a
source infra/.env
set +a
bash tests/attack/token-replay.sh
bash tests/attack/webhook-forgery.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

## Test Rate Limiting

```bash
bash tests/attack/rate-limit-trigger.sh
```

## CI Security Scan (Local)

```bash
bash ci/run-local-security-scan.sh
```

## Final Regression

Run the final regression gate before review or merge:

```bash
bash tests/final/main-regression.sh
```

The regression preflight runs `scripts/bootstrap-lab-env.sh` when `infra/.env`
is missing or still contains placeholders. This creates local lab-only values
for Docker Compose and does not commit them.

Secret-management alignment is documented in
`docs/evidence/tv2/vault-lab-secret-bootstrap.md`: `infra/.env` is only a
local compatibility/bootstrap artifact, while production should use Vault HA,
cloud KMS, Secrets Manager, or an equivalent managed secret store.

## Final Evidence Before Packaging

Run this while the project is still inside the real Git repository, before
removing `.git` or creating a zip/package archive:

```bash
bash scripts/generate-final-evidence.sh
```

## MTTD/MTTR Measurement

```bash
bash tests/metrics/measure-mttd-mttr.sh
```

## Gateway Edge Tests

```bash
bash demo/curl/test-gateway-routes.sh
bash demo/curl/test-cors.sh
bash demo/curl/test-rate-limit.sh
bash demo/curl/test-waf-filter.sh
bash demo/curl/test-correlation-id.sh
```

## Stop Services

```bash
docker compose -f infra/docker-compose.yml down
```

## Project Structure

| Path | Purpose |
|------|---------|
| `gateway/` | Kong DB-less gateway configuration |
| `infra/` | Docker Compose lab runtime |
| `idp/` | Keycloak realm and identity-flow docs |
| `vault/` | Vault dev-mode secret-management workflow evidence |
| `services/user/` | User Service (FastAPI) |
| `services/order/` | Order Service (FastAPI) |
| `services/billing/` | Billing Service (FastAPI) |
| `services/admin/` | Admin Service (FastAPI) |
| `observability/` | Loki/Promtail/Grafana configs |
| `demo/auth/` | Token demo scripts |
| `demo/curl/` | Gateway test scripts |
| `demo/webhook/` | Webhook HMAC scripts |
| `frontend/` | Interactive security dashboard |
| `tests/security/` | Security regression suites |
| `tests/metrics/` | MTTD/MTTR and latency metrics |
| `ci/` | Local CI/security scan helpers |
| `.github/workflows/` | GitHub Actions |
| `docs/` | Documentation and evidence |
| `services/openapi.yaml` | Shared API contract |

## Notes

- Do not commit real secrets, private keys, `.env`, `.pem`, or `.key` files.
- Kong OSS is used for gateway-level filtering, not as a full enterprise WAF.
- Keycloak runs in dev mode for this prototype.
- Vault runs in dev mode for this prototype; it demonstrates central secret
  management, but `.env` remains the local Docker Compose bootstrap file.
- For full testing guide see `TESTING_GUIDE.md`.
