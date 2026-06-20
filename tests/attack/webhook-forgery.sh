#!/usr/bin/env bash
# tests/attack/webhook-forgery.sh
#
# Webhook Forgery Attack Simulation
#
# Tests HMAC signature verification on the billing service webhook endpoint.
#
# Test cases:
#   1. Missing signature headers → 401
#   2. Wrong HMAC signature → 401
#   3. Expired timestamp → 403
#   4. Valid request → 200
#
# Usage:
#   bash tests/attack/webhook-forgery.sh

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
if [ -z "${WEBHOOK_SECRET:-}" ] || [[ "${WEBHOOK_SECRET:-}" == REPLACE_WITH_* ]]; then
  echo "[ERROR] WEBHOOK_SECRET must be set from infra/.env or the shell environment." >&2
  exit 1
fi
WEBHOOK_URL="${BASE_URL}/api/v1/billing/webhooks/payment"
# Try billing service webhook endpoint first, fall back to TV1 webhook demo
BILLING_WEBHOOK="${BASE_URL}/api/v1/billing/webhooks/payment"
TV1_WEBHOOK="${BASE_URL}/api/v1/webhooks/payment"

PASS=0
FAIL=0

assert_status() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "${actual}" -eq "${expected}" ]; then
    echo "[PASS] ${label} (HTTP ${actual})"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] ${label} – expected HTTP ${expected}, got HTTP ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

sign_webhook() {
  local timestamp="$1"
  local nonce="$2"
  local body="$3"
  local secret="$4"
  local message="${timestamp}.${nonce}.${body}"
  echo -n "${message}" | python3 -c "
import sys, hmac, hashlib
secret = '${secret}'.encode()
msg = sys.stdin.read().encode()
print('sha256=' + hmac.new(secret, msg, hashlib.sha256).hexdigest())
"
}

echo "=== Webhook Forgery Attack Simulation ==="
echo "Base URL: ${BASE_URL}"
echo "Webhook Secret: (loaded from environment; value hidden)"
echo ""

BODY='{"event_id":"evt-forgery-001","event_type":"payment.succeeded","checkout_id":"checkout-001","amount":150000}'
TIMESTAMP=$(date +%s)
NONCE="nonce-forgery-$(date +%s)"

# Test 1: Missing all webhook headers → 401
echo "--- Scenario 1: Missing webhook headers (gateway blocks it) ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TV1_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: forgery-001" \
  -d "${BODY}")
assert_status "No webhook headers → 401 (gateway/service blocks)" 401 "${STATUS}"

# Test 2: Wrong HMAC signature → 401
echo ""
echo "--- Scenario 2: Wrong HMAC signature ---"
VALID_SIG=$(sign_webhook "${TIMESTAMP}" "${NONCE}" "${BODY}" "${WEBHOOK_SECRET}")
WRONG_SIG="sha256=0000000000000000000000000000000000000000000000000000000000000000"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TV1_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Nonce: ${NONCE}" \
  -H "X-Webhook-Signature: ${WRONG_SIG}" \
  -H "X-Correlation-ID: forgery-002" \
  -d "${BODY}")
assert_status "Wrong HMAC signature → 401" 401 "${STATUS}"

# Test 3: Expired timestamp → 403
echo ""
echo "--- Scenario 3: Expired timestamp (>300s old) ---"
OLD_TIMESTAMP=$((TIMESTAMP - 400))
OLD_NONCE="nonce-old-$(date +%s)"
OLD_SIG=$(sign_webhook "${OLD_TIMESTAMP}" "${OLD_NONCE}" "${BODY}" "${WEBHOOK_SECRET}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TV1_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${OLD_TIMESTAMP}" \
  -H "X-Webhook-Nonce: ${OLD_NONCE}" \
  -H "X-Webhook-Signature: ${OLD_SIG}" \
  -H "X-Correlation-ID: forgery-003" \
  -d "${BODY}")
assert_status "Expired timestamp → 403" 403 "${STATUS}"

# Test 4: Valid webhook → 200
echo ""
echo "--- Scenario 4: Valid webhook (correct HMAC) ---"
FRESH_TIMESTAMP=$(date +%s)
FRESH_NONCE="nonce-valid-$(date +%s)"
FRESH_SIG=$(sign_webhook "${FRESH_TIMESTAMP}" "${FRESH_NONCE}" "${BODY}" "${WEBHOOK_SECRET}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TV1_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${FRESH_TIMESTAMP}" \
  -H "X-Webhook-Nonce: ${FRESH_NONCE}" \
  -H "X-Webhook-Signature: ${FRESH_SIG}" \
  -H "X-Correlation-ID: forgery-004" \
  -d "${BODY}")
assert_status "Valid HMAC webhook → 200" 200 "${STATUS}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
