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
  local exit_code=0

  echo ""
  echo "┌──────────────────────────────────────────────┐"
  echo "│  Regression: $name"
  echo "└──────────────────────────────────────────────┘"
  echo ""

  bash "${PROJECT_ROOT}/${script}" || exit_code=$?

  if [ "${exit_code}" -eq 0 ]; then
    REGRESSION_PASSED=$((REGRESSION_PASSED + 1))
    echo ""
    echo "  ✓ ${name} PASSED"
  else
    REGRESSION_FAILED=$((REGRESSION_FAILED + 1))
    echo ""
    echo "  ✗ ${name} FAILED (exit ${exit_code})"
  fi
}

reset_kong_after_edge() {
  echo ""
  echo "[INFO] Resetting Kong after edge rate-limit test"
  if [ -f "${PROJECT_ROOT}/infra/docker-compose.yml" ]; then
    (cd "${PROJECT_ROOT}" && docker compose -f infra/docker-compose.yml restart kong)
  else
    echo "[INFO] infra/docker-compose.yml not available; skipping Kong restart"
  fi
  sleep 20
}

echo "=============================================="
echo "  FINAL REGRESSION TEST"
echo "  $(date)"
echo "=============================================="

run_suite "Smoke Test" "tests/smoke/main-smoke.sh"
run_suite "Authz Negative" "tests/security/authz-negative-tests.sh"
run_suite "Edge Hardening" "tests/security/edge-hardening-tests.sh"
reset_kong_after_edge
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
