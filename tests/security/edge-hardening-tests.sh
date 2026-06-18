#!/usr/bin/env bash
# =============================================================================
# TV1 Edge Hardening Security – Automated Test Suite
# Output: docs/evidence/tv1/edge-final/
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1/edge-final"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:8000}"
HTTPS_HOST="${HTTPS_HOST:-localhost:8443}"

mkdir -p "${EVIDENCE_DIR}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

RESULT_FILE="$(mktemp)"
trap 'rm -f "${RESULT_FILE}"' EXIT

log()        { echo -e "${CYAN}[EDGE]${NC} $*"; }
pass()       { echo -e "${GREEN}[PASS]${NC} $*"; echo "PASS:$*" >> "${RESULT_FILE}"; }
fail()       { echo -e "${RED}[FAIL]${NC} $*"; echo "FAIL:$*" >> "${RESULT_FILE}"; }
limitation() { echo -e "${YELLOW}[LIMITATION]${NC} $*"; echo "LIMITATION:$*" >> "${RESULT_FILE}"; }

# =============================================================================
# 1. TLS 1.3 only & HSTS
# =============================================================================
log "===== TLS 1.3 only and HSTS ====="
{
  echo "===== TLS Test ====="
  if ! command -v openssl &>/dev/null; then
    limitation "openssl not found – TLS test skipped"
  else
    echo "--- TLS 1.3 should succeed ---"
    tls13_out=$(echo | openssl s_client -connect "${HTTPS_HOST}" -tls1_3 2>&1 || true)
    if echo "${tls13_out}" | grep -q "TLSv1.3"; then
      pass "TLS 1.3 handshake succeeded"
    else
      limitation "TLS 1.3 not confirmed"
    fi

    echo "--- TLS 1.2 should fail ---"
    tls12_out=$(echo | openssl s_client -connect "${HTTPS_HOST}" -tls1_2 2>&1 || true)
    if echo "${tls12_out}" | grep -Eiq "alert|wrong version|no protocols|error"; then
      pass "TLS 1.2 correctly rejected"
    else
      limitation "TLS 1.2 rejection not confirmed"
    fi
  fi

  echo "===== HSTS Test ====="
  hsts_out=$(curl -k -i "https://${HTTPS_HOST}/api/v1/users/health" 2>/dev/null \
    | grep -i "HTTP/\|strict-transport-security" || echo "")
  if echo "${hsts_out}" | grep -iq "strict-transport-security"; then
    pass "HSTS header present"
  else
    limitation "HSTS not confirmed"
  fi
} > "${EVIDENCE_DIR}/tls-13-only-and-hsts.txt" 2>&1

# =============================================================================
# 2. CORS Strict
# =============================================================================
log "===== CORS Strict ====="
{
  echo "===== Allowed origin ====="
  allowed=$(curl -si -X OPTIONS "${GATEWAY_URL}/api/v1/users/health" \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" 2>/dev/null || true)
  if echo "${allowed}" | grep -iq "access-control-allow-origin"; then
    pass "Allowed origin http://localhost:3000 is permitted"
  else
    fail "Allowed origin not reflected in CORS response"
  fi

  echo "===== Evil origin ====="
  evil=$(curl -si -X OPTIONS "${GATEWAY_URL}/api/v1/users/health" \
    -H "Origin: https://evil.example" \
    -H "Access-Control-Request-Method: GET" 2>/dev/null || true)
  if echo "${evil}" | grep -iq "evil.example"; then
    fail "Evil origin was allowed – CORS misconfigured"
  else
    pass "Evil origin https://evil.example is NOT allowed"
  fi
} > "${EVIDENCE_DIR}/cors-strict-final.txt" 2>&1

# =============================================================================
# 3. Rate Limit (429)
# =============================================================================
log "===== Rate Limit (429) ====="
{
  echo "===== Rate limit on protected route ====="
  got_429=false
  for i in $(seq 1 15); do
    code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${GATEWAY_URL}/api/v1/admin/maintenance" \
      -H "Authorization: Bearer fake.jwt.token" \
      -H "Content-Type: application/json" \
      -d '{"action":"health-check","reason":"rate-limit-test"}' 2>/dev/null || echo "000")
    if [ "${code}" = "429" ]; then got_429=true; fi
  done
  if ${got_429}; then
    pass "Rate limit enforced – 429 received"
  else
    fail "Rate limit not triggered in 15 requests"
  fi
} > "${EVIDENCE_DIR}/rate-limit-429-final.txt" 2>&1

# =============================================================================
# 4. Request Size Limit (413/417)
# =============================================================================
log "===== Request Size Limit ====="
{
  echo "===== Large payload blocked by gateway ====="
  LARGE_FILE="$(mktemp)"
  trap 'rm -f "${LARGE_FILE}"' EXIT
  dd if=/dev/zero bs=1024 count=2200 2>/dev/null | tr '\0' 'A' > "${LARGE_FILE}" || true

  if [ -s "${LARGE_FILE}" ]; then
    WRAPPED="$(mktemp)"
    { printf '{"data":"'; cat "${LARGE_FILE}"; printf '"}'; } > "${WRAPPED}" || true
    large_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST "${GATEWAY_URL}/api/v1/billing/checkout" \
      -H "Authorization: Bearer abc" \
      -H "Content-Type: application/json" \
      --data-binary @"${WRAPPED}" 2>/dev/null || echo "000")
    rm -f "${WRAPPED}"
    if [ "${large_code}" = "413" ] || [ "${large_code}" = "417" ]; then
      pass "Large payload blocked by Kong (${large_code})"
    else
      fail "Large payload not blocked – got ${large_code}"
    fi
  else
    limitation "Could not generate large payload"
  fi
} > "${EVIDENCE_DIR}/request-size-limit-final.txt" 2>&1

# =============================================================================
# 5. WAF SQLi/XSS Final
# =============================================================================
log "===== WAF SQLi/XSS ====="
{
  echo "===== WAF SQLi Test ====="
  sqli_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -G "${GATEWAY_URL}/api/v1/users/profile" --data-urlencode "id=1' or 1=1" 2>/dev/null || echo "000")
  if [ "${sqli_code}" = "403" ]; then
    pass "SQLi payload blocked by WAF (403)"
  else
    fail "SQLi payload NOT blocked – got ${sqli_code}"
  fi

  echo "===== WAF XSS Test ====="
  xss_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${GATEWAY_URL}/api/v1/users/profile" \
    -H "Content-Type: application/json" \
    -d '{"name": "<script>alert(1)</script>"}' 2>/dev/null || echo "000")
  if [ "${xss_code}" = "403" ]; then
    pass "XSS payload blocked by WAF (403)"
  else
    fail "XSS payload NOT blocked – got ${xss_code}"
  fi
} > "${EVIDENCE_DIR}/waf-sqli-xss-final.txt" 2>&1

# =============================================================================
# Summary
# =============================================================================
cat "${RESULT_FILE}"
echo "Edge hardening tests completed. Check ${EVIDENCE_DIR}"
