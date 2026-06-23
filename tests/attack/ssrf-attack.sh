#!/usr/bin/env bash
# =============================================================================
# TV1 SSRF Attack Simulation & Network Egress Evidence
# Output: docs/evidence/tv1/ssrf-egress/
#
# Self-contained: reuses the local demo/dev token helper when ACCESS_TOKEN is
# not provided. The helper output is not copied into committed evidence.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1/ssrf-egress"
GATEWAY_URL="${GATEWAY_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }

# Source secrets so we have CLIENT_SECRET, etc.
if [ -f "${REPO_ROOT}/infra/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/infra/.env"
    set +a
fi

mkdir -p "${EVIDENCE_DIR}"

ACCESS_TOKEN="${ACCESS_TOKEN:-}"
if [ -z "${ACCESS_TOKEN}" ]; then
  echo "Fetching admin01 user token with local demo/dev helper..."
  TOKEN_HELPER_LOG="$(mktemp /tmp/topic10-ssrf-token-helper.XXXXXX)"
  if bash "${REPO_ROOT}/demo/auth/get-user-token.sh" admin01 >"${TOKEN_HELPER_LOG}" 2>&1; then
    ACCESS_TOKEN="$(cat /tmp/user-token.txt 2>/dev/null || true)"
  fi
  rm -f "${TOKEN_HELPER_LOG}"
fi

if [ -z "${ACCESS_TOKEN}" ]; then
  echo "ERROR: ACCESS_TOKEN is required. Could not auto-fetch."
  echo "Set ACCESS_TOKEN manually or rerun: bash demo/auth/get-user-token.sh admin01"
  exit 1
fi

echo "Token obtained (${#ACCESS_TOKEN} chars). Running SSRF tests..."
AUTH_HEADER="Authorization: Bearer ${ACCESS_TOKEN}"

# =============================================================================
# 1. Vulnerable SSRF (Red-team demo)
# =============================================================================
echo "===== 1. SSRF Vulnerable Attack Demo ====="
{
  echo "--- Fetching 169.254.169.254 from vulnerable endpoint ---"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${GATEWAY_URL}/api/v1/admin/metadata-fetch/vulnerable" \
    -H "Content-Type: application/json" \
    -H "${AUTH_HEADER}" \
    -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}')
  if [ "${STATUS}" = "200" ]; then
    echo "[PASS] Vulnerable endpoint allowed metadata fetch (HTTP 200) - RED TEAM SUCCESS"
  else
    echo "[FAIL] Vulnerable endpoint did not return 200 (got ${STATUS})"
  fi
} > "${EVIDENCE_DIR}/ssrf-vulnerable-attack-demo.txt" 2>&1


# =============================================================================
# 2. Fixed SSRF: Block Metadata IP
# =============================================================================
echo "===== 2. SSRF Fixed: Block Metadata ====="
{
  echo "--- Fetching 169.254.169.254 from fixed endpoint ---"
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${GATEWAY_URL}/api/v1/admin/metadata-fetch/fixed" \
    -H "Content-Type: application/json" \
    -H "${AUTH_HEADER}" \
    -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}')
  if [ "${STATUS}" = "403" ]; then
    echo "[PASS] Fixed endpoint blocked metadata fetch (HTTP 403) - DEFENSE SUCCESS"
  else
    echo "[FAIL] Fixed endpoint did not return 403 (got ${STATUS})"
  fi
} > "${EVIDENCE_DIR}/ssrf-fixed-block-metadata-ip.txt" 2>&1

# =============================================================================
# 3. Fixed SSRF: Application URL Validation for Public Host
# =============================================================================
echo "===== 3. SSRF Fixed: Application URL Validation for Public Host ====="
{
  echo "--- Requesting https://example.com through fixed endpoint ---"
  echo "Application-layer SSRF validation permits this public URL."
  echo "Docker network egress control may still prevent the container from completing the outbound fetch."
  BODY_FILE="$(mktemp)"
  STATUS=$(curl -s -o "${BODY_FILE}" -w "%{http_code}" -X POST \
    "${GATEWAY_URL}/api/v1/admin/metadata-fetch/fixed" \
    -H "Content-Type: application/json" \
    -H "${AUTH_HEADER}" \
    -d '{"fetch_url":"https://example.com"}')
  cat "${BODY_FILE}"
  rm -f "${BODY_FILE}"
  if [ "${STATUS}" = "200" ]; then
    echo "[PASS] Fixed endpoint accepted a syntactically safe public URL after URL validation (HTTP 200)"
  else
    echo "[FAIL] Fixed endpoint did not accept safe public URL for validation-path test (got ${STATUS})"
  fi
} > "${EVIDENCE_DIR}/ssrf-fixed-allowlist-valid-host.txt" 2>&1

# =============================================================================
# 4. Network Egress Control Evidence
# =============================================================================
echo "===== 4. Network Egress Control Evidence ====="
{
  echo "--- SSRF Network Egress Control Evidence ---"
  echo "Docker-level network egress control is implemented in infra/docker-compose.yml."
  echo "Backend services are attached only to internal:true Docker networks:"
  echo "- user-service, order-service, billing-service, and admin-service are not attached to infra_default or any other non-internal network."
  echo "- Kong remains on infra_default for host/test access and joins per-service internal upstream networks."
  echo "- billing-service no longer shares a direct plaintext network with order-service."
  echo "- Billing-to-Order ownership verification uses order-service with a Billing client certificate."
  echo ""
  echo "Runtime proof is produced by:"
  echo "  bash tests/security/network-egress-control-tests.sh"
  echo ""
  echo "Runtime evidence output:"
  echo "  docs/evidence/tv1/ssrf-egress/network-egress-control-runtime-after-fix.txt"
  echo ""
  echo "Application-layer SSRF URL validation remains separate evidence:"
  echo "  docs/evidence/tv1/ssrf-egress/ssrf-fixed-block-metadata-ip.txt"
} > "${EVIDENCE_DIR}/network-egress-control-evidence.txt" 2>&1

echo "SSRF Tests completed. Check ${EVIDENCE_DIR}"
