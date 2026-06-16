#!/usr/bin/env bash
# tests/security/client-credentials-tests.sh
#
# Regression coverage for backend service-to-service Client Credentials flow.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TOKEN_OUTPUT="/tmp/client-credentials-token-output.txt"
TOKEN_FILE="${SERVICE_TOKEN_FILE:-/tmp/service-token.txt}"

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

assert_status() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "${actual}" = "${expected}" ]; then
    pass "${name} -> ${actual}"
  else
    fail "${name} expected ${expected} got ${actual}"
  fi
}

echo "=============================================="
echo "  CLIENT CREDENTIALS SECURITY TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

echo "===== Static Keycloak config checks ====="
STATIC_CHECKS="$(python3 - "${PROJECT_ROOT}/idp/realm-export/topic10-realm.json" <<'PY'
import json
import sys

realm = json.load(open(sys.argv[1], encoding="utf-8"))
clients = {client.get("clientId"): client for client in realm.get("clients", [])}
service_client = clients.get("sme-service-client")
service_users = {
    user.get("serviceAccountClientId"): user
    for user in realm.get("users", [])
    if user.get("serviceAccountClientId")
}
service_account = service_users.get("sme-service-client")

print(f"realm_access_token_lifespan={realm.get('accessTokenLifespan')}")
print(f"service_client_present={str(service_client is not None).lower()}")
print(f"service_accounts_enabled={str(bool(service_client and service_client.get('serviceAccountsEnabled'))).lower()}")
print(f"service_direct_grant_enabled={str(bool(service_client and service_client.get('directAccessGrantsEnabled'))).lower()}")
print(f"service_client_token_lifespan={service_client.get('attributes', {}).get('access.token.lifespan', '') if service_client else ''}")
print("service_account_roles=" + ",".join(service_account.get("realmRoles", []) if service_account else []))
PY
)"

echo "${STATIC_CHECKS}"
assert_equals "realm access token lifespan" "300" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="realm_access_token_lifespan"{print $2}')"
assert_equals "service client exists" "true" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="service_client_present"{print $2}')"
assert_equals "service account enabled" "true" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="service_accounts_enabled"{print $2}')"
assert_equals "service password grant disabled" "false" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="service_direct_grant_enabled"{print $2}')"
assert_equals "service client access token lifespan" "300" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="service_client_token_lifespan"{print $2}')"

SERVICE_ACCOUNT_ROLES="$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="service_account_roles"{print $2}')"
case ",${SERVICE_ACCOUNT_ROLES}," in
  *,internal-service,*) pass "service account has internal-service role" ;;
  *) fail "service account missing internal-service role" ;;
esac

echo ""
echo "===== Obtain service token ====="

if [ -z "${SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] SERVICE_CLIENT_SECRET is required for dynamic Client Credentials tests."
  echo "[ERROR] Set it from Keycloak/Vault; this test will not print the secret."
  exit 1
fi

if bash "${PROJECT_ROOT}/demo/auth/get-service-token.sh" > "${TOKEN_OUTPUT}" 2>&1; then
  pass "service token script completed"
else
  fail "service token script failed"
  echo "Sanitized script output:"
  cat "${TOKEN_OUTPUT}"
  echo ""
  echo "=============================================="
  echo "  CLIENT CREDENTIALS RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
  echo "=============================================="
  exit 1
fi

if [ -s "${TOKEN_FILE}" ]; then
  pass "service token file written"
else
  fail "service token file missing or empty"
  echo ""
  echo "=============================================="
  echo "  CLIENT CREDENTIALS RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
  echo "=============================================="
  exit 1
fi

if grep -q '^service_token_obtained=true$' "${TOKEN_OUTPUT}"; then
  pass "service token metadata confirms success"
else
  fail "service token metadata missing success flag"
fi

if grep -Eq 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.' "${TOKEN_OUTPUT}"; then
  fail "service token stdout leaked JWT material"
else
  pass "service token stdout does not leak JWT material"
fi

SCRIPT_TTL="$(awk -F= '$1=="token_ttl_seconds"{print $2}' "${TOKEN_OUTPUT}" | tail -n 1)"
assert_equals "service token TTL from script metadata" "300" "${SCRIPT_TTL}"

DECODED_TTL="$(python3 - "${TOKEN_FILE}" <<'PY'
import base64
import json
import sys

token = open(sys.argv[1], encoding="utf-8").read().strip()
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")))
print(int(claims["exp"]) - int(claims["iat"]))
PY
)"
assert_equals "service token TTL from JWT claims" "300" "${DECODED_TTL}"

TOKEN_ROLES="$(python3 - "${TOKEN_FILE}" <<'PY'
import base64
import json
import sys

token = open(sys.argv[1], encoding="utf-8").read().strip()
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")))
print(",".join(claims.get("realm_access", {}).get("roles", [])))
PY
)"
case ",${TOKEN_ROLES}," in
  *,internal-service,*) pass "service token contains internal-service role" ;;
  *) fail "service token missing internal-service role" ;;
esac

echo ""
echo "===== Service token authorization ====="

SERVICE_TOKEN="$(cat "${TOKEN_FILE}")"

assert_status "service token admin maintenance allowed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "Authorization: Bearer ${SERVICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check"}')"

assert_status "service token admin metadata fixed forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/metadata-fetch/fixed" \
    -H "Authorization: Bearer ${SERVICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"fetch_url":"https://example.com"}')"

assert_status "service token billing checkout forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer ${SERVICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "service token users me forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "Authorization: Bearer ${SERVICE_TOKEN}")"

echo ""
echo "=============================================="
echo "  CLIENT CREDENTIALS RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] Client Credentials tests have failures."
  exit 1
fi
