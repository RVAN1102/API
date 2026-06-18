# Testing Guide – Capstone API Security (Topic 10)

## Prerequisites

1. **Docker Desktop** running
2. **Git Bash** (for running `.sh` scripts on Windows)
3. Project cloned from GitHub

---

## 1. Start the Stack

```bash
cp infra/.env.example infra/.env

# Edit infra/.env and set at least:
#   BILLING_SERVICE_CLIENT_SECRET
#   ADMIN_SERVICE_CLIENT_SECRET
#   WEBHOOK_SECRET

docker compose -f infra/docker-compose.yml up -d --build

# If Keycloak fails or you encounter Network Errors, use the clean restart script:
# bash fix-and-restart.sh

docker compose -f infra/docker-compose.yml ps
```

Expected services (all must show `healthy` or `running`):
```
infra-kong-1
infra-user-service-1
infra-order-service-1
infra-billing-service-1
infra-admin-service-1
infra-keycloak-1
infra-vault-1
infra-loki-1
infra-promtail-1
infra-grafana-1
infra-webhook-demo-1
```

> [!NOTE]
> Keycloak takes ~60 seconds to start. Kong waits for real services to be healthy before starting.
> If Kong fails to start, wait 30 seconds and run `docker compose -f infra/docker-compose.yml restart kong`.

---

## 2. Health Checks

```bash
curl http://localhost:8000/api/v1/users/health
curl http://localhost:8000/api/v1/orders/health
curl http://localhost:8000/api/v1/billing/health
curl http://localhost:8000/api/v1/admin/health
```

Expected response for each:
```json
{"status": "ok", "service": "<service-name>"}
```

---

## 3. Get Access Tokens (TV2)

> [!IMPORTANT]
> Wait for Keycloak to be fully up (`http://localhost:8080` accessible) before running these.

```bash
# Get Alice token (role: user)
bash demo/auth/get-user-token.sh alice
ALICE_TOKEN=$(cat /tmp/user-token.txt)

# Get Bob token (role: user)
bash demo/auth/get-user-token.sh bob
BOB_TOKEN=$(cat /tmp/user-token.txt)

# Get Admin token (role: user + admin)
bash demo/auth/get-user-token.sh admin01
ADMIN_TOKEN=$(cat /tmp/user-token.txt)
```

---

## 4. Test User API (TV2)

```bash
# Run automated tests
bash tests/auth/test-user-profile.sh

# With token
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/auth/test-user-profile.sh
```

Manual tests:
```bash
# Public endpoint
curl http://localhost:8000/api/v1/users/health

# Protected /me (with token)
curl http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "X-Correlation-ID: test-me-001"

# No token → 401
curl http://localhost:8000/api/v1/users/me
```

---

## 5. Test Order API (TV2)

```bash
# Run automated tests
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/auth/test-order-access.sh
```

Manual tests:
```bash
# Health
curl http://localhost:8000/api/v1/orders/health

# List orders (alice sees her orders)
curl http://localhost:8000/api/v1/orders \
  -H "Authorization: Bearer ${ALICE_TOKEN}"

# Get alice's order
curl "http://localhost:8000/api/v1/orders/ord-alice-1001" \
  -H "Authorization: Bearer ${ALICE_TOKEN}"
```

---

## 6. Test BOLA Demo (TV2)

```bash
# Run BOLA attack simulation
ALICE_TOKEN="${ALICE_TOKEN}" BOB_TOKEN="${BOB_TOKEN}" bash tests/attack/bola-object-access.sh
```

Expected results:
| Test | Expected |
|------|----------|
| Alice → Bob's order `/vulnerable` | **200** (BOLA flaw) |
| Alice → Bob's order `/fixed` | **403** (blocked) |
| Bob → Bob's order `/fixed` | **200** (owner allowed) |
| No token → `/fixed` | **401** |

---

## 7. Test Billing Service (TV3)

```bash
# Health
curl http://localhost:8000/api/v1/billing/health

# Checkout
curl -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: billing-test-001" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'
```

---

## 8. Test Admin Service + SSRF (TV3)

