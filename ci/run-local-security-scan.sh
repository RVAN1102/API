#!/usr/bin/env bash
# ci/run-local-security-scan.sh
#
# Local security scan runner.
# Runs the same checks as the GitHub Actions workflow locally.
#
# Tools used:
#   - bandit: Python static analysis for security issues
#   - gitleaks: Secret scan in git history
#   - trivy: Filesystem vulnerability scan
#
# Usage:
#   bash ci/run-local-security-scan.sh
#
# Requirements:
#   pip install bandit
#   # Install gitleaks: https://github.com/gitleaks/gitleaks/releases
#   # Install trivy: https://aquasecurity.github.io/trivy/

set -uo pipefail

REPORT_DIR="docs/evidence/tv3"
SUPPLY_CHAIN_DIR="${REPORT_DIR}/supply-chain"
GITLEAKS_REPORT="${SUPPLY_CHAIN_DIR}/gitleaks-report-after-secret-purge.json"
EXIT_CODE=0
mkdir -p "${REPORT_DIR}"
mkdir -p "${SUPPLY_CHAIN_DIR}"

PACKAGE_SCAN_DIR=""

cleanup() {
  if [ -n "${PACKAGE_SCAN_DIR}" ] && [ -d "${PACKAGE_SCAN_DIR}" ]; then
    rm -rf "${PACKAGE_SCAN_DIR}"
  fi
}
trap cleanup EXIT

prepare_package_scan_dir() {
  PACKAGE_SCAN_DIR="$(mktemp -d /tmp/topic10-gitleaks-package.XXXXXX)"
  while IFS= read -r -d '' path; do
    [ -f "${path}" ] || continue
    mkdir -p "${PACKAGE_SCAN_DIR}/$(dirname "${path}")"
    cp "${path}" "${PACKAGE_SCAN_DIR}/${path}"
  done < <(git ls-files --cached --modified --others --exclude-standard -z)
  printf '%s\n' "${PACKAGE_SCAN_DIR}"
}

echo "=== Local Security Scan ==="
echo "Output: ${REPORT_DIR}/"
echo ""

# --------------------------------------------------
# 1. Bandit – Python static analysis
# --------------------------------------------------
echo "--- [1/3] Bandit – Python Static Analysis ---"
if command -v bandit > /dev/null 2>&1; then
  bandit -r services/ \
    --severity-level medium \
    --confidence-level medium \
    --format txt \
    --output "${REPORT_DIR}/bandit-report.txt" 2>&1 || true
  echo "Bandit report: ${REPORT_DIR}/bandit-report.txt"
  grep -E "^(Issue|Severity|Confidence|Total)" "${REPORT_DIR}/bandit-report.txt" | head -20 || true
else
  echo "[WARN] bandit not found. Install: pip install bandit"
  echo "bandit not installed" > "${REPORT_DIR}/bandit-report.txt"
fi

echo ""

# --------------------------------------------------
# 2. Gitleaks – secret scan
# --------------------------------------------------
echo "--- [2/3] Gitleaks – Secret Detection ---"
if command -v gitleaks > /dev/null 2>&1; then
  GITLEAKS_EXIT=0
  SCAN_DIR="$(prepare_package_scan_dir)"
  gitleaks dir "${SCAN_DIR}" \
    --report-path "${GITLEAKS_REPORT}" \
    --report-format json \
    --no-banner \
    --redact 2>&1 || GITLEAKS_EXIT=$?
  echo "Gitleaks report: ${GITLEAKS_REPORT}"
  if [ "${GITLEAKS_EXIT}" -ne 0 ]; then
    echo "[FAIL] Gitleaks detected secret-like findings. See redacted report."
    EXIT_CODE=1
  else
    echo "[PASS] Gitleaks detected no secrets in the current tracked/non-ignored source package."
  fi
else
  echo "[WARN] gitleaks not found. Download from https://github.com/gitleaks/gitleaks/releases"
  printf '{"error":"gitleaks not installed"}\n' > "${GITLEAKS_REPORT}"
  EXIT_CODE=1
fi

echo ""

# --------------------------------------------------
# 3. Trivy – filesystem scan
# --------------------------------------------------
echo "--- [3/3] Trivy – Filesystem Vulnerability Scan ---"
if command -v trivy > /dev/null 2>&1; then
  trivy fs . \
    --severity HIGH,CRITICAL \
    --format table \
    --output "${REPORT_DIR}/trivy-report.txt" 2>&1 || true
  echo "Trivy report: ${REPORT_DIR}/trivy-report.txt"
  head -40 "${REPORT_DIR}/trivy-report.txt" || true
else
  echo "[WARN] trivy not found. Install from https://aquasecurity.github.io/trivy/"
  echo "trivy not installed" > "${REPORT_DIR}/trivy-report.txt"
fi

echo ""
echo "=== Scan complete ==="
echo "Reports saved to ${REPORT_DIR}/"
ls -la "${REPORT_DIR}/"*report* 2>/dev/null || true

# Combine into evidence file
{
  echo "=== LOCAL SECURITY SCAN RESULTS ==="
  echo "Date: $(date)"
  echo ""
  echo "=== BANDIT ==="
  cat "${REPORT_DIR}/bandit-report.txt" 2>/dev/null || echo "No bandit report"
  echo ""
  echo "=== GITLEAKS ==="
  cat "${GITLEAKS_REPORT}" 2>/dev/null || echo "No gitleaks report"
  echo ""
  echo "=== TRIVY ==="
  cat "${REPORT_DIR}/trivy-report.txt" 2>/dev/null || echo "No trivy report"
} > "${REPORT_DIR}/security-scan-local.txt"

echo ""
echo "Combined evidence: ${REPORT_DIR}/security-scan-local.txt"
exit "${EXIT_CODE}"
