#!/usr/bin/env bash
# demo/auth/revoke-token.sh
#
# Safely call the Keycloak token revocation endpoint without printing secrets.

set -euo pipefail

KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-${KEYCLOAK_URL:-https://localhost:8446}}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-topic10-sme-api}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYCLOAK_CACERT="${KEYCLOAK_CACERT:-${PROJECT_ROOT}/infra/certs/gateway-backend/ca.crt}"
CURL_TLS_ARGS=()
if [ -s "${KEYCLOAK_CACERT}" ]; then
  CURL_TLS_ARGS=(--cacert "${KEYCLOAK_CACERT}")
fi

CLIENT_ID="${REVOCATION_CLIENT_ID:-${SERVICE_CLIENT_ID:-${BILLING_SERVICE_CLIENT_ID:-billing-service-client}}}"
CLIENT_SECRET="${REVOCATION_CLIENT_SECRET:-${SERVICE_CLIENT_SECRET:-${BILLING_SERVICE_CLIENT_SECRET:-}}}"
TOKEN_FILE="${TOKEN_FILE:-${ACCESS_TOKEN_FILE:-/tmp/service-token.txt}}"
TOKEN_TYPE_HINT="${TOKEN_TYPE_HINT:-access_token}"

if [ -n "${1:-}" ]; then
  TOKEN_FILE="$1"
fi

if [ -z "${CLIENT_SECRET}" ]; then
  echo "ERROR: REVOCATION_CLIENT_SECRET or SERVICE_CLIENT_SECRET is required." >&2
  echo "Set it from Keycloak/Vault; the script will not print it." >&2
  exit 1
fi

case "${TOKEN_FILE}" in
  /tmp/*) ;;
  *)
    echo "ERROR: TOKEN_FILE must be under /tmp." >&2
    exit 1
    ;;
esac

if [ ! -s "${TOKEN_FILE}" ]; then
  echo "ERROR: token file does not exist or is empty: ${TOKEN_FILE}" >&2
  exit 1
fi

canonical_host() {
  python3 - "${KEYCLOAK_ISSUER:-}" <<'PY'
import sys
from urllib.parse import urlparse

try:
    print(urlparse(sys.argv[1]).netloc if sys.argv[1] else "")
except Exception:
    print("")
PY
}

REVOKE_URL="${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/revoke"
RESPONSE_FILE="$(mktemp /tmp/keycloak-revocation-response.XXXXXX)"
CANONICAL_HOST="$(canonical_host)"
HOST_HEADER=()
trap 'rm -f "${RESPONSE_FILE}"' EXIT

if [ -n "${CANONICAL_HOST}" ]; then
  HOST_HEADER=(-H "Host: ${CANONICAL_HOST}")
fi

CURL_EXIT=0
HTTP_STATUS="$(curl "${CURL_TLS_ARGS[@]}" -sS -o "${RESPONSE_FILE}" -w "%{http_code}" -X POST "${REVOKE_URL}" \
  "${HOST_HEADER[@]}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "token@${TOKEN_FILE}" \
  --data-urlencode "token_type_hint=${TOKEN_TYPE_HINT}" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}")" || CURL_EXIT=$?

case "${HTTP_STATUS}" in
  200|204) ;;
  *)
    echo "ERROR: token revocation request failed (HTTP ${HTTP_STATUS}, curl_exit=${CURL_EXIT})." >&2
    echo "Sanitized response body:" >&2
    python3 - "${RESPONSE_FILE}" >&2 <<'PY'
import json
import sys

body = open(sys.argv[1], encoding="utf-8", errors="replace").read()
try:
    data = json.loads(body) if body.strip() else {}
    for key in ("access_token", "refresh_token", "id_token", "token", "client_secret", "password"):
        if key in data:
            data[key] = "<redacted>"
    print(json.dumps(data, ensure_ascii=False))
except json.JSONDecodeError:
    print(body[:1000])
PY
    exit 1
    ;;
esac

if [ "${CURL_EXIT}" -ne 0 ]; then
  echo "ERROR: token revocation curl failed (HTTP ${HTTP_STATUS}, curl_exit=${CURL_EXIT})." >&2
  exit 1
fi

echo "revocation_request_sent=true"
echo "client_id=${CLIENT_ID}"
echo "token_type_hint=${TOKEN_TYPE_HINT}"
echo "http_status=${HTTP_STATUS}"
