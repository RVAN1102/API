#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_EXAMPLE="${PROJECT_ROOT}/infra/.env.example"
ENV_FILE="${PROJECT_ROOT}/infra/.env"

REQUIRED_VARS=(
  BILLING_SERVICE_CLIENT_SECRET
  ADMIN_SERVICE_CLIENT_SECRET
  WEBHOOK_SECRET
)

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[ERROR] Missing required command: ${command_name}" >&2
    exit 1
  fi
}

is_placeholder_or_empty() {
  local value="${1:-}"

  value="${value%$'\r'}"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"

  [ -z "${value}" ] || [[ "${value}" == REPLACE_WITH_* ]]
}

read_env_value() {
  local name="$1"

  sed -n "s/^${name}=//p" "${ENV_FILE}" | tail -n 1
}

write_env_value() {
  local name="$1"
  local value="$2"

  if grep -q "^${name}=" "${ENV_FILE}"; then
    sed -i.bak "s|^${name}=.*|${name}=${value}|" "${ENV_FILE}"
    rm -f "${ENV_FILE}.bak"
  else
    {
      printf '\n'
      printf '%s=%s\n' "${name}" "${value}"
    } >> "${ENV_FILE}"
  fi
}

require_command openssl
require_command sed

if [ ! -f "${ENV_EXAMPLE}" ]; then
  echo "[ERROR] Missing infra/.env.example" >&2
  exit 1
fi

for name in "${REQUIRED_VARS[@]}"; do
  if ! grep -q "^${name}=" "${ENV_EXAMPLE}"; then
    echo "[ERROR] infra/.env.example is missing ${name}" >&2
    echo "[ERROR] Add ${name}=REPLACE_WITH_LOCAL_${name} to infra/.env.example and rerun." >&2
    exit 1
  fi
done

umask 077

if [ ! -f "${ENV_FILE}" ]; then
  cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  echo "[INFO] created infra/.env from infra/.env.example"
fi

chmod 600 "${ENV_FILE}" 2>/dev/null || true

for name in "${REQUIRED_VARS[@]}"; do
  current_value="$(read_env_value "${name}")"
  if is_placeholder_or_empty "${current_value}"; then
    generated_value="$(openssl rand -hex 24)"
    write_env_value "${name}" "${generated_value}"
    echo "[INFO] generated ${name}"
  else
    echo "[OK] ${name} present"
  fi
done

echo "[OK] lab environment bootstrap complete"
