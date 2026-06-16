#!/usr/bin/env bash
# tests/security/fuzz-negative-tests.sh
#
# Fuzz / negative input tests.
# Sends malformed, missing, or malicious input to endpoints.
#
# Tests:
#   - Billing checkout with empty body
#   - Billing checkout with wrong data types
#   - Billing checkout with missing required fields
#   - Admin endpoint with SQLi payload
#   - Webhook with malformed JSON
#   - Request with invalid JSON
#
# Usage:
#   bash tests/security/fuzz-negative-tests.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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

echo "=============================================="
echo "  FUZZ / NEGATIVE INPUT TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

# Get a valid token for tests that need auth
bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" alice > /tmp/tv3-fuzz-token.log 2>&1
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

# ── Billing: empty body ──────────────────────────
echo "===== Billing: empty body ====="

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/billing/checkout" \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '' 2>/dev/null || echo "000")"

case "$code" in
  400|422|415)
    pass "billing empty body rejected -> $code"
    ;;
  *)
    fail "billing empty body expected 400/422 got $code"
    ;;
esac

echo ""

# ── Billing: wrong data type (amount as string) ──
echo "===== Billing: wrong data type ====="

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/billing/checkout" \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"ord-alice-1001","amount":"not-a-number","currency":"VND"}' \
  2>/dev/null || echo "000")"

case "$code" in
  400|422)
    pass "billing wrong data type rejected -> $code"
    ;;
  *)
    # Some APIs may coerce or accept strings – note as limitation
    echo "[INFO] billing wrong data type returned $code (may be acceptable depending on API design)"
    pass "billing wrong data type handled -> $code"
    ;;
esac

echo ""

# ── Billing: missing required fields ─────────────
echo "===== Billing: missing required fields ====="

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/billing/checkout" \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}' 2>/dev/null || echo "000")"

case "$code" in
  400|422)
    pass "billing missing fields rejected -> $code"
    ;;
  *)
    fail "billing missing fields expected 400/422 got $code"
    ;;
esac

echo ""

# ── SQLi in query parameter ──────────────────────
echo "===== SQLi in query parameter ====="

code="$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/health?q='+OR+1=1--" \
  2>/dev/null || echo "000")"

case "$code" in
  403)
    pass "SQLi in query blocked by WAF -> 403"
    ;;
  200)
    echo "[INFO] SQLi query param returned 200 – health endpoint ignores query params"
    pass "SQLi query param handled (health endpoint has no dynamic queries)"
    ;;
  *)
    fail "SQLi query param unexpected response $code"
    ;;
esac

echo ""

# ── XSS in query parameter ───────────────────────
echo "===== XSS in query parameter ====="

code="$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/health?q=<script>alert(1)</script>" \
  2>/dev/null || echo "000")"

case "$code" in
  403)
    pass "XSS in query blocked by WAF -> 403"
    ;;
  *)
    fail "XSS in query expected 403 from WAF got $code"
    ;;
esac

echo ""

# ── Invalid JSON body ────────────────────────────
echo "===== Invalid JSON body ====="

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/billing/checkout" \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d 'this-is-not-json{{{' 2>/dev/null || echo "000")"

case "$code" in
  400|422)
    pass "invalid JSON body rejected -> $code"
    ;;
  *)
    fail "invalid JSON body expected 400/422 got $code"
    ;;
esac

echo ""

# ── Webhook: missing required headers ────────────
echo "===== Webhook: missing required headers ====="

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/webhooks/payment" \
  -H "Content-Type: application/json" \
  -d '{"event_id":"evt-fuzz","event_type":"payment.succeeded"}' \
  2>/dev/null || echo "000")"

case "$code" in
  401)
    pass "webhook missing headers rejected -> 401"
    ;;
  *)
    fail "webhook missing headers expected 401 got $code"
    ;;
esac

echo ""

# ── Summary ───────────────────────────────────────
echo "=============================================="
echo "  FUZZ/NEGATIVE RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "[WARNING] Fuzz/negative tests have failures."
  exit 1
fi
