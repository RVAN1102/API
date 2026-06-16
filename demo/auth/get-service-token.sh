#!/usr/bin/env bash
# demo/auth/get-service-token.sh
#
# Obtain a service-account access token using OAuth2 Client Credentials.
# The raw token is written to /tmp/service-token.txt; stdout prints metadata only.

set -euo pipefail

KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-${KEYCLOAK_URL:-http://localhost:8080}}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-topic10-sme-api}"
CLIENT_ID="${SERVICE_CLIENT_ID:-sme-service-client}"
CLIENT_SECRET="${SERVICE_CLIENT_SECRET:-}"
TOKEN_FILE="${SERVICE_TOKEN_FILE:-/tmp/service-token.txt}"

if [ -z "${CLIENT_SECRET}" ]; then
  echo "ERROR: SERVICE_CLIENT_SECRET is required." >&2
  echo "Set SERVICE_CLIENT_SECRET from Keycloak/Vault; the script will not print it." >&2
  exit 1
fi

TOKEN_URL="${KEYCLOAK_BASE_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token"
RESPONSE_FILE="$(mktemp /tmp/keycloak-service-token-response.XXXXXX)"
trap 'rm -f "${RESPONSE_FILE}"' EXIT

rm -f "${TOKEN_FILE}"

CURL_EXIT=0
HTTP_STATUS="$(curl -sS -o "${RESPONSE_FILE}" -w "%{http_code}" -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}")" || CURL_EXIT=$?

if [ "${CURL_EXIT}" -ne 0 ] || [ "${HTTP_STATUS}" != "200" ]; then
  echo "ERROR: service token request failed (HTTP ${HTTP_STATUS}, curl_exit=${CURL_EXIT})." >&2
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

ACCESS_TOKEN="$(python3 - "${RESPONSE_FILE}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
token = data.get("access_token")
if not token:
    raise SystemExit("missing access_token in response")
print(token)
PY
)"

umask 077
printf '%s' "${ACCESS_TOKEN}" > "${TOKEN_FILE}"

python3 - "${TOKEN_FILE}" "${CLIENT_ID}" <<'PY'
import base64
import json
import sys

token_path, expected_client_id = sys.argv[1], sys.argv[2]
token = open(token_path, encoding="utf-8").read().strip()
parts = token.split(".")
if len(parts) != 3:
    raise SystemExit("service token is not a JWT")

payload_segment = parts[1]
payload_segment += "=" * (-len(payload_segment) % 4)
payload = json.loads(base64.urlsafe_b64decode(payload_segment.encode("ascii")))

iat = int(payload["iat"])
exp = int(payload["exp"])
ttl = exp - iat
token_client_id = payload.get("azp") or payload.get("client_id") or expected_client_id
if token_client_id != expected_client_id:
    raise SystemExit("service token client_id mismatch")

roles = payload.get("realm_access", {}).get("roles", [])
roles = sorted(str(role) for role in roles)
scope = str(payload.get("scope", "")).strip()

print("service_token_obtained=true")
print(f"client_id={token_client_id}")
print(f"token_length={len(token)}")
print(f"token_ttl_seconds={ttl}")
if roles:
    print("roles=" + ",".join(roles))
if scope:
    print("scopes=" + scope)
PY
