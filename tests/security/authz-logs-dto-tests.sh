#!/usr/bin/env bash
# tests/security/authz-logs-dto-tests.sh
#
# TV2 auth-failure logging and DTO/schema consistency checks.
#
# Usage:
#   bash tests/security/authz-logs-dto-tests.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/infra/docker-compose.yml"
AUTH_HEADER_NAME="Authorization"
BEARER_SCHEME="Bearer"

TOTAL=0
PASSED=0
FAILED=0
TMP_FILES=()

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

tmp_file() {
  local file
  file="$(mktemp /tmp/tv2-authz-logs-dto.XXXXXX)"
  TMP_FILES+=("${file}")
  printf "%s" "${file}"
}

cleanup() {
  if [ "${#TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${TMP_FILES[@]}"
  fi
}
trap cleanup EXIT

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

assert_json_keys() {
  local name="$1"
  local file="$2"
  shift 2

  if python3 - "${file}" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
keys = sys.argv[2:]
with open(path, encoding="utf-8") as handle:
    body = json.load(handle)
missing = [key for key in keys if key not in body]
if missing:
    print(",".join(missing))
    raise SystemExit(1)
PY
  then
    pass "${name} JSON fields present"
  else
    fail "${name} JSON fields missing"
  fi
}

assert_json_list_field() {
  local name="$1"
  local file="$2"
  local field="$3"

  if python3 - "${file}" "${field}" <<'PY'
import json
import sys

path, field = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    body = json.load(handle)
value = body.get(field)
if not isinstance(value, list):
    raise SystemExit(1)
PY
  then
    pass "${name} ${field} is a list"
  else
    fail "${name} ${field} is not a list"
  fi
}

docker_logs() {
  local service="$1"
  docker compose -f "${COMPOSE_FILE}" logs --no-color --tail=300 "${service}" 2>/dev/null || true
}

assert_auth_log_event() {
  local service="$1"
  local correlation_id="$2"
  local expected_status="$3"
  local expected_reason="$4"

  for _ in {1..10}; do
    local log_file
    log_file="$(tmp_file)"
    docker_logs "${service}" > "${log_file}"

    if python3 - "${service}" "${correlation_id}" "${expected_status}" "${expected_reason}" "${log_file}" <<'PY'
import json
import sys

service, correlation_id, expected_status, expected_reason, log_path = sys.argv[1:6]
required = {
    "timestamp",
    "level",
    "service",
    "event_type",
    "method",
    "path",
    "status_code",
    "reason",
    "correlation_id",
}

with open(log_path, encoding="utf-8") as handle:
    for raw in handle:
        start = raw.find("{")
        if start < 0:
            continue
        try:
            record = json.loads(raw[start:])
        except json.JSONDecodeError:
            continue
        if record.get("correlation_id") != correlation_id:
            continue
        if record.get("event_type") != "auth_failure":
            continue
        if record.get("service") != service:
            continue
        if str(record.get("status_code")) != expected_status:
            continue
        if record.get("reason") != expected_reason:
            continue
        if record.get("category") != expected_reason:
            continue
        if required - set(record):
            continue
        raise SystemExit(0)

raise SystemExit(1)
PY
    then
      pass "${service} auth_failure ${expected_reason} log"
      return
    fi
    sleep 1
  done

  fail "${service} auth_failure ${expected_reason} log not found"
}

assert_log_safe() {
  local service="$1"
  local correlation_id="$2"
  local sensitive_value="$3"
  local label="$4"
  local logs

  logs="$(docker_logs "${service}" | grep -F "${correlation_id}" || true)"
  if printf "%s\n" "${logs}" | grep -F -- "${sensitive_value}" >/dev/null 2>&1; then
    fail "${service} log leaked ${label}"
  else
    pass "${service} log does not contain ${label}"
  fi

  if printf "%s\n" "${logs}" | grep -F -- "${AUTH_HEADER_NAME}: ${BEARER_SCHEME}" >/dev/null 2>&1; then
    fail "${service} log leaked bearer request header value"
  else
    pass "${service} log does not contain bearer request header value"
  fi
}

echo "=============================================="
echo "  TV2 AUTHZ LOGS AND DTO TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker is required for service log assertions."
  exit 1
fi

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "[ERROR] Compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

if [ -z "${BILLING_SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] BILLING_SERVICE_CLIENT_SECRET is required; this script will not print it."
  exit 1
fi

if [ -z "${ADMIN_SERVICE_CLIENT_SECRET:-}" ]; then
  echo "[ERROR] ADMIN_SERVICE_CLIENT_SECRET is required; this script will not print it."
  exit 1
fi

echo "===== Prepare tokens ====="

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-alice > /tmp/tv2-authz-logs-ci-alice-token.log 2>&1
CI_ALICE_TOKEN="$(cat /tmp/user-token.txt)"
echo "[INFO] ci-alice automation token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-billing-service-token.sh" > /tmp/tv2-authz-logs-billing-token.log 2>&1
BILLING_TOKEN="$(cat /tmp/billing-service-token.txt)"
echo "[INFO] billing service token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-admin-service-token.sh" > /tmp/tv2-authz-logs-admin-token.log 2>&1
ADMIN_TOKEN="$(cat /tmp/admin-service-token.txt)"
echo "[INFO] admin service token obtained"

echo ""
echo "===== Auth failure logs ====="

CID_INVALID="tv2-invalid-token-$(date +%s)"
FAKE_TOKEN="fake.jwt.token"
assert_status "users me fake token" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "$(bearer_header "${FAKE_TOKEN}")" \
    -H "X-Correlation-ID: ${CID_INVALID}")"
assert_auth_log_event "user-service" "${CID_INVALID}" 401 "invalid_token"
assert_log_safe "user-service" "${CID_INVALID}" "${FAKE_TOKEN}" "raw fake token"

CID_USER_REQUIRED="tv2-user-required-$(date +%s)"
assert_status "billing service token users me forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "X-Correlation-ID: ${CID_USER_REQUIRED}")"
assert_auth_log_event "user-service" "${CID_USER_REQUIRED}" 403 "user_required"
assert_log_safe "user-service" "${CID_USER_REQUIRED}" "${BILLING_TOKEN}" "raw service token"

CID_ORDER_SERVICE="tv2-order-service-client-$(date +%s)"
assert_status "admin service token order ownership forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: ${CID_ORDER_SERVICE}" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"
assert_auth_log_event "order-service" "${CID_ORDER_SERVICE}" 403 "service_client_forbidden"
assert_log_safe "order-service" "${CID_ORDER_SERVICE}" "${ADMIN_TOKEN}" "raw service token"

CID_BILLING_OWNER="tv2-billing-owner-$(date +%s)"
assert_status "ci-alice checkout bob forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: ${CID_BILLING_OWNER}" \
    -d '{"order_id":"ord-bob-2001","amount":80000,"currency":"VND"}')"
