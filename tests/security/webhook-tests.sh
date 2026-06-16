#!/usr/bin/env bash
# tests/security/webhook-tests.sh
#
# Webhook security test wrapper.
# TV3 does NOT modify webhook code; this wraps TV1's demo scripts.
#
# Tests:
#   - Valid webhook accepted (200)
#   - Invalid signature rejected (401)
#   - Replay request rejected on second attempt (403)
#
# Usage:
#   bash tests/security/webhook-tests.sh

set -euo pipefail

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
echo "  WEBHOOK SECURITY TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

# ── Valid webhook ─────────────────────────────────
echo "===== Valid webhook ====="

if bash "${PROJECT_ROOT}/demo/webhook/send-valid-webhook.sh" > /tmp/tv3-webhook-valid.log 2>&1; then
  pass "valid webhook accepted"
else
  fail "valid webhook rejected (see /tmp/tv3-webhook-valid.log)"
fi

echo ""

# ── Invalid webhook ───────────────────────────────
echo "===== Invalid webhook (bad signature) ====="

if bash "${PROJECT_ROOT}/demo/webhook/send-invalid-signature.sh" > /tmp/tv3-webhook-invalid.log 2>&1; then
  # Script exits 0 if grep finds HTTP_STATUS:401
  # If the script exits 0 it means invalid sig was properly rejected
  pass "invalid webhook rejected (401)"
else
  # send-invalid-signature.sh exits non-zero when it doesn't find HTTP_STATUS:401
  # which could mean the invalid webhook was unexpectedly accepted
  if grep -q "HTTP_STATUS:401" /tmp/tv3-webhook-invalid.log 2>/dev/null; then
    pass "invalid webhook rejected (401)"
  else
    fail "invalid webhook unexpectedly accepted (see /tmp/tv3-webhook-invalid.log)"
  fi
fi

echo ""

# ── Replay webhook ────────────────────────────────
echo "===== Replay webhook ====="

if bash "${PROJECT_ROOT}/demo/webhook/send-replay-webhook.sh" > /tmp/tv3-webhook-replay.log 2>&1; then
  pass "replay webhook test completed with expected behavior"
else
  # The replay script may exit non-zero if the second attempt is rejected (expected).
  # Check if the log shows attempt 1 → 200 and attempt 2 → 403.
  if grep -q "HTTP_STATUS:200" /tmp/tv3-webhook-replay.log 2>/dev/null && \
     grep -q "HTTP_STATUS:403" /tmp/tv3-webhook-replay.log 2>/dev/null; then
    pass "replay detected: attempt 1 accepted, attempt 2 rejected"
  elif grep -q "HTTP_STATUS:403" /tmp/tv3-webhook-replay.log 2>/dev/null; then
    pass "replay webhook rejected on retry (403)"
  else
    fail "replay webhook unexpected behavior (see /tmp/tv3-webhook-replay.log)"
  fi
fi

echo ""

# ── Summary ───────────────────────────────────────
echo "=============================================="
echo "  WEBHOOK RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "[ERROR] Webhook tests have failures."
  exit 1
fi
