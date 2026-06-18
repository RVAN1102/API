#!/usr/bin/env bash
# tests/attack/bola-object-access.sh
#
# BOLA (Broken Object Level Authorization) Attack Simulation
#
# Demonstrates the difference between the vulnerable and fixed endpoints:
#   Vulnerable: Alice can access Bob's order (BOLA flaw)
#   Fixed:      Alice is blocked from Bob's order (403)
#
# Usage:
#   # Get tokens first:
#   bash demo/auth/get-user-token.sh alice
#   ALICE_TOKEN=$(cat /tmp/user-token.txt)
#
#   bash demo/auth/get-user-token.sh bob
#   BOB_TOKEN=$(cat /tmp/user-token.txt)
#
#   ALICE_TOKEN=<token> BOB_TOKEN=<token> bash tests/attack/bola-object-access.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
ALICE_TOKEN="${ALICE_TOKEN:-}"
BOB_TOKEN="${BOB_TOKEN:-}"

# Bob's order (Alice should NOT be able to access this)
BOB_ORDER="ord-bob-2001"

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

echo "=== BOLA Attack Simulation ==="
echo "Base URL:    ${BASE_URL}"
echo "Target order: ${BOB_ORDER} (owned by bob)"
echo ""

if [ -z "${ALICE_TOKEN}" ] || [ -z "${BOB_TOKEN}" ]; then
  echo "ERROR: ALICE_TOKEN and BOB_TOKEN are required."
  echo ""
  echo "Obtain tokens:"
  echo "  bash demo/auth/get-user-token.sh alice && ALICE_TOKEN=\$(cat /tmp/user-token.txt)"
  echo "  bash demo/auth/get-user-token.sh bob && BOB_TOKEN=\$(cat /tmp/user-token.txt)"
  exit 1
fi

echo "--- Scenario 1: Alice accesses Bob's order via VULNERABLE endpoint ---"
echo "(Expected: 200 – BOLA flaw allows unauthorized access)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/orders/${BOB_ORDER}/vulnerable" \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "X-Correlation-ID: bola-attack-001")
assert_status "Alice → GET /orders/${BOB_ORDER}/vulnerable → 200 (BOLA flaw)" 200 "${STATUS}"

echo ""
echo "--- Scenario 2: Alice accesses Bob's order via FIXED endpoint ---"
echo "(Expected: 403 – ownership check blocks access)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/orders/${BOB_ORDER}/fixed" \
  -H "Authorization: Bearer ${ALICE_TOKEN}" \
  -H "X-Correlation-ID: bola-attack-002")
assert_status "Alice → GET /orders/${BOB_ORDER}/fixed → 403 (blocked)" 403 "${STATUS}"

echo ""
echo "--- Scenario 3: Bob accesses his own order via FIXED endpoint ---"
echo "(Expected: 200 – owner is allowed)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/orders/${BOB_ORDER}/fixed" \
  -H "Authorization: Bearer ${BOB_TOKEN}" \
  -H "X-Correlation-ID: bola-attack-003")
assert_status "Bob → GET /orders/${BOB_ORDER}/fixed → 200 (owner allowed)" 200 "${STATUS}"

echo ""
echo "--- Scenario 4: No token → 403 ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}/api/v1/orders/${BOB_ORDER}/fixed")
assert_status "No token → GET /orders/${BOB_ORDER}/fixed → 403" 403 "${STATUS}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
