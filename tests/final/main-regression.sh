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

load_service_client_env() {
  local env_file="${PROJECT_ROOT}/infra/.env"
  local bootstrap_script="${PROJECT_ROOT}/scripts/bootstrap-lab-env.sh"
  local needs_bootstrap=0
  local required_var
  local value
  local required_vars=(
    BILLING_SERVICE_CLIENT_SECRET
    ADMIN_SERVICE_CLIENT_SECRET
    WEBHOOK_SECRET
  )

  # Auto-source secrets so tests work in any shell (Git Bash, WSL, PowerShell).
  # Do not print secret values.
  if [ -f "${env_file}" ]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
    echo "[INFO] Loaded service-client environment from infra/.env"
    for required_var in "${required_vars[@]}"; do
      if ! grep -q "^${required_var}=" "${env_file}"; then
        needs_bootstrap=1
      fi
    done
  else
    echo "[INFO] infra/.env not found; lab bootstrap is required"
    needs_bootstrap=1
  fi

  for required_var in "${required_vars[@]}"; do
    value="${!required_var:-}"
    if [ -z "${value}" ] || [[ "${value}" == REPLACE_WITH_* ]]; then
      needs_bootstrap=1
    fi
  done

  if [ "${needs_bootstrap}" -eq 1 ]; then
    if [ ! -f "${bootstrap_script}" ]; then
      echo "[ERROR] Missing required lab secret bootstrap script." >&2
      echo "[ERROR] Run: bash scripts/bootstrap-lab-env.sh" >&2
      exit 1
    fi

    echo "[INFO] Running lab secret bootstrap"
    if ! bash "${bootstrap_script}"; then
      echo "[ERROR] Lab secret bootstrap failed." >&2
      echo "[ERROR] Run: bash scripts/bootstrap-lab-env.sh" >&2
      exit 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
    echo "[INFO] Reloaded service-client environment from infra/.env"
  fi

  for required_var in "${required_vars[@]}"; do
    value="${!required_var:-}"
    if [ -z "${value}" ] || [[ "${value}" == REPLACE_WITH_* ]]; then
      echo "[ERROR] ${required_var} is missing or still a placeholder after loading infra/.env." >&2
      echo "[ERROR] Run: bash scripts/bootstrap-lab-env.sh" >&2
      exit 1
    fi
  done

  export BILLING_SERVICE_CLIENT_SECRET
  export ADMIN_SERVICE_CLIENT_SECRET
  export WEBHOOK_SECRET
}

load_service_client_env

REGRESSION_PASSED=0
REGRESSION_FAILED=0
WEBHOOK_CERT_BACKUP_DIR=""

snapshot_webhook_cert_artifacts() {
  WEBHOOK_CERT_BACKUP_DIR="$(mktemp -d /tmp/final-regression-webhook-certs.XXXXXX)"
  for name in webhook-ca.crt webhook-client.crt; do
    if [ -f "${PROJECT_ROOT}/infra/certs/${name}" ]; then
      cp "${PROJECT_ROOT}/infra/certs/${name}" "${WEBHOOK_CERT_BACKUP_DIR}/${name}"
    fi
  done
}

restore_webhook_cert_artifacts() {
  local name

  if [ -n "${WEBHOOK_CERT_BACKUP_DIR}" ] && [ -d "${WEBHOOK_CERT_BACKUP_DIR}" ]; then
    for name in webhook-ca.crt webhook-client.crt; do
      if [ -f "${WEBHOOK_CERT_BACKUP_DIR}/${name}" ]; then
        cp "${WEBHOOK_CERT_BACKUP_DIR}/${name}" "${PROJECT_ROOT}/infra/certs/${name}"
      fi
    done
    rm -rf "${WEBHOOK_CERT_BACKUP_DIR}"
    WEBHOOK_CERT_BACKUP_DIR=""
  fi

  rm -f \
    "${PROJECT_ROOT}/infra/certs/webhook-ca.key" \
    "${PROJECT_ROOT}/infra/certs/webhook-client.key" \
    "${PROJECT_ROOT}/infra/certs/webhook-client.p12" \
    "${PROJECT_ROOT}/infra/certs/webhook-ca.srl" \
    "${PROJECT_ROOT}/infra/certs/webhook-client.csr" \
    "${PROJECT_ROOT}/infra/certs/webhook-client.ext"
}

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
    wait_for_kong
  else
    echo "[INFO] infra/docker-compose.yml not available; skipping Kong restart"
  fi
}

reset_kong_before_authz_negative() {
  echo ""
  echo "[INFO] Resetting Kong before authz negative test"
  if [ -f "${PROJECT_ROOT}/infra/docker-compose.yml" ]; then
    (cd "${PROJECT_ROOT}" && docker compose -f infra/docker-compose.yml restart kong)
    wait_for_kong
  else
    echo "[INFO] infra/docker-compose.yml not available; skipping Kong restart"
  fi
}

