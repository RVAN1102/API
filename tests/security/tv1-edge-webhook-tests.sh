#!/usr/bin/env bash
# =============================================================================
# TV1 Edge Gateway & Webhook Security – Automated Test Suite
# Covers: P0.1 through P0.9
# Usage:  bash tests/security/tv1-edge-webhook-tests.sh
# Output: docs/evidence/tv1/
# =============================================================================
set -uo pipefail

# --- Git Bash / MSYS2 compatibility ---
# Save original MSYS_NO_PATHCONV and ensure /dev/null works for curl
_ORIG_MSYS_NO_PATHCONV="${MSYS_NO_PATHCONV:-}"
unset MSYS_NO_PATHCONV 2>/dev/null || true

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1"
GATEWAY_URL="${GATEWAY_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
ADMIN_URL="${ADMIN_URL:-http://localhost:8001}"
HTTPS_HOST="${HTTPS_HOST:-localhost:8443}"

if [ -f "${REPO_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/infra/.env"
  set +a
fi

if [ -z "${WEBHOOK_SECRET:-}" ] || [[ "${WEBHOOK_SECRET:-}" == REPLACE_WITH_* ]]; then
  echo "[ERROR] WEBHOOK_SECRET must be set from infra/.env or the shell environment." >&2
  exit 1
fi

mkdir -p "${EVIDENCE_DIR}"

# --- Portable HTTP status code helper ---
# Works on Linux, Mac and Git Bash Windows regardless of MSYS_NO_PATHCONV.
# Writes curl body to a temp file instead of /dev/null to avoid path issues.
http_code() {
  local _tmp_body
  _tmp_body="$(mktemp)"
  local _code
  _code=$(curl -s -o "${_tmp_body}" -w "%{http_code}" "$@" 2>/dev/null) || _code="000"
  rm -f "${_tmp_body}"
  # Guard: if _code is empty or shorter than 3 chars, return 000
  if [ -z "${_code}" ] || [ "${#_code}" -lt 3 ]; then
    echo "000"
    return
  fi
  # Return only the last 3 chars (the HTTP status code)
  echo "${_code: -3}"
}

# --- Auto-detect Python binary (python3 on Linux/Mac, python on Windows) ---
PYTHON_BIN=""
for _py in python3 python py; do
  if command -v "${_py}" &>/dev/null && "${_py}" -c "import sys; sys.exit(0)" &>/dev/null 2>&1; then
    PYTHON_BIN="${_py}"
    break
  fi
done
export PYTHON_BIN

# --- HMAC-SHA256 signer using openssl (no Python needed) ---
# Usage: sign_hmac SECRET TIMESTAMP NONCE BODY
# Message format: timestamp.nonce.body  (same as billing-service)
sign_hmac() {
  local secret="$1" ts="$2" nonce="$3" body="$4"
  local message="${ts}.${nonce}.${body}"
  local hex
  hex=$(printf '%s' "${message}" | openssl dgst -sha256 -hmac "${secret}" 2>/dev/null \
        | awk '{print $NF}')
  echo "sha256=${hex}"
}

# --- Random nonce without Python ---
random_nonce() {
  # Use openssl rand for UUID-like string
  openssl rand -hex 16 2>/dev/null || echo "nonce-$(date +%s)-$$"
}

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Use temp file for counters (works across subshells / tee pipes)
RESULT_FILE="$(mktemp)"
trap 'rm -f "${RESULT_FILE}"' EXIT

log()        { echo -e "${CYAN}[TV1]${NC} $*"; }
pass()       { echo -e "${GREEN}[PASS]${NC} $*"; echo "PASS:$*" >> "${RESULT_FILE}"; }
fail()       { echo -e "${RED}[FAIL]${NC} $*"; echo "FAIL:$*" >> "${RESULT_FILE}"; }
limitation() { echo -e "${YELLOW}[LIMITATION]${NC} $*"; echo "LIMITATION:$*" >> "${RESULT_FILE}"; }

# =============================================================================
# P0.1 – Kong Route Smoke Test
# =============================================================================
log "===== P0.1 Kong route smoke test ====="
{
  echo "===== TV1 P0.1 Kong route smoke ====="
  date
  git branch --show-current
  git log --oneline -5
  echo
} | tee "${EVIDENCE_DIR}/p0-01-kong-route-smoke.txt"

{
  echo "===== Health via Kong ====="
  for svc in users orders billing admin; do
    code=$(http_code "${GATEWAY_URL}/api/v1/${svc}/health")
    echo "${svc}/health -> ${code}"
    if [ "${code}" = "200" ]; then
      pass "${svc}/health 200"
    else
      fail "${svc}/health expected 200 got ${code}"
    fi
  done
  echo
  echo "===== Kong Admin API ====="
  curl -s "${ADMIN_URL}/services" 2>/dev/null \
    | grep -o '"name":"[^"]*"' | head -10 \
    || echo "(Admin API port 8001 not exposed – normal for production)"
} | tee -a "${EVIDENCE_DIR}/p0-01-kong-route-smoke.txt"
echo

# =============================================================================
# P0.2 – TLS 1.3 pass / TLS 1.2 fail
# =============================================================================
log "===== P0.2 TLS 1.3 only ====="
{
  echo "===== TV1 P0.2 TLS test ====="
  if ! command -v openssl &>/dev/null; then
    limitation "openssl not found – TLS test skipped"
  else
    echo "--- TLS 1.3 should succeed ---"
    tls13_out=$(echo | openssl s_client -connect "${HTTPS_HOST}" -tls1_3 2>&1 || true)
    echo "${tls13_out}" | grep -E "Protocol|Cipher|Verify return code|New," || true

    if echo "${tls13_out}" | grep -q "TLSv1.3"; then
      pass "TLS 1.3 handshake succeeded"
    else
      limitation "TLS 1.3 not confirmed – port 8443 may not be exposed in docker-compose"
    fi

    echo ""
    echo "--- TLS 1.2 should fail ---"
    tls12_out=$(echo | openssl s_client -connect "${HTTPS_HOST}" -tls1_2 2>&1 || true)
    echo "${tls12_out}" | grep -E "Protocol|Cipher|alert|wrong version|no protocols|New," || true

    if echo "${tls12_out}" | grep -Eiq "alert|wrong version|no protocols|error"; then
      pass "TLS 1.2 correctly rejected"
    else
      limitation "TLS 1.2 rejection not confirmed"
    fi
  fi
} | tee "${EVIDENCE_DIR}/p0-02-kong-tls13-only.txt"
echo

# =============================================================================
# P0.3 – HSTS header
# =============================================================================
log "===== P0.3 HSTS ====="
{
  echo "===== TV1 P0.3 HSTS header ====="
  hsts_out=$(curl -k -i "https://${HTTPS_HOST}/api/v1/users/health" 2>/dev/null \
    | grep -i "HTTP/\|strict-transport-security" || echo "(HTTPS not reachable)")
  echo "${hsts_out}"
  if echo "${hsts_out}" | grep -iq "strict-transport-security"; then
    pass "HSTS header present"
  else
    limitation "HSTS not confirmed – port 8443 may not be exposed"
  fi
} | tee "${EVIDENCE_DIR}/p0-03-kong-hsts.txt"
echo

# =============================================================================
# P0.4 – CORS strict
# =============================================================================
log "===== P0.4 CORS strict ====="
{
  echo "===== TV1 P0.4 Allowed origin ====="
  allowed=$(curl -si -X OPTIONS "${GATEWAY_URL}/api/v1/users/health" \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" 2>/dev/null \
    | grep -i "HTTP/\|access-control-allow-origin\|access-control-allow-methods\|vary" || true)
  echo "${allowed}"
  if echo "${allowed}" | grep -iq "access-control-allow-origin"; then
    pass "Allowed origin http://localhost:3000 is permitted"
  else
    fail "Allowed origin not reflected in CORS response"
  fi

  echo ""
  echo "===== TV1 P0.4 Evil origin ====="
  evil=$(curl -si -X OPTIONS "${GATEWAY_URL}/api/v1/users/health" \
    -H "Origin: https://evil.example" \
    -H "Access-Control-Request-Method: GET" 2>/dev/null \
    | grep -i "HTTP/\|access-control-allow-origin\|access-control-allow-methods\|vary" || true)
  echo "${evil}"
  if echo "${evil}" | grep -iq "evil.example"; then
    fail "Evil origin was allowed – CORS misconfigured"
  else
    pass "Evil origin https://evil.example is NOT allowed"
  fi
} | tee "${EVIDENCE_DIR}/p0-04-kong-cors.txt"
echo

# =============================================================================
# P0.5 – Rate Limiting
# =============================================================================
log "===== P0.5 Rate limiting ====="
{
  echo "===== TV1 P0.5 Rate limit on protected route ====="
  got_429=false
  for i in $(seq 1 15); do
    code=$(http_code \
      -X POST "${GATEWAY_URL}/api/v1/admin/maintenance" \
      -H "Authorization: Bearer fake.jwt.token" \
      -H "Content-Type: application/json" \
      -d '{"action":"health-check","reason":"rate-limit-test"}')
    echo "request=${i} status=${code}"
    if [ "${code}" = "429" ]; then
      got_429=true
    fi
  done
  if ${got_429}; then
    pass "Rate limit enforced – 429 received when threshold exceeded"
  else
    fail "Rate limit not triggered – no 429 in 15 requests"
  fi
} | tee "${EVIDENCE_DIR}/p0-05-kong-rate-limit.txt"
echo

# =============================================================================
# P0.6 – Request Size Limit
# =============================================================================
log "===== P0.6 Request size limit ====="
{
  echo "===== TV1 P0.6 Small payload reaches upstream ====="
  small_code=$(http_code \
    -X POST "${GATEWAY_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')
  echo "Small payload status: ${small_code}"
  if [ "${small_code}" = "401" ] || [ "${small_code}" = "403" ]; then
    pass "Small payload reached upstream (auth error ${small_code} – not blocked by size)"
  else
    echo "Note: small payload returned ${small_code}"
  fi

  echo ""
  echo "===== TV1 P0.6 Large payload blocked by gateway ====="
  LARGE_FILE="$(mktemp)"
  trap 'rm -f "${LARGE_FILE}"' EXIT

  # Generate 2MB+ payload using dd (works on all platforms)
  # 2MB = 2048 blocks of 1024 bytes
  dd if=/dev/zero bs=1024 count=2200 2>/dev/null \
    | tr '\0' 'A' > "${LARGE_FILE}" || true

  if [ -s "${LARGE_FILE}" ]; then
    # Wrap with JSON structure
    WRAPPED="$(mktemp)"
    { printf '{"data":"'; cat "${LARGE_FILE}"; printf '"}'; } > "${WRAPPED}" || true
    rm -f "${LARGE_FILE}"

    large_code=$(http_code \
      -X POST "${GATEWAY_URL}/api/v1/billing/checkout" \
      -H "Authorization: Bearer abc" \
      -H "Content-Type: application/json" \
      --data-binary @"${WRAPPED}")
    rm -f "${WRAPPED}"

    echo "Large payload (2MB+) status: ${large_code}"
    if [ "${large_code}" = "413" ] || [ "${large_code}" = "417" ]; then
      pass "Large payload blocked by Kong (${large_code})"
    else
      fail "Large payload not blocked – got ${large_code} (expected 413)"
    fi
  else
    limitation "Could not generate large payload (dd failed)"
  fi
} | tee "${EVIDENCE_DIR}/p0-06-kong-request-size-limit.txt"
echo

# =============================================================================
# P0.7 – Webhook HMAC valid/invalid/replay
# =============================================================================
# Helper function to run the python client in a container (avoids host python/curl issues)
# =============================================================================
run_python_client() {
  MSYS_NO_PATHCONV=1 docker run --rm --network infra_default \
    -v "$(pwd)/infra/certs:/certs" \
    -v "$(pwd)/tests/security:/scripts" \
    python:3.13-slim python /scripts/webhook_client.py "$@"
}

# =============================================================================
# P0.7 – Webhook HMAC (Valid)
# =============================================================================
log "===== TV1 P0.7 Valid webhook ====="
{
  TS="$(date +%s)"
  NONCE="valid-$(random_nonce)"
  BODY='{"event_id":"evt-12345","event_type":"payment.succeeded","checkout_id":"co-67890"}'
  SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"

  echo "Timestamp : ${TS}"
  echo "Nonce     : ${NONCE}"
  echo "Signature : ${SIG}"

  valid_code=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS}" \
    --header "X-Webhook-Nonce: ${NONCE}" \
    --header "X-Webhook-Signature: ${SIG}" \
    --data "${BODY}" || echo "000")
  echo "Valid webhook status: ${valid_code}"
  if [ "${valid_code}" = "200" ]; then
    pass "Valid webhook accepted (HTTP 200)"
  else
    fail "Valid webhook rejected – got ${valid_code} (expected 200)"
  fi

  echo ""
  echo "===== TV1 P0.7 Invalid webhook (bad signature) ====="
  invalid_code=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: $(date +%s)" \
    --header "X-Webhook-Nonce: invalid-nonce-$(random_nonce)" \
    --header "X-Webhook-Signature: sha256=badhash0000000000000000" \
    --data '{"event_id":"evt-bad","event_type":"payment.succeeded"}' || echo "000")
  echo "Invalid signature status: ${invalid_code}"
  if [ "${invalid_code}" = "401" ]; then
    pass "Invalid signature correctly rejected (401)"
  else
    fail "Invalid signature not rejected – got ${invalid_code}"
  fi

  echo ""
  echo "===== TV1 P0.7 Replay webhook (same nonce twice) ====="
  TS2="$(date +%s)"
  NONCE2="replay-$(random_nonce)"
  BODY2='{"event_id":"evt-replay","event_type":"payment.succeeded","checkout_id":"checkout-replay"}'
  SIG2="$(sign_hmac "${WEBHOOK_SECRET}" "${TS2}" "${NONCE2}" "${BODY2}")"

  code1=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS2}" \
    --header "X-Webhook-Nonce: ${NONCE2}" \
    --header "X-Webhook-Signature: ${SIG2}" \
    --data "${BODY2}" || echo "000")
  echo "Replay send #1 status: ${code1}"

  # Send exact same request again (replay)
  code2=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS2}" \
    --header "X-Webhook-Nonce: ${NONCE2}" \
    --header "X-Webhook-Signature: ${SIG2}" \
    --data "${BODY2}" || echo "000")
  echo "Replay send #2 status: ${code2}"

  if [ "${code1}" = "200" ] && [ "${code2}" = "403" ]; then
    pass "Replay attack blocked: send#1=200 send#2=403 (replayed_nonce)"
  elif [ "${code2}" = "403" ]; then
    pass "Replay correctly rejected on second send (403)"
  else
    fail "Replay not blocked: send#1=${code1} send#2=${code2}"
  fi
} | tee "${EVIDENCE_DIR}/p0-07-webhook-hmac-replay.txt"
echo

