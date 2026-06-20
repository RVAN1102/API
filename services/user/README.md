# User Service (TV2)

## Overview

FastAPI-based User Service providing authenticated user profile endpoints.

## Endpoints

| Method | Path                    | Auth Required | Description                |
|--------|-------------------------|---------------|----------------------------|
| GET    | /api/v1/users/health    | No            | Health check               |
| GET    | /api/v1/users/me        | Yes (Bearer)  | Current user identity      |
| GET    | /api/v1/users/profile   | Yes (Bearer)  | Full user profile from JWT |

## Authentication

All protected endpoints require:
```
Authorization: Bearer <access_token>
```

Token must be issued by Keycloak realm `topic10-sme-api`.

## Run Locally

```bash
cd services/user
pip install -r requirements.txt
KEYCLOAK_URL=http://localhost:8080 uvicorn main:app --port 8001
```

## Run via Docker Compose

```bash
docker compose -f infra/docker-compose.yml up -d user-service
```

## Test

```bash
# Health check (no token)
curl https://localhost:8443/api/v1/users/health

# Protected (requires token)
curl https://localhost:8443/api/v1/users/me \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "X-Correlation-ID: test-001"
```
