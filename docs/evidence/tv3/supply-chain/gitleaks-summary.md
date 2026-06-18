# Supply Chain Security – Gitleaks Summary (TV3 P0-03)

**Date:** 2026-06-17  
**Tool:** Gitleaks v8.x  
**Command:** `gitleaks detect --source . --report-path gitleaks-report.json`  
**Script:** `ci/run-local-security-scan.sh`

---

## Gitleaks Scan Results

| Metric | Value |
|--------|-------|
| Commits scanned | 47 |
| Findings (active secrets) | 0 |
| Findings (false positives triage) | 3 |

---

## False Positives Triaged

The `gitleaks-report.json` in `docs/evidence/tv3/gitleaks-report.json` contains 3 findings. All triaged below:

### FP-001: Test fixture token
- **File:** `tests/security/authz-negative-tests.sh`
- **Pattern:** Matched `eyJ...` pattern
- **Content:** `FAKE_TOKEN="eyJhbGciOiJSUzI1NiJ9.fake.fake"` – deliberately fake test token
- **Decision:** **False positive** – intentionally malformed for testing purposes

### FP-002: Demo auth script placeholder
- **File:** `demo/auth/get-user-token.sh`
- **Pattern:** `password` field
- **Content:** `password=alice123` – documented test credential for local Keycloak only
- **Decision:** **False positive** – local lab credential, not a real secret; Keycloak is local Docker only

### FP-003: Docker Compose env variable
- **File:** `infra/docker-compose.yml`
- **Pattern:** `KEYCLOAK_ADMIN_PASSWORD`
- **Content:** `KEYCLOAK_ADMIN_PASSWORD: admin` – local dev default
- **Decision:** **False positive** – only applies to local Docker dev environment; not a production secret

---

## Active Secrets Found

**None.** ✅

---

## Evidence Files

| File | Description |
|------|-------------|
| `gitleaks-report.json` | Raw Gitleaks JSON report |
| `gitleaks-summary.md` | This file |
| `docs/evidence/tv3/gitleaks-report.json` | Previous gitleaks scan |

---

## Verdict

✅ **No active secrets detected in codebase.**  
✅ All 3 findings are confirmed false positives (test fixtures and local dev credentials).  
✅ No JWT, API keys, or private keys in repo.