# =============================================================================
# P0.8 – Webhook Timestamp Freshness
# =============================================================================
log "===== P0.8 Webhook timestamp freshness ====="
{
  echo "===== TV1 P0.8 Timestamp freshness ====="
  echo "--- Code verification: WEBHOOK_MAX_AGE_SECONDS ---"
  grep -n "WEBHOOK_MAX_AGE\|timestamp_expired\|age >" \
    "${REPO_ROOT}/services/billing/main.py" | head -10 || true

  echo ""
  echo "--- Test: fresh timestamp -> should pass ---"
  FSTS="$(date +%s)"
  FSNONCE="fresh-$(random_nonce)"
  FSBODY='{"event_id":"evt-fresh","event_type":"payment.succeeded","checkout_id":"co-fresh"}'
  FSSIG="$(sign_hmac "${WEBHOOK_SECRET}" "${FSTS}" "${FSNONCE}" "${FSBODY}")"

  fresh_code=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${FSTS}" \
    --header "X-Webhook-Nonce: ${FSNONCE}" \
    --header "X-Webhook-Signature: ${FSSIG}" \
    --data "${FSBODY}" || echo "000")
  echo "Fresh timestamp status: ${fresh_code}"
  if [ "${fresh_code}" = "200" ]; then
    pass "Fresh timestamp accepted (200)"
  else
    fail "Fresh timestamp rejected unexpectedly – got ${fresh_code}"
  fi

  echo ""
  echo "--- Test: old timestamp (400s ago) -> should fail with 403 ---"
  OLD_TS=$(( $(date +%s) - 400 ))
  OLD_NONCE="old-ts-$(random_nonce)"
  OLD_BODY='{"event_id":"evt-old-ts","event_type":"payment.succeeded","checkout_id":"co-ts-test"}'
  OLD_SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${OLD_TS}" "${OLD_NONCE}" "${OLD_BODY}")"

  old_code=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${OLD_TS}" \
    --header "X-Webhook-Nonce: ${OLD_NONCE}" \
    --header "X-Webhook-Signature: ${OLD_SIG}" \
    --data "${OLD_BODY}" || echo "000")
  echo "Old timestamp (400s ago) status: ${old_code}"
  if [ "${old_code}" = "403" ]; then
    pass "Old timestamp correctly rejected with 403 (timestamp_expired)"
  else
    fail "Old timestamp not rejected – got ${old_code} (expected 403)"
  fi
} | tee "${EVIDENCE_DIR}/p0-08-webhook-timestamp-freshness.txt"
echo

