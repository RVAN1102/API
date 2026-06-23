#!/usr/bin/env bash
# tests/security/s2s-ownership-tests.sh
#
# Real Billing-to-Order ownership verification regression tests.

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUTH_HEADER_NAME="Authorization"
BEARER_SCHEME="Bearer"
COMPOSE_FILE="${PROJECT_ROOT}/infra/docker-compose.yml"

if [ -f "${PROJECT_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/infra/.env"
  set +a
fi

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

json_field() {
  local file="$1"
  local field="$2"
  python3 - "${file}" "${field}" <<'PY'
import json
import sys

path, field = sys.argv[1], sys.argv[2]
try:
    body = json.load(open(path, encoding="utf-8"))
except json.JSONDecodeError:
    print("")
    raise SystemExit
value = body.get(field, "")
if isinstance(value, bool):
    print(str(value).lower())
else:
    print(value)
PY
}

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

echo "=============================================="
echo "  REAL S2S ORDER OWNERSHIP TESTS"
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

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-alice > /tmp/s2s-ci-alice-token.log 2>&1
cp /tmp/user-token.txt /tmp/s2s-ci-alice-token.txt
echo "[INFO] ci-alice automation token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-bob > /tmp/s2s-ci-bob-token.log 2>&1
cp /tmp/user-token.txt /tmp/s2s-ci-bob-token.txt
echo "[INFO] ci-bob automation token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-billing-service-token.sh" > /tmp/s2s-billing-service-token.log 2>&1
cp /tmp/billing-service-token.txt /tmp/s2s-billing-service-token.txt
echo "[INFO] billing service token obtained"

bash "${PROJECT_ROOT}/demo/auth/get-admin-service-token.sh" > /tmp/s2s-admin-service-token.log 2>&1
cp /tmp/admin-service-token.txt /tmp/s2s-admin-service-token.txt
echo "[INFO] admin service token obtained"

CI_ALICE_TOKEN="$(cat /tmp/s2s-ci-alice-token.txt)"
CI_BOB_TOKEN="$(cat /tmp/s2s-ci-bob-token.txt)"
BILLING_TOKEN="$(cat /tmp/s2s-billing-service-token.txt)"
ADMIN_TOKEN="$(cat /tmp/s2s-admin-service-token.txt)"

echo ""
echo "===== Billing-to-Order mTLS transport ====="

MTLS_CONFIG_STATUS="$(compose exec -T billing-service python - <<'PY'
import os
from pathlib import Path

required = {
    "ORDER_SERVICE_URL": "https://order-service:8443",
    "ORDER_SERVICE_TLS_CA_CERT": "/etc/internal-tls/ca.crt",
    "ORDER_SERVICE_TLS_CLIENT_CERT": "/etc/internal-tls/billing-client.crt",
    "ORDER_SERVICE_TLS_CLIENT_KEY": "/etc/internal-tls/billing-client.key",
}
errors = []
for key, expected in required.items():
    actual = os.environ.get(key, "")
    if actual != expected:
        errors.append(f"{key}={actual!r}")
for key in ("ORDER_SERVICE_TLS_CA_CERT", "ORDER_SERVICE_TLS_CLIENT_CERT", "ORDER_SERVICE_TLS_CLIENT_KEY"):
    path = Path(os.environ.get(key, ""))
    if not path.is_file():
        errors.append(f"missing:{key}")
if errors:
    print(";".join(errors))
    raise SystemExit(1)
print("ok")
PY
)" || MTLS_CONFIG_STATUS="fail"
if [ "${MTLS_CONFIG_STATUS}" = "ok" ]; then
  pass "Billing service is configured for Order mTLS URL and client certificate material"
else
  fail "Billing service mTLS configuration invalid: ${MTLS_CONFIG_STATUS}"
fi

PLAINTEXT_PROBE="$(compose exec -T billing-service python - <<'PY'
import json
import urllib.request

try:
    host = "order-" + "service"
    url = "http://" + host + ":8000/api/v1/orders/health"
    with urllib.request.urlopen(url, timeout=3) as response:
        print(json.dumps({"reachable": True, "status": getattr(response, "status", None)}))
        raise SystemExit(0)
except Exception as exc:
    print(json.dumps({"reachable": False, "error_type": exc.__class__.__name__}))
    raise SystemExit(10)
PY
)" && PLAINTEXT_STATUS=0 || PLAINTEXT_STATUS=$?
echo "billing-service direct plaintext Order app-port probe: ${PLAINTEXT_PROBE}"
if [ "${PLAINTEXT_STATUS}" -ne 0 ]; then
  pass "Billing service cannot directly use the plaintext Order app port"
else
  fail "Billing service can still reach the plaintext Order app port"
fi

