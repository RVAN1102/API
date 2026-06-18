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
    wait_for_kong
  else
    echo "[INFO] infra/docker-compose.yml not available; skipping Kong restart"
  fi
}

reset_kong_at_start() {
  echo ""
  echo "[INFO] Resetting Kong before final regression"
  if [ -f "${PROJECT_ROOT}/infra/docker-compose.yml" ]; then
    (cd "${PROJECT_ROOT}" && docker compose -f infra/docker-compose.yml restart kong)
    wait_for_kong
  else
    echo "[INFO] infra/docker-compose.yml not available; skipping Kong restart"
  fi
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

wait_for_kong() {
  local code
  for _attempt in $(seq 1 30); do
    code="$(curl -ks -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")"
    if [ "${code}" != "000" ]; then
      echo "[INFO] Kong reachable on localhost:8000 (HTTP ${code})"
      return 0
    fi
    sleep 2
  done
  echo "[WARN] Kong did not become reachable on localhost:8000 within 60s; continuing so suite can report exact failure"
}

ensure_webhook_mtls_certs() {
  local cert_dir="${PROJECT_ROOT}/infra/certs"
  local generator="${PROJECT_ROOT}/demo/mtls/generate-mtls-certs.sh"
  local missing=0

  for required in \
    "${cert_dir}/webhook-ca.crt" \
    "${cert_dir}/webhook-ca.key" \
    "${cert_dir}/webhook-client.crt" \
    "${cert_dir}/webhook-client.key" \
    "${cert_dir}/webhook-client.p12"; do
    [ -r "${required}" ] || missing=1
  done

  if [ "${missing}" -eq 0 ]; then
    echo "[INFO] Webhook runtime mTLS demo certs are present"
    return 0
  fi

  [ -x "${generator}" ] || [ -f "${generator}" ] \
    || {
      echo "[ERROR] Missing webhook mTLS generator: ${generator}" >&2
      return 1
    }

  echo "[INFO] Generating missing local-only webhook mTLS demo certs"
  bash "${generator}"
  echo "[INFO] Generated webhook mTLS runtime certs. Do not commit infra/certs/*.key or infra/certs/*.p12."
  echo "[INFO] Before final security scan/package creation, remove runtime private artifacts: rm -f infra/certs/*.key infra/certs/*.p12"
}

echo "=============================================="
echo "  FINAL REGRESSION TEST"
echo "  $(date)"
echo "=============================================="

reset_kong_at_start
run_suite "Smoke Test" "tests/smoke/main-smoke.sh"
run_suite "Client Credentials" "tests/security/client-credentials-tests.sh"
run_suite "Token Lifecycle" "tests/security/token-lifecycle-tests.sh"
run_suite "Real S2S Ownership" "tests/security/s2s-ownership-tests.sh"
run_suite "Authz Negative" "tests/security/authz-negative-tests.sh"
reset_kong_before_opa
run_suite "OPA Authz" "tests/security/opa-authz-tests.sh"
run_suite "Edge Hardening" "tests/security/edge-hardening-tests.sh"
ensure_webhook_mtls_certs || REGRESSION_FAILED=$((REGRESSION_FAILED + 1))
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