assert_auth_log_event "billing-service" "${CID_BILLING_OWNER}" 403 "ownership_denied"
assert_log_safe "billing-service" "${CID_BILLING_OWNER}" "${CI_ALICE_TOKEN}" "raw user token"

CID_ADMIN_SERVICE="tv2-admin-service-client-$(date +%s)"
assert_status "billing service token admin maintenance forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: ${CID_ADMIN_SERVICE}" \
    -d '{"action":"health-check"}')"
assert_auth_log_event "admin-service" "${CID_ADMIN_SERVICE}" 403 "service_client_forbidden"
assert_log_safe "admin-service" "${CID_ADMIN_SERVICE}" "${BILLING_TOKEN}" "raw service token"

echo ""
echo "===== DTO response fields ====="

BODY="$(tmp_file)"
CID_USER_DTO="tv2-user-dto-$(date +%s)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/me" \
  -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
  -H "X-Correlation-ID: ${CID_USER_DTO}")"
assert_status "users me DTO status" 200 "${STATUS_CODE}"
assert_json_keys "users me" "${BODY}" user_id username email roles correlation_id
assert_json_list_field "users me" "${BODY}" roles

BODY="$(tmp_file)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/profile" \
  -H "$(bearer_header "${CI_ALICE_TOKEN}")")"
assert_status "users profile DTO status" 200 "${STATUS_CODE}"
assert_json_keys "users profile" "${BODY}" user_id username email roles azp scope correlation_id

BODY="$(tmp_file)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" \
  "${BASE_URL}/api/v1/orders" \
  -H "$(bearer_header "${CI_ALICE_TOKEN}")")"
assert_status "orders list DTO status" 200 "${STATUS_CODE}"
assert_json_keys "orders list" "${BODY}" caller orders count correlation_id
assert_json_list_field "orders list" "${BODY}" orders

BODY="$(tmp_file)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" \
  "${BASE_URL}/api/v1/orders/ord-alice-1001/fixed" \
  -H "$(bearer_header "${CI_ALICE_TOKEN}")")"
assert_status "order detail DTO status" 200 "${STATUS_CODE}"
assert_json_keys "order detail" "${BODY}" order_id owner_id amount status currency correlation_id

BODY="$(tmp_file)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
  -H "$(bearer_header "${BILLING_TOKEN}")" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"ord-alice-1001","subject":"alice"}')"
assert_status "order internal verify DTO status" 200 "${STATUS_CODE}"
assert_json_keys "order internal verify" "${BODY}" order_id allowed correlation_id

BODY="$(tmp_file)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/billing/checkout" \
  -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"
assert_status "billing checkout DTO status" 202 "${STATUS_CODE}"
assert_json_keys "billing checkout" "${BODY}" payment_id order_id status amount currency correlation_id

BODY="$(tmp_file)"
STATUS_CODE="$(curl -s -o "${BODY}" -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/admin/maintenance" \
  -H "$(bearer_header "${ADMIN_TOKEN}")" \
  -H "Content-Type: application/json" \
  -d '{"action":"health-check"}')"
assert_status "admin maintenance DTO status" 200 "${STATUS_CODE}"
assert_json_keys "admin maintenance" "${BODY}" status action correlation_id

echo ""
echo "=============================================="
echo "  TV2 AUTHZ LOGS/DTO RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] TV2 authz logs/DTO tests have failures."
  exit 1
fi
