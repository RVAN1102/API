# Kong Edge Gateway

This directory contains the DB-less Kong configuration for the SME API security
runtime. Kong terminates client HTTPS on `https://localhost:8443`, applies edge
controls, and proxies the stable API contract without changing application
paths.

## Runtime

```bash
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
bash demo/curl/test-gateway-routes.sh
```

The default runtime routes to real User, Order, Billing, and Admin backend
services. Gateway-to-backend traffic uses direct HTTPS/mTLS to backend port
`8443`.

| Listener | Purpose |
|---|---|
| `https://localhost:8443` | Local HTTPS application gateway |
| `https://127.0.0.1:8445` | Kong Admin API, bound to loopback only |

## Public Routes

- `/api/v1/users`
- `/api/v1/orders`
- `/api/v1/billing`
- `/api/v1/admin`
- `/api/v1/webhooks`

The gateway applies CORS, correlation IDs, request-size limiting, basic edge
filtering, route-specific rate limits, and HTTPS-only HSTS. Kong OSS is not
presented as a full WAF. See `waf-rules.md` for the exact protection boundary.

## Upstreams

| Service | Upstream |
|---|---|
| User | `https://user-service:8443` |
| Order | `https://order-service:8443` |
| Billing | `https://billing-service:8443` |
| Admin | `https://admin-service:8443` |

Kong presents the internal `kong-client` certificate to each backend and
verifies backend server certificates with the internal CA.

## CORS

Allowed origins are local development HTTPS origins and `https://app.localhost`.
Credentials are disabled. The policy permits the required authorization,
correlation, and webhook headers.

## Integration

Each upstream must expose its route with the public path intact, or
`strip_path` and upstream paths must be updated deliberately. Do not expose the
Admin API outside loopback in the demo environment.
