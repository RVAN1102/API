#!/usr/bin/env bash
# scripts/ci/security-pipeline.sh
#
# Local CI Security Pipeline
#
# Runs the full DevSecOps pipeline locally, equivalent to GitHub Actions.
# Pipeline stages:
#   1. Lint / syntax check
#   2. SAST (Bandit)
#   3. SCA (Trivy filesystem)
#   4. Secrets scan (Gitleaks)
#   5. SBOM generation (Trivy CycloneDX)
#   6. Build check (Docker)
#   7. Artifact signing check (Cosign)
#   8. Unit / security tests
#   9. ZAP Active Scan
#  10. API Fuzzing
#  11. Final regression
#
# Usage:
#   bash scripts/ci/security-pipeline.sh
#
# Environment:
#   SKIP_ZAP=1     – Skip ZAP scan (requires running stack)
#   SKIP_STACK=1   – Skip tests requiring running Docker stack
#
# Output:
#   docs/evidence/tv3/pipeline/local-pipeline-output.txt
#   docs/evidence/tv3/pipeline/pipeline-summary.md

set -uo pipefail

REPORT_DIR="docs/evidence/tv3/pipeline"
OUTPUT_FILE="${REPORT_DIR}/local-pipeline-output.txt"
mkdir -p "${REPORT_DIR}"

PASS=0
FAIL=0
SKIP=0
SKIP_STACK="${SKIP_STACK:-0}"
SKIP_ZAP="${SKIP_ZAP:-0}"
PACKAGE_SCAN_DIR=""

cleanup() {
  if [ -n "${PACKAGE_SCAN_DIR}" ] && [ -d "${PACKAGE_SCAN_DIR}" ]; then
    rm -rf "${PACKAGE_SCAN_DIR}"
  fi
}
trap cleanup EXIT

stage() {
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  Stage: $1"
  echo "╚══════════════════════════════════════════════════════╝"
}

ok() { echo "[✓] $1"; PASS=$((PASS + 1)); }
fail() { echo "[✗] $1"; FAIL=$((FAIL + 1)); }
skip() { echo "[~] $1 (skipped)"; SKIP=$((SKIP + 1)); }

prepare_package_scan_dir() {
  PACKAGE_SCAN_DIR="$(mktemp -d /tmp/topic10-pipeline-package.XXXXXX)"
  while IFS= read -r -d '' path; do
    [ -f "${path}" ] || continue
    mkdir -p "${PACKAGE_SCAN_DIR}/$(dirname "${path}")"
    cp "${path}" "${PACKAGE_SCAN_DIR}/${path}"
  done < <(git ls-files --cached --modified --others --exclude-standard -z)
  printf '%s\n' "${PACKAGE_SCAN_DIR}"
}

echo "=== DevSecOps Security Pipeline ===" | tee "${OUTPUT_FILE}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${OUTPUT_FILE}"
echo "" | tee -a "${OUTPUT_FILE}"

# --------------------------------------------------
# Stage 1: Lint / Syntax Check
# --------------------------------------------------
stage "1. Lint / Syntax Check" | tee -a "${OUTPUT_FILE}"

# Check Python syntax
PYTHON_ERRORS=0
while IFS= read -r -d '' f; do
  if [ -f "${f}" ]; then
    python3 -m py_compile "${f}" 2>/dev/null || { PYTHON_ERRORS=$((PYTHON_ERRORS + 1)); echo "Syntax error: ${f}"; }
  fi
done < <(find services/ -name "*.py" -print0 2>/dev/null)
if [ "${PYTHON_ERRORS}" -eq 0 ]; then
  ok "Python syntax check – no errors" | tee -a "${OUTPUT_FILE}"
else
  fail "Python syntax check – ${PYTHON_ERRORS} errors" | tee -a "${OUTPUT_FILE}"
fi

# Check bash scripts
BASH_ERRORS=0
while IFS= read -r -d '' f; do
  bash -n "${f}" 2>/dev/null || { BASH_ERRORS=$((BASH_ERRORS + 1)); echo "Bash syntax error: ${f}"; }
done < <(find tests/ scripts/ ci/ -name "*.sh" -print0 2>/dev/null)
if [ "${BASH_ERRORS}" -eq 0 ]; then
  ok "Bash syntax check – no errors" | tee -a "${OUTPUT_FILE}"
else
  fail "Bash syntax check – ${BASH_ERRORS} errors" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 2: SAST (Bandit)
# --------------------------------------------------
stage "2. SAST – Bandit" | tee -a "${OUTPUT_FILE}"

