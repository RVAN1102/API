#!/usr/bin/env bash
# Fail-closed static gate for final runtime transport security.
# The final Docker Compose path must not reintroduce plaintext HTTP between containers.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

failures=0
fail() { echo "[FAIL] $*" >&2; failures=$((failures + 1)); }
pass() { echo "[PASS] $*"; }

assert_no_match() {
  local name="$1" pattern="$2"; shift 2
  local out
  out="$(grep -RInE --exclude-dir=.git --exclude-dir=docs/evidence --exclude='no-plaintext-transport-tests.sh' --exclude='*.png' --exclude='*.jpg' --exclude='*.lock' "$pattern" "$@" 2>/dev/null || true)"
  if [ -n "${out}" ]; then
    fail "${name}"
    echo "${out}" >&2
  else
    pass "${name}"
  fi
}

assert_no_match "Kong final declarative config has no plaintext upstream" 'url:[[:space:]]*http://' gateway/kong.yml
assert_no_match "No Nginx proxy_pass plaintext fallback" 'proxy_pass[[:space:]]+http://' infra/nginx gateway
assert_no_match "No backend service URL on plaintext port 8000" '(user-service|order-service|billing-service|admin-service):8000' infra gateway services tests
assert_no_match "No Keycloak plaintext default" 'KEYCLOAK_URL.*http://|KEYCLOAK_BASE_URL.*http://|KC_URL.*http://' infra services demo tests
assert_no_match "No OPA plaintext default" 'OPA_URL.*http://|OPA_URL_HOST.*http://' infra services tests
assert_no_match "No Vault plaintext default" 'VAULT_ADDR.*http://|address=http://localhost:8200' infra tests scripts
assert_no_match "No Redis plaintext default" 'redis://redis' infra services tests
assert_no_match "Removed obsolete proxy runtime references" 'user-mtls-proxy|order-mtls-proxy|billing-mtls-proxy|admin-mtls-proxy|webhook-demo|/etc/s2s-mtls' infra/docker-compose.yml gateway/kong.yml tests/final/main-regression.sh tests/security/s2s-ownership-tests.sh tests/security/gateway-backend-mtls-tests.sh

for file in services/user/Dockerfile services/order/Dockerfile services/billing/Dockerfile services/admin/Dockerfile; do
  if grep -q -- '--ssl-certfile' "${file}" && grep -q -- '--ssl-cert-reqs 2' "${file}" && ! grep -q -- '--port", "8000\|--port 8000' "${file}"; then
    pass "${file} starts uvicorn with HTTPS/mTLS on 8443"
  else
    fail "${file} does not enforce uvicorn HTTPS/mTLS"
  fi
done

if [ "${failures}" -ne 0 ]; then
  echo "[SUMMARY] no-plaintext transport gate failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "[SUMMARY] no-plaintext transport gate passed."
