#!/usr/bin/env bash
# =============================================================================
# TV1 Webhook Security – Automated Test Suite (Regression)
# Sends webhook requests through Docker network with mTLS client certs,
# matching the same approach used in tv1-edge-webhook-tests.sh.
#
# Output: docs/evidence/tv1/webhook-final/
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1/webhook-final"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret-change-me}"
WEBHOOK_CA_CRT="${REPO_ROOT}/infra/certs/webhook-ca.crt"
WEBHOOK_CA_KEY="${REPO_ROOT}/infra/certs/webhook-ca.key"
WEBHOOK_CERT_DIR=""

# Git Bash / MSYS2: save original MSYS_NO_PATHCONV
_ORIG_MSYS_NO_PATHCONV="${MSYS_NO_PATHCONV:-}"

mkdir -p "${EVIDENCE_DIR}"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

RESULT_FILE="$(mktemp)"

cleanup() {
  rm -f "${RESULT_FILE}"
  if [ -n "${WEBHOOK_CERT_DIR}" ] && [ -d "${WEBHOOK_CERT_DIR}" ]; then
    rm -f \
      "${WEBHOOK_CERT_DIR}/webhook-ca.crt" \
      "${WEBHOOK_CERT_DIR}/webhook-client.crt" \
      "${WEBHOOK_CERT_DIR}/webhook-client.csr" \
      "${WEBHOOK_CERT_DIR}/webhook-client.ext" \
      "${WEBHOOK_CERT_DIR}/webhook-client.key"
    rmdir "${WEBHOOK_CERT_DIR}" 2>/dev/null
  fi
  return 0
}
trap cleanup EXIT

TOTAL=0
PASSED=0
FAILED=0

log()  { echo -e "${CYAN}[WEBHOOK]${NC} $*"; }
pass() { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); echo -e "${GREEN}[PASS]${NC} $*"; echo "PASS:$*" >> "${RESULT_FILE}"; }
fail() { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); echo -e "${RED}[FAIL]${NC} $*"; echo "FAIL:$*" >> "${RESULT_FILE}"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

wait_for_kong() {
  local code
  local health_url="http://localhost:8000/api/v1/users/health"

  for attempt in $(seq 1 30); do
    if code="$(curl -sS -o /dev/null -w "%{http_code}" "${health_url}" 2>/dev/null)"; then
      :
    else
      code="000"
    fi

    echo "[INFO] Kong readiness attempt ${attempt}/30: users health HTTP ${code}"
    if [ "${code}" = "200" ]; then
      echo "[INFO] Kong users health is ready (HTTP 200)"
      return 0
    fi
    sleep 2
  done

  die "Kong did not return HTTP 200 from ${health_url} within 60s."
}

ensure_webhook_certs_and_reload_kong() {
  bash "${REPO_ROOT}/demo/mtls/ensure-mtls-certs.sh"

  echo "[INFO] Restarting Kong so nginx reloads the current webhook CA"
  (
    cd "${REPO_ROOT}/infra"
    BILLING_SERVICE_CLIENT_SECRET="${BILLING_SERVICE_CLIENT_SECRET:-compose-restart-placeholder}" \
    ADMIN_SERVICE_CLIENT_SECRET="${ADMIN_SERVICE_CLIENT_SECRET:-compose-restart-placeholder}" \
    WEBHOOK_SECRET="${WEBHOOK_SECRET}" \
      docker compose restart kong
  )
  wait_for_kong
}

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

cert_key_match() {
  local cert_file="$1"
  local key_file="$2"
  local cert_hash key_hash

  cert_hash="$(
    openssl x509 -in "${cert_file}" -pubkey -noout 2>/dev/null \
      | openssl pkey -pubin -outform DER 2>/dev/null \
      | openssl dgst -sha256 -binary 2>/dev/null \
      | openssl base64 -A 2>/dev/null
  )"
  key_hash="$(
    openssl pkey -in "${key_file}" -pubout 2>/dev/null \
      | openssl pkey -pubin -outform DER 2>/dev/null \
      | openssl dgst -sha256 -binary 2>/dev/null \
      | openssl base64 -A 2>/dev/null
  )"

  [ -n "${cert_hash}" ] && [ "${cert_hash}" = "${key_hash}" ]
}

