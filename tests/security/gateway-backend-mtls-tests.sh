#!/usr/bin/env bash
# Runtime evidence for default Gateway-to-Backend direct HTTPS/mTLS enforcement.
#
# The test starts the default compose stack, verifies that normal Kong routes
# work through direct HTTPS/mTLS upstreams, and verifies that backend HTTPS/mTLS listeners
# reject TLS callers that do not present Kong's client certificate.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASE_COMPOSE="${REPO_ROOT}/infra/docker-compose.yml"
OFFICIAL_EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1/gateway-backend-mtls"
OFFICIAL_EVIDENCE_FILE="${OFFICIAL_EVIDENCE_DIR}/gateway-backend-mtls-runtime.txt"
ARTIFACT_DIR="${REPO_ROOT}/.artifacts/test-runs"
RUN_ID="$(date -u +"%Y%m%dT%H%M%SZ")"

if [ "${UPDATE_OFFICIAL_EVIDENCE:-0}" = "1" ]; then
  EVIDENCE_DIR="${OFFICIAL_EVIDENCE_DIR}"
  EVIDENCE_FILE="${OFFICIAL_EVIDENCE_FILE}"
else
  EVIDENCE_DIR="${ARTIFACT_DIR}"
  EVIDENCE_FILE="${EVIDENCE_DIR}/gateway-backend-mtls-runtime-${RUN_ID}.txt"
fi

mkdir -p "${EVIDENCE_DIR}"
exec > >(tee "${EVIDENCE_FILE}") 2>&1

cleanup_evidence() {
  if [ -f "${EVIDENCE_FILE}" ] && command -v sed >/dev/null 2>&1; then
    sed -i 's/[[:space:]]\+$//' "${EVIDENCE_FILE}" || true
  fi
}
trap cleanup_evidence EXIT

if [ -x "${REPO_ROOT}/scripts/bootstrap-lab-env.sh" ]; then
  bash "${REPO_ROOT}/scripts/bootstrap-lab-env.sh"
fi

if [ -f "${REPO_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/infra/.env"
  set +a
fi

compose() {
  docker compose -f "${BASE_COMPOSE}" "$@"
}

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

http_code() {
  local code
  local curl_tls_opts="${CURL_TLS_OPTS:---insecure}"
  code="$(curl ${curl_tls_opts} -s -o /tmp/gw-backend-mtls-body.$$ -w '%{http_code}' "$@" 2>/dev/null || true)"
  rm -f /tmp/gw-backend-mtls-body.$$
  [ -n "${code}" ] || code="000"
  echo "${code: -3}"
}

wait_http_200() {
  local url="$1"
  local label="$2"
  local i code
  for i in $(seq 1 40); do
    code="$(http_code "${url}")"
    if [ "${code}" = "200" ]; then
      pass "${label} returned 200"
      return
    fi
    sleep 3
  done
  fail "${label} did not return 200; last status=${code:-none}"
}

kong_exec() {
  compose exec -T kong /bin/sh -lc "$*"
}

assert_kong_has_openssl() {
  kong_exec 'command -v openssl >/dev/null 2>&1' \
    || fail "openssl is required inside the Kong container for mTLS probes"
  pass "Kong container has openssl for runtime TLS probes"
}


proxy_health_path() {
  case "$1" in
    user-service) echo "/api/v1/users/health" ;;
    order-service) echo "/api/v1/orders/health" ;;
    billing-service) echo "/api/v1/billing/health" ;;
    admin-service) echo "/api/v1/admin/health" ;;
    *) echo "/health" ;;
  esac
}

assert_rejected_http_probe() {
  local label="$1"
  local out="$2"
  local rc="$3"

  if printf '%s' "${out}" | grep -Eq 'HTTP/[0-9.]+ 200|\"status\":\"ok\"'; then
    echo "--- unexpected accepted output ---"
    printf '%s\n' "${out}"
    fail "${label} was accepted with HTTP 200"
  fi

  if [ "${rc}" -ne 0 ] || printf '%s' "${out}" | grep -Eiq 'HTTP/[0-9.]+ (400|401|403|421|495|496|497)|No required SSL certificate|client certificate|certificate required|bad certificate|unknown ca|handshake failure|alert|verify error'; then
    pass "${label}"
  else
    echo "--- unexpected rejection output ---"
    printf '%s\n' "${out}"
    fail "${label} did not provide clear rejection evidence"
  fi
}

