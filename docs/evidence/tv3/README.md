# TV3 Evidence Index

This directory contains all QA/regression/security evidence produced by TV3.

---

## P0 – Mandatory Evidence

| File | Source Script | What it Proves |
|------|--------------|----------------|
| `p0-01-main-smoke.txt` | `tests/smoke/main-smoke.sh` | All 4 health endpoints, Keycloak, and /users/me work |
| `p0-02-authz-negative-tests.txt` | `tests/security/authz-negative-tests.sh` | Fake/malformed tokens rejected, RBAC enforced, BOLA fixed |
| `p0-03-edge-hardening-tests.txt` | `tests/security/edge-hardening-tests.sh` | TLS, HSTS, CORS, request size limit, rate limit |
| `p0-04-webhook-tests.txt` | `tests/security/webhook-tests.sh` | Valid/invalid/replay webhook behavior |
| `p0-06-security-scan-final-sanitized.txt` | `ci/run-local-security-scan.sh` | Bandit/Trivy/Gitleaks scan results |
| `p0-07-structured-json-log.txt` | Manual verification | Service logs are valid JSON |
| `p0-08-correlation-id-log.txt` | Manual verification | Correlation ID appears in logs |

## P1 – Important Evidence

| File | Source Script | What it Proves |
|------|--------------|----------------|
| `p1-03-fuzz-negative-tests.txt` | `tests/security/fuzz-negative-tests.sh` | Malformed input handled gracefully |

## How to Reproduce

```bash
# Start stack
docker compose -f infra/docker-compose.yml up -d --build

# Generate all evidence
mkdir -p docs/evidence/tv3 docs/evidence/final

bash tests/smoke/main-smoke.sh | tee docs/evidence/tv3/p0-01-main-smoke.txt
bash tests/security/authz-negative-tests.sh | tee docs/evidence/tv3/p0-02-authz-negative-tests.txt
bash tests/security/edge-hardening-tests.sh | tee docs/evidence/tv3/p0-03-edge-hardening-tests.txt
bash tests/security/webhook-tests.sh | tee docs/evidence/tv3/p0-04-webhook-tests.txt
bash tests/security/fuzz-negative-tests.sh | tee docs/evidence/tv3/p1-03-fuzz-negative-tests.txt
bash tests/final/main-regression.sh | tee docs/evidence/final/main-regression-final.txt
```
