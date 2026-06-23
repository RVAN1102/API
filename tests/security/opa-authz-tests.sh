#!/usr/bin/env bash
# tests/security/opa-authz-tests.sh
#
# Regression coverage for OPA-backed high-risk authorization decisions.

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
OPA_URL="${OPA_URL_HOST:-https://localhost:8181}"
OPA_CONTAINER="${OPA_CONTAINER:-infra-opa-1}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_FILE="${EVIDENCE_FILE:-${PROJECT_ROOT}/.artifacts/test-runs/tv2/opa-policy-engine.txt}"
AUTH_HEADER_NAME="Authorization"
BEARER_SCHEME="Bearer"
OPA_STOPPED=false

TOTAL=0
PASSED=0
FAILED=0

cleanup() {
  if ${OPA_STOPPED}; then
    docker start "${OPA_CONTAINER}" >/dev/null
  fi
}
trap cleanup EXIT

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

assert_not_status() {
  local name="$1"
  local forbidden="$2"
  local actual="$3"

  if [ "${actual}" != "${forbidden}" ]; then
    pass "${name} -> ${actual}"
  else
    fail "${name} expected not ${forbidden} got ${actual}"
  fi
}

assert_opa_result() {
  local name="$1"
  local expected="$2"
  local body="$3"
  local actual

  actual="$(printf "%s" "${body}" | python3 -c 'import json, sys; print(str(json.load(sys.stdin).get("result")).lower())')"
  if [ "${actual}" = "${expected}" ]; then
    pass "${name} -> ${actual}"
  else
    fail "${name} expected ${expected} got ${actual}"
  fi
}

opa_query() {
  local input_json="$1"
  curl -sS \
    -H "Content-Type: application/json" \
    -d "{\"input\":${input_json}}" \
    "${OPA_URL}/v1/data/topic10/authz/allow"
}

http_code() {
  curl -s -o /dev/null -w "%{http_code}" "$@"
}

wait_for_opa() {
  local code="000"
  for _ in {1..30}; do
    if code="$(curl -s -o /dev/null -w "%{http_code}" "${OPA_URL}/health" 2>/dev/null)"; then
      if [ "${code}" = "200" ]; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

docker_logs() {
  local service="$1"
  docker logs "infra-${service}-1" 2>&1
}

assert_auth_failure_event() {
  local service="$1"
  local correlation_id="$2"
  local expected_status="$3"
  local expected_reason="$4"

  for _ in {1..10}; do
    local log_file
    log_file="$(mktemp)"
    docker_logs "${service}" > "${log_file}"

    if python3 - "${service}" "${correlation_id}" "${expected_status}" "${expected_reason}" "${log_file}" <<'PY'
import json
import sys

service, correlation_id, expected_status, expected_reason, log_path = sys.argv[1:6]

with open(log_path, encoding="utf-8") as handle:
    for raw in handle:
        start = raw.find("{")
        if start < 0:
            continue
        try:
            record = json.loads(raw[start:])
        except json.JSONDecodeError:
            continue
        if record.get("event_type") != "auth_failure":
            continue
        if record.get("service") != service:
            continue
        if record.get("correlation_id") != correlation_id:
            continue
        if str(record.get("status_code")) != expected_status:
            continue
        if record.get("reason") != expected_reason:
            continue
        if record.get("category") != expected_reason:
            continue
        raise SystemExit(0)

raise SystemExit(1)
PY
    then
      rm -f "${log_file}"
      pass "${service} OPA deny auth_failure log"
      return
    fi
    rm -f "${log_file}"
    sleep 1
  done

  fail "${service} OPA deny auth_failure log not found"
}

record_evidence_header() {
  mkdir -p "$(dirname "${EVIDENCE_FILE}")"
  {
    echo "TV2 OPA Policy Engine Evidence"
    echo "Generated: $(date)"
    echo ""
    echo "OPA service health/status: ${OPA_URL}/health -> ${OPA_HEALTH_CODE}"
    echo "Policy path/name: opa/policies/authz.rego package topic10.authz"
    echo ""
    echo "Allow/Deny matrix:"
  } > "${EVIDENCE_FILE}"
}

record_evidence_result() {
  local name="$1"
  local result="$2"
  printf -- "- %s: %s\n" "${name}" "${result}" >> "${EVIDENCE_FILE}"
}

finish_evidence() {
  {
    echo ""
    echo "OPA authz test summary: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
    echo "Final regression summary: populated by final regression run evidence after full suite execution."
    echo ""
    echo "Secret handling: no full JWT, client_secret, password, refresh_token, private key, Vault token, or .env secret is written here."
  } >> "${EVIDENCE_FILE}"
}

echo "=============================================="
echo "  OPA AUTHZ POLICY TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

echo "===== Prepare tokens ====="

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

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-alice > /tmp/opa-ci-alice-token.log 2>&1
CI_ALICE_TOKEN="$(cat /tmp/user-token.txt)"
echo "[INFO] ci-alice automation token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-billing-service-token.sh" > /tmp/opa-billing-token.log 2>&1
BILLING_TOKEN="$(cat /tmp/billing-service-token.txt)"
echo "[INFO] billing service token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-admin-service-token.sh" > /tmp/opa-admin-token.log 2>&1
ADMIN_TOKEN="$(cat /tmp/admin-service-token.txt)"
echo "[INFO] admin service token obtained"

echo ""
echo "===== OPA health and policy ====="

OPA_HEALTH_CODE="$(http_code "${OPA_URL}/health")"
assert_status "OPA health" 200 "${OPA_HEALTH_CODE}"
record_evidence_header

if [ -f "${PROJECT_ROOT}/opa/policies/authz.rego" ]; then
  pass "OPA policy file exists"
else
  fail "OPA policy file missing"
fi

ADMIN_ALLOW="$(opa_query '{"action":"admin_maintenance","subject_type":"service","client_id":"admin-service-client","roles":["admin-maintenance"]}')"
assert_opa_result "OPA admin-service-client admin_maintenance allow" true "${ADMIN_ALLOW}"
record_evidence_result "admin_maintenance admin-service-client/admin-maintenance" "allow"

ADMIN_DENY="$(opa_query '{"action":"admin_maintenance","subject_type":"service","client_id":"billing-service-client","roles":["order-ownership-read"]}')"
assert_opa_result "OPA billing-service-client admin_maintenance deny" false "${ADMIN_DENY}"
record_evidence_result "admin_maintenance billing-service-client/order-ownership-read" "deny"

ORDER_ALLOW="$(opa_query '{"action":"order_verify_ownership","subject_type":"service","client_id":"billing-service-client","roles":["order-ownership-read"],"order_id":"ord-alice-1001","order_owner":"alice","requested_username":"alice"}')"
assert_opa_result "OPA billing-service-client order owner allow" true "${ORDER_ALLOW}"
record_evidence_result "order_verify_ownership billing-service-client alice owns alice" "allow"

ORDER_DENY="$(opa_query '{"action":"order_verify_ownership","subject_type":"service","client_id":"billing-service-client","roles":["order-ownership-read"],"order_id":"ord-alice-1001","order_owner":"alice","requested_username":"bob"}')"
assert_opa_result "OPA wrong owner deny" false "${ORDER_DENY}"
record_evidence_result "order_verify_ownership billing-service-client alice vs bob" "deny"

ORDER_MISSING_REQUESTED="$(opa_query '{"action":"order_verify_ownership","subject_type":"service","client_id":"billing-service-client","roles":["order-ownership-read"],"order_id":"ord-alice-1001","order_owner":"alice"}')"
assert_opa_result "OPA missing requested username deny" false "${ORDER_MISSING_REQUESTED}"
record_evidence_result "order_verify_ownership missing requested_username" "deny"

BILLING_ALLOW="$(opa_query '{"action":"billing_checkout","subject_type":"human","username":"alice","roles":["user"],"ownership_confirmed":true,"ownership_confirmation_source":"order-service"}')"
assert_opa_result "OPA human billing checkout allow after ownership" true "${BILLING_ALLOW}"
record_evidence_result "billing_checkout human alice order-service ownership_confirmed=true" "allow"

BILLING_DENY="$(opa_query '{"action":"billing_checkout","subject_type":"service","client_id":"billing-service-client","roles":["order-ownership-read"],"ownership_confirmed":true}')"
assert_opa_result "OPA service token billing checkout deny" false "${BILLING_DENY}"
record_evidence_result "billing_checkout billing-service-client" "deny"

BILLING_CLIENT_SUPPLIED_DENY="$(opa_query '{"action":"billing_checkout","subject_type":"human","username":"alice","roles":["user"],"ownership_confirmed":true,"ownership_confirmation_source":"client"}')"
assert_opa_result "OPA client-supplied ownership confirmation deny" false "${BILLING_CLIENT_SUPPLIED_DENY}"
record_evidence_result "billing_checkout client-supplied ownership_confirmed=true" "deny"

echo ""
echo "===== Backend OPA enforcement ====="

assert_status "Order verify owner allowed" 200 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-order-allow" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "Order verify wrong owner denied by OPA" 403 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-order-deny" \
    -d '{"order_id":"ord-alice-1001","subject":"bob"}')"