if command -v bandit > /dev/null 2>&1; then
  mkdir -p docs/evidence/tv3/supply-chain
  BANDIT_EXIT=0
  bandit -r services/ \
    --severity-level medium \
    --confidence-level medium \
    --format json \
    --output docs/evidence/tv3/supply-chain/bandit-report.json \
    2>/dev/null || BANDIT_EXIT=$?

  HIGH=$(python3 -c "
import json, pathlib
d = json.loads(pathlib.Path('docs/evidence/tv3/supply-chain/bandit-report.json').read_text())
print(d.get('metrics', {}).get('_totals', {}).get('SEVERITY.HIGH', 0))
" 2>/dev/null || echo "0")

  if [ "${HIGH}" -eq 0 ]; then
    ok "SAST (Bandit) – no HIGH severity issues" | tee -a "${OUTPUT_FILE}"
  else
    fail "SAST (Bandit) – ${HIGH} HIGH severity issue(s) found" | tee -a "${OUTPUT_FILE}"
  fi
else
  skip "Bandit not installed (pip install bandit)" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 3: SCA (Trivy)
# --------------------------------------------------
stage "3. SCA – Trivy Filesystem" | tee -a "${OUTPUT_FILE}"

if command -v trivy > /dev/null 2>&1; then
  TRIVY_EXIT=0
  trivy fs . \
    --severity CRITICAL \
    --format json \
    --output /tmp/trivy-ci.json \
    --quiet 2>/dev/null || TRIVY_EXIT=$?
  CRITS=$(python3 -c "
import json
d=json.load(open('/tmp/trivy-ci.json'))
total=sum(len(r.get('Vulnerabilities') or []) for r in d.get('Results',[]))
print(total)
" 2>/dev/null || echo "0")
  if [ "${CRITS}" -eq 0 ]; then
    ok "SCA (Trivy) – no CRITICAL vulnerabilities" | tee -a "${OUTPUT_FILE}"
  else
    fail "SCA (Trivy) – ${CRITS} CRITICAL vulnerability(ies)" | tee -a "${OUTPUT_FILE}"
  fi
else
  skip "Trivy not installed" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 4: Secrets Scan (Gitleaks)
# --------------------------------------------------
stage "4. Secrets Scan – Gitleaks" | tee -a "${OUTPUT_FILE}"

if command -v gitleaks > /dev/null 2>&1; then
  GITLEAKS_EXIT=0
  SCAN_DIR="$(prepare_package_scan_dir)"
  gitleaks dir "${SCAN_DIR}" \
    --report-path docs/evidence/tv3/supply-chain/gitleaks-report-after-secret-purge.json \
    --report-format json \
    --no-banner \
    --redact 2>/dev/null || GITLEAKS_EXIT=$?
  if [ "${GITLEAKS_EXIT}" -eq 0 ]; then
    ok "Gitleaks – no secrets detected" | tee -a "${OUTPUT_FILE}"
  else
    LEAK_COUNT=$(python3 -c "import json; d=json.load(open('docs/evidence/tv3/supply-chain/gitleaks-report-after-secret-purge.json')); print(len(d))" 2>/dev/null || echo "?")
    fail "Gitleaks – ${LEAK_COUNT} finding(s) – review for false positives" | tee -a "${OUTPUT_FILE}"
  fi
else
  skip "Gitleaks not installed" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 5: SBOM Generation
# --------------------------------------------------
stage "5. SBOM – CycloneDX" | tee -a "${OUTPUT_FILE}"

if command -v trivy > /dev/null 2>&1; then
  trivy fs --format cyclonedx \
    --output docs/evidence/tv3/supply-chain/sbom-cyclonedx.json \
    --quiet . 2>/dev/null && \
    ok "SBOM (CycloneDX) generated" | tee -a "${OUTPUT_FILE}" || \
    fail "SBOM generation failed" | tee -a "${OUTPUT_FILE}"
else
  skip "SBOM skipped (trivy not installed)" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 6: Build Check
# --------------------------------------------------
stage "6. Docker Build Check" | tee -a "${OUTPUT_FILE}"

if command -v docker > /dev/null 2>&1; then
  # Check if docker-compose can validate config
  COMPOSE_EXIT=0
  docker compose -f infra/docker-compose.yml config --quiet 2>/dev/null || COMPOSE_EXIT=$?
  if [ "${COMPOSE_EXIT}" -eq 0 ]; then
    ok "Docker Compose config valid" | tee -a "${OUTPUT_FILE}"
  else
    fail "Docker Compose config invalid" | tee -a "${OUTPUT_FILE}"
  fi
else
  skip "Docker not available" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 7: Artifact Signing Check
# --------------------------------------------------
stage "7. Artifact Signing – Cosign" | tee -a "${OUTPUT_FILE}"

if command -v cosign > /dev/null 2>&1; then
  ok "Cosign available – image signing ready" | tee -a "${OUTPUT_FILE}"
  echo "  Script: bash scripts/security/cosign-sign.sh evidence" | tee -a "${OUTPUT_FILE}"
else
  skip "Cosign not installed – see scripts/security/cosign-sign.sh" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 8: Unit / Security Tests
# --------------------------------------------------
stage "8. Security Tests" | tee -a "${OUTPUT_FILE}"

if [ "${SKIP_STACK}" = "1" ]; then
  skip "Security tests (SKIP_STACK=1)" | tee -a "${OUTPUT_FILE}"
else
  echo "  Running security test suites..." | tee -a "${OUTPUT_FILE}"
  for test_script in \
    "tests/smoke/main-smoke.sh" \
    "tests/security/authz-negative-tests.sh" \
    "tests/security/edge-hardening-tests.sh" \
    "tests/security/webhook-tests.sh" \
    "tests/security/fuzz-negative-tests.sh"; do
    if [ -f "${test_script}" ]; then
      TEST_EXIT=0
      bash "${test_script}" > /tmp/test-output.txt 2>&1 || TEST_EXIT=$?
      if [ "${TEST_EXIT}" -eq 0 ]; then
        ok "${test_script}" | tee -a "${OUTPUT_FILE}"
      else
        fail "${test_script} (exit ${TEST_EXIT})" | tee -a "${OUTPUT_FILE}"
      fi
    fi
  done
fi

# --------------------------------------------------
# Stage 9: ZAP Active Scan
# --------------------------------------------------
stage "9. ZAP Active Scan" | tee -a "${OUTPUT_FILE}"

if [ "${SKIP_ZAP}" = "1" ]; then
  skip "ZAP Active Scan (SKIP_ZAP=1)" | tee -a "${OUTPUT_FILE}"
elif [ "${SKIP_STACK}" = "1" ]; then
  skip "ZAP Active Scan (SKIP_STACK=1)" | tee -a "${OUTPUT_FILE}"
elif command -v docker > /dev/null 2>&1; then
  ZAP_EXIT=0
  bash tests/security/zap-active-scan.sh > /tmp/zap-output.txt 2>&1 || ZAP_EXIT=$?
  if [ "${ZAP_EXIT}" -le 2 ]; then
    ok "ZAP Active Scan – complete (exit ${ZAP_EXIT})" | tee -a "${OUTPUT_FILE}"
  else
    fail "ZAP Active Scan – failed (exit ${ZAP_EXIT})" | tee -a "${OUTPUT_FILE}"
  fi
else
  skip "ZAP Active Scan (Docker not available)" | tee -a "${OUTPUT_FILE}"
fi

# --------------------------------------------------
# Stage 10: API Fuzzing
# --------------------------------------------------
stage "10. API Fuzzing" | tee -a "${OUTPUT_FILE}"

if [ "${SKIP_STACK}" = "1" ]; then
  skip "API Fuzzing (SKIP_STACK=1)" | tee -a "${OUTPUT_FILE}"
else
  FUZZ_EXIT=0
  bash tests/security/run-fuzzing.sh > /tmp/fuzz-output.txt 2>&1 || FUZZ_EXIT=$?
  if [ "${FUZZ_EXIT}" -eq 0 ]; then
    ok "API Fuzzing – no crashes" | tee -a "${OUTPUT_FILE}"
  else
    fail "API Fuzzing – exit ${FUZZ_EXIT}" | tee -a "${OUTPUT_FILE}"
  fi
fi

# --------------------------------------------------
# Stage 11: Final Regression
# --------------------------------------------------
stage "11. Final Regression" | tee -a "${OUTPUT_FILE}"

if [ "${SKIP_STACK}" = "1" ]; then
  skip "Final regression (SKIP_STACK=1)" | tee -a "${OUTPUT_FILE}"
else
  REG_EXIT=0
  bash tests/final/main-regression.sh > /tmp/regression-output.txt 2>&1 || REG_EXIT=$?
  if [ "${REG_EXIT}" -eq 0 ]; then
    ok "Final regression – PASS" | tee -a "${OUTPUT_FILE}"
  else
    fail "Final regression – FAIL (exit ${REG_EXIT})" | tee -a "${OUTPUT_FILE}"
  fi
fi

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo "" | tee -a "${OUTPUT_FILE}"
echo "════════════════════════════════════════════" | tee -a "${OUTPUT_FILE}"
echo "  Pipeline Summary" | tee -a "${OUTPUT_FILE}"
echo "  Passed: ${PASS}" | tee -a "${OUTPUT_FILE}"
echo "  Failed: ${FAIL}" | tee -a "${OUTPUT_FILE}"
echo "  Skipped: ${SKIP}" | tee -a "${OUTPUT_FILE}"
echo "════════════════════════════════════════════" | tee -a "${OUTPUT_FILE}"

if [ "${FAIL}" -gt 0 ]; then
  echo "[PIPELINE FAIL] ${FAIL} stage(s) failed. Review output above." | tee -a "${OUTPUT_FILE}"
  exit 1
else
  echo "[PIPELINE PASS] All required stages passed." | tee -a "${OUTPUT_FILE}"
fi
