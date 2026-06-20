#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret-change-me}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TIMESTAMP="$(date +%s)"
NONCE="replay-demo-$(date +%s)"
BODY='{"event_id":"evt-tv1-replay","event_type":"payment.succeeded","checkout_id":"checkout-001","amount":150000}'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SIGNATURE="$("${PYTHON_BIN}" "${SCRIPT_DIR}/sign_webhook.py" --secret "${WEBHOOK_SECRET}" \
  --timestamp "${TIMESTAMP}" --nonce "${NONCE}" --body "${BODY}")"

expected_statuses=(200 403)
for attempt in 1 2; do
  echo "===== attempt ${attempt} ====="
  response="$(curl --silent --show-error --include --request POST \
    "${BASE_URL}/api/v1/webhooks/payment" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TIMESTAMP}" \
    --header "X-Webhook-Nonce: ${NONCE}" \
    --header "X-Webhook-Signature: ${SIGNATURE}" \
    --data-binary "${BODY}" \
    --write-out $'\nHTTP_STATUS:%{http_code}\n')"
  printf '%s\n' "${response}"
  grep -q "HTTP_STATUS:${expected_statuses[$((attempt - 1))]}" <<<"${response}"
done
