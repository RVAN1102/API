# Project Status

**Last updated:** 2026-06-21

---

## Current Baseline Status

The current baseline is defined by `tests/final/main-regression.sh` and the
authoritative evidence index at
`docs/evidence/final/AUTHORITATIVE_EVIDENCE_INDEX.md`.
Canonical URL/security scope is defined in
`docs/runbooks/url-and-security-scope.md`.

### Implemented And Evidenced

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
- ✅ Frontend security dashboard at http://localhost:3002
- ✅ Container runtime hardening and OpenAPI/excessive-data contract tests are integrated
- ✅ Final regression gate currently runs 12 suites

### Prototype Boundaries

- ✅ MFA: runtime Keycloak required actions are configured for demo human users (`alice`, `bob`, `admin01` must complete `CONFIGURE_TOTP`; CI automation uses dedicated lab accounts)
- ✅ Webhook mTLS: implemented and evidenced at Kong (valid client cert accepted, missing cert rejected)
- ✅ Gateway-to-backend mTLS: enforced by default through Nginx sidecars in `infra/docker-compose.yml`
- ✅ Billing-to-Order S2S: ownership verification uses the Order mTLS sidecar plus short-lived `billing-service-client` Client Credentials
- ✅ OPA: policy decision point and backend enforcement evidenced for selected authorization paths
- ✅ Public API endpoint is `https://localhost:8443`; HTTP Kong Admin,
  Keycloak, Vault, and Grafana URLs are lab-local control-plane/observability
  endpoints only
- ⚠️ Keycloak runs in dev mode (not production-grade)
- ⚠️ Vault runs in dev mode
- ⚠️ This is a lab/prototype baseline with production-oriented controls, not a fully managed production deployment

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
