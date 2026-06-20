#!/usr/bin/env bash
# tests/auth/test-order-access.sh
#
# Tests Order API authentication and access control.
#
# Test cases:
#   1. Health check (no token) → 200
#   2. GET /orders (no token)  → 401
#   3. GET /orders (valid token) → 200
#   4. GET /orders/ord-alice-1001 (alice token) → 200
#
# Usage:
#   ACCESS_TOKEN=$(cat /tmp/user-token.txt) bash tests/auth/test-order-access.sh

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
ACCESS_TOKEN="${ACCESS_TOKEN:-}"

PASS=0
FAIL=0

assert_status() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "${actual}" -eq "${expected}" ]; then
    echo "[PASS] ${label} (HTTP ${actual})"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] ${label} – expected HTTP ${expected}, got HTTP ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Order Access Tests ==="
echo "Base URL: ${BASE_URL}"
echo ""

# Test 1: Health check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/health")
assert_status "GET /orders/health (public) → 200" 200 "${STATUS}"

# Test 2: List orders without token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders")
assert_status "GET /orders (no token) → 401" 401 "${STATUS}"

if [ -n "${ACCESS_TOKEN}" ]; then
  # Test 3: List orders with token → 200
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Correlation-ID: test-order-001")
  assert_status "GET /orders (valid token) → 200" 200 "${STATUS}"

  # Test 4: Get specific order with token
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/ord-alice-1001" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Correlation-ID: test-order-002")
  assert_status "GET /orders/ord-alice-1001 (alice token) → 200 or 403" 200 "${STATUS}" 2>/dev/null || \
  assert_status "GET /orders/ord-alice-1001 (alice token) → 403 if not alice" 403 "${STATUS}"
else
  echo "[SKIP] Token-required tests (set ACCESS_TOKEN env var to enable)"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
