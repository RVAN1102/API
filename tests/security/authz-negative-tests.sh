#!/usr/bin/env bash
# tests/security/authz-negative-tests.sh
#
# Authorization negative regression tests.
# Verifies that auth bugs already fixed do NOT regress.
#
# Tests:
#   - Fake/malformed tokens rejected (401)
#   - RBAC: user cannot access service-only admin automation (403)
#   - Service client can access service-only admin automation (200)
#   - BOLA fixed: ci-alice cannot read Bob's order (403)
#   - Billing: checkout ownership enforced (202/403)
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

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-alice > /tmp/tv3-ci-alice-token.log 2>&1
cp /tmp/user-token.txt /tmp/tv3-ci-alice-token.txt
echo "[INFO] ci-alice automation token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-bob > /tmp/tv3-ci-bob-token.log 2>&1
cp /tmp/user-token.txt /tmp/tv3-ci-bob-token.txt
echo "[INFO] ci-bob automation token obtained"

if [ -z "${SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] SERVICE_CLIENT_SECRET is required for service-client admin automation checks."
  echo "[ERROR] Set it from Keycloak/Vault; this test will not print the secret."
  exit 1
fi

bash "${PROJECT_ROOT}/demo/auth/get-service-token.sh" > /tmp/tv3-service-token.log 2>&1
cp /tmp/service-token.txt /tmp/tv3-service-token.txt
echo "[INFO] service client token obtained"

CI_ALICE_TOKEN="$(cat /tmp/tv3-ci-alice-token.txt)"
CI_BOB_TOKEN="$(cat /tmp/tv3-ci-bob-token.txt)"
SERVICE_TOKEN="$(cat /tmp/tv3-service-token.txt)"

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

assert_status "ci-alice automation admin maintenance forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer ${CI_ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "service client maintenance allowed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer ${SERVICE_TOKEN}" \
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

assert_status "ci-alice automation bob order fixed forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" \
    -H "Authorization: Bearer ${CI_ALICE_TOKEN}")"

assert_status "ci-bob automation bob order fixed allowed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" \
    -H "Authorization: Bearer ${CI_BOB_TOKEN}")"

echo ""

# ── Billing auth ──────────────────────────────────
echo "===== Billing auth ====="

assert_status "billing ci-alice automation checkout accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer ${CI_ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "billing ci-alice automation bob checkout forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer ${CI_ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-bob-2001","amount":80000,"currency":"VND"}')"

assert_status "billing ci-bob automation checkout accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer ${CI_BOB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-bob-2001","amount":80000,"currency":"VND"}')"

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

assert_status "billing malformed compact token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer eyJ.invalid" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "billing extremely malformed token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer not-a-jwt-@@@" \
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
