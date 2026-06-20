# Kong Edge Gateway

This directory contains the DB-less Kong configuration for the SME API
security prototype. Kong terminates client connections and proxies the stable
API contract without changing application paths.

## Run locally

```bash
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
bash demo/curl/test-gateway-routes.sh
```

The Compose baseline routes to real User, Order, Billing, and Admin backend
services. Gateway-to-Backend mTLS is enforced by local Nginx sidecars in the
default runtime. The standalone webhook demo receiver remains only for focused
HMAC/replay demonstrations.

| Listener | Purpose |
|---|---|
| `https://localhost:8443` | Local HTTPS gateway using Kong's development certificate |
| `http://127.0.0.1:8001` | Kong Admin API, bound to loopback only |

The legacy plaintext gateway listener is disabled and not exposed.

## Public routes

- `/api/v1/users`
- `/api/v1/orders`
- `/api/v1/billing`
- `/api/v1/admin`
- `/api/v1/webhooks`

The gateway applies CORS, correlation IDs, request-size limiting, basic edge
filtering, route-specific rate limits, and HTTPS-only HSTS. Kong OSS is not
presented as a full WAF. See `waf-rules.md` for the exact protection boundary.

## CORS

Allowed origins are `http://localhost:3000`, `http://localhost:5173`, and
`https://app.localhost`. Credentials are disabled. The policy permits the
required authorization, correlation, and webhook headers.

## Integration

Each upstream must expose its route with the public path intact, or `strip_path`
and upstream paths must be updated deliberately. Do not expose the Admin API
outside loopback in the demo environment.
