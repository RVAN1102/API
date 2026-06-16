#!/usr/bin/env bash
# tests/security/authz-negative-tests.sh
#
# Authorization negative regression tests.
# Verifies that auth bugs already fixed do NOT regress.
#
# Tests:
#   - Fake/malformed tokens rejected (401)
#   - RBAC: user cannot access admin endpoints (403)
#   - BOLA fixed: Alice cannot read Bob's order (403)
#   - Billing: malformed tokens rejected (401)
#
# Usage:
#   bash tests/security/authz-negative-tests.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
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
echo "  AUTHZ NEGATIVE REGRESSION TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

# ── Prepare tokens ────────────────────────────────
echo "===== Prepare tokens ====="

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" alice > /tmp/tv3-alice-token.log 2>&1
cp /tmp/user-token.txt /tmp/tv3-alice-token.txt
echo "[INFO] Alice token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" bob > /tmp/tv3-bob-token.log 2>&1
cp /tmp/user-token.txt /tmp/tv3-bob-token.txt
echo "[INFO] Bob token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" admin01 > /tmp/tv3-admin-token.log 2>&1
cp /tmp/user-token.txt /tmp/tv3-admin-token.txt
echo "[INFO] Admin token obtained"

ALICE_TOKEN="$(cat /tmp/tv3-alice-token.txt)"
BOB_TOKEN="$(cat /tmp/tv3-bob-token.txt)"
ADMIN_TOKEN="$(cat /tmp/tv3-admin-token.txt)"

echo ""

# ── User endpoint negative ────────────────────────
echo "===== User endpoint negative ====="

assert_status "users me fake token" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "Authorization: Bearer fake.jwt.token")"

echo ""

# ── Admin RBAC ────────────────────────────────────
echo "===== Admin RBAC ====="

assert_status "alice admin maintenance forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer ${ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "admin maintenance allowed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "admin fake token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer fake.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "admin malformed token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv3-authz-test"}')"

echo ""

# ── BOLA fixed endpoint ──────────────────────────
echo "===== BOLA fixed endpoint ====="

assert_status "alice own order fixed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/orders/ord-alice-1001/fixed" \
    -H "Authorization: Bearer ${ALICE_TOKEN}")"

assert_status "alice bob order fixed forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" \
    -H "Authorization: Bearer ${ALICE_TOKEN}")"

assert_status "bob own order fixed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" \
    -H "Authorization: Bearer ${BOB_TOKEN}")"

echo ""

# ── Billing auth ──────────────────────────────────
echo "===== Billing auth ====="

assert_status "billing alice checkout accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer ${ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "billing fake token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer fake.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "billing malformed token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

echo ""

# ── Summary ───────────────────────────────────────
echo "=============================================="
echo "  AUTHZ NEGATIVE RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "[ERROR] Authz negative tests have failures."
  exit 1
fi
