#!/usr/bin/env bash
# Verify Redis-backed webhook nonce persistence across billing-service restart.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${EVIDENCE_DIR:-${REPO_ROOT}/.artifacts/test-runs/tv1/webhook-nonce-persistence}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret-change-me}"
WEBHOOK_CERT_DIR="${REPO_ROOT}/infra/certs"
REDIS_WAS_STOPPED=0

if [ -f "${REPO_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/infra/.env"
  set +a
  WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret-change-me}"
fi

mkdir -p "${EVIDENCE_DIR}"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

compose() {
  (cd "${REPO_ROOT}" && docker compose -f infra/docker-compose.yml "$@")
}

cleanup() {
  if [ "${REDIS_WAS_STOPPED}" -eq 1 ]; then
    compose start redis >/dev/null 2>&1 || true
    wait_for_redis >/dev/null 2>&1 || true
    compose restart billing-service >/dev/null 2>&1 || true
    wait_for_billing >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

sign_hmac() {
  local secret="$1" ts="$2" nonce="$3" body="$4"
  local message="${ts}.${nonce}.${body}"
  local hex
  hex=$(printf '%s' "${message}" | openssl dgst -sha256 -hmac "${secret}" 2>/dev/null | awk '{print $NF}')
  echo "sha256=${hex}"
}

random_nonce() {
  openssl rand -hex 16 2>/dev/null || echo "nonce-$(date +%s)-$$"
}

wait_for_billing() {
  local code
  local curl_tls_opts="${CURL_TLS_OPTS:---insecure}"
  for attempt in $(seq 1 30); do
    code="$(curl ${curl_tls_opts} -sS -o /dev/null -w "%{http_code}" https://localhost:8443/api/v1/billing/health 2>/dev/null || echo "000")"
    echo "[INFO] billing readiness attempt ${attempt}/30: HTTP ${code}"
    [ "${code}" = "200" ] && return 0
    sleep 2
  done
  return 1
}

wait_for_redis() {
  for attempt in $(seq 1 30); do
    if compose exec -T redis redis-cli ping >/dev/null 2>&1; then
      echo "[INFO] redis readiness attempt ${attempt}/30: PONG"
      return 0
    fi
    echo "[INFO] redis readiness attempt ${attempt}/30: not ready"
    sleep 1
  done
  return 1
}

ensure_mtls_certs_and_reload_kong() {
  bash "${REPO_ROOT}/demo/mtls/ensure-mtls-certs.sh" >/dev/null
  compose restart kong >/dev/null
  wait_for_billing >/dev/null || fail "Kong/Billing did not become ready after mTLS reload"
}

run_webhook_client() {
  MSYS_NO_PATHCONV=1 docker run --rm -i --network infra_default \
    -v "${WEBHOOK_CERT_DIR}:/certs:ro" \
    python:3.13-slim python - "$@" <<'PY'
import argparse
import ssl
import sys
import urllib.error
import urllib.request

parser = argparse.ArgumentParser(description="mTLS webhook nonce persistence client")
parser.add_argument("--url", required=True)
parser.add_argument("--cert", required=True)
parser.add_argument("--key", required=True)
parser.add_argument("--data", required=True)
parser.add_argument("--header", action="append", default=[])
args = parser.parse_args()

context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE
context.load_cert_chain(certfile=args.cert, keyfile=args.key)

request = urllib.request.Request(args.url, method="POST")
for header in args.header:
    if ":" in header:
        key, value = header.split(":", 1)
        request.add_header(key.strip(), value.strip())

try:
    response = urllib.request.urlopen(request, data=args.data.encode("utf-8"), context=context, timeout=10)
    print(response.getcode())
except urllib.error.HTTPError as exc:
    print(exc.code)
except Exception as exc:
    print("000")
    print(f"client_error={type(exc).__name__}", file=sys.stderr)
PY
}

send_signed_webhook() {
  local ts="$1" nonce="$2" body="$3" sig="$4"
  run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" \
    --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${ts}" \
    --header "X-Webhook-Nonce: ${nonce}" \
    --header "X-Webhook-Signature: ${sig}" \
    --data "${body}" | tail -n 1
}

command -v docker >/dev/null 2>&1 || fail "docker is required"
command -v openssl >/dev/null 2>&1 || fail "openssl is required"

wait_for_redis || fail "Redis nonce store is not ready"
ensure_mtls_certs_and_reload_kong

echo "===== Redis nonce survives billing restart =====" | tee "${EVIDENCE_DIR}/webhook-nonce-persistence.txt"
TS="$(date +%s)"
NONCE="persist-$(random_nonce)"
BODY='{"event_id":"evt-persist","event_type":"payment.succeeded","checkout_id":"checkout-persist"}'
SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"

code1="$(send_signed_webhook "${TS}" "${NONCE}" "${BODY}" "${SIG}")"
[ "${code1}" = "200" ] || fail "First valid webhook was not accepted: HTTP ${code1}"
pass "First valid webhook accepted (HTTP 200)"

compose restart billing-service >/dev/null
wait_for_billing || fail "Billing did not become ready after restart"

code2="$(send_signed_webhook "${TS}" "${NONCE}" "${BODY}" "${SIG}")"
if [ "${code2}" = "403" ]; then
  pass "Replay after billing restart rejected (HTTP 403)"
else
  fail "Replay after billing restart was not rejected as replay: HTTP ${code2}"
fi

echo "===== Redis unavailable fails closed =====" | tee "${EVIDENCE_DIR}/webhook-nonce-fail-closed.txt"
compose stop redis >/dev/null
REDIS_WAS_STOPPED=1
compose restart billing-service >/dev/null
wait_for_billing || fail "Billing did not become ready with Redis unavailable"

TS_DOWN="$(date +%s)"
NONCE_DOWN="redis-down-$(random_nonce)"
BODY_DOWN='{"event_id":"evt-redis-down","event_type":"payment.succeeded","checkout_id":"checkout-redis-down"}'
SIG_DOWN="$(sign_hmac "${WEBHOOK_SECRET}" "${TS_DOWN}" "${NONCE_DOWN}" "${BODY_DOWN}")"
code_down="$(send_signed_webhook "${TS_DOWN}" "${NONCE_DOWN}" "${BODY_DOWN}" "${SIG_DOWN}")"
if [ "${code_down}" != "200" ]; then
  pass "Redis unavailable failed closed (HTTP ${code_down})"
else
  fail "Redis unavailable allowed webhook unexpectedly"
fi

compose start redis >/dev/null
wait_for_redis || fail "Redis did not recover"
compose restart billing-service >/dev/null
wait_for_billing || fail "Billing did not recover after Redis restart"
REDIS_WAS_STOPPED=0

echo "Webhook nonce persistence tests completed. Evidence: ${EVIDENCE_DIR}"