assert_proxy_rejects_no_client_cert() {
  local host="$1"
  local path out rc
  path="$(proxy_health_path "${host}")"

  set +e
  out="$(kong_exec "printf 'GET ${path} HTTP/1.1
Host: ${host}
Connection: close

' | timeout 8 openssl s_client -quiet -connect ${host}:8443 -servername ${host} -CAfile /kong/gb-mtls/ca.crt -verify_return_error" 2>&1)"
  rc=$?
  set -e

  assert_rejected_http_probe "${host} rejects HTTP caller without client certificate" "${out}" "${rc}"
}

assert_proxy_rejects_wrong_client_cert() {
  local host="$1"
  local path out rc
  path="$(proxy_health_path "${host}")"

  set +e
  out="$(kong_exec "openssl req -x509 -nodes -newkey rsa:2048 -keyout /tmp/rogue.key -out /tmp/rogue.crt -subj /CN=rogue-client -days 1 >/dev/null 2>&1 && printf 'GET ${path} HTTP/1.1
Host: ${host}
Connection: close

' | timeout 8 openssl s_client -quiet -connect ${host}:8443 -servername ${host} -CAfile /kong/gb-mtls/ca.crt -cert /tmp/rogue.crt -key /tmp/rogue.key -verify_return_error" 2>&1)"
  rc=$?
  set -e

  assert_rejected_http_probe "${host} rejects wrong/self-signed client certificate" "${out}" "${rc}"
}

assert_proxy_accepts_kong_client_cert() {
  local host="$1"
  local path="$2"
  local out rc
  set +e
  out="$(kong_exec "printf 'GET ${path} HTTP/1.1\\r\\nHost: ${host}\\r\\nConnection: close\\r\\n\\r\\n' | timeout 8 openssl s_client -quiet -connect ${host}:8443 -servername ${host} -CAfile /kong/gb-mtls/ca.crt -cert /kong/gb-mtls/kong-client.crt -key /kong/gb-mtls/kong-client.key -verify_return_error" 2>/dev/null)"
  rc=$?
  set -e
  echo "${host} valid-cert probe: $(printf '%s' "${out}" | head -1)"
  if printf '%s' "${out}" | grep -Eq 'HTTP/[0-9.]+ 200|\"status\":\"ok\"'; then
    pass "${host} accepts Kong client certificate and returns backend health"
  else
    echo "--- valid certificate probe output (exit ${rc}) ---"
    printf '%s\n' "${out}"
    fail "${host} did not accept Kong client certificate or did not return 200"
  fi
}

echo "============================================================"
echo "Gateway-to-Backend mTLS Runtime Evidence"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Compose file: ${BASE_COMPOSE}"
echo "Evidence file: ${EVIDENCE_FILE}"
if [ "${UPDATE_OFFICIAL_EVIDENCE:-0}" != "1" ]; then
  echo "Official evidence snapshot is not overwritten. Set UPDATE_OFFICIAL_EVIDENCE=1 to refresh it intentionally."
fi
echo "============================================================"
echo

if ! command -v docker >/dev/null 2>&1; then
  fail "docker is required"
fi
if ! command -v curl >/dev/null 2>&1; then
  fail "curl is required"
fi

bash "${REPO_ROOT}/demo/mtls/ensure-gateway-backend-certs.sh"

compose up -d --build

wait_http_200 "https://localhost:8443/api/v1/users/health" "Kong -> user via direct HTTPS/mTLS"
wait_http_200 "https://localhost:8443/api/v1/orders/health" "Kong -> order via direct HTTPS/mTLS"
wait_http_200 "https://localhost:8443/api/v1/billing/health" "Kong -> billing via direct HTTPS/mTLS"
wait_http_200 "https://localhost:8443/api/v1/admin/health" "Kong -> admin via direct HTTPS/mTLS"

assert_kong_has_openssl

assert_proxy_rejects_no_client_cert "user-service"
assert_proxy_rejects_no_client_cert "order-service"
assert_proxy_rejects_no_client_cert "billing-service"
assert_proxy_rejects_no_client_cert "admin-service"

assert_proxy_rejects_wrong_client_cert "user-service"
assert_proxy_rejects_wrong_client_cert "order-service"
assert_proxy_rejects_wrong_client_cert "billing-service"
assert_proxy_rejects_wrong_client_cert "admin-service"

assert_proxy_accepts_kong_client_cert "user-service" "/api/v1/users/health"
assert_proxy_accepts_kong_client_cert "order-service" "/api/v1/orders/health"
assert_proxy_accepts_kong_client_cert "billing-service" "/api/v1/billing/health"
assert_proxy_accepts_kong_client_cert "admin-service" "/api/v1/admin/health"

echo
echo "[OK] Gateway-to-Backend mTLS runtime profile passed"
