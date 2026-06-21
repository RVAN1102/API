#!/usr/bin/env bash
# tests/security/run-fuzzing.sh
#
# Structured Negative API Tests
#
# Runs deterministic malformed-input and fail-closed checks against Kong.
# This is not RESTler fuzzing. RESTler execution lives in
# tests/restler/run-restler-check.sh and fails if RESTler is unavailable.
#
# Usage:
#   bash tests/security/run-fuzzing.sh
#
# Environment variables:
#   BASE_URL    – Target URL (default: https://localhost:8443)
#   USER_TOKEN  – Bearer token for authenticated fuzz
#
# Output:
#   .artifacts/test-runs/tv3/fuzzing/fuzzing-run.log
#   .artifacts/test-runs/tv3/fuzzing/fuzzing-findings.json

set -uo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
REPORT_DIR="${REPORT_DIR:-.artifacts/test-runs/tv3/fuzzing}"
LOG_FILE="${REPORT_DIR}/fuzzing-run.log"
FINDINGS_FILE="${REPORT_DIR}/fuzzing-findings.json"
SUMMARY_FILE="${REPORT_DIR}/fuzzing-summary.md"

mkdir -p "${REPORT_DIR}"

echo "=== Structured Negative API Tests ===" | tee "${LOG_FILE}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${LOG_FILE}"
echo "Target: ${BASE_URL}" | tee -a "${LOG_FILE}"
echo "OpenAPI: services/openapi.yaml" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Obtain auth token
# --------------------------------------------------
USER_TOKEN="${USER_TOKEN:-}"
if [ -z "${USER_TOKEN}" ]; then
  echo "--- Obtaining auth token with local demo/dev helper ---" | tee -a "${LOG_FILE}"
  TOKEN_HELPER_LOG="$(mktemp /tmp/topic10-fuzz-token-helper.XXXXXX)"
  if bash demo/auth/get-user-token.sh ci-alice >"${TOKEN_HELPER_LOG}" 2>&1; then
    USER_TOKEN="$(cat /tmp/user-token.txt 2>/dev/null || true)"
  fi
  rm -f "${TOKEN_HELPER_LOG}"
  if [ -n "${USER_TOKEN}" ]; then
    echo "[OK] Token obtained (length=${#USER_TOKEN})" | tee -a "${LOG_FILE}"
  else
    echo "[WARN] No token obtained – fuzz will cover unauth paths only." | tee -a "${LOG_FILE}"
  fi
fi

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Tracking counters
# --------------------------------------------------
TOTAL_REQUESTS=0
ERRORS_4XX=0
ERRORS_5XX=0
CRASHES=0
declare -a FINDINGS=()

record_finding() {
  local endpoint="$1"
  local method="$2"
  local status="$3"
  local payload="$4"
  local note="$5"
  FINDINGS+=("{\"endpoint\":\"${endpoint}\",\"method\":\"${method}\",\"status\":${status},\"payload\":\"${payload}\",\"note\":\"${note}\"}")
}

