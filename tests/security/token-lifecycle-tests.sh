#!/usr/bin/env bash
# tests/security/token-lifecycle-tests.sh
#
# IdP-level token introspection and revocation checks for TV2.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BILLING_TOKEN_OUTPUT="/tmp/token-lifecycle-billing-token-output.txt"
BILLING_TOKEN_FILE="${BILLING_SERVICE_TOKEN_FILE:-/tmp/billing-service-token.txt}"
VALID_INTROSPECTION_OUTPUT="/tmp/token-lifecycle-introspection-valid.txt"
INVALID_TOKEN_FILE="/tmp/token-lifecycle-invalid-token.txt"
INVALID_INTROSPECTION_OUTPUT="/tmp/token-lifecycle-introspection-invalid.txt"
REVOCATION_OUTPUT="/tmp/token-lifecycle-revocation.txt"

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

metadata_value() {
  local file="$1"
  local key="$2"
  awk -F= -v k="${key}" '$1==k{print $2}' "${file}" | tail -n 1
}

assert_equals() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "${actual}" = "${expected}" ]; then
    pass "${name} -> ${actual}"
  else
    fail "${name} expected ${expected} got ${actual}"
  fi
}

assert_one_of() {
  local name="$1"
  local actual="$2"
  shift 2

  local expected
  for expected in "$@"; do
    if [ "${actual}" = "${expected}" ]; then
      pass "${name} -> ${actual}"
      return
    fi
  done

  fail "${name} unexpected value ${actual}"
}

assert_no_sensitive_output() {
  local name="$1"
  local file="$2"

  if grep -Eq 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.' "${file}"; then
    fail "${name} leaked JWT material"
  elif [ -n "${BILLING_SERVICE_CLIENT_SECRET:-}" ] && grep -Fq "${BILLING_SERVICE_CLIENT_SECRET}" "${file}"; then
    fail "${name} leaked client secret"
  else
    pass "${name} output is metadata-only"
  fi
}

echo "=============================================="
echo "  TOKEN LIFECYCLE SECURITY TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

if [ -z "${BILLING_SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] BILLING_SERVICE_CLIENT_SECRET is required."
  echo "[ERROR] Set it from Keycloak/Vault; this test will not print the secret."
  exit 1
fi

echo "===== Obtain service token ====="
if bash "${PROJECT_ROOT}/demo/auth/get-billing-service-token.sh" > "${BILLING_TOKEN_OUTPUT}" 2>&1; then
  pass "billing service token obtained"
else
  fail "billing service token script failed"
  cat "${BILLING_TOKEN_OUTPUT}"
  exit 1
fi
assert_no_sensitive_output "billing token script" "${BILLING_TOKEN_OUTPUT}"
assert_equals "billing token TTL metadata" "300" "$(metadata_value "${BILLING_TOKEN_OUTPUT}" ttl_seconds)"

echo ""
echo "===== Introspect valid token ====="
if TOKEN_FILE="${BILLING_TOKEN_FILE}" \
  INTROSPECTION_CLIENT_ID="${BILLING_SERVICE_CLIENT_ID:-billing-service-client}" \
  INTROSPECTION_CLIENT_SECRET="${BILLING_SERVICE_CLIENT_SECRET}" \
  bash "${PROJECT_ROOT}/demo/auth/introspect-token.sh" > "${VALID_INTROSPECTION_OUTPUT}" 2>&1; then
  pass "valid token introspection completed"
else
  fail "valid token introspection failed"
  cat "${VALID_INTROSPECTION_OUTPUT}"
  exit 1
fi
assert_no_sensitive_output "valid introspection" "${VALID_INTROSPECTION_OUTPUT}"
assert_equals "valid token active" "true" "$(metadata_value "${VALID_INTROSPECTION_OUTPUT}" active)"
assert_equals "valid token client_id" "billing-service-client" "$(metadata_value "${VALID_INTROSPECTION_OUTPUT}" client_id)"

echo ""
echo "===== Introspect invalid token ====="
umask 077
printf '%s' "fake.jwt.token" > "${INVALID_TOKEN_FILE}"
if TOKEN_FILE="${INVALID_TOKEN_FILE}" \
  INTROSPECTION_CLIENT_ID="${BILLING_SERVICE_CLIENT_ID:-billing-service-client}" \
  INTROSPECTION_CLIENT_SECRET="${BILLING_SERVICE_CLIENT_SECRET}" \
  bash "${PROJECT_ROOT}/demo/auth/introspect-token.sh" > "${INVALID_INTROSPECTION_OUTPUT}" 2>&1; then
  assert_no_sensitive_output "invalid introspection" "${INVALID_INTROSPECTION_OUTPUT}"
  assert_equals "invalid token active" "false" "$(metadata_value "${INVALID_INTROSPECTION_OUTPUT}" active)"
else
  assert_no_sensitive_output "invalid introspection failure" "${INVALID_INTROSPECTION_OUTPUT}"
  pass "invalid token introspection failed closed"
fi

echo ""
echo "===== Revoke token at IdP ====="
if TOKEN_FILE="${BILLING_TOKEN_FILE}" \
  REVOCATION_CLIENT_ID="${BILLING_SERVICE_CLIENT_ID:-billing-service-client}" \
  REVOCATION_CLIENT_SECRET="${BILLING_SERVICE_CLIENT_SECRET}" \
  bash "${PROJECT_ROOT}/demo/auth/revoke-token.sh" > "${REVOCATION_OUTPUT}" 2>&1; then
  pass "revocation endpoint completed"
else
  fail "revocation endpoint failed"
  cat "${REVOCATION_OUTPUT}"
  exit 1
fi
assert_no_sensitive_output "revocation" "${REVOCATION_OUTPUT}"
assert_equals "revocation request sent" "true" "$(metadata_value "${REVOCATION_OUTPUT}" revocation_request_sent)"
assert_one_of "revocation HTTP status" "$(metadata_value "${REVOCATION_OUTPUT}" http_status)" "200" "204"

echo ""
echo "=============================================="
echo "  TOKEN LIFECYCLE RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] Token lifecycle tests have failures."
  exit 1
fi
