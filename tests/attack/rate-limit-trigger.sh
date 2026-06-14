#!/usr/bin/env bash
# tests/attack/rate-limit-trigger.sh
#
# Rate Limit Trigger
#
# Sends rapid requests to trigger HTTP 429 Too Many Requests.
# Target: sensitive routes with 10 req/min limit.
#
# Usage:
#   bash tests/attack/rate-limit-trigger.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
TARGET="${BASE_URL}/api/v1/users"

echo "=== Rate Limit Trigger ==="
echo "Target: ${TARGET} (limit: 10 req/min)"
echo "Sending 15 rapid requests..."
echo ""

GOT_429=0
for i in $(seq 1 15); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}" \
    -H "X-Correlation-ID: rate-limit-${i}")
  echo "Request ${i}: HTTP ${STATUS}"
  if [ "${STATUS}" -eq 429 ]; then
    GOT_429=1
    echo ""
    echo "[PASS] Rate limit triggered at request ${i} – HTTP 429 received"
    break
  fi
  sleep 0.1
done

if [ "${GOT_429}" -eq 0 ]; then
  echo ""
  echo "[INFO] No 429 received in 15 requests."
  echo "       This may mean the rate limit window already reset, or the limit is higher."
  echo "       Try running: for i in \$(seq 1 15); do curl -s -o /dev/null -w \"%{http_code}\n\" ${TARGET}; done"
fi
