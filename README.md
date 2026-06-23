# SME Cloud API Security

This repository is a local Docker Compose implementation of a secured
cloud-style API for small company services. The final runtime is HTTPS-first:
application traffic enters through Kong on `https://localhost:8443`, and Kong
connects directly to every FastAPI backend over HTTPS/mTLS on backend port
`8443`.

The local certificates are lab-generated and self-signed, so local curl
examples use `-k`.

## Architecture Summary

```text
client or test runner
    |
    | HTTPS
    v
Kong API Gateway :8443
    |
    | direct HTTPS/mTLS
    v
User, Order, Billing, Admin FastAPI services :8443
```

Supporting services:

| Component | Purpose |
|---|---|
| Keycloak | OIDC realm, human users, realm roles, service clients |
| OPA | selected authorization policy decisions over HTTPS |
| Redis | webhook nonce TTL storage when enabled |
| Vault | lab-local dev-mode secret workflow surface over HTTPS |
| Loki, Promtail, Alertmanager, Grafana | local logs, alerting, dashboards |
| Jaeger, OpenTelemetry Collector | local tracing |

Control-plane and observability endpoints are lab-local. The application API
surface remains `https://localhost:8443`.

## Transport Security Summary

- Client-to-Kong traffic uses HTTPS on `https://localhost:8443`.
- Kong-to-backend traffic uses direct HTTPS/mTLS to:
  - `https://user-service:8443`
  - `https://order-service:8443`
  - `https://billing-service:8443`
  - `https://admin-service:8443`
- Backend services run uvicorn with TLS/mTLS directly on port `8443`.
- Billing verifies Order ownership through `https://order-service:8443`.
- Billing's Order client material is:
  - `/etc/internal-tls/ca.crt`
  - `/etc/internal-tls/billing-client.crt`
  - `/etc/internal-tls/billing-client.key`
- Backend services reach Keycloak through `https://keycloak:8443`.
- Backend services expect JWT issuer
  `https://localhost:8446/realms/topic10-sme-api`.
- Backend services reach OPA through `https://opa:8181`.
- Vault's default runtime URL is `https://vault:8200`.

## Authn And Authz Summary

Keycloak provides the `topic10-sme-api` realm, Authorization Code + PKCE for
the public web client, demo human users, realm roles, and confidential service
clients. Backend services validate JWTs themselves and enforce token-client
binding, expiration, issuer, and role requirements.

OPA is used for selected least-privilege authorization decisions in Order,
Billing, and Admin. Billing uses a dedicated service client for Order ownership
verification, while Admin uses its own service client for maintenance paths.
The documented service clients are intentionally scoped to their own duties and
are rejected from unrelated service paths by the regression suite.

## Webhook Security Summary

Payment webhooks require all of the following:

- HMAC-SHA256 signature over timestamp, nonce, and raw body.
- Timestamp freshness.
- Nonce replay protection.
- Client certificate verification propagated from Kong to Billing.

Replay protection uses a TTL nonce store. The final regression path expects
replayed nonces, stale timestamps, missing headers, invalid signatures, and
missing client certificates to fail closed.

## Runtime Hardening And Egress

Network egress is constrained with Docker internal networks. Billing and Order
share only the approved direct HTTPS/mTLS network
`billing-order-mtls-internal` for ownership verification.

Backend services and OPA are expected to run with:

- `no-new-privileges`
- `cap_drop: [ALL]`
- `read_only: true`
- `tmpfs: /tmp`

Keycloak, Kong, and Vault are intentionally not read-only because they need
writable runtime state for realm import/runtime files, gateway runtime state,
and dev-mode Vault storage or lock behavior.

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

## Evidence And Test Commands

| Purpose | Command | Expected result |
|---|---|---|
| No plaintext transport gate | `bash tests/security/no-plaintext-transport-tests.sh` | no-plaintext transport gate passed |
| Gateway-backend mTLS | `bash tests/security/gateway-backend-mtls-tests.sh` | direct HTTPS/mTLS health and certificate rejection checks pass |
| S2S ownership | `bash tests/security/s2s-ownership-tests.sh` | `25/25` |
| OPA authorization | `bash tests/security/opa-authz-tests.sh` | `22/22` |
| Webhook security | `bash tests/security/webhook-tests.sh` | `7/7` |
| Network egress control | `bash tests/security/network-egress-control-tests.sh` | `28/28` |
| Container runtime hardening | `bash tests/security/container-runtime-hardening-tests.sh` | passed |

Kong uses local rate-limit counters. Restart Kong between rate-limit-sensitive
suites when rerunning tests manually to avoid false HTTP `429` responses.

See `TESTING_GUIDE.md` for the broader test catalog and setup notes.

## Documentation Map

- `docs/README.md` maps the technical documents.
- `docs/technical/` describes the current architecture and controls.
- `docs/evidence/README.md` indexes curated evidence summaries.
- `docs/evidence/results/` contains concise evidence summaries grouped by
  requirement.

Do not commit `.env`, private keys, `.p12` files, generated certificates,
tokens, `.artifacts`, raw secrets, `__pycache__`, or `.pyc`.
