#!/usr/bin/env bash
# Initialize, unseal, and seed the HTTPS Vault lab runtime without printing secrets.

set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VAULT_ADDR="${VAULT_ADDR:-https://localhost:8200}"
VAULT_CA_CERT="${VAULT_CACERT:-${REPO_ROOT}/infra/certs/gateway-backend/ca.crt}"
VAULT_INIT_FILE="${VAULT_INIT_FILE:-${REPO_ROOT}/infra/.vault-init.json}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"
TMP_DIR="$(mktemp -d /tmp/topic10-vault-ready.XXXXXX)"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

new_tmp() {
  local path
  path="$(mktemp "${TMP_DIR}/file.XXXXXX")"
  chmod 0600 "${path}"
  printf '%s\n' "${path}"
}

vault_curl() {
  command curl --silent --show-error --cacert "${VAULT_CA_CERT}" "$@"
}

json_bool() {
  local file="$1" key="$2"
  python3 - "${file}" "${key}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
print("true" if data.get(sys.argv[2]) is True else "false")
PY
}

init_value() {
  local key="$1"
  python3 - "${VAULT_INIT_FILE}" "${key}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
key = sys.argv[2]
if key == "unseal":
    values = data.get("keys_base64") or data.get("keys") or []
    print(values[0] if values else "")
else:
    print(data.get("root_token", ""))
PY
}

command -v curl >/dev/null 2>&1 || die "curl is required."
command -v openssl >/dev/null 2>&1 || die "openssl is required."
command -v python3 >/dev/null 2>&1 || die "python3 is required."
[ -s "${VAULT_CA_CERT}" ] || die "Vault CA certificate not found: ${VAULT_CA_CERT}. Run demo/mtls/ensure-gateway-backend-certs.sh first."

if [ -z "${WEBHOOK_SECRET}" ] && [ -f "${REPO_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/infra/.env"
  set +a
  WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"
fi

init_status_file="$(new_tmp)"
init_status="$(
  vault_curl \
    --output "${init_status_file}" \
    --write-out '%{http_code}' \
    "${VAULT_ADDR%/}/v1/sys/init" || true
)"
[ "${init_status}" = "200" ] || die "Cannot reach Vault initialization endpoint over HTTPS at ${VAULT_ADDR} (HTTP ${init_status:-000})."

if [ "$(json_bool "${init_status_file}" initialized)" = "false" ]; then
  init_response="$(new_tmp)"
  init_http="$(
    vault_curl \
      --request POST \
      --header 'Content-Type: application/json' \
      --data '{"secret_shares":1,"secret_threshold":1}' \
      --output "${init_response}" \
      --write-out '%{http_code}' \
      "${VAULT_ADDR%/}/v1/sys/init" || true
  )"
  [ "${init_http}" = "200" ] || die "Vault initialization failed (HTTP ${init_http:-000})."
  python3 - "${init_response}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if not data.get("root_token") or not (data.get("keys_base64") or data.get("keys")):
    raise SystemExit("Vault init response did not contain required init material")
PY
  mkdir -p "$(dirname "${VAULT_INIT_FILE}")"
  cp "${init_response}" "${VAULT_INIT_FILE}"
  chmod 0600 "${VAULT_INIT_FILE}"
  echo "[OK] Vault initialized; init material stored in ignored local file infra/.vault-init.json."
else
  echo "[OK] Vault is already initialized."
fi

VAULT_UNSEAL_KEY="${VAULT_UNSEAL_KEY:-}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
if [ -s "${VAULT_INIT_FILE}" ]; then
  VAULT_UNSEAL_KEY="${VAULT_UNSEAL_KEY:-$(init_value unseal)}"
  VAULT_TOKEN="${VAULT_TOKEN:-$(init_value token)}"
fi

health_file="$(new_tmp)"
health_http="$(
  vault_curl \
    --output "${health_file}" \
    --write-out '%{http_code}' \
    "${VAULT_ADDR%/}/v1/sys/health" || true
)"
sealed="$(json_bool "${health_file}" sealed)"
if [ "${sealed}" = "true" ]; then
  [ -n "${VAULT_UNSEAL_KEY}" ] || die "Vault is sealed and no unseal key is available from VAULT_UNSEAL_KEY or ${VAULT_INIT_FILE}."
  unseal_payload="$(new_tmp)"
  UNSEAL_KEY="${VAULT_UNSEAL_KEY}" python3 - "${unseal_payload}" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"key": os.environ["UNSEAL_KEY"]}, f)
PY
  unseal_http="$(
    vault_curl \
      --request POST \
      --header 'Content-Type: application/json' \
      --data-binary "@${unseal_payload}" \
      --output /dev/null \
      --write-out '%{http_code}' \
      "${VAULT_ADDR%/}/v1/sys/unseal" || true
  )"
  [ "${unseal_http}" = "200" ] || die "Vault unseal failed (HTTP ${unseal_http:-000})."
  echo "[OK] Vault unsealed."
elif [ "${health_http}" = "200" ]; then
  echo "[OK] Vault is already unsealed."
else
  die "Vault health response was not ready (HTTP ${health_http:-000})."
fi

[ -n "${VAULT_TOKEN}" ] || die "No Vault token is available from VAULT_TOKEN or ${VAULT_INIT_FILE}."

mounts_file="$(new_tmp)"
mount_http="$(
  vault_curl \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --output "${mounts_file}" \
    --write-out '%{http_code}' \
    "${VAULT_ADDR%/}/v1/sys/mounts" || true
)"
[ "${mount_http}" = "200" ] || die "Could not inspect Vault mounts (HTTP ${mount_http:-000})."
secret_mount_exists="$(
  python3 - "${mounts_file}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
print("true" if "secret/" in data else "false")
PY
)"
if [ "${secret_mount_exists}" = "false" ]; then
  mount_http="$(
    vault_curl \
      --request POST \
      --header "X-Vault-Token: ${VAULT_TOKEN}" \
      --header 'Content-Type: application/json' \
      --data '{"type":"kv","options":{"version":"2"}}' \
      --output /dev/null \
      --write-out '%{http_code}' \
      "${VAULT_ADDR%/}/v1/sys/mounts/secret" || true
  )"
  [ "${mount_http}" = "204" ] || die "Could not enable the required KV v2 mount (HTTP ${mount_http:-000})."
fi

if [ -z "${WEBHOOK_SECRET}" ] || [[ "${WEBHOOK_SECRET}" == REPLACE_WITH_* ]]; then
  WEBHOOK_SECRET="$(openssl rand -hex 32)"
fi
secret_payload="$(new_tmp)"
WEBHOOK_SECRET_VALUE="${WEBHOOK_SECRET}" python3 - "${secret_payload}" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump({"data": {"webhook_secret": os.environ["WEBHOOK_SECRET_VALUE"]}}, f)
PY
seed_http="$(
  vault_curl \
    --request POST \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header 'Content-Type: application/json' \
    --data-binary "@${secret_payload}" \
    --output /dev/null \
    --write-out '%{http_code}' \
    "${VAULT_ADDR%/}/v1/secret/data/api/webhook" || true
)"
[ "${seed_http}" = "200" ] || die "Could not seed the required lab webhook secret (HTTP ${seed_http:-000})."

echo "[OK] Required Vault lab secret path is ready over HTTPS."
