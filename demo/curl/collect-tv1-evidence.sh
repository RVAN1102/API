#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="${ROOT_DIR}/docs/evidence/tv1"
mkdir -p "${EVIDENCE_DIR}"

capture() {
  local output="$1"
  shift
  echo "Collecting ${output}"
  local result=0
  {
    echo "command: $*"
    echo "collected_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    "$@" || result=$?
    echo
    echo "exit_code: ${result}"
  } >"${EVIDENCE_DIR}/${output}" 2>&1
  echo "exit=${result}"
}

capture initial-gateway-health.txt bash "${ROOT_DIR}/demo/curl/test-gateway-routes.sh"
capture gateway-routes.txt bash "${ROOT_DIR}/demo/curl/test-gateway-routes.sh"
capture cors-preflight.txt bash "${ROOT_DIR}/demo/curl/test-cors.sh"
capture rate-limit-result.txt bash "${ROOT_DIR}/demo/curl/test-rate-limit.sh"
capture waf-filter-result.txt bash "${ROOT_DIR}/demo/curl/test-waf-filter.sh"
capture https-result.txt bash "${ROOT_DIR}/demo/curl/test-https.sh"
capture hsts-header.txt bash "${ROOT_DIR}/demo/curl/test-hsts.sh"
capture correlation-id-result.txt bash "${ROOT_DIR}/demo/curl/test-correlation-id.sh"
capture webhook-valid.txt bash "${ROOT_DIR}/demo/webhook/send-valid-webhook.sh"
capture webhook-invalid-signature.txt bash "${ROOT_DIR}/demo/webhook/send-invalid-signature.sh"
capture webhook-replay.txt bash "${ROOT_DIR}/demo/webhook/send-replay-webhook.sh"

echo "Evidence collected under ${EVIDENCE_DIR}"
