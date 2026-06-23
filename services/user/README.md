# User Service

## Overview

FastAPI-based User service for authenticated profile endpoints. In the Compose
runtime it listens directly with uvicorn TLS/mTLS on port `8443`.

## Endpoints

| Method | Path | Auth required | Description |
|---|---|---|---|
| GET | `/api/v1/users/health` | No | Health check |
| GET | `/api/v1/users/me` | Yes | Current user identity |
| GET | `/api/v1/users/profile` | Yes | Full user profile from JWT |

## Authentication

Protected endpoints require:

```text
Authorization: Bearer <access_token>
```

Tokens must be issued by Keycloak realm `topic10-sme-api` with issuer
`https://localhost:8446/realms/topic10-sme-api`.

The service reaches Keycloak through `https://keycloak:8443` and trusts the
internal CA mounted at `/etc/internal-tls/ca.crt`.

## Runtime

Compose starts the service with:

```text
uvicorn main:app --host 0.0.0.0 --port 8443 --ssl-certfile ... --ssl-keyfile ... --ssl-ca-certs ... --ssl-cert-reqs 2
```

Start via Docker Compose:

```bash
docker compose -f infra/docker-compose.yml up -d user-service
```

Public checks should go through Kong:

```bash
curl -k https://localhost:8443/api/v1/users/health
curl -k https://localhost:8443/api/v1/users/me \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "X-Correlation-ID: test-001"
```
