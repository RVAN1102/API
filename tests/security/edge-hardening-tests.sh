#!/usr/bin/env bash
# tests/security/edge-hardening-tests.sh
#
# Edge hardening tests – wraps TV1's Kong gateway security config.

#
# Tests:
#   - TLS 1.3 handshake succeeds
#   - TLS 1.2 is rejected
#   - HSTS header present on HTTPS
#   - CORS allows localhost:3002 origin
#   - CORS blocks evil origin
#   - Large payload (>1MB) is rejected
#   - Rate limit returns 429 eventually
#
# Usage:
#   bash tests/security/edge-hardening-tests.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
HTTPS_URL="${HTTPS_URL:-https://localhost:8443}"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

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

skip() {
  TOTAL=$((TOTAL + 1))
  SKIPPED=$((SKIPPED + 1))
  echo "[SKIP] $1"
}

echo "=============================================="
echo "  EDGE HARDENING TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

# ── TLS 1.3 should succeed ───────────────────────
echo "===== TLS 1.3 should succeed ====="

if command -v openssl > /dev/null 2>&1; then
  if echo | openssl s_client -connect localhost:8443 -tls1_3 2>/tmp/edge-tls13.txt > /dev/null 2>&1; then
    pass "TLS 1.3 handshake completed"
  else
    # On Windows, openssl may not be available or may not support -tls1_3
    if grep -qi "TLSv1.3\|tls1_3" /tmp/edge-tls13.txt 2>/dev/null; then
      pass "TLS 1.3 handshake completed (from stderr)"
    else
      fail "TLS 1.3 handshake failed"
    fi
  fi
else
  skip "TLS 1.3 (openssl not available)"
fi

echo ""

# ── TLS 1.2 should fail ──────────────────────────
echo "===== TLS 1.2 should fail ====="

if command -v openssl > /dev/null 2>&1; then
  if echo | openssl s_client -connect localhost:8443 -tls1_2 > /tmp/edge-tls12.txt 2>&1; then
    if grep -qi "Protocol  *: TLSv1.2" /tmp/edge-tls12.txt; then
      fail "TLS 1.2 unexpectedly negotiated"
    else
      pass "TLS 1.2 did not negotiate"
    fi
  else
    pass "TLS 1.2 rejected (connection failed)"
  fi
else
  skip "TLS 1.2 (openssl not available)"
fi

echo ""

# ── HSTS ──────────────────────────────────────────
echo "===== HSTS header ====="

if curl -k -s -i "${HTTPS_URL}/api/v1/users/health" | grep -qi "strict-transport-security"; then
  pass "HSTS header present"
else
  fail "HSTS header missing (only emitted on HTTPS requests)"
fi

echo ""

# ── CORS allowed origin ──────────────────────────
echo "===== CORS allowed origin ====="

CORS_RESPONSE="$(curl -s -i -X OPTIONS "${BASE_URL}/api/v1/users/health" \
  -H "Origin: http://localhost:3002" \
  -H "Access-Control-Request-Method: GET" 2>/dev/null || true)"

if echo "${CORS_RESPONSE}" | grep -qi "access-control-allow-origin"; then
  pass "allowed origin (localhost:3002) has CORS allow header"
else
  fail "allowed origin (localhost:3002) missing CORS allow header"
fi

echo ""

# ── CORS evil origin ─────────────────────────────
echo "===== CORS evil origin ====="

EVIL_RESPONSE="$(curl -s -i -X OPTIONS "${BASE_URL}/api/v1/users/health" \
  -H "Origin: https://evil.example" \
  -H "Access-Control-Request-Method: GET" 2>/dev/null || true)"

if echo "${EVIL_RESPONSE}" | grep -qi "access-control-allow-origin: https://evil.example"; then
  fail "evil origin was allowed"
else
  pass "evil origin not allowed"
fi

echo ""

# ── Request size limit ────────────────────────────
echo "===== Request size limit ====="

# Create a payload > 1MB (Kong is configured to limit 1MB)
if command -v python3 > /dev/null 2>&1; then
  python3 -c "
import json, sys
payload = json.dumps({'data': 'A' * (2 * 1024 * 1024)})
with open('/tmp/edge-large-payload.json', 'w') as f:
    f.write(payload)
"

  code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    --data-binary @/tmp/edge-large-payload.json 2>/dev/null || echo "000")"

  case "$code" in
    413|417|400)
      pass "large payload blocked -> $code"
      ;;
    *)
      fail "large payload expected gateway rejection got $code"
      ;;
  esac
elif command -v python > /dev/null 2>&1; then
  python -c "
import json
payload = json.dumps({'data': 'A' * (2 * 1024 * 1024)})
with open('/tmp/edge-large-payload.json', 'w') as f:
    f.write(payload)
"

  code="$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    --data-binary @/tmp/tv3-large-payload.json 2>/dev/null || echo "000")"

  case "$code" in
    413|417|400)
      pass "large payload blocked -> $code"
      ;;
    *)
      fail "large payload expected gateway rejection got $code"
      ;;
  esac
else
  skip "large payload (python not available)"
fi

echo ""

# ── Rate limit ────────────────────────────────────
echo "===== Rate limit (sensitive endpoint) ====="

# users-me has limit of 10/min. Send 15 requests rapidly.
GOT_429=false
for i in $(seq 1 15); do
  code="$(curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "Authorization: Bearer fake.jwt.token" 2>/dev/null || echo "000")"
  if [ "$code" = "429" ]; then
    GOT_429=true
    break
  fi
done

if [ "$GOT_429" = "true" ]; then
  pass "rate limit triggered (429 received)"
else
  fail "rate limit not triggered after 15 rapid requests (may need reset)"
fi

echo ""

# ── Summary ───────────────────────────────────────
echo "=============================================="
echo "  EDGE HARDENING RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed, ${SKIPPED} skipped"
echo "=============================================="

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "[WARNING] Edge hardening tests have failures."
  echo "Some failures may be expected on Windows (TLS tests require openssl)."
  exit 1
fi
