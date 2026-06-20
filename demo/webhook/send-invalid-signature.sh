#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
PYTHON_BIN="${PYTHON_BIN:-python3}"
TIMESTAMP="$(date +%s)"
NONCE="$("${PYTHON_BIN}" -c 'import uuid; print(uuid.uuid4())')"
BODY='{"event_id":"evt-tv1-invalid","event_type":"payment.succeeded","checkout_id":"checkout-001","amount":150000}'

response="$(curl --silent --show-error --include --request POST \
  "${BASE_URL}/api/v1/webhooks/payment" \
  --header "Content-Type: application/json" \
  --header "X-Webhook-Timestamp: ${TIMESTAMP}" \
  --header "X-Webhook-Nonce: ${NONCE}" \
  --header "X-Webhook-Signature: sha256=invalid" \
  --data-binary "${BODY}" \
  --write-out $'\nHTTP_STATUS:%{http_code}\n')"
printf '%s\n' "${response}"
grep -q 'HTTP_STATUS:401' <<<"${response}"