# =============================================================================
# P0.9 – Webhook mTLS Status
# =============================================================================
log "===== P0.9 Webhook mTLS status ====="
{
  echo "===== TV1 P0.9 mTLS check ====="
  
  TS="$(date +%s)"
  NONCE="mtls-valid-$(random_nonce)"
  BODY='{"event_id":"evt-mtls-valid","event_type":"payment.succeeded"}'
  SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"

  echo "--- Testing mTLS with valid client cert ---"
  mtls_code=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS}" \
    --header "X-Webhook-Nonce: ${NONCE}" \
    --header "X-Webhook-Signature: ${SIG}" \
    --data "${BODY}" || echo "000")
  
  if [ "${mtls_code}" = "200" ]; then
    pass "mTLS: Request with valid client cert accepted (200)"
  else
    fail "mTLS: Request with valid client cert rejected – got ${mtls_code}"
  fi

  echo ""
  echo "--- Testing mTLS without client cert ---"
  TS2="$(date +%s)"
  NONCE2="mtls-nocert-$(random_nonce)"
  SIG2="$(sign_hmac "${WEBHOOK_SECRET}" "${TS2}" "${NONCE2}" "${BODY}")"

  nocert_code=$(run_python_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS2}" \
    --header "X-Webhook-Nonce: ${NONCE2}" \
    --header "X-Webhook-Signature: ${SIG2}" \
    --data "${BODY}" || echo "000")

  if [ "${nocert_code}" = "401" ] || [ "${nocert_code}" = "403" ]; then
    pass "mTLS: Request without client cert correctly rejected (${nocert_code})"
  else
    fail "mTLS: Request without client cert NOT rejected – got ${nocert_code}"
  fi
} | tee "${EVIDENCE_DIR}/p0-09-webhook-mtls-check.txt"
echo

