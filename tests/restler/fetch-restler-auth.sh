#!/bin/sh
# Fetch a Keycloak access token for RESTler without printing credentials.

set -eu

KEYCLOAK_BASE_URL="${RESTLER_KEYCLOAK_BASE_URL:-${KEYCLOAK_BASE_URL:-https://localhost:8446}}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-topic10-sme-api}"
RESTLER_AUTH_CLIENT_ID="${RESTLER_AUTH_CLIENT_ID:-sme-lab-automation-client}"
RESTLER_AUTH_USERNAME="${RESTLER_AUTH_USERNAME:-ci-alice}"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

[ -n "${RESTLER_AUTH_PASSWORD:-}" ] || die "RESTLER_AUTH_PASSWORD is required."

ACCESS_TOKEN="$(
  KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL}" \
  KEYCLOAK_REALM="${KEYCLOAK_REALM}" \
  RESTLER_AUTH_CLIENT_ID="${RESTLER_AUTH_CLIENT_ID}" \
  RESTLER_AUTH_USERNAME="${RESTLER_AUTH_USERNAME}" \
  RESTLER_AUTH_PASSWORD="${RESTLER_AUTH_PASSWORD}" \
  python3 <<'PY'
import json
import os
import sys
import urllib.parse
import urllib.request

base_url = os.environ.get("KEYCLOAK_BASE_URL", "https://localhost:8446").rstrip("/")
realm = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
client_id = os.environ.get("RESTLER_AUTH_CLIENT_ID", "sme-lab-automation-client")
username = os.environ.get("RESTLER_AUTH_USERNAME", "ci-alice")
password = os.environ.get("RESTLER_AUTH_PASSWORD", "")

if not password:
    raise SystemExit(2)

token_url = f"{base_url}/realms/{realm}/protocol/openid-connect/token"
body = urllib.parse.urlencode(
    {
        "grant_type": "password",
        "client_id": client_id,
        "username": username,
        "password": password,
    }
).encode("utf-8")

request = urllib.request.Request(
    token_url,
    data=body,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
)

try:
    with urllib.request.urlopen(request, timeout=15) as response:
        payload = json.loads(response.read().decode("utf-8"))
except Exception:
    raise SystemExit(3)

token = payload.get("access_token")
if not isinstance(token, str) or not token:
    raise SystemExit(4)

print(token)
PY
)" || die "Keycloak token request failed."

[ -n "${ACCESS_TOKEN}" ] || die "Keycloak response did not contain an access token."

printf "{u'app1': {}}\n"
printf 'Authorization: Bearer %s\n' "${ACCESS_TOKEN}"
