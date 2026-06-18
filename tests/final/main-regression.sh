#!/usr/bin/env bash
# tests/final/main-regression.sh
#
# Final regression test – runs ALL test suites in sequence.
# This is the gatekeeper script: must pass before any merge into main.
#
# Usage:
#   bash tests/final/main-regression.sh
#
# Windows Git Bash: if python3/python is not in PATH, set PYTHON_BIN first:
#   PYTHON_BIN="/c/Users/.../python.exe" bash tests/final/main-regression.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Prepend repo bin/ to PATH so our python3 shim overrides Windows Store stub
export PATH="${PROJECT_ROOT}/bin:${PATH}"

# Source compat shim – detects Python, sets up python3() function if needed
# shellcheck source=../compat.sh
source "${SCRIPT_DIR}/../compat.sh"

# Auto-source secrets so tests work in any shell (Git Bash, WSL, PowerShell)
if [ -f "${PROJECT_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/infra/.env"
  set +a
fi

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
  sleep 30
}

reset_kong_before_opa() {
  echo ""
  echo "[INFO] Resetting Kong before OPA authz test"
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
run_suite "Client Credentials" "tests/security/client-credentials-tests.sh"
run_suite "Token Lifecycle" "tests/security/token-lifecycle-tests.sh"
run_suite "Real S2S Ownership" "tests/security/s2s-ownership-tests.sh"
run_suite "Authz Negative" "tests/security/authz-negative-tests.sh"
reset_kong_before_opa
run_suite "OPA Authz" "tests/security/opa-authz-tests.sh"
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