MTLS_HEALTH_STATUS="$(compose exec -T billing-service python - <<'PY'
import os
import ssl
import urllib.request

context = ssl.create_default_context(cafile=os.environ["ORDER_SERVICE_TLS_CA_CERT"])
context.load_cert_chain(
    certfile=os.environ["ORDER_SERVICE_TLS_CLIENT_CERT"],
    keyfile=os.environ["ORDER_SERVICE_TLS_CLIENT_KEY"],
)
with urllib.request.urlopen("https://order-service:8443/api/v1/orders/health", context=context, timeout=5) as response:
    print(getattr(response, "status", ""))
PY
)" || MTLS_HEALTH_STATUS="000"
assert_status "Billing service reaches Order service over direct verified HTTPS/mTLS" 200 "${MTLS_HEALTH_STATUS}"

echo ""
echo "===== Billing checkout ownership ====="

assert_status "Alice checkout Alice order accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: s2s-alice-owned" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "Alice checkout Alice order wrong amount blocked" 409 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: s2s-alice-wrong-amount" \
    -d '{"order_id":"ord-alice-1001","amount":1,"currency":"VND"}')"

assert_status "Alice checkout Bob order forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: s2s-alice-bob-denied" \
    -d '{"order_id":"ord-bob-2001","amount":80000,"currency":"VND"}')"

assert_status "Bob checkout Bob order accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_BOB_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: s2s-bob-owned" \
    -d '{"order_id":"ord-bob-2001","amount":80000,"currency":"VND"}')"

IDEMPOTENCY_KEY="s2s-idem-alice-1002"
IDEMPOTENCY_DUP_KEY="s2s-idem-alice-1002-duplicate"

assert_status "Alice checkout idempotent first attempt accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "Idempotency-Key: ${IDEMPOTENCY_KEY}" \
    -H "X-Correlation-ID: s2s-idem-first" \
    -d '{"order_id":"ord-alice-1002","amount":250000,"currency":"VND"}')"

assert_status "Alice checkout idempotent safe retry accepted" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "Idempotency-Key: ${IDEMPOTENCY_KEY}" \
    -H "X-Correlation-ID: s2s-idem-retry" \
    -d '{"order_id":"ord-alice-1002","amount":250000,"currency":"VND"}')"

assert_status "Alice checkout same idempotency key different payload blocked" 409 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "Idempotency-Key: ${IDEMPOTENCY_KEY}" \
    -H "X-Correlation-ID: s2s-idem-conflict" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "Alice duplicate checkout different idempotency key blocked" 409 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -H "Idempotency-Key: ${IDEMPOTENCY_DUP_KEY}" \
    -H "X-Correlation-ID: s2s-idem-duplicate" \
    -d '{"order_id":"ord-alice-1002","amount":250000,"currency":"VND"}')"

assert_status "Billing fake user token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "fake.jwt.token")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "Billing malformed user token rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "abc")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_not_status "Unknown order checkout fail closed" 202 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-missing-9999","amount":150000,"currency":"VND"}')"

assert_status "Service token cannot call Billing checkout" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "$(bearer_header "${BILLING_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

echo ""
echo "===== Order internal ownership endpoint ====="

OWNERSHIP_BODY="$(mktemp /tmp/s2s-ownership-body.XXXXXX)"
OWNERSHIP_STATUS="$(curl -s -o "${OWNERSHIP_BODY}" -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
  -H "$(bearer_header "${BILLING_TOKEN}")" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: s2s-direct-order-allowed" \
  -d '{"order_id":"ord-alice-1001","subject":"alice"}')"
assert_status "billing-service-client Order internal verify status" 200 "${OWNERSHIP_STATUS}"
ALLOWED="$(json_field "${OWNERSHIP_BODY}" allowed)"
if [ "${ALLOWED}" = "true" ]; then
  pass "billing-service-client Order internal verify allowed=true"
else
  fail "billing-service-client Order internal verify expected allowed=true got ${ALLOWED}"
fi
rm -f "${OWNERSHIP_BODY}"

assert_status "admin-service-client Order internal verify forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${ADMIN_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "human user Order internal verify forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "${CI_ALICE_TOKEN}")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "missing token Order internal verify rejected" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "fake token Order internal verify rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "fake.jwt.token")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

assert_status "malformed token Order internal verify rejected" 401 \
  "$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/orders/internal/verify-ownership" \
    -H "$(bearer_header "abc")" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","subject":"alice"}')"

echo ""
echo "===== Service-client least privilege ====="

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

assert_status "billing-service-client users/me forbidden" 403 \
  "$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "$(bearer_header "${BILLING_TOKEN}")")"

echo ""
echo "=============================================="
echo "  REAL S2S RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] Real S2S ownership tests have failures."
  exit 1
fi