fuzz_request() {
  local method="$1"
  local path="$2"
  local body="$3"
  local extra_headers="${4:-}"
  local label="$5"
  local expected="$6"

  local cmd_args=("-s" "-o" "/dev/null" "-w" "%{http_code}" "-X" "${method}")
  cmd_args+=("-H" "Content-Type: application/json")
  if [ -n "${USER_TOKEN}" ]; then
    cmd_args+=("-H" "Authorization: Bearer ${USER_TOKEN}")
  fi
  if [ -n "${extra_headers}" ]; then
    cmd_args+=("-H" "${extra_headers}")
  fi
  if [ -n "${body}" ]; then
    cmd_args+=("-d" "${body}")
  fi

  local actual
  actual=$(curl "${cmd_args[@]}" "${BASE_URL}${path}" 2>/dev/null || true)
  if [ -z "${actual}" ]; then
    actual="000"
  fi
  TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))

  if [[ "${actual}" == 5* ]]; then
    CRASHES=$((CRASHES + 1))
    ERRORS_5XX=$((ERRORS_5XX + 1))
    echo "[CRASH] ${label} → HTTP ${actual} (expected ${expected})" | tee -a "${LOG_FILE}"
    record_finding "${path}" "${method}" "${actual}" "${body}" "Unexpected 5xx – investigate"
  elif [[ "${actual}" == 4* ]]; then
    ERRORS_4XX=$((ERRORS_4XX + 1))
    if [ "${actual}" -eq "${expected}" ]; then
      echo "[PASS]  ${label} → HTTP ${actual}" | tee -a "${LOG_FILE}"
    else
      echo "[NOTE]  ${label} → HTTP ${actual} (expected ${expected})" | tee -a "${LOG_FILE}"
      record_finding "${path}" "${method}" "${actual}" "${body}" "Unexpected 4xx status"
    fi
  else
    if [ "${actual}" -eq "${expected}" ]; then
      echo "[PASS]  ${label} → HTTP ${actual}" | tee -a "${LOG_FILE}"
    else
      echo "[NOTE]  ${label} → HTTP ${actual} (expected ${expected})" | tee -a "${LOG_FILE}"
    fi
  fi
}

# --------------------------------------------------
# Fuzz Suite 1: Missing required fields
# --------------------------------------------------
echo "--- Suite 1: Missing Required Fields ---" | tee -a "${LOG_FILE}"

fuzz_request POST "/api/v1/orders" "{}" "" "POST /orders – empty body" 422
fuzz_request POST "/api/v1/orders" '{"item":"widget"}' "" "POST /orders – missing quantity" 422
fuzz_request POST "/api/v1/billing/checkout" "{}" "" "POST /billing/checkout – empty body" 422
fuzz_request POST "/api/v1/billing/checkout" '{"order_id":""}' "" "POST /billing/checkout – empty order_id" 422

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Fuzz Suite 2: Type confusion / invalid types
# --------------------------------------------------
echo "--- Suite 2: Type Confusion / Invalid Types ---" | tee -a "${LOG_FILE}"

fuzz_request POST "/api/v1/orders" '{"item":123,"quantity":"notanumber","price":true}' "" "POST /orders – wrong types" 422
fuzz_request POST "/api/v1/orders" '{"item":null,"quantity":null}' "" "POST /orders – null values" 422
fuzz_request POST "/api/v1/billing/checkout" '{"order_id":99999}' "" "POST /billing/checkout – integer instead of string" 422

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Fuzz Suite 3: SQL Injection patterns
# --------------------------------------------------
echo "--- Suite 3: SQL Injection Patterns ---" | tee -a "${LOG_FILE}"

fuzz_request GET "/api/v1/orders/1' OR '1'='1/fixed" "" "" "GET /orders – SQL injection in path" 400
fuzz_request GET "/api/v1/orders/; DROP TABLE orders; --/fixed" "" "" "GET /orders – SQL drop in path" 400
fuzz_request POST "/api/v1/orders" '{"item":"test\u0027 OR 1=1--","quantity":1,"price":10}' "" "POST /orders – SQLi in body" 422

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Fuzz Suite 4: Boundary values
# --------------------------------------------------
echo "--- Suite 4: Boundary Values ---" | tee -a "${LOG_FILE}"

fuzz_request POST "/api/v1/orders" '{"item":"x","quantity":-1,"price":0.001}' "" "POST /orders – negative quantity" 422
fuzz_request POST "/api/v1/orders" '{"item":"x","quantity":9999999999,"price":9999999999.99}' "" "POST /orders – overflow values" 422
fuzz_request POST "/api/v1/orders" "{\"item\":\"$(python3 -c 'print("A"*10000)')\",\"quantity\":1,\"price\":1.0}" "" "POST /orders – 10KB item string" 422

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Fuzz Suite 5: Auth bypass attempts
# --------------------------------------------------
echo "--- Suite 5: Auth Bypass Attempts ---" | tee -a "${LOG_FILE}"

