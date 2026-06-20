#!/usr/bin/env bash
# tests/security/client-credentials-tests.sh
#
# Regression coverage for per-service Client Credentials clients.

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BILLING_TOKEN_OUTPUT="/tmp/billing-service-token-output.txt"
ADMIN_TOKEN_OUTPUT="/tmp/admin-service-token-output.txt"
BILLING_TOKEN_FILE="${BILLING_SERVICE_TOKEN_FILE:-/tmp/billing-service-token.txt}"
ADMIN_TOKEN_FILE="${ADMIN_SERVICE_TOKEN_FILE:-/tmp/admin-service-token.txt}"
AUTH_HEADER_NAME="Authorization"
BEARER_SCHEME="Bearer"

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

bearer_header() {
  printf "%s: %s %s" "${AUTH_HEADER_NAME}" "${BEARER_SCHEME}" "$1"
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

metadata_value() {
  local file="$1"
  local key="$2"
  awk -F= -v k="${key}" '$1==k{print $2}' "${file}" | tail -n 1
}

jwt_claims_value() {
  local token_file="$1"
  local field="$2"
  python3 - "${token_file}" "${field}" <<'PY'
import base64
import json
import sys

token = open(sys.argv[1], encoding="utf-8").read().strip()
field = sys.argv[2]
payload = token.split(".")[1]
payload += "=" * (-len(payload) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")))

if field == "ttl":
    print(int(claims["exp"]) - int(claims["iat"]))
elif field == "roles":
    print(",".join(claims.get("realm_access", {}).get("roles", [])))
else:
    print(claims.get(field, ""))
PY
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
service_users = {
    user.get("serviceAccountClientId"): user
    for user in realm.get("users", [])
    if user.get("serviceAccountClientId")
}

print(f"realm_access_token_lifespan={realm.get('accessTokenLifespan')}")
for client_id in ("billing-service-client", "admin-service-client"):
    client = clients.get(client_id) or {}
    account = service_users.get(client_id) or {}
    prefix = client_id.replace("-", "_")
    print(f"{prefix}_present={str(bool(client)).lower()}")
    print(f"{prefix}_service_accounts_enabled={str(bool(client.get('serviceAccountsEnabled'))).lower()}")
    print(f"{prefix}_direct_grant_enabled={str(bool(client.get('directAccessGrantsEnabled'))).lower()}")
    print(f"{prefix}_token_lifespan={client.get('attributes', {}).get('access.token.lifespan', '')}")
    print(f"{prefix}_roles=" + ",".join(account.get("realmRoles", [])))
PY
)"

echo "${STATIC_CHECKS}"
assert_equals "realm access token lifespan" "300" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="realm_access_token_lifespan"{print $2}')"

for prefix in billing_service_client admin_service_client; do
  assert_equals "${prefix} exists" "true" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= -v k="${prefix}_present" '$1==k{print $2}')"
  assert_equals "${prefix} service account enabled" "true" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= -v k="${prefix}_service_accounts_enabled" '$1==k{print $2}')"
  assert_equals "${prefix} password grant disabled" "false" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= -v k="${prefix}_direct_grant_enabled" '$1==k{print $2}')"
  assert_equals "${prefix} access token lifespan" "300" "$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= -v k="${prefix}_token_lifespan" '$1==k{print $2}')"
done

BILLING_ROLES="$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="billing_service_client_roles"{print $2}')"
ADMIN_ROLES="$(printf '%s\n' "${STATIC_CHECKS}" | awk -F= '$1=="admin_service_client_roles"{print $2}')"
case ",${BILLING_ROLES}," in
  *,order-ownership-read,*) pass "billing-service-client has order-ownership-read role" ;;
  *) fail "billing-service-client missing order-ownership-read role" ;;
esac
case ",${ADMIN_ROLES}," in
  *,admin-maintenance,*) pass "admin-service-client has admin-maintenance role" ;;
  *) fail "admin-service-client missing admin-maintenance role" ;;
esac

echo ""
echo "===== Obtain service tokens ====="

if [ -z "${BILLING_SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] BILLING_SERVICE_CLIENT_SECRET is required."
  echo "[ERROR] Set it from Keycloak/Vault; this test will not print the secret."
  exit 1
fi

if [ -z "${ADMIN_SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] ADMIN_SERVICE_CLIENT_SECRET is required."
  echo "[ERROR] Set it from Keycloak/Vault; this test will not print the secret."
  exit 1
fi

if bash "${PROJECT_ROOT}/demo/auth/get-billing-service-token.sh" > "${BILLING_TOKEN_OUTPUT}" 2>&1; then
  pass "billing service token script completed"
else
  fail "billing service token script failed"
  cat "${BILLING_TOKEN_OUTPUT}"
  exit 1
fi

if bash "${PROJECT_ROOT}/demo/auth/get-admin-service-token.sh" > "${ADMIN_TOKEN_OUTPUT}" 2>&1; then
  pass "admin service token script completed"
else
  fail "admin service token script failed"
  cat "${ADMIN_TOKEN_OUTPUT}"
  exit 1
fi

for output_file in "${BILLING_TOKEN_OUTPUT}" "${ADMIN_TOKEN_OUTPUT}"; do
  if grep -q '^token_obtained=true$' "${output_file}"; then
    pass "$(basename "${output_file}") metadata confirms success"
  else
    fail "$(basename "${output_file}") metadata missing success flag"
  fi

  if grep -Eq 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.' "${output_file}"; then
    fail "$(basename "${output_file}") stdout leaked JWT material"
  else
    pass "$(basename "${output_file}") stdout does not leak JWT material"
  fi
done

assert_equals "billing token TTL metadata" "300" "$(metadata_value "${BILLING_TOKEN_OUTPUT}" ttl_seconds)"
assert_equals "admin token TTL metadata" "300" "$(metadata_value "${ADMIN_TOKEN_OUTPUT}" ttl_seconds)"
assert_equals "billing token TTL claims" "300" "$(jwt_claims_value "${BILLING_TOKEN_FILE}" ttl)"
assert_equals "admin token TTL claims" "300" "$(jwt_claims_value "${ADMIN_TOKEN_FILE}" ttl)"

BILLING_TOKEN_ROLES="$(jwt_claims_value "${BILLING_TOKEN_FILE}" roles)"
ADMIN_TOKEN_ROLES="$(jwt_claims_value "${ADMIN_TOKEN_FILE}" roles)"
case ",${BILLING_TOKEN_ROLES}," in
  *,order-ownership-read,*) pass "billing token contains order-ownership-read role" ;;
  *) fail "billing token missing order-ownership-read role" ;;
esac
case ",${ADMIN_TOKEN_ROLES}," in
  *,admin-maintenance,*) pass "admin token contains admin-maintenance role" ;;
  *) fail "admin token missing admin-maintenance role" ;;
esac

echo ""
echo "===== Service token authorization ====="

BILLING_TOKEN="$(cat "${BILLING_TOKEN_FILE}")"
ADMIN_TOKEN="$(cat "${ADMIN_TOKEN_FILE}")"

assert_status "billing-service-client Order ownership allowed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "admin-service-client Order ownership forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "billing-service-client Admin maintenance forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check"}')"

assert_status "admin-service-client Admin maintenance allowed" 200 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check"}')"

assert_status "billing service token users me forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "$(bearer_header "${BILLING_TOKEN}")")"

assert_status "admin service token users me forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "$(bearer_header "${ADMIN_TOKEN}")")"

assert_status "billing service token billing checkout forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

echo ""
echo "=============================================="
echo "  CLIENT CREDENTIALS RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] Client Credentials tests have failures."
  exit 1
fi