assert_auth_failure_event "order-service" "opa-order-deny" 403 "ownership_denied"

assert_status "Admin maintenance allowed by OPA" 200 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-admin-allow" \
    -d '{"action":"health-check"}')"

assert_status "Admin maintenance denies billing-service-client" 403 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-admin-deny" \
    -d '{"action":"health-check"}')"

assert_status "Billing checkout allowed after Order ownership" 202 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-billing-allow" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "Billing checkout wrong owner denied" 403 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-billing-deny" \
    -d '{"order_id":"ord-bob-2001","amount":80000,"currency":"VND"}')"

if grep -Fq '"action": "billing_checkout"' "${PROJECT_ROOT}/services/billing/main.py" \
    && grep -Fq "require_opa_allow" "${PROJECT_ROOT}/services/billing/main.py"; then
  pass "Billing checkout backend is wired to OPA decision helper"
else
  fail "Billing checkout backend is not wired to OPA decision helper"
fi

echo ""
echo "===== OPA unavailable fail-closed ====="

docker stop "${OPA_CONTAINER}" >/dev/null
OPA_STOPPED=true

assert_not_status "Admin maintenance fails closed when OPA is stopped" 200 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-admin-unavailable" \
    -d '{"action":"health-check"}')"

assert_not_status "Order verify fails closed when OPA is stopped" 200 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-order-unavailable" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

docker start "${OPA_CONTAINER}" >/dev/null
OPA_STOPPED=false
if wait_for_opa; then
  pass "OPA restarted after fail-closed checks"
else
  fail "OPA did not restart after fail-closed checks"
fi

assert_status "Admin maintenance recovers after OPA restart" 200 \
  "$(http_code -X POST \
    "${BASE_URL}/api/v1/admin/maintenance" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: opa-admin-recovered" \
    -d '{"action":"health-check"}')"

finish_evidence

echo ""
echo "=============================================="
echo "  OPA AUTHZ RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] OPA authz tests have failures."
  exit 1
fi
