#!/usr/bin/env bash
# demo/auth/get-user-token.sh
#
# Get an access token for a test user using Keycloak Direct Grant (password flow).
# This is for DEMO/DEV purposes only.
#
# Usage:
#   bash demo/auth/get-user-token.sh [alice|bob|admin01|ci-alice|ci-bob]
#
# Environment variables:
#   KEYCLOAK_URL   – default: http://localhost:8080
#   USERNAME       – default: alice
#   PASSWORD       – default: mapped demo/dev password

set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="topic10-sme-api"
CLIENT_ID="sme-lab-automation-client"
USERNAME="${1:-${USERNAME:-alice}}"
TOKEN_FILE="/tmp/user-token.txt"

rm -f "${TOKEN_FILE}"

# Map username to password (dev only)
case "${USERNAME}" in
  alice)    PASSWORD="${PASSWORD:-alice-password-123}" ;;
  bob)      PASSWORD="${PASSWORD:-bob-password-123}" ;;
  admin01)  PASSWORD="${PASSWORD:-admin-password-123}" ;;
  ci-alice) PASSWORD="${PASSWORD:-ci-alice-password-123}" ;;
  ci-bob)   PASSWORD="${PASSWORD:-ci-bob-password-123}" ;;
  *)        PASSWORD="${PASSWORD:-}" ;;
esac

if [ -z "${PASSWORD}" ]; then
  echo "ERROR: No password for user '${USERNAME}'. Set PASSWORD env var."
  exit 1
fi

TOKEN_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
RESPONSE_FILE="$(mktemp /tmp/keycloak-token-response.XXXXXX)"
trap 'rm -f "${RESPONSE_FILE}"' EXIT

echo "=== Getting token for user: ${USERNAME} ==="
echo "Token URL: ${TOKEN_URL}"
echo ""

CURL_EXIT=0
HTTP_STATUS="$(curl -sS -o "${RESPONSE_FILE}" -w "%{http_code}" -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "scope=openid profile email")" || CURL_EXIT=$?

if [ "${CURL_EXIT}" -ne 0 ] || [ "${HTTP_STATUS}" != "200" ]; then
  echo "ERROR: Token request failed for user '${USERNAME}' (HTTP ${HTTP_STATUS}, curl_exit=${CURL_EXIT})."
  echo "Sanitized response body:"
  python3 - "${RESPONSE_FILE}" <<'PY'
import json
import sys

path = sys.argv[1]
body = open(path, encoding="utf-8", errors="replace").read()
try:
    data = json.loads(body) if body.strip() else {}
    for key in ("access_token", "refresh_token", "id_token", "token", "password", "client_secret"):
        if key in data:
            data[key] = "<redacted>"
    print(json.dumps(data, ensure_ascii=False))
except json.JSONDecodeError:
    print(body[:1000])
PY
  exit 1
fi

ACCESS_TOKEN=$(python3 -c "import sys,json; print(json.load(open(sys.argv[1]))['access_token'])" "${RESPONSE_FILE}")

echo "Access token (first 60 chars):"
echo "${ACCESS_TOKEN:0:60}..."
echo ""
echo "Full token saved to /tmp/user-token.txt"
echo "${ACCESS_TOKEN}" > "${TOKEN_FILE}"
echo ""
echo "To use in curl:"
echo "  ACCESS_TOKEN=\$(cat /tmp/user-token.txt)"
echo "  curl -k -H \"Authorization: Bearer \${ACCESS_TOKEN}\" https://localhost:8443/api/v1/users/me"
