#!/usr/bin/env bash
# tests/final/main-regression.sh
#
# Final regression test – runs ALL test suites in sequence.
# This is the gatekeeper script: must pass before any merge into main.
#
# Usage:
#   bash tests/final/main-regression.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REGRESSION_PASSED=0
REGRESSION_FAILED=0

run_suite() {
  local name="$1"
  local script="$2"

  echo ""
  echo "┌──────────────────────────────────────────────┐"
  echo "│  Regression: $name"
  echo "└──────────────────────────────────────────────┘"
  echo ""

  if bash "${PROJECT_ROOT}/${script}"; then
    REGRESSION_PASSED=$((REGRESSION_PASSED + 1))
    echo ""
    echo "  ✓ ${name} PASSED"
  else
    REGRESSION_FAILED=$((REGRESSION_FAILED + 1))
    echo ""
    echo "  ✗ ${name} FAILED"
  fi
}

echo "=============================================="
echo "  FINAL REGRESSION TEST"
echo "  $(date)"
echo "=============================================="

run_suite "Smoke Test" "tests/smoke/main-smoke.sh"
run_suite "Authz Negative" "tests/security/authz-negative-tests.sh"
run_suite "Edge Hardening" "tests/security/edge-hardening-tests.sh"
run_suite "Webhook Security" "tests/security/webhook-tests.sh"
run_suite "Fuzz/Negative" "tests/security/fuzz-negative-tests.sh"

echo ""
echo "=============================================="
echo "  REGRESSION SUMMARY"
echo "  Suites passed: ${REGRESSION_PASSED}"
echo "  Suites failed: ${REGRESSION_FAILED}"
echo "=============================================="

if [ "$REGRESSION_FAILED" -gt 0 ]; then
  echo ""
  echo "[ERROR] Regression has ${REGRESSION_FAILED} failing suite(s)."
  echo "DO NOT merge into main until all suites pass."
  exit 1
else
  echo ""
  echo "[OK] All regression suites passed. Safe to merge."
fi
