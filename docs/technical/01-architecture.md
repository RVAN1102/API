# Architecture

## Public API Boundary

The public application API is exposed only through Kong:

```text
https://localhost:8443
```

Backend application containers expose ports only inside Docker networks. Users
and tests should not call backend service containers directly.

## Compose Services

`docker compose -f infra/docker-compose.yml config --services` renders:

```text
loki
promtail
user-service
user-service
opa
order-service
admin-service
redis
billing-service
billing-service
admin-service
order-service
kong
vault
webhook-demo
alertmanager
jaeger
otel-collector
grafana
keycloak
```

## Application Services

| Service | Public routes through Kong | Responsibility |
|---|---|---|
| User | `/api/v1/users/health`, `/api/v1/users/me`, `/api/v1/users/profile` | health and authenticated user profile |
| Order | `/api/v1/orders/*` | order listing, protected order detail, BOLA demonstration path, internal ownership verification |
| Billing | `/api/v1/billing/*`, `/api/v1/webhooks/payment` | checkout, Order ownership verification, signed webhook handling |
| Admin | `/api/v1/admin/*` | maintenance and SSRF demonstration/fixed metadata fetch endpoints |

## Gateway

Kong runs in DB-less mode from `gateway/kong.yml`. It terminates the public TLS
listener, applies edge controls, and routes to direct HTTPS/mTLS upstreams:

| Upstream | Kong target |
|---|---|
| User | `https://user-service:8443` |
| Order | `https://order-service:8443` |
| Billing | `https://billing-service:8443` |
| Admin | `https://admin-service:8443` |
| Webhook demo container | Docker-internal `webhook-demo:8080` |

## Supporting Services

| Component | Purpose |
|---|---|
| Keycloak | local OIDC issuer, realm roles, human users, service clients |
| OPA | selected policy decisions for service authorization |
| Redis | webhook nonce TTL storage |
| Vault | local dev-mode secret workflow surface |
| Loki, Promtail, Alertmanager, Grafana | local logs, alerts, dashboards |
| Jaeger, OpenTelemetry Collector | local tracing |

## Local Control Plane

These endpoints are not public application APIs:

| Component | URL |
|---|---|
| Kong Admin API | `http://127.0.0.1:8001` |
| Keycloak | `http://localhost:8080` |
| Vault | `http://localhost:8200` |
| Grafana | `http://localhost:3001` |

## Trust Boundaries

- Client to Kong uses HTTPS/TLS at the public gateway.
- Kong to backends uses gateway-backend direct HTTPS/mTLS upstreams.
- Billing to Order ownership verification uses `https://order-service:8443`.
- Webhook uses HMAC timestamp/nonce validation plus mTLS client certificate.
- Keycloak tokens and selected OPA decisions enforce identity and authorization.

mTLS coverage is limited to those scoped paths.

