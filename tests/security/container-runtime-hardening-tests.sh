#!/usr/bin/env bash
# Verify production-oriented container runtime hardening in docker-compose.yml.
#
# This test is static by default: it renders Docker Compose config and checks
# intended settings without writing tracked evidence files.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/infra/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT}/infra/.env"
BOOTSTRAP_SCRIPT="${PROJECT_ROOT}/scripts/bootstrap-lab-env.sh"
CONFIG_FILE="$(mktemp /tmp/topic10-compose-config.XXXXXX.yml)"

cleanup() {
  rm -f "${CONFIG_FILE}"
}
trap cleanup EXIT

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "[ERROR] Missing compose file: ${COMPOSE_FILE}" >&2
  exit 1
fi

if [ ! -f "${ENV_FILE}" ] && [ -f "${BOOTSTRAP_SCRIPT}" ]; then
  bash "${BOOTSTRAP_SCRIPT}" >/dev/null
fi

if [ -f "${ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

docker compose -f "${COMPOSE_FILE}" config > "${CONFIG_FILE}"

python3 - "${CONFIG_FILE}" <<'PY'
import sys

import yaml

config_path = sys.argv[1]
with open(config_path, encoding="utf-8") as handle:
    config = yaml.safe_load(handle)

services = config.get("services", {})

readonly_services = {
    "opa",
    "user-service",
    "order-service",
    "billing-service",
    "admin-service",
    "webhook-demo",
    "otel-collector",
}

no_new_privileges_only_services = {
    "user-mtls-proxy",
    "order-mtls-proxy",
    "billing-mtls-proxy",
    "admin-mtls-proxy",
}

cap_drop_services = readonly_services

intentionally_not_readonly = {
    "kong": "Kong writes runtime prefix files and nginx state.",
    "keycloak": "Keycloak dev mode imports realm data into a writable runtime directory.",
    "vault": "Vault dev server and IPC_LOCK behavior require runtime write/lock support.",
    "redis": "Redis is the runtime nonce TTL store.",
    "loki": "Loki writes log index/chunk data to its volume.",
    "grafana": "Grafana writes dashboard/database state to its volume.",
    "promtail": "Promtail tails Docker logs and may persist positions in real deployments.",
    "alertmanager": "Alertmanager uses a writable storage path.",
    "jaeger": "Jaeger all-in-one keeps runtime telemetry state.",
    "user-mtls-proxy": "Nginx entrypoint renders config and needs startup filesystem ownership changes.",
    "order-mtls-proxy": "Nginx entrypoint renders config and needs startup filesystem ownership changes.",
    "billing-mtls-proxy": "Nginx entrypoint renders config and needs startup filesystem ownership changes.",
    "admin-mtls-proxy": "Nginx entrypoint renders config and needs startup filesystem ownership changes.",
}

failures = []

def has_no_new_privileges(service):
    values = service.get("security_opt") or []
    return any(str(value).startswith("no-new-privileges") for value in values)

for name in sorted(readonly_services | no_new_privileges_only_services):
    service = services.get(name)
    if not service:
        failures.append(f"{name}: service missing from compose config")
        continue
    if not has_no_new_privileges(service):
        failures.append(f"{name}: missing security_opt no-new-privileges")

for name in sorted(cap_drop_services):
    service = services.get(name)
    if not service:
        continue
    if "ALL" not in [str(value) for value in service.get("cap_drop") or []]:
        failures.append(f"{name}: missing cap_drop ALL")

for name in sorted(readonly_services):
    service = services.get(name, {})
    if service.get("read_only") is not True:
        failures.append(f"{name}: missing read_only: true")
    if "/tmp" not in [str(value) for value in service.get("tmpfs") or []]:
        failures.append(f"{name}: missing tmpfs /tmp")

for name, reason in sorted(intentionally_not_readonly.items()):
    service = services.get(name)
    if service and service.get("read_only") is True:
        failures.append(f"{name}: unexpectedly read_only despite documented reason: {reason}")

if failures:
    print("CONTAINER RUNTIME HARDENING RESULT: failed")
    for failure in failures:
        print(f"[FAIL] {failure}")
    raise SystemExit(1)

print("CONTAINER RUNTIME HARDENING RESULT: passed")
for name in sorted(readonly_services):
    print(f"[PASS] {name}: no-new-privileges, cap_drop ALL, read_only, tmpfs /tmp")
for name in sorted(no_new_privileges_only_services):
    print(f"[PASS] {name}: no-new-privileges")
print("[INFO] Intentionally not read-only:")
for name, reason in sorted(intentionally_not_readonly.items()):
    if name in services:
        print(f"  - {name}: {reason}")
PY
