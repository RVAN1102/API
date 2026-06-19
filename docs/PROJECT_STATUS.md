# Project Status

**Last updated:** 2026-06-19

---

## Current `main` Status

`main` is the **daily stable checkpoint** for the team.

### What's in `main`:

- ✅ Docker Compose stack (Kong, Keycloak, Vault, Grafana, Loki/Promtail, 4 services)
- ✅ Kong Gateway routes to user/order/billing/admin services
- ✅ 4 health endpoints via Kong → 200
- ✅ Keycloak realm/client/user/token flow
- ✅ JWT validation (RS256 with JWKS)
- ✅ RBAC user/admin
- ✅ BOLA vulnerable (intentional demo) + fixed endpoints
- ✅ Admin/Billing auth bypass fixed
- ✅ Webhook HMAC-SHA256 + nonce/timestamp
- ✅ TLS 1.3, HSTS, CORS, rate limit, request size limit
- ✅ Structured JSON logs (user/order services)
- ✅ Security scan (Bandit/Trivy/Gitleaks) – python-jose CVE fixed
- ✅ TV1 frontend dashboard at http://localhost:3002
- ✅ QA hardening pass merged
- ✅ 10 known issues fixed/triaged

### Known Limitations:

- ✅ MFA: runtime Keycloak required actions are configured for demo human users (`alice`, `bob`, `admin01` must complete `CONFIGURE_TOTP`; CI automation uses dedicated lab accounts)
- ✅ Webhook mTLS: implemented and evidenced at Kong (valid client cert accepted, missing cert rejected)
- ✅ Gateway-to-backend mTLS: enforced by default through Nginx sidecars in `infra/docker-compose.yml`; backend S2S ownership still uses short-lived Keycloak Client Credentials
- ✅ OPA: policy decision point and backend enforcement evidenced for selected authorization paths
- ⚠️ Keycloak runs in dev mode (not production-grade)
- ⚠️ Vault runs in dev mode

---

## Branch Ownership

| Member | Responsibility | Merge early when | Merge end-of-day when |
|--------|---------------|------------------|-----------------------|
| TV1 | Gateway, Edge, Webhook | Fix gateway/webhook runtime, mTLS, timestamp | Only evidence/summary |
| TV2 | Identity, Auth, Authz, Core API | Fix Keycloak/JWT/RBAC/BOLA/Billing auth | Only evidence/authz model |
| TV3 | QA, Regression, Observability, DevSecOps | Create shared test scripts, fix CI/test | Security scan/evidence/docs |

---

## Merge Rules

1. **Never push directly to `main`** – always use a branch + merge.
2. **Before merging**, run at minimum:
   ```bash
   bash tests/smoke/main-smoke.sh
   ```
3. **For large or runtime changes**, run:
   ```bash
   bash tests/final/main-regression.sh
   ```
4. **Do not merge** if:
   - Any health endpoint returns non-200
   - `/users/me` with Alice token fails
   - There are unresolved conflicts
   - Tests pass falsely (silencing errors)
   - Real secrets are in evidence files
