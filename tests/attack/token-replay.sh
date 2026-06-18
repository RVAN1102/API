#!/usr/bin/env bash
# tests/attack/token-replay.sh
#
# Token Replay Attack Simulation
#
# Demonstrates what happens when an expired/invalid JWT is replayed.
# A real replay defense requires short-lived tokens (handled by Keycloak exp claim)
# and optionally token revocation lists.
#
# Test cases:
#   1. Use a clearly invalid/expired token → 401
#   2. Use a missing token → 401
#   3. Use a malformed token → 401
#
# Usage:
#   bash tests/attack/token-replay.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"

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

# A well-formed but expired JWT (static, will always fail signature verification)
EXPIRED_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImZha2Uta2lkIn0.eyJzdWIiOiJhbGljZSIsInByZWZlcnJlZF91c2VybmFtZSI6ImFsaWNlIiwiZXhwIjoxNjAwMDAwMDAwLCJpc3MiOiJodHRwOi8va2V5Y2xvYWs6ODA4MC9yZWFsbXMvdG9waWMxMC1zbWUtYXBpIn0.FAKESIGNATURE"

echo "=== Token Replay Attack Simulation ==="
echo "Base URL: ${BASE_URL}"
echo ""

echo "--- Scenario 1: Expired/invalid JWT (bad signature) ---"
echo "(Expected: 401 – token verification fails)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/me" \
  -H "Authorization: Bearer ${EXPIRED_TOKEN}" \
  -H "X-Correlation-ID: replay-attack-001")
assert_status "Replayed/expired token → GET /users/me → 401" 401 "${STATUS}"

echo ""
echo "--- Scenario 2: No token ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/me")
assert_status "No token → GET /users/me → 403" 403 "${STATUS}"

echo ""
echo "--- Scenario 3: Malformed token (not JWT) ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/users/me" \
  -H "Authorization: Bearer not-a-real-jwt" \
  -H "X-Correlation-ID: replay-attack-003")
assert_status "Malformed token → GET /users/me → 401" 401 "${STATUS}"

echo ""
echo "--- Scenario 4: Webhook HMAC replay (using duplicate nonce) ---"
echo "(First request should succeed, second should fail with 403 – replay detected)"
TIMESTAMP=$(date +%s)
NONCE="test-nonce-replay-$(date +%s)"
BODY='{"event_id":"evt-replay-001","event_type":"payment.succeeded","checkout_id":"checkout-001"}'
WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret-change-me}"
MESSAGE="${TIMESTAMP}.${NONCE}.${BODY}"
SIG=$(echo -n "${MESSAGE}" | python3 -c "
import sys, hmac, hashlib
secret = '${WEBHOOK_SECRET}'.encode()
msg = sys.stdin.read().encode()
print('sha256=' + hmac.new(secret, msg, hashlib.sha256).hexdigest())
")

echo "Sending first webhook (nonce: ${NONCE})"
STATUS1=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/webhooks/payment" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Nonce: ${NONCE}" \
  -H "X-Webhook-Signature: ${SIG}" \
  -H "X-Correlation-ID: replay-attack-004" \
  -d "${BODY}")
assert_status "First webhook (new nonce) → 200" 200 "${STATUS1}"

echo "Sending second webhook (SAME nonce – replay)"
STATUS2=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/webhooks/payment" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Nonce: ${NONCE}" \
  -H "X-Webhook-Signature: ${SIG}" \
  -H "X-Correlation-ID: replay-attack-005" \
  -d "${BODY}")
assert_status "Second webhook (replayed nonce) → 403" 403 "${STATUS2}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
