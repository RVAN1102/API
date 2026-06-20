# Authoritative Evidence Index

This index points to the official, reviewable evidence set for the current hardening baseline. The evidence supports the statement that known P0 findings were addressed and validated by regression; it does not claim that the system has no remaining vulnerabilities.

## Final Regression

- Historical final regression 9/9: `docs/evidence/final/main-regression-final.txt`
- Historical post-hardening final regression: `docs/evidence/final/final-security-regression-after-all-hardening.txt`
- Quality gate summary: `docs/evidence/final/final-quality-gate-summary.txt`
- Production-oriented hardening bundle 1: `docs/evidence/final/production-hardening-bundle-1.md`
- Final stale reference audit: `docs/evidence/final/FINAL_REPO_STALE_AUDIT.md`

## Identity, Authorization, And Service-To-Service

- Client Credentials: `docs/evidence/tv2/gvhd-client-credentials-tests.txt`
- Token lifecycle, introspection, and revocation: `docs/evidence/tv2/token-lifecycle-introspection-revocation.txt`
- Real S2S ownership: `docs/evidence/tv2/real-s2s-billing-order-ownership.txt`
- Authz negative regression: `docs/evidence/tv2/gvhd-authz-negative-after-client-credentials.txt`
- OPA authz policy and backend enforcement: `docs/evidence/tv2/opa-policy-engine.txt`
- Lab secret bootstrap and Vault/KMS production alignment: `docs/evidence/tv2/vault-lab-secret-bootstrap.md`

## Edge And Webhook Security

- Edge hardening: `docs/evidence/tv1/edge-final/`
- Webhook security final cases: `docs/evidence/tv1/webhook-final/`
- Webhook persistent nonce store: `docs/evidence/tv1/webhook-final/persistent-nonce-store.md`
- Gateway route smoke: `docs/evidence/tv1/p0-01-kong-route-smoke.txt`
- TLS 1.3 and HSTS: `docs/evidence/tv1/p0-02-kong-tls13-only.txt`, `docs/evidence/tv1/p0-03-kong-hsts.txt`
- Gateway-to-backend mTLS default runtime evidence: `docs/evidence/tv1/gateway-backend-mtls/` (local reruns write transient output to `.artifacts/test-runs/` unless `UPDATE_OFFICIAL_EVIDENCE=1` is set)

## SSRF And Network Egress

- SSRF vulnerable/fixed endpoint evidence: `docs/evidence/tv1/ssrf-egress/`
- Network egress control runtime evidence: `docs/evidence/tv1/ssrf-egress/network-egress-control-runtime-after-fix.txt`

## Observability And Alerting

- Loki alert rules loaded at runtime: `docs/evidence/tv3/observability/loki-rules-runtime-loaded-after-p0-fix.yml`
- Alert diagnostics and selected samples: `docs/evidence/tv3/metrics/`
- Authoritative SecOps MTTD/MTTR summary: `docs/evidence/tv3/secops-metrics/secops-mttd-mttr-summary.md`
- Latency, p50/p95 method, and SME cost trade-off summary: `docs/evidence/tv3/secops-metrics/latency-cost-tradeoff-summary.md`
- Latency smoke command: `BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh`

## DAST, Fuzzing, And Security Scans

- ZAP Active Scan: rerun `bash tests/security/zap-active-scan.sh` against the current HTTPS gateway before making current DAST claims. Pre-HTTPS reports are archived under `docs/evidence/archive/pre-8443-http8000/tv3/zap/`.
- RESTler execution: rerun `bash tests/restler/run-restler-check.sh` against the current HTTPS gateway before making current RESTler claims. Pre-HTTPS summary is archived under `docs/evidence/archive/pre-8443-http8000/tv3/restler/`.
- Structured fuzzing: rerun `bash tests/security/run-fuzzing.sh` against the current HTTPS gateway before making current fuzzing claims. Pre-HTTPS summary is archived under `docs/evidence/archive/pre-8443-http8000/tv3/fuzzing/`.
- Local security scan evidence: `docs/evidence/tv3/security-scan-local.txt`
- Supply-chain evidence, SBOM, and signing summaries: `docs/evidence/tv3/supply-chain/`
- CI image SBOM and Cosign dry-run path: `.github/workflows/security-scan.yml`, `scripts/security/generate-sbom.sh`, `scripts/security/cosign-sign.sh`

## Runtime Test Artifacts

New local regression runs write transient evidence to `.artifacts/test-runs/` by default. That directory is intentionally ignored so rerunning regression does not overwrite the official evidence above or dirty the working tree.
