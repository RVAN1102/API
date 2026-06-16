# Testing Guide – TV3 QA Regression & Security

This document describes how to start the system, run tests, and interpret results.

---

## 1. Prerequisites

- **Docker Engine** on Linux or **Docker Desktop** on Windows/macOS installed and running
- **Git Bash** (on Windows) or any bash-compatible shell
- **curl** available in PATH
- **python3** available in PATH (for token scripts and payload generation)
- **openssl** (optional, for TLS tests)

---

## 2. Start the Stack

```bash
cd API

# Start all services
docker compose -f infra/docker-compose.yml up -d --build

# Wait until services are running; services with healthchecks should become healthy (~60-90 seconds for Keycloak)
docker compose -f infra/docker-compose.yml ps
```

If Keycloak or other services are unhealthy:

```bash
# Clean restart
bash fix-and-restart.sh

# Or force recreate
docker compose -f infra/docker-compose.yml up -d --build --force-recreate
```

### Expected services

| Container | Port | Purpose |
|-----------|------|---------|
| `infra-kong-1` | 8000 (HTTP), 8443 (HTTPS) | API Gateway |
| `infra-keycloak-1` | 8080 | Identity Provider |
| `infra-user-service-1` | internal | User API |
| `infra-order-service-1` | internal | Order API |
| `infra-billing-service-1` | internal | Billing API |
| `infra-admin-service-1` | internal | Admin API |
| `infra-webhook-demo-1` | internal | Webhook receiver |
| `infra-vault-1` | 8200 | Secret management |
| `infra-loki-1` | internal | Log aggregation |
| `infra-promtail-1` | internal | Log collector |
| `infra-grafana-1` | 3001 | Dashboards |

---

## 3. Quick Health Check

```bash
curl http://localhost:8000/api/v1/users/health
curl http://localhost:8000/api/v1/orders/health
curl http://localhost:8000/api/v1/billing/health
curl http://localhost:8000/api/v1/admin/health
```

All should return `200` with a JSON body.

---

## 4. Run Tests

### 4.1. Smoke Test (mandatory before every merge)

```bash
bash tests/smoke/main-smoke.sh
```

Tests: 4 health endpoints + Keycloak discovery + Alice token + /users/me

### 4.2. Authz Negative Tests

```bash
bash tests/security/authz-negative-tests.sh
```

Tests: fake tokens rejected, admin RBAC enforced, BOLA fixed, billing auth

### 4.3. Edge Hardening Tests

```bash
bash tests/security/edge-hardening-tests.sh
```

Tests: TLS 1.3/1.2, HSTS, CORS, evil origin, request size limit, rate limit

### 4.4. Webhook Tests

```bash
bash tests/security/webhook-tests.sh
```

Tests: valid webhook, invalid signature, replay detection

### 4.5. Fuzz / Negative Input Tests

```bash
bash tests/security/fuzz-negative-tests.sh
```

Tests: empty body, wrong types, missing fields, SQLi/XSS, invalid JSON, missing headers

### 4.6. Full Regression (runs all of the above)

```bash
bash tests/final/main-regression.sh
```

### 4.7. Security Scan (Bandit / Trivy / Gitleaks)

```bash
bash ci/run-local-security-scan.sh
```

---

## 5. Save Evidence

After running tests, pipe output to evidence files:

```bash
mkdir -p docs/evidence/tv3 docs/evidence/final

bash tests/smoke/main-smoke.sh | tee docs/evidence/tv3/p0-01-main-smoke.txt
bash tests/security/authz-negative-tests.sh | tee docs/evidence/tv3/p0-02-authz-negative-tests.txt
bash tests/security/edge-hardening-tests.sh | tee docs/evidence/tv3/p0-03-edge-hardening-tests.txt
bash tests/security/webhook-tests.sh | tee docs/evidence/tv3/p0-04-webhook-tests.txt
bash tests/security/fuzz-negative-tests.sh | tee docs/evidence/tv3/p1-03-fuzz-negative-tests.txt
bash tests/final/main-regression.sh | tee docs/evidence/final/main-regression-final.txt
```

---

## 6. Frontend Dashboard

```bash
python frontend/serve.py
```

Open `http://localhost:3002` for the interactive security dashboard.

---

## 7. Get Tokens (for manual testing)

```bash
bash demo/auth/get-user-token.sh alice
ALICE_TOKEN=$(cat /tmp/user-token.txt)

bash demo/auth/get-user-token.sh bob
BOB_TOKEN=$(cat /tmp/user-token.txt)

bash demo/auth/get-user-token.sh admin01
ADMIN_TOKEN=$(cat /tmp/user-token.txt)
```

---

## 8. Common Issues

### Keycloak shows "unhealthy" but OIDC discovery returns 200

This is normal during startup. Keycloak's `/health/ready` may lag behind the actual realm availability. Wait 30-60 seconds after container starts.

### Rate limit test fails with no 429

The rate limit counter may not have reset. Wait 60 seconds or restart Kong:

```bash
docker compose -f infra/docker-compose.yml restart kong
```

### TLS tests skip on Windows

TLS tests require `openssl` command. Install OpenSSL for Windows or run in Git Bash which includes OpenSSL.

### Token errors

If token scripts fail, check that Keycloak is healthy:

```bash
curl http://localhost:8080/realms/topic10-sme-api/.well-known/openid-configuration
```

---

## 9. Stop Services

```bash
docker compose -f infra/docker-compose.yml down

# To also remove volumes (clean state):
docker compose -f infra/docker-compose.yml down -v
```

## Rate-limit test note

`tests/security/edge-hardening-tests.sh` intentionally triggers HTTP 429 on a sensitive endpoint. Running smoke/regression immediately after that can fail with `429` until Kong's rate-limit window resets.

Recommended reset:

    docker compose -f infra/docker-compose.yml restart kong
    sleep 15
