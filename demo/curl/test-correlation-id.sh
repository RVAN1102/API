#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
CORRELATION_ID="${CORRELATION_ID:-tv1-demo-correlation-id}"

headers="$(curl --silent --show-error --dump-header - --output /dev/null \
  "${BASE_URL}/api/v1/users/health" \
  --header "X-Correlation-ID: ${CORRELATION_ID}")"
printf '%s\n' "${headers}"
grep -qi "^X-Correlation-ID: ${CORRELATION_ID}" <<<"${headers}"

