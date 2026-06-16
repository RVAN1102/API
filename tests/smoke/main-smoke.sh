#!/usr/bin/env bash
# tests/smoke/main-smoke.sh
#
# Main smoke test – verifies the foundation of the system.
# Every member must run this BEFORE merging into main.
#
# Usage:
#   bash tests/smoke/main-smoke.sh
#
# Environment:
#   BASE_URL      – default: http://localhost:8000
#   KEYCLOAK_URL  – default: http://localhost:8080
#   REALM         – default: topic10-sme-api

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="${REALM:-topic10-sme-api}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TOTAL=0
PASSED=0
FAILED=0

pass() {
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
  echo "[PASS] $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  echo "[FAIL] $1"
}

assert_status() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" = "$expected" ]; then
    pass "$name -> $actual"
  else
    fail "$name expected $expected got $actual"
  fi
}

echo "=============================================="
echo "  MAIN SMOKE TEST"
echo "  $(date)"
echo "=============================================="
echo ""

# ── Health endpoints ──────────────────────────────
echo "===== Smoke: health endpoints ====="

assert_status "users health" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/health")"

assert_status "orders health" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/health")"

assert_status "billing health" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/billing/health")"

assert_status "admin health" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/admin/health")"

echo ""

# ── Keycloak discovery ────────────────────────────
echo "===== Smoke: Keycloak OIDC discovery ====="
DISCOVERY_URL="${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration"

echo "Waiting for Keycloak discovery endpoint..."
DISCOVERY_CODE="000"
for i in {1..40}; do
  DISCOVERY_CODE="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${DISCOVERY_URL}" || true)"
  if [[ "${DISCOVERY_CODE}" == "200" ]]; then
    break
  fi
  sleep 3
done

assert_status "keycloak discovery" 200 "${DISCOVERY_CODE}"

echo ""
# ── Alice token + /users/me ───────────────────────
echo "===== Smoke: Alice token and /users/me ====="

# Get Alice token
if bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" alice > /tmp/tv3-alice-smoke.log 2>&1; then
  ALICE_TOKEN="$(cat /tmp/user-token.txt)"
  pass "alice token obtained"

  assert_status "users me alice" 200 \
    "$(curl -s -o /dev/null -w "%{http_code}" \
      "${BASE_URL}/api/v1/users/me" \
      -H "Authorization: Bearer ${ALICE_TOKEN}")"
else
  fail "alice token failed (see /tmp/tv3-alice-smoke.log)"
  fail "users me alice (skipped – no token)"
fi

echo ""

# ── Summary ───────────────────────────────────────
echo "=============================================="
echo "  SMOKE RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "[ERROR] Smoke test has failures. DO NOT merge into main."
  exit 1
fi