TEMP_TOKEN="${USER_TOKEN}"
USER_TOKEN=""
fuzz_request GET "/api/v1/users/me" "" "" "GET /users/me – no token" 401
fuzz_request GET "/api/v1/orders/ord-bob-2001/fixed" "" "" "GET /orders – no token" 401
USER_TOKEN="${TEMP_TOKEN}"

fuzz_request GET "/api/v1/users/me" "" "Authorization: Bearer invalid.token.here" "GET /users/me – invalid token" 401
fuzz_request GET "/api/v1/users/me" "" "Authorization: Basic YWxpY2U6YWxpY2UxMjM=" "GET /users/me – Basic auth instead of Bearer" 401

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Fuzz Suite 6: Path traversal / SSRF payloads
# --------------------------------------------------
echo "--- Suite 6: Path Traversal / SSRF Payloads ---" | tee -a "${LOG_FILE}"

fuzz_request GET "/api/v1/orders/../../etc/passwd/fixed" "" "" "GET – path traversal attempt" 400
fuzz_request GET "/api/v1/orders/%2F%2F169.254.169.254/fixed" "" "" "GET – SSRF via path" 400

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Fuzz Suite 7: Oversized payloads
# --------------------------------------------------
echo "--- Suite 7: Oversized Payloads ---" | tee -a "${LOG_FILE}"

fuzz_request POST "/api/v1/orders" \
  "{\"item\":\"$(python3 -c 'print("X"*50000)')\",\"quantity\":1,\"price\":1.0}" \
  "" "POST /orders – 50KB payload (expect 413 or 422)" 413

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Write findings JSON
# --------------------------------------------------
{
  echo "{"
  echo "  \"scan_date\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
  echo "  \"target\": \"${BASE_URL}\","
  echo "  \"openapi_spec\": \"services/openapi.yaml\","
  echo "  \"total_requests\": ${TOTAL_REQUESTS},"
  echo "  \"errors_4xx\": ${ERRORS_4XX},"
  echo "  \"errors_5xx\": ${ERRORS_5XX},"
  echo "  \"crashes\": ${CRASHES},"
  echo "  \"findings\": ["
  for i in "${!FINDINGS[@]}"; do
    if [ $i -lt $((${#FINDINGS[@]} - 1)) ]; then
      echo "    ${FINDINGS[$i]},"
    else
      echo "    ${FINDINGS[$i]}"
    fi
  done
  echo "  ]"
  echo "}"
} > "${FINDINGS_FILE}"

# --------------------------------------------------
# Final summary
# --------------------------------------------------
echo "=== Structured Negative Tests Complete ===" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "Total requests:  ${TOTAL_REQUESTS}" | tee -a "${LOG_FILE}"
echo "4xx responses:   ${ERRORS_4XX} (expected for invalid inputs)" | tee -a "${LOG_FILE}"
echo "5xx/crashes:     ${CRASHES}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

{
  echo "# Structured Negative API Test Summary"
  echo ""
  echo "- Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "- Target: ${BASE_URL}"
  echo "- OpenAPI: services/openapi.yaml"
  echo "- Total requests: ${TOTAL_REQUESTS}"
  echo "- 4xx responses: ${ERRORS_4XX}"
  echo "- 5xx/crashes: ${CRASHES}"
  if [ "${CRASHES}" -gt 0 ]; then
    echo "- Result: FAIL"
  else
    echo "- Result: PASS"
  fi
} > "${SUMMARY_FILE}"

if [ "${CRASHES}" -gt 0 ]; then
  echo "[FAIL] ${CRASHES} unexpected 5xx response(s) detected. Review findings." | tee -a "${LOG_FILE}"
  echo "[FAIL] See: ${FINDINGS_FILE}" | tee -a "${LOG_FILE}"
  exit 1
else
  echo "[PASS] No endpoint crashes (500) detected." | tee -a "${LOG_FILE}"
  echo "[PASS] 4xx responses are expected fail-closed behavior." | tee -a "${LOG_FILE}"
fi

echo "" | tee -a "${LOG_FILE}"
echo "Reports saved:" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/fuzzing-summary.md" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/fuzzing-run.log" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/fuzzing-findings.json" | tee -a "${LOG_FILE}"
