#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
if [ -z "${WEBHOOK_SECRET:-}" ] || [[ "${WEBHOOK_SECRET:-}" == REPLACE_WITH_* ]]; then
  echo "[ERROR] WEBHOOK_SECRET must be set from infra/.env or the shell environment." >&2
  exit 1
fi
PYTHON_BIN="${PYTHON_BIN:-python3}"
TIMESTAMP="$(date +%s)"
NONCE="${NONCE:-$("${PYTHON_BIN}" -c 'import uuid; print(uuid.uuid4())')}"
BODY='{"event_id":"evt-tv1-valid","event_type":"payment.succeeded","checkout_id":"checkout-001","amount":150000}'
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SIGNATURE="$("${PYTHON_BIN}" "${SCRIPT_DIR}/sign_webhook.py" --secret "${WEBHOOK_SECRET}" \
  --timestamp "${TIMESTAMP}" --nonce "${NONCE}" --body "${BODY}")"

response="$(curl --silent --show-error --include --request POST \
  "${BASE_URL}/api/v1/webhooks/payment" \
  --header "Content-Type: application/json" \
  --header "X-Webhook-Timestamp: ${TIMESTAMP}" \
  --header "X-Webhook-Nonce: ${NONCE}" \
  --header "X-Webhook-Signature: ${SIGNATURE}" \
  --data-binary "${BODY}" \
  --write-out $'\nHTTP_STATUS:%{http_code}\n')"
printf '%s\n' "${response}"
grep -q 'HTTP_STATUS:200' <<<"${response}"