cert_has_client_auth() {
  local cert_file="$1"
  openssl x509 -in "${cert_file}" -noout -ext extendedKeyUsage 2>/dev/null \
    | grep -Eq "TLS Web Client Authentication|clientAuth"
}

prepare_ephemeral_client_cert() {
  [ -r "${WEBHOOK_CA_CRT}" ] || die "Webhook CA certificate is missing or unreadable: ${WEBHOOK_CA_CRT}"
  [ -r "${WEBHOOK_CA_KEY}" ] || die "Webhook CA private key is missing or unreadable: ${WEBHOOK_CA_KEY}"
  cert_key_match "${WEBHOOK_CA_CRT}" "${WEBHOOK_CA_KEY}" \
    || die "Webhook CA certificate and private key do not match"

  WEBHOOK_CERT_DIR="$(mktemp -d /tmp/webhook-client-cert.XXXXXX)"
  local client_key="${WEBHOOK_CERT_DIR}/webhook-client.key"
  local client_csr="${WEBHOOK_CERT_DIR}/webhook-client.csr"
  local client_crt="${WEBHOOK_CERT_DIR}/webhook-client.crt"
  local client_ext="${WEBHOOK_CERT_DIR}/webhook-client.ext"

  cp "${WEBHOOK_CA_CRT}" "${WEBHOOK_CERT_DIR}/webhook-ca.crt"
  chmod 700 "${WEBHOOK_CERT_DIR}"

  openssl genrsa -out "${client_key}" 2048 >/dev/null 2>&1 \
    || die "Failed to generate temporary webhook client private key"
  chmod 600 "${client_key}"

  openssl req -new \
    -key "${client_key}" \
    -out "${client_csr}" \
    -subj "/C=VN/O=Topic10-SME-API/OU=TV1-WebhookSender/CN=webhook-sender-ephemeral" >/dev/null 2>&1 \
    || die "Failed to generate temporary webhook client CSR"

  cat > "${client_ext}" <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

  openssl x509 -req \
    -in "${client_csr}" \
    -CA "${WEBHOOK_CA_CRT}" \
    -CAkey "${WEBHOOK_CA_KEY}" \
    -set_serial "0x$(openssl rand -hex 16)" \
    -out "${client_crt}" \
    -days 1 \
    -sha256 \
    -extfile "${client_ext}" >/dev/null 2>&1 \
    || die "Failed to sign temporary webhook client certificate"

  cert_key_match "${client_crt}" "${client_key}" \
    || die "Temporary webhook client certificate and private key do not match"
  cert_has_client_auth "${client_crt}" \
    || die "Temporary webhook client certificate is missing extendedKeyUsage=clientAuth"
}

# =============================================================================
# Docker-based webhook client (matches tv1-edge-webhook-tests.sh approach)
# Runs inside Docker network so it can reach kong:8443 with mTLS
# =============================================================================
run_webhook_client() {
  MSYS_NO_PATHCONV=1 docker run --rm -i --network infra_default \
    -v "${WEBHOOK_CERT_DIR}:/certs:ro" \
    python:3.13-slim python - "$@" <<'PY'
import argparse
import ssl
import sys
import urllib.error
import urllib.request


parser = argparse.ArgumentParser(description="mTLS Webhook Test Client")
parser.add_argument("--url", required=True)
parser.add_argument("--cert", required=False)
parser.add_argument("--key", required=False)
parser.add_argument("--data", required=False)
parser.add_argument("--header", action="append", default=[])
args = parser.parse_args()

context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

if args.cert and args.key:
    try:
        context.load_cert_chain(certfile=args.cert, keyfile=args.key)
    except Exception as exc:
        print(f"Error loading cert: {exc}", file=sys.stderr)
        sys.exit(1)

req = urllib.request.Request(args.url, method="POST")
for header in args.header:
    if ":" in header:
        key, value = header.split(":", 1)
        req.add_header(key.strip(), value.strip())

data = args.data.encode("utf-8") if args.data else b""

try:
    response = urllib.request.urlopen(req, data=data, context=context)
    print(response.getcode())
except urllib.error.HTTPError as exc:
    print(exc.code)
    body = exc.read().decode("utf-8", errors="replace")
    if body:
        print(f"response_body={body}", file=sys.stderr)
except urllib.error.URLError as exc:
    print("000")
    print(f"URLError: {exc}", file=sys.stderr)
except Exception as exc:
    print("000")
    print(f"Exception: {exc}", file=sys.stderr)
PY
}