wait_for_kong() {
  local code
  local health_url="https://localhost:8443/api/v1/users/health"
  local curl_tls_opts="${CURL_TLS_OPTS:---insecure}"

  for attempt in $(seq 1 30); do
    if code="$(curl ${curl_tls_opts} -sS -o /dev/null -w "%{http_code}" "${health_url}" 2>/dev/null)"; then
      :
    else
      code="000"
    fi

    echo "[INFO] Kong readiness attempt ${attempt}/30: users health HTTP ${code}"
    if [ "${code}" = "200" ]; then
      echo "[INFO] Kong users health is ready (HTTP 200)"
      return 0
    fi
    sleep 2
  done

  echo "[ERROR] Kong did not return HTTP 200 from ${health_url} within 60s." >&2
  exit 1
}


ensure_keycloak_ready() {
  echo "[INFO] Ensuring Keycloak is running before token-based regression suites"

  local project_root
  project_root="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

  local compose_file
  compose_file="${COMPOSE_FILE:-${project_root}/infra/docker-compose.yml}"

  docker compose -f "${compose_file}" up -d keycloak >/dev/null

  for attempt in $(seq 1 60); do
    code="$(curl -sS -o /tmp/final-regression-keycloak-discovery.json -w '%{http_code}' \
      --max-time 5 \
      "http://localhost:8080/realms/topic10-sme-api/.well-known/openid-configuration" 2>/dev/null || true)"
    echo "[INFO] Keycloak discovery attempt ${attempt}/60: HTTP ${code}"
    if [ "${code}" = "200" ]; then
      echo "[INFO] Keycloak discovery is ready (HTTP 200)"
      return 0
    fi
    sleep 5
  done

  echo "[FAIL] Keycloak discovery did not become ready at http://localhost:8080" >&2
  docker compose -f "${compose_file}" ps keycloak >&2 || true
  docker compose -f "${compose_file}" logs --no-color --tail=120 keycloak >&2 || true
  return 1
}

ensure_webhook_mtls_certs() {
  local ensure_script="${PROJECT_ROOT}/demo/mtls/ensure-mtls-certs.sh"

  [ -x "${ensure_script}" ] || [ -f "${ensure_script}" ] \
    || {
      echo "[FAIL] Missing webhook mTLS ensure script: ${ensure_script}" >&2
      return 1
    }

  echo "[INFO] Ensuring local-only webhook mTLS demo certs are present and consistent"
  if ! bash "${ensure_script}"; then
    echo "[FAIL] Webhook mTLS cert generation failed: ${ensure_script}" >&2
    return 1
  fi
  echo "[INFO] Before final security scan/package creation, remove runtime private artifacts: rm -f infra/certs/*.key infra/certs/*.p12"
}

ensure_gateway_backend_mtls_certs() {
  local ensure_script="${PROJECT_ROOT}/demo/mtls/ensure-gateway-backend-certs.sh"

  [ -x "${ensure_script}" ] || [ -f "${ensure_script}" ] \
    || {
      echo "[ERROR] Missing gateway-backend mTLS ensure script: ${ensure_script}" >&2
      return 1
    }

  echo "[INFO] Ensuring local-only gateway-backend mTLS demo certs are present"
  bash "${ensure_script}"
}

restart_gateway_backend_mtls_proxies() {
  echo ""
  echo "[INFO] Restarting gateway-backend mTLS sidecars after cert generation"
  if [ -f "${PROJECT_ROOT}/infra/docker-compose.yml" ]; then
    (cd "${PROJECT_ROOT}" && docker compose -f infra/docker-compose.yml restart \
      user-mtls-proxy \
      order-mtls-proxy \
      billing-mtls-proxy \
      admin-mtls-proxy)
  else
    echo "[INFO] infra/docker-compose.yml not available; skipping mTLS sidecar restart"
  fi
}

echo "=============================================="
echo "  FINAL REGRESSION TEST"
echo "  $(date)"
echo "=============================================="

ensure_webhook_mtls_certs
ensure_gateway_backend_mtls_certs
restart_gateway_backend_mtls_proxies
reset_kong_at_start
ensure_keycloak_ready

run_suite "Container Runtime Hardening" "tests/security/container-runtime-hardening-tests.sh"
run_suite "Smoke Test" "tests/smoke/main-smoke.sh"
run_suite "OpenAPI Contract" "tests/security/openapi-contract-tests.sh"
run_suite "Client Credentials" "tests/security/client-credentials-tests.sh"
run_suite "Token Lifecycle" "tests/security/token-lifecycle-tests.sh"
run_suite "Real S2S Ownership" "tests/security/s2s-ownership-tests.sh"
reset_kong_before_authz_negative
run_suite "Authz Negative" "tests/security/authz-negative-tests.sh"
reset_kong_before_opa
run_suite "OPA Authz" "tests/security/opa-authz-tests.sh"
run_suite "Edge Hardening" "tests/security/edge-hardening-tests.sh"
snapshot_webhook_cert_artifacts
ensure_webhook_mtls_certs
reset_kong_after_edge
run_suite "Webhook Security" "tests/security/webhook-tests.sh"
run_suite "Webhook Nonce Persistence" "tests/security/webhook-nonce-persistence-tests.sh"
restore_webhook_cert_artifacts
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
