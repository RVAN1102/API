#!/usr/bin/env bash
# tests/attack/ssrf-attack.sh
#
# SSRF Attack Simulation
#
# Demonstrates the difference between vulnerable and fixed SSRF endpoints:
#   Vulnerable: fetches any URL including internal metadata endpoints
#   Fixed:      blocks dangerous URLs (169.254.169.254, localhost, private IPs)
#
# Usage:
#   ACCESS_TOKEN=<token> bash tests/attack/ssrf-attack.sh
#
# Environment variables:
#   BASE_URL      – default: http://localhost:8000
#   ACCESS_TOKEN  – Bearer token (required for protected endpoints)

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
ACCESS_TOKEN="${ACCESS_TOKEN:-}"

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

if [ -z "${ACCESS_TOKEN}" ]; then
  echo "ERROR: ACCESS_TOKEN is required."
  echo "  Obtain an MFA-protected human admin token outside this script."
  echo "  ACCESS_TOKEN=<admin-token> bash tests/attack/ssrf-attack.sh"
  exit 1
fi

echo "=== SSRF Attack Simulation ==="
echo "Base URL: ${BASE_URL}"
echo ""

AUTH_HEADER="Authorization: Bearer ${ACCESS_TOKEN}"

echo "--- Scenario 1: SSRF attempt to AWS metadata (vulnerable endpoint) ---"
echo "(Expected: 200 – endpoint fetches without validation, SSRF flaw)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/admin/metadata-fetch/vulnerable" \
  -H "Content-Type: application/json" \
  -H "${AUTH_HEADER}" \
  -H "X-Correlation-ID: ssrf-attack-001" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}')
assert_status "SSRF vulnerable → http://169.254.169.254 → 200 (flaw)" 200 "${STATUS}"

echo ""
echo "--- Scenario 2: SSRF attempt to localhost (vulnerable endpoint) ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/admin/metadata-fetch/vulnerable" \
  -H "Content-Type: application/json" \
  -H "${AUTH_HEADER}" \
  -H "X-Correlation-ID: ssrf-attack-002" \
  -d '{"fetch_url":"http://localhost:8200/v1/sys/health"}')
assert_status "SSRF vulnerable → http://localhost:8200 → 200 (flaw)" 200 "${STATUS}"

echo ""
echo "--- Scenario 3: SSRF attempt blocked by FIXED endpoint (AWS metadata) ---"
echo "(Expected: 403 – SSRF protection blocks dangerous URL)"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/admin/metadata-fetch/fixed" \
  -H "Content-Type: application/json" \
  -H "${AUTH_HEADER}" \
  -H "X-Correlation-ID: ssrf-attack-003" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}')
assert_status "SSRF fixed → http://169.254.169.254 → 403 (blocked)" 403 "${STATUS}"

echo ""
echo "--- Scenario 4: SSRF attempt blocked by FIXED endpoint (localhost) ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/admin/metadata-fetch/fixed" \
  -H "Content-Type: application/json" \
  -H "${AUTH_HEADER}" \
  -H "X-Correlation-ID: ssrf-attack-004" \
  -d '{"fetch_url":"http://localhost:8200/v1/sys/health"}')
assert_status "SSRF fixed → http://localhost → 403 (blocked)" 403 "${STATUS}"

echo ""
echo "--- Scenario 5: SSRF blocked for file:// scheme ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${BASE_URL}/api/v1/admin/metadata-fetch/fixed" \
  -H "Content-Type: application/json" \
  -H "${AUTH_HEADER}" \
  -H "X-Correlation-ID: ssrf-attack-005" \
  -d '{"fetch_url":"file:///etc/passwd"}')
assert_status "SSRF fixed → file:///etc/passwd → 403 (blocked)" 403 "${STATUS}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
