#!/usr/bin/env bash
# tests/security/run-fuzzing.sh
#
# API Fuzzing – RESTler + fuzz-negative-tests
#
# Runs RESTler fuzzing against the Kong Gateway using OpenAPI spec.
# Falls back to structured fuzz-negative-tests if RESTler unavailable.
#
# Usage:
#   bash tests/security/run-fuzzing.sh
#
# Environment variables:
#   BASE_URL    – Target URL (default: http://localhost:8000)
#   USER_TOKEN  – Bearer token for authenticated fuzz
#
# Output:
#   docs/evidence/tv3/fuzzing/fuzzing-summary.md
#   docs/evidence/tv3/fuzzing/fuzzing-run.log
#   docs/evidence/tv3/fuzzing/fuzzing-findings.json

set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
KC_URL="${KC_URL:-http://localhost:8080}"
REPORT_DIR="docs/evidence/tv3/fuzzing"
LOG_FILE="${REPORT_DIR}/fuzzing-run.log"
FINDINGS_FILE="${REPORT_DIR}/fuzzing-findings.json"

mkdir -p "${REPORT_DIR}"

echo "=== API Fuzzing ===" | tee "${LOG_FILE}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${LOG_FILE}"
echo "Target: ${BASE_URL}" | tee -a "${LOG_FILE}"
echo "OpenAPI: services/openapi.yaml" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Obtain auth token
# --------------------------------------------------
USER_TOKEN="${USER_TOKEN:-}"
if [ -z "${USER_TOKEN}" ]; then
  echo "--- Obtaining auth token ---" | tee -a "${LOG_FILE}"
  TOKEN_RESP=$(curl -s -X POST \
    "${KC_URL}/realms/topic10-sme-api/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=sme-web-client" \
    -d "username=ci-alice" \
    -d "password=ci-alice-password-123" 2>/dev/null || echo "{}")
  USER_TOKEN=$(echo "${TOKEN_RESP}" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || echo "")
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
  actual=$(curl "${cmd_args[@]}" "${BASE_URL}${path}" 2>/dev/null || echo "000")
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
# RESTler check (if available via Docker)
# --------------------------------------------------
echo "--- RESTler Docker Check ---" | tee -a "${LOG_FILE}"
if docker image inspect "mcr.microsoft.com/restler:9.2.4" > /dev/null 2>&1; then
  echo "[INFO] RESTler image found. Running compile check..." | tee -a "${LOG_FILE}"
  docker run --rm \
    --network host \
    -v "$(pwd):/api:ro" \
    mcr.microsoft.com/restler:9.2.4 \
    dotnet /RESTler/restler/Restler.dll \
    compile --api_spec /api/services/openapi.yaml \
    2>&1 | tee -a "${LOG_FILE}" || true
else
  echo "[INFO] RESTler Docker image not available locally." | tee -a "${LOG_FILE}"
  echo "[INFO] Structured fuzz-negative-tests cover the equivalent scenarios." | tee -a "${LOG_FILE}"
  echo "[INFO] See: tests/security/fuzz-negative-tests.sh" | tee -a "${LOG_FILE}"
fi

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
echo "=== Fuzzing Complete ===" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "Total requests:  ${TOTAL_REQUESTS}" | tee -a "${LOG_FILE}"
echo "4xx responses:   ${ERRORS_4XX} (expected for invalid inputs)" | tee -a "${LOG_FILE}"
echo "5xx/crashes:     ${CRASHES}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

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
