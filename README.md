# Capstone Project - Cloud API-Based Network Application Security

## Overview

This project is a prototype for **Cloud API-Based Network Application Security
for Small Company Services** (Topic 10). The goal is to design, implement, and
evaluate a practical API security architecture suitable for a small company.

## Team Members & Responsibilities

| Member | Role | Branch |
|--------|------|--------|
| **TV1** | Edge, Network & Webhook Security Engineer | `feat/tv1-gateway-edge-security` |
| **TV2** | Identity & Core Application Architect | `feat/tv2-idp-authz-core-services` |
| **TV3** | DevSecOps, Observability & Red Team Analyst | `feat/tv3-devsecops-observability-redteam` |

## Architecture

```text
Browser (Frontend UI) / Test Scripts
        │
        ▼
Kong API Gateway (TV1)
  - Routing, CORS, Rate limiting
  - Edge filtering (SQLi/XSS)
  - HTTPS/HSTS, Correlation ID
  - Webhook HMAC header enforcement
        │
        ├──▶ User Service    (TV2) – /api/v1/users/*
        ├──▶ Order Service   (TV2) – /api/v1/orders/*
        ├──▶ Billing Service (TV3) – /api/v1/billing/* (and /webhooks/payment)
        ├──▶ Admin Service   (TV3) – /api/v1/admin/*
        └──▶ Webhook Demo    (TV1) – /api/v1/webhooks/*

Supporting Services:
  Keycloak   (TV2) – OAuth2/OIDC Identity Provider
  Vault      (TV2) – Secret Management
  Redis      (TV3) – Webhook replay nonce TTL store
  Loki       (TV3) – Log Aggregation
  Promtail   (TV3) – Log Collector
  Grafana    (TV3) – Dashboards & Alerting
```

## Security Features

### TV1 – Gateway Edge Security
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

### TV2 – Identity & Authorization
- Keycloak OAuth2/OIDC realm (`topic10-sme-api`)
- Authorization Code + PKCE for user login
- Client Credentials for service-to-service
- JWT validation with JWKS (RS256)
- RBAC backend authorization (roles: user, admin, billing-service)
- BOLA vulnerable/fixed demo (Order Service)
- HashiCorp Vault dev-mode secret-path and rotation workflow evidence; local
  Docker Compose injects prototype runtime secrets from ignored `infra/.env`

### TV3 – DevSecOps & Observability
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
Open `http://localhost:3002` in your browser to interactively test BOLA, SSRF, and Webhooks.

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
| Kong HTTP   | http://localhost:8000               |
| Kong HTTPS  | https://localhost:8443              |
| Kong Admin  | http://127.0.0.1:8001              |
| Keycloak    | http://localhost:8080               |
| Vault       | http://localhost:8200               |
| Grafana     | http://localhost:3001               |

Redis is internal-only in Docker Compose and is not exposed on a host port.

## Health Checks

```bash
curl http://localhost:8000/api/v1/users/health
curl http://localhost:8000/api/v1/orders/health
curl http://localhost:8000/api/v1/billing/health
curl http://localhost:8000/api/v1/admin/health
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

## TV1 Tests (Gateway Edge)

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

| Path | Owner | Purpose |
|------|-------|---------|
| `gateway/` | TV1 | Kong configuration |
| `infra/` | All | Docker Compose |
| `idp/` | TV2 | Keycloak IDP docs & realm |
| `vault/` | TV2 | Secret management |
| `services/user/` | TV2 | User Service (FastAPI) |
| `services/order/` | TV2 | Order Service (FastAPI) |
| `services/billing/` | TV3 | Billing Service (FastAPI) |
| `services/admin/` | TV3 | Admin Service (FastAPI) |
| `observability/` | TV3 | Loki/Grafana configs |
| `demo/auth/` | TV2 | Token demo scripts |
| `demo/curl/` | TV1 | Gateway test scripts |
| `demo/webhook/` | TV1 | Webhook HMAC scripts |
| `frontend/` | All | Interactive Red Team Dashboard |
| `tests/auth/` | TV2 | Auth test scripts |
| `tests/attack/` | TV3 | Attack simulation |
| `tests/zap/` | TV3 | ZAP scan |
| `tests/restler/` | TV3 | API fuzzing |
| `tests/metrics/` | TV3 | MTTD/MTTR |
| `ci/` | TV3 | CI security scan |
| `.github/workflows/` | TV3 | GitHub Actions |
| `docs/` | All | Documentation |
| `services/openapi.yaml` | TV2 | Shared API contract |

## Notes

- Do not commit real secrets, private keys, `.env`, `.pem`, or `.key` files.
- Kong OSS is used for gateway-level filtering, not as a full enterprise WAF.
- Keycloak runs in dev mode for this prototype.
- Vault runs in dev mode for this prototype; it demonstrates central secret
  management, but `.env` remains the local Docker Compose bootstrap file.
- For full testing guide see `TESTING_GUIDE.md`.
