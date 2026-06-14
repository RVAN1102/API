#!/usr/bin/env bash
# tests/auth/test-user-profile.sh
#
# Tests User API authentication and authorization.
#
# Test cases:
#   1. Public health check (no token)
#   2. Protected /me with valid token → 200
#   3. Protected /me without token    → 401
#   4. Protected /profile with valid token → 200
#
# Usage:
#   # With Keycloak running (requires valid token):
#   ACCESS_TOKEN=$(bash demo/auth/get-user-token.sh alice 2>/dev/null | tail -1)
#   bash tests/auth/test-user-profile.sh
#
#   # Without Keycloak (expects 401 for protected endpoints):
#   bash tests/auth/test-user-profile.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
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

echo "=== User Profile Tests ==="
echo "Base URL: ${BASE_URL}"
echo ""

# Test 1: Health check (public)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/health")
assert_status "Health check (public, no token)" 200 "${STATUS}"

# Test 2: /me without token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/me")
assert_status "GET /users/me (no token) → 401" 401 "${STATUS}"

# Test 3: /profile without token → 401
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/profile")
assert_status "GET /users/profile (no token) → 401" 401 "${STATUS}"

# Test 4: /me with valid token (only if token is provided)
if [ -n "${ACCESS_TOKEN}" ]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/me" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Correlation-ID: test-user-profile-001")
  assert_status "GET /users/me (valid token) → 200" 200 "${STATUS}"

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/profile" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "X-Correlation-ID: test-user-profile-002")
  assert_status "GET /users/profile (valid token) → 200" 200 "${STATUS}"
else
  echo "[SKIP] Token-required tests (set ACCESS_TOKEN env var to enable)"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