```bash
# Run SSRF attack simulation
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/attack/ssrf-attack.sh
```

Manual tests:
```bash
# SSRF vulnerable → 200 (fetches anything)
curl -X POST http://localhost:8000/api/v1/admin/metadata-fetch/vulnerable \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}'

# SSRF fixed → 403 (blocked)
curl -X POST http://localhost:8000/api/v1/admin/metadata-fetch/fixed \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}'
```

---

## 9. Test Webhook Security (TV1 + TV3)

```bash
# Token replay and webhook forgery
bash tests/attack/token-replay.sh

# Webhook forgery
WEBHOOK_SECRET="dev-webhook-secret-change-me" bash tests/attack/webhook-forgery.sh
```

Expected:
- Wrong signature → **401**
- Expired timestamp → **403**
- Replayed nonce → **403**
- Valid webhook → **200**

---

## 10. Test Rate Limiting (TV1)

```bash
bash tests/attack/rate-limit-trigger.sh
```

Expected: HTTP **429** after 10+ requests to `/api/v1/users`.

---

## 11. View Grafana Dashboard (TV3)

1. Open **http://localhost:3001**
2. Login: `admin` / `admin`
3. Navigate: **Dashboards → API Security → API Security Overview**
4. Run attack scripts and watch security events appear in real time

---

## 12. Initialize Vault (TV2)

```bash
bash vault/scripts/init-dev-vault.sh
```

Access Vault UI: **http://localhost:8200**  
Token: `dev-root-token` (dev mode only)

---

## 13. PKCE Flow Demo (TV2)

```bash
# Generate authorization URL
bash demo/auth/pkce-token-request.sh url
```

Follow the printed URL in a browser to complete the PKCE flow.

---

## 14. CI Security Scan (TV3)

```bash
# Install bandit first
pip install bandit

# Run local scan (gitleaks and trivy optional)
bash ci/run-local-security-scan.sh
```

Results saved to `docs/evidence/tv3/security-scan-local.txt`.

---

## Final Regression Gate

Run this before review or merge:

```bash
bash tests/final/main-regression.sh
```

Expected result: `Suites passed: 9`, `Suites failed: 0`.

---

## 15. MTTD/MTTR Measurement (TV3)

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/metrics/measure-mttd-mttr.sh
```

Results saved to:
- `docs/evidence/tv3/mttd-mttr-results.csv`
- `docs/evidence/tv3/mttd-mttr-analysis.md`

---

## 16. TV1 Gateway Tests

```bash
# Test all routes
bash demo/curl/test-gateway-routes.sh

# Test CORS
bash demo/curl/test-cors.sh

# Test rate limiting
bash demo/curl/test-rate-limit.sh

# Test WAF edge filter
bash demo/curl/test-waf-filter.sh

# Test HTTPS + HSTS (requires Docker curl)
docker run --rm curlimages/curl:latest --insecure --include \
  https://host.docker.internal:8443/api/v1/users/health
```

---

## 17. Stop Stack

```bash
docker compose -f infra/docker-compose.yml down
docker compose -f infra/docker-compose.yml down -v  # also remove volumes
```

---

## Troubleshooting

### Kong fails to start
Kong depends on all 4 services being healthy. If a service fails to build:
```bash
docker compose -f infra/docker-compose.yml logs user-service
docker compose -f infra/docker-compose.yml logs order-service
```

### Keycloak not ready / Network Error / Failed to fetch
If you get a "Failed to fetch" error on the frontend or `exit 1` when getting a token, Keycloak is down or its database is out of sync.
Run the clean restart script:
```bash
bash fix-and-restart.sh
```

### Token verification fails (503 idp_unavailable)
The user/order services try to reach `http://keycloak:8080` (internal Docker name).
If Keycloak is not up yet, wait and retry. The JWKS cache will be populated on the next request.

### Rate limit resets
Rate limits reset each minute. If you want to trigger 429 again, wait 60 seconds.

### Windows: Python path issue for webhook scripts
```bash
export PYTHON_BIN=/c/Users/duynh/AppData/Local/Programs/Python/Python313/python.exe
```