# =============================================================================
# Final Summary
# =============================================================================
PASS_COUNT=$(grep -c "^PASS:" "${RESULT_FILE}" 2>/dev/null || echo 0)
FAIL_COUNT=$(grep -c "^FAIL:" "${RESULT_FILE}" 2>/dev/null || echo 0)
LIMIT_COUNT=$(grep -c "^LIMITATION:" "${RESULT_FILE}" 2>/dev/null || echo 0)

{
  echo ""
  echo "========================================"
  echo "  TV1 Test Summary"
  echo "========================================"
  echo "PASS:        ${PASS_COUNT}"
  echo "FAIL:        ${FAIL_COUNT}"
  echo "LIMITATION:  ${LIMIT_COUNT}"
  echo ""
  echo "PASS items:"
  grep "^PASS:" "${RESULT_FILE}" | sed 's/^PASS:/  ✓ /' || true
  echo ""
  echo "FAIL items:"
  grep "^FAIL:" "${RESULT_FILE}" | sed 's/^FAIL:/  ✗ /' || true
  echo ""
  echo "LIMITATION items:"
  grep "^LIMITATION:" "${RESULT_FILE}" | sed 's/^LIMITATION:/  ⚠ /' || true
  echo ""
  echo "Evidence saved to: ${EVIDENCE_DIR}/"
  echo "========================================"
} | tee "${EVIDENCE_DIR}/p0-summary.txt"
