# Pipeline Summary (TV3 P1-02)

**Date:** 2026-06-17  
**Script:** `scripts/ci/security-pipeline.sh`  
**GitHub Actions:** `.github/workflows/security-scan.yml`

---

## Pipeline Stages

| Stage | Tool | Status | Evidence |
|-------|------|--------|----------|
| 1. Lint/Syntax Check | Python/Bash | ✅ PASS | – |
| 2. SAST | Bandit v1.8.0 | ✅ PASS (0 HIGH) | `supply-chain/bandit-report.json` |
| 3. SCA | Trivy v0.50.x | ✅ PASS (0 CRITICAL) | `supply-chain/sca-report.txt` |
| 4. Secrets Scan | Gitleaks v8.x | Superseded by 2026-06-18 post-purge package scan | `supply-chain/gitleaks-report-after-secret-purge.json` |
| 5. SBOM | Trivy CycloneDX | ✅ PASS | `supply-chain/sbom-cyclonedx.json` |
| 6. Build Check | Docker Compose | ✅ PASS | – |
| 7. Artifact Signing | Cosign | ✅ PASS | `supply-chain/cosign-verify-output.txt` |
| 8. Security Tests | Bash test suite | ✅ PASS | `docs/evidence/tv3/` |
| 9. ZAP Active Scan | OWASP ZAP | ✅ PASS (0 HIGH) | `zap/zap-active-summary.md` |
| 10. API Fuzzing | Fuzz suite | ✅ PASS (0 crashes) | `fuzzing/fuzzing-summary.md` |
| 11. Final Regression | main-regression.sh | ✅ PASS | `docs/evidence/final/` |

---

## How to Run Locally

```bash
# Full pipeline (requires running stack):
bash scripts/ci/security-pipeline.sh

# Skip stack-dependent tests (for CI without Docker):
SKIP_STACK=1 bash scripts/ci/security-pipeline.sh

# Skip ZAP only:
SKIP_ZAP=1 bash scripts/ci/security-pipeline.sh
```

---

## GitHub Actions

File: `.github/workflows/security-scan.yml`

Jobs:
- `bandit` – Python SAST
- `gitleaks` – secrets scan
- `trivy` – SCA filesystem scan

Triggers on push to: `qa/tv3-*`, `main`

---

## Pipeline Flow Diagram

```
Code Push
    │
    ▼
lint/syntax check
    │
    ▼
SAST (Bandit) ─────────────────┐
    │                          │
    ▼                          │
SCA (Trivy) ───────────────────┤
    │                          │
    ▼                          │ If any stage fails:
Gitleaks ──────────────────────┤ → Pipeline FAIL
    │                          │ → Block merge to main
    ▼                          │
SBOM (Trivy CycloneDX) ────────┤
    │                          │
    ▼                          │
Build + Sign (Cosign) ─────────┤
    │                          │
    ▼                          │
Security Tests ────────────────┤
    │                          │
    ▼                          │
ZAP Active Scan ───────────────┤
    │                          │
    ▼                          │
API Fuzzing ───────────────────┤
    │                          │
    ▼                          │
Final Regression ──────────────┘
    │
    ▼
Pipeline PASS → Ready for merge
```
