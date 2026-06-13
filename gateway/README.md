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

The Compose baseline uses Prism to mock the non-webhook routes from
`services/openapi.yaml`, because the real service implementations are owned by
other team members. A separate webhook receiver PoC demonstrates HMAC and
replay verification. Replace demo upstreams with real service hosts when they
are available; keep the public paths unchanged.

| Listener | Purpose |
|---|---|
| `http://localhost:8000` | Local HTTP gateway testing |
| `https://localhost:8443` | Local HTTPS termination using Kong's development certificate |
| `http://127.0.0.1:8001` | Kong Admin API, bound to loopback only |

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

Before replacing Prism, ensure each upstream exposes its route with the public
path intact or update `strip_path` and upstream paths deliberately. Do not
expose the Admin API outside loopback in the demo environment.