ensure_webhook_certs_and_reload_kong
prepare_ephemeral_client_cert

# =============================================================================
# 1. Valid HMAC (with mTLS client cert, via Docker network)
# =============================================================================
log "===== 1. Valid HMAC ====="
{
  TS="$(date +%s)"
  NONCE="valid-$(random_nonce)"
  BODY='{"event_id":"evt-tv1-valid","event_type":"payment.succeeded","checkout_id":"checkout-001","amount":150000}'
  SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"

  # Retry up to 5 times to handle Kong/service startup timing after restart
  valid_code="000"
  for _retry in 1 2 3 4 5; do
    valid_code=$(run_webhook_client \
      --url "https://kong:8443/api/v1/webhooks/payment" \
      --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
      --header "Content-Type: application/json" \
      --header "X-Webhook-Timestamp: ${TS}" \
      --header "X-Webhook-Nonce: ${NONCE}" \
      --header "X-Webhook-Signature: ${SIG}" \
      --data "${BODY}" || echo "000")
    [ "${valid_code}" = "200" ] && break
    sleep 5
    TS="$(date +%s)"
    NONCE="valid-$(random_nonce)"
    SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"
  done
  if [ "${valid_code}" = "200" ]; then
    pass "Valid webhook accepted (HTTP 200)"
  else
    fail "Valid webhook rejected – got ${valid_code}"
  fi
} > "${EVIDENCE_DIR}/webhook-valid-hmac.txt" 2>&1

# =============================================================================
# 2. Invalid Signature
# =============================================================================
log "===== 2. Invalid Signature ====="
{
  invalid_code=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: $(date +%s)" \
    --header "X-Webhook-Nonce: invalid-$(random_nonce)" \
    --header "X-Webhook-Signature: sha256=badhash0000000000000000" \
    --data '{"event_id":"evt-bad","event_type":"payment.succeeded","checkout_id":"checkout-bad"}' || echo "000")
  if [ "${invalid_code}" = "401" ]; then
    pass "Invalid signature correctly rejected (401)"
  else
    fail "Invalid signature not rejected – got ${invalid_code}"
  fi
} > "${EVIDENCE_DIR}/webhook-invalid-signature.txt" 2>&1

# =============================================================================
# 3. Replay Nonce
# =============================================================================
log "===== 3. Replay Nonce ====="
{
  TS2="$(date +%s)"
  NONCE2="replay-$(random_nonce)"
  BODY2='{"event_id":"evt-replay","event_type":"payment.succeeded","checkout_id":"checkout-replay"}'
  SIG2="$(sign_hmac "${WEBHOOK_SECRET}" "${TS2}" "${NONCE2}" "${BODY2}")"

  code1=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS2}" \
    --header "X-Webhook-Nonce: ${NONCE2}" \
    --header "X-Webhook-Signature: ${SIG2}" \
    --data "${BODY2}" || echo "000")

  code2=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS2}" \
    --header "X-Webhook-Nonce: ${NONCE2}" \
    --header "X-Webhook-Signature: ${SIG2}" \
    --data "${BODY2}" || echo "000")

  if [ "${code1}" = "200" ] && [ "${code2}" = "403" ]; then
    pass "Replay blocked: send#1=200 send#2=403"
  else
    fail "Replay not blocked: send#1=${code1} send#2=${code2}"
  fi
} > "${EVIDENCE_DIR}/webhook-replay-nonce.txt" 2>&1

