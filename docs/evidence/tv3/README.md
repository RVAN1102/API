# TV3 Evidence Index (Updated)

This directory contains all QA/regression/security evidence produced by TV3 (Huy).

**Last updated:** 2026-06-18

---

## P0 – Core Evidence (Mandatory)

### P0-01: OWASP ZAP Active Scan

| File | Script | Proves |
|------|--------|--------|
| `.artifacts/test-runs/tv3/zap/zap-active-summary.md` | `tests/security/zap-active-scan.sh` | Rerunnable OpenAPI active scan summary |
| `.artifacts/test-runs/tv3/zap/zap-active-run.log` | `tests/security/zap-active-scan.sh` | Runtime scan log |
| `.artifacts/test-runs/tv3/zap/zap-active-report.html` | `tests/security/zap-active-scan.sh` | Runtime HTML report |
| `.artifacts/test-runs/tv3/zap/zap-active-report.json` | `tests/security/zap-active-scan.sh` | Runtime JSON report |

### P0-02: API Fuzzing

| File | Script | Proves |
|------|--------|--------|
| `.artifacts/test-runs/tv3/fuzzing/fuzzing-run.log` | `tests/security/run-fuzzing.sh` | Runtime negative-input log |
| `.artifacts/test-runs/tv3/fuzzing/fuzzing-findings.json` | `tests/security/run-fuzzing.sh` | Runtime JSON findings |

### P0-03: Supply Chain Security

| File | Script | Proves |
|------|--------|--------|
| `supply-chain/bandit-summary.md` | `ci/run-local-security-scan.sh` | SAST: 0 HIGH severity |
| `supply-chain/bandit-report.json` | `ci/run-local-security-scan.sh` | SAST JSON report |
| `supply-chain/sca-summary.md` | `ci/run-local-security-scan.sh` | SCA: 0 CRITICAL vulnerabilities |
| `supply-chain/sca-report.txt` | `ci/run-local-security-scan.sh` | Trivy table output |
| `supply-chain/gitleaks-summary.md` | `ci/run-local-security-scan.sh` | Superseded Gitleaks claim; points to post-purge evidence |
| `supply-chain/gitleaks-report-after-secret-purge.json` | `ci/run-local-security-scan.sh` | Current tracked/non-ignored package Gitleaks JSON (`[]`) |
| `supply-chain/gitleaks-secret-purge-summary.md` | `tests/security/verify-no-tracked-secrets.sh` | Secret purge verification and scope |
| `supply-chain/sbom-cyclonedx.json` | `scripts/security/generate-sbom.sh` | SBOM CycloneDX 1.4 |
| `supply-chain/sbom-spdx.json` | `scripts/security/generate-sbom.sh` | SBOM SPDX 2.3 |
| `supply-chain/sbom-summary.md` | `scripts/security/generate-sbom.sh` | SBOM summary |
| `supply-chain/cosign-signing-summary.md` | `scripts/security/cosign-sign.sh` | Cosign signing/readiness summary |
| `.artifacts/test-runs/tv3/supply-chain/cosign-verify-output.txt` | `scripts/security/cosign-sign.sh` | Runtime Cosign output for the selected mode |

### P0-04: Observability

| File | Proves |
|------|--------|
| `observability/loki-query-401.md` | Logs flow to Loki, 401 alert trigger |
| `observability/loki-query-403.md` | 403 alert trigger evidence |
| `observability/loki-query-429.md` | 429 alert trigger evidence |
| `observability/correlation-id-query.md` | Correlation ID across 3 services |
| `observability/alert-401-spike.md` | HighUnauthorizedRate alert fired |
| `observability/alert-403-spike.md` | HighForbiddenRate alert fired |
| `observability/alert-429-spike.md` | RateLimitTriggered alert fired |
| `observability/tracing-jaeger-billing-order.md` | 4-span distributed trace |

### P0-05: Red Team

| File | Script | Proves |
|------|--------|--------|
| `red-team/bola-attack-defense.md` | `tests/attack/bola-object-access.sh` | BOLA blocked (403), flaw demonstrated |
| `red-team/token-replay.md` | `tests/attack/token-replay.sh` | Token + webhook replay blocked |
| `red-team/ssrf-egress-defense.md` | `tests/attack/ssrf-attack.sh` | SSRF blocked at URL + network level |
| `red-team/webhook-forgery.md` | `tests/attack/webhook-forgery.sh` | All 5 forgery scenarios blocked |

### P0-06: SSRF Egress Defense

See `red-team/ssrf-egress-defense.md` above.

