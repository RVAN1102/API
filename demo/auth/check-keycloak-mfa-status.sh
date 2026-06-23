#!/usr/bin/env bash
set -Eeuo pipefail

KC_BASE="${KC_BASE:-https://localhost:8446}"
MASTER_REALM="${MASTER_REALM:-master}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYCLOAK_CACERT="${KEYCLOAK_CACERT:-${PROJECT_ROOT}/infra/certs/gateway-backend/ca.crt}"
CURL_TLS_ARGS=()
if [ -s "${KEYCLOAK_CACERT}" ]; then
  CURL_TLS_ARGS=(--cacert "${KEYCLOAK_CACERT}")
fi

KC_REALM="${KC_REALM:-topic10-sme-api}"
KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"

if [ "$#" -gt 0 ]; then
  USERS=("$@")
else
  USERS=("alice" "bob" "admin01")
fi

TOKEN_JSON="$(mktemp)"
curl "${CURL_TLS_ARGS[@]}" -fsS -X POST "${KC_BASE}/realms/${MASTER_REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN_USER}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" > "$TOKEN_JSON"

ADMIN_TOKEN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["access_token"])' "$TOKEN_JSON")"

for USERNAME in "${USERS[@]}"; do
  USER_JSON="$(mktemp)"

  curl "${CURL_TLS_ARGS[@]}" -fsS \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KC_BASE}/admin/realms/${KC_REALM}/users?username=${USERNAME}&exact=true" \
    > "$USER_JSON"

  python3 - "$USERNAME" "$USER_JSON" <<'PY'
import json
import sys

username = sys.argv[1]
path = sys.argv[2]

data = json.load(open(path, encoding="utf-8"))
if len(data) != 1:
    print(f"username={username} status=ERROR count={len(data)}")
    raise SystemExit(1)

u = data[0]
actions = u.get("requiredActions") or []
enabled = "CONFIGURE_TOTP" in actions
print(f"username={username} requiredActions={actions} mfa_runtime_required={enabled}")
PY
done