# =============================================================================
# 4. Old Timestamp
# =============================================================================
log "===== 4. Old Timestamp ====="
{
  OLD_TS=$(( $(date +%s) - 400 ))
  OLD_NONCE="old-ts-$(random_nonce)"
  OLD_BODY='{"event_id":"evt-old-ts","event_type":"payment.succeeded","checkout_id":"checkout-old-ts"}'
  OLD_SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${OLD_TS}" "${OLD_NONCE}" "${OLD_BODY}")"

  old_code=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${OLD_TS}" \
    --header "X-Webhook-Nonce: ${OLD_NONCE}" \
    --header "X-Webhook-Signature: ${OLD_SIG}" \
    --data "${OLD_BODY}" || echo "000")
  if [ "${old_code}" = "403" ] || [ "${old_code}" = "401" ]; then
    pass "Old timestamp correctly rejected (${old_code})"
  else
    fail "Old timestamp not rejected – got ${old_code}"
  fi
} > "${EVIDENCE_DIR}/webhook-old-timestamp.txt" 2>&1

# =============================================================================
# 5. Missing Headers
# =============================================================================
log "===== 5. Missing Headers ====="
{
  missing_code=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --data '{"event_id":"evt-missing","event_type":"payment.succeeded","checkout_id":"checkout-missing"}' || echo "000")
  if [ "${missing_code}" = "401" ]; then
    pass "Missing headers correctly rejected by Gateway WAF (401)"
  else
    fail "Missing headers not rejected – got ${missing_code}"
  fi
} > "${EVIDENCE_DIR}/webhook-missing-headers.txt" 2>&1

# =============================================================================
# 6. mTLS with valid client cert
# =============================================================================
log "===== 6. mTLS with valid client cert ====="
{
  TS="$(date +%s)"
  NONCE="mtls-valid-$(random_nonce)"
  BODY='{"event_id":"evt-mtls-valid","event_type":"payment.succeeded","checkout_id":"checkout-mtls-valid"}'
  SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"

  mtls_code=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --cert "/certs/webhook-client.crt" --key "/certs/webhook-client.key" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS}" \
    --header "X-Webhook-Nonce: ${NONCE}" \
    --header "X-Webhook-Signature: ${SIG}" \
    --data "${BODY}" || echo "000")

  if [ "${mtls_code}" = "200" ]; then
    pass "mTLS: Request with valid client cert accepted (200)"
  else
    fail "mTLS: Request with valid client cert rejected – got ${mtls_code}"
  fi
} > "${EVIDENCE_DIR}/webhook-mtls-with-cert.txt" 2>&1

# =============================================================================
# 7. mTLS without client cert
# =============================================================================
log "===== 7. mTLS without client cert ====="
{
  TS="$(date +%s)"
  NONCE="mtls-nocert-$(random_nonce)"
  BODY='{"event_id":"evt-mtls-nocert","event_type":"payment.succeeded","checkout_id":"checkout-mtls-nocert"}'
  SIG="$(sign_hmac "${WEBHOOK_SECRET}" "${TS}" "${NONCE}" "${BODY}")"

  nocert_code=$(run_webhook_client \
    --url "https://kong:8443/api/v1/webhooks/payment" \
    --header "Content-Type: application/json" \
    --header "X-Webhook-Timestamp: ${TS}" \
    --header "X-Webhook-Nonce: ${NONCE}" \
    --header "X-Webhook-Signature: ${SIG}" \
    --data "${BODY}" || echo "000")

  if [ "${nocert_code}" = "401" ] || [ "${nocert_code}" = "403" ]; then
    pass "mTLS: Request without client cert correctly rejected (${nocert_code})"
  else
    fail "mTLS: Request without client cert NOT rejected – got ${nocert_code}"
  fi
} > "${EVIDENCE_DIR}/webhook-mtls-no-cert-rejected.txt" 2>&1

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "  WEBHOOK RESULT: ${PASSED}/${TOTAL} passed, ${FAILED} failed"
echo "=============================================="
cat "${RESULT_FILE}"
echo "Webhook tests completed. Check ${EVIDENCE_DIR}"

# Restore MSYS_NO_PATHCONV
if [ -n "${_ORIG_MSYS_NO_PATHCONV}" ]; then
  export MSYS_NO_PATHCONV="${_ORIG_MSYS_NO_PATHCONV}"
fi

if [ "${FAILED}" -gt 0 ]; then
  echo ""
  echo "[ERROR] Webhook security tests have failures."
  exit 1
fi