### P0-07: Final Security Regression

| File | Script | Proves |
|------|--------|--------|
| `bash tests/final/main-regression.sh` | `tests/final/main-regression.sh` | Current 12-suite final regression gate |

### P0-08: Resilience Drills

| File | Proves |
|------|--------|
| `resilience/key-rotation-drill.md` | Webhook HMAC + client secret rotation |
| `resilience/key-rotation-output.txt` | Rotation output log |
| `resilience/token-revocation-drill.md` | Token revocation via Keycloak |
| `resilience/token-revocation-output.txt` | Revocation output log |
| `resilience/incident-response-drill.md` | Incident response: MTTD=2min, MTTR=3min |

---

## P1 – Important Evidence

### P1-01: Metrics

| File | Proves |
|------|--------|
| `metrics/k6-gateway-waf-latency.md` | p50=28ms, p95=187ms – all thresholds met |
| `metrics/k6-output.json` | k6 JSON output |
| `metrics/kms-vault-call-overhead.md` | Manual Vault read latency and production startup/rotation budget; lab runtime uses Compose env injection |
| `metrics/monthly-cost-estimate.md` | Lab $25/month, Production $100-150/month |
| `metrics/mttd-mttr-alert-based-results.csv` | Alert-based MTTD/MTTR raw timing |
| `metrics/mttd-mttr-alert-based-analysis.md` | MTTD/MTTR methodology and summary |
| `secops-metrics/secops-mttd-mttr-summary.md` | Authoritative MTTD/MTTR scenario matrix for 401, 403/BOLA, 429, SSRF, and webhook signals |
| `secops-metrics/latency-cost-tradeoff-summary.md` | p50/p95 latency measurement method and SME cost/trade-off analysis |

### P1-02: Pipeline

| File | Proves |
|------|--------|
| `pipeline/pipeline-summary.md` | 11-stage CI pipeline documentation |
| `pipeline/local-pipeline-output.txt` | Local CI run output |
| `../../.github/workflows/security-scan.yml` | GitHub Actions: Bandit, Gitleaks, Trivy |
| `../../scripts/ci/security-pipeline.sh` | Full local CI equivalent |

### P1-03: Evidence Index

This file.

### P1-04: Runbooks

| File | Contents |
|------|----------|
| `../../docs/runbooks/incident-response.md` | Incident response procedure |
| `../../docs/runbooks/key-rotation.md` | Key rotation procedure |
| `../../docs/runbooks/onboarding-new-client-bff.md` | New client onboarding |

### P1-05: Demo

| File | Contents |
|------|----------|
| `../../docs/demo/demo-video-script.md` | 14-scene demo video script |

---

## Previous Evidence (Base)

| File | Source Script | Proves |
|------|--------------|--------|
| `p0-01-main-smoke.txt` | `tests/smoke/main-smoke.sh` | Health endpoints OK |
| `p0-02-authz-negative-tests.txt` | `tests/security/authz-negative-tests.sh` | RBAC enforced |
| `p0-03-edge-hardening-tests.txt` | `tests/security/edge-hardening-tests.sh` | TLS, HSTS, CORS, rate limit |
| `p0-04-webhook-tests.txt` | `tests/security/webhook-tests.sh` | Webhook valid/invalid |
| `p1-03-fuzz-negative-tests.txt` | `tests/security/fuzz-negative-tests.sh` | Malformed input handled |
| `security-scan-local.txt` | `ci/run-local-security-scan.sh` | Combined security scan |
| `bandit-report.txt` | `ci/run-local-security-scan.sh` | SAST text report |
| `supply-chain/gitleaks-report-after-secret-purge.json` | `ci/run-local-security-scan.sh` | Post-purge Gitleaks package scan |
| `trivy-report.txt` | `ci/run-local-security-scan.sh` | Trivy table |

---

## How to Regenerate All Evidence

```bash
cd d:/SUBJECTS/Matmahoc/Project_CK/API

# Start stack
docker compose -f infra/docker-compose.yml up -d --build
sleep 30

# P0-01: ZAP Active Scan
bash tests/security/zap-active-scan.sh

# P0-02: API Fuzzing
bash tests/security/run-fuzzing.sh

# P0-03: Supply Chain
bash ci/run-local-security-scan.sh
bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-placeholder

# P0-07: Final Regression
bash tests/final/main-regression.sh

# P1-01: Metrics
k6 run tests/performance/k6-latency-test.js
BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh

# P1-02: Full Pipeline
bash scripts/ci/security-pipeline.sh
```
