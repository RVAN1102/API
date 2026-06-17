#!/usr/bin/env bash
# demo/auth/introspect-token.sh
#
# Safely introspect a token with Keycloak and print metadata only.

set -euo pipefail

KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-${KEYCLOAK_URL:-http://localhost:8080}}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-topic10-sme-api}"
CLIENT_ID="${INTROSPECTION_CLIENT_ID:-${SERVICE_CLIENT_ID:-${BILLING_SERVICE_CLIENT_ID:-billing-service-client}}}"
CLIENT_SECRET="${INTROSPECTION_CLIENT_SECRET:-${SERVICE_CLIENT_SECRET:-${BILLING_SERVICE_CLIENT_SECRET:-}}}"
TOKEN_FILE="${TOKEN_FILE:-${ACCESS_TOKEN_FILE:-/tmp/service-token.txt}}"

if [ -n "${1:-}" ]; then
  TOKEN_FILE="$1"
fi

if [ -z "${CLIENT_SECRET}" ]; then
  echo "ERROR: INTROSPECTION_CLIENT_SECRET or SERVICE_CLIENT_SECRET is required." >&2
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

INTROSPECT_URL="${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token/introspect"
RESPONSE_FILE="$(mktemp /tmp/keycloak-introspection-response.XXXXXX)"
CANONICAL_HOST="$(canonical_host)"
HOST_HEADER=()
trap 'rm -f "${RESPONSE_FILE}"' EXIT

if [ -n "${CANONICAL_HOST}" ]; then
  HOST_HEADER=(-H "Host: ${CANONICAL_HOST}")
fi

CURL_EXIT=0
HTTP_STATUS="$(curl -sS -o "${RESPONSE_FILE}" -w "%{http_code}" -X POST "${INTROSPECT_URL}" \
  "${HOST_HEADER[@]}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "token@${TOKEN_FILE}" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}")" || CURL_EXIT=$?

if [ "${CURL_EXIT}" -ne 0 ] || [ "${HTTP_STATUS}" != "200" ]; then
  echo "ERROR: token introspection request failed (HTTP ${HTTP_STATUS}, curl_exit=${CURL_EXIT})." >&2
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
fi

python3 - "${RESPONSE_FILE}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))

print("introspection_obtained=true")
active = data.get("active")
if isinstance(active, bool):
    print(f"active={str(active).lower()}")

client_id = data.get("client_id") or data.get("azp")
if client_id:
    print(f"client_id={client_id}")

for key in ("username", "token_type", "iat", "exp", "scope"):
    value = data.get(key)
    if value is not None and value != "":
        print(f"{key}={value}")

roles = data.get("realm_access", {}).get("roles", [])
if roles:
    print("roles=" + ",".join(sorted(str(role) for role in roles)))
PY
