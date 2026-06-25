# Architecture

## Public API Boundary

The public application API is exposed only through Kong:

```text
https://localhost:8443
```

Backend application containers expose port `8443` only inside Docker networks.
Users and tests should not call backend service containers directly.

## Runtime Flow

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

Kong runs in DB-less mode from `gateway/kong.yml`. It terminates the public
HTTPS listener, applies edge controls, and routes to direct HTTPS/mTLS
upstreams:

| Upstream | Kong target |
|---|---|
| User | `https://user-service:8443` |
| Order | `https://order-service:8443` |
| Billing | `https://billing-service:8443` |
| Admin | `https://admin-service:8443` |

## Application Services

| Service | Public routes through Kong | Responsibility |
|---|---|---|
| User | `/api/v1/users/health`, `/api/v1/users/me`, `/api/v1/users/profile` | health and authenticated user profile |
| Order | `/api/v1/orders/*` | order listing, protected order detail, BOLA demonstration path, internal ownership verification |
| Billing | `/api/v1/billing/*`, `/api/v1/webhooks/payment` | checkout, Order ownership verification, signed webhook handling |
| Admin | `/api/v1/admin/*` | maintenance and SSRF demonstration/fixed metadata fetch endpoints |

Each FastAPI service runs uvicorn with its own service certificate, private key,
trusted CA, and required client certificate validation on port `8443`.

## Supporting Services

| Component | Runtime endpoint | Purpose |
|---|---|---|
| Keycloak | `https://keycloak:8443` internal, `https://localhost:8446` local host access | OIDC issuer, realm roles, human users, service clients |
| OPA | `https://opa:8181` | selected policy decisions for service authorization |
| Redis | Docker-internal | webhook nonce TTL storage when enabled |
| Vault | `https://vault:8200` | local persistent secret workflow surface |
| Loki, Promtail, Alertmanager, Grafana | local observability profile | logs, alerts, dashboards |
| Jaeger, OpenTelemetry Collector | local observability profile | tracing |

The expected JWT issuer is:

```text
https://localhost:8446/realms/topic10-sme-api
```

## Network Layout

Application services are attached to internal Docker networks for their
required communication paths. Billing and Order share only the approved
`billing-order-mtls-internal` network for Billing-to-Order ownership
verification.

Kong has one internal network per backend service. Services that call OPA or
Keycloak have dedicated policy and identity networks. This keeps backend egress
constrained to documented runtime dependencies.

## Trust Boundaries

- Client to Kong uses HTTPS at the public gateway.
- Kong to backend services uses direct HTTPS/mTLS on port `8443`.
- Billing to Order ownership verification uses `https://order-service:8443`.
- Backend to Keycloak uses `https://keycloak:8443`.
- Backend to OPA uses `https://opa:8181`.
- Vault defaults to `https://vault:8200`.
- Webhook security combines mTLS, HMAC, timestamp freshness, and nonce replay
  protection.
