#!/usr/bin/env bash
# Runtime evidence for optional Gateway-to-Backend mTLS sidecar profile.
#
# The test starts the compose stack with infra/docker-compose.mtls.yml, verifies
# that normal Kong routes still work, and verifies that backend sidecar proxies
# reject TLS callers that do not present Kong's client certificate.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASE_COMPOSE="${REPO_ROOT}/infra/docker-compose.yml"
MTLS_COMPOSE="${REPO_ROOT}/infra/docker-compose.mtls.yml"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1/gateway-backend-mtls"
EVIDENCE_FILE="${EVIDENCE_DIR}/gateway-backend-mtls-runtime.txt"

mkdir -p "${EVIDENCE_DIR}"
exec > >(tee "${EVIDENCE_FILE}") 2>&1

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
  docker compose -f "${BASE_COMPOSE}" -f "${MTLS_COMPOSE}" "$@"
}

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

http_code() {
  local code
  code="$(curl -s -o /tmp/gw-backend-mtls-body.$$ -w '%{http_code}' "$@" 2>/dev/null || true)"
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
    user-mtls-proxy) echo "/api/v1/users/health" ;;
    order-mtls-proxy) echo "/api/v1/orders/health" ;;
    billing-mtls-proxy) echo "/api/v1/billing/health" ;;
    admin-mtls-proxy) echo "/api/v1/admin/health" ;;
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
  if [ "${rc}" -eq 0 ] && printf '%s' "${out}" | grep -q '200'; then
    pass "${host} accepts Kong client certificate and returns backend health"
  else
    fail "${host} did not accept Kong client certificate or did not return 200"
  fi
}

echo "============================================================"
echo "Gateway-to-Backend mTLS Runtime Evidence"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Compose files:"
echo "  - ${BASE_COMPOSE}"
echo "  - ${MTLS_COMPOSE}"
echo "Evidence file: ${EVIDENCE_FILE}"
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

wait_http_200 "http://localhost:8000/api/v1/users/health" "Kong -> user via mTLS sidecar"
wait_http_200 "http://localhost:8000/api/v1/orders/health" "Kong -> order via mTLS sidecar"
wait_http_200 "http://localhost:8000/api/v1/billing/health" "Kong -> billing via mTLS sidecar"
wait_http_200 "http://localhost:8000/api/v1/admin/health" "Kong -> admin via mTLS sidecar"

assert_kong_has_openssl

assert_proxy_rejects_no_client_cert "user-mtls-proxy"
assert_proxy_rejects_no_client_cert "order-mtls-proxy"
assert_proxy_rejects_no_client_cert "billing-mtls-proxy"
assert_proxy_rejects_no_client_cert "admin-mtls-proxy"

assert_proxy_rejects_wrong_client_cert "user-mtls-proxy"

assert_proxy_accepts_kong_client_cert "user-mtls-proxy" "/api/v1/users/health"
assert_proxy_accepts_kong_client_cert "order-mtls-proxy" "/api/v1/orders/health"
assert_proxy_accepts_kong_client_cert "billing-mtls-proxy" "/api/v1/billing/health"
assert_proxy_accepts_kong_client_cert "admin-mtls-proxy" "/api/v1/admin/health"

echo
echo "[OK] Gateway-to-Backend mTLS runtime profile passed"
