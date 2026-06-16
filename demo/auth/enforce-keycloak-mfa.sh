#!/usr/bin/env bash
set -Eeuo pipefail

KC_BASE="${KC_BASE:-http://localhost:8080}"
MASTER_REALM="${MASTER_REALM:-master}"
KC_REALM="${KC_REALM:-topic10-sme-api}"
KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"

if [ "$#" -gt 0 ]; then
  USERS=("$@")
else
  USERS=("alice" "bob" "admin01")
fi

TOKEN_JSON="$(mktemp)"
curl -fsS -X POST "${KC_BASE}/realms/${MASTER_REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN_USER}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" > "$TOKEN_JSON"

ADMIN_TOKEN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["access_token"])' "$TOKEN_JSON")"

for USERNAME in "${USERS[@]}"; do
  USER_JSON="$(mktemp)"
  UPDATED_JSON="$(mktemp)"

  curl -fsS \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KC_BASE}/admin/realms/${KC_REALM}/users?username=${USERNAME}&exact=true" \
    > "$USER_JSON"

  USER_ID="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert len(data)==1, data; print(data[0]["id"])' "$USER_JSON")"

  python3 - "$USER_JSON" > "$UPDATED_JSON" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
user = data[0]

actions = set(user.get("requiredActions") or [])
actions.add("CONFIGURE_TOTP")
user["requiredActions"] = sorted(actions)

print(json.dumps(user, ensure_ascii=False))
PY

  curl -fsS -X PUT \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    --data @"$UPDATED_JSON" \
    "${KC_BASE}/admin/realms/${KC_REALM}/users/${USER_ID}"

  echo "mfa_required_action=CONFIGURE_TOTP username=${USERNAME} user_id=${USER_ID} status=ENFORCED"
done
