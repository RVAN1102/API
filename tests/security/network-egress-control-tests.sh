#!/usr/bin/env bash
# Runtime Docker network egress control checks for SSRF defense.
#
# This test expects the Docker Compose stack to already be running. It does not
# start services; it verifies the live container/network state and writes
# runtime evidence for the P0 SSRF egress-control fix.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/infra/docker-compose.yml"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv1/ssrf-egress"
EVIDENCE_FILE="${EVIDENCE_DIR}/network-egress-control-runtime-after-fix.txt"

if [ -f "${REPO_ROOT}/infra/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/infra/.env"
  set +a
fi

mkdir -p "${EVIDENCE_DIR}"
exec > >(tee "${EVIDENCE_FILE}") 2>&1

TOTAL=0
PASSED=0
FAILED=0

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

pass() {
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
  echo "[PASS] $*"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  echo "[FAIL] $*"
}

container_id() {
  compose ps -q "$1"
}

network_names() {
  docker inspect -f '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$1"
}

network_internal() {
  docker network inspect -f '{{.Internal}}' "$1"
}

assert_service_running() {
  local service="$1"
  local cid
  cid="$(container_id "${service}")"
  if [ -z "${cid}" ]; then
    fail "${service} has no running Compose container"
    return
  fi

  if [ "$(docker inspect -f '{{.State.Running}}' "${cid}")" = "true" ]; then
    pass "${service} container is running (${cid})"
  else
    fail "${service} container is not running (${cid})"
  fi
}

assert_only_internal_networks() {
  local service="$1"
  local cid="$2"
  local found=0
  local net

  for net in $(network_names "${cid}"); do
    found=1
    if [ "$(network_internal "${net}")" = "true" ]; then
      pass "${service} network ${net} is internal=true"
    else
      fail "${service} network ${net} is not internal; backend would inherit unrestricted egress"
    fi
  done

  if [ "${found}" -eq 0 ]; then
    fail "${service} has no Docker networks"
  fi
}

assert_billing_order_s2s_network() {
  local billing_cid="$1"
  local order_cid="$2"
  local shared=""
  local count=0
  local billing_net
  local order_net

  for billing_net in $(network_names "${billing_cid}"); do
    for order_net in $(network_names "${order_cid}"); do
      if [ "${billing_net}" = "${order_net}" ]; then
        shared="${billing_net}"
        count=$((count + 1))
      fi
    done
  done

  if [ "${count}" -eq 1 ] && [[ "${shared}" == *"billing-order-s2s-internal" ]]; then
    pass "billing-service and order-service share only approved S2S network: ${shared}"
  else
    fail "billing-service/order-service shared networks are not limited to billing-order-s2s-internal (count=${count}, last=${shared:-none})"
  fi

  if [ -n "${shared}" ] && [ "$(network_internal "${shared}")" = "true" ]; then
    pass "approved Billing-to-Order S2S network is internal=true"
  else
    fail "approved Billing-to-Order S2S network is missing or not internal"
  fi
}

probe_blocked_url() {
  local service="$1"
  local url="$2"
  local label="$3"
  local output
  local code

  set +e
  output="$(compose exec -T "${service}" python - "${url}" <<'PY'
import json
import ssl
import sys
import urllib.request

url = sys.argv[1]
try:
    context = ssl._create_unverified_context()
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "network-egress-control-runtime-test"},
    )
    with urllib.request.urlopen(request, timeout=3, context=context) as response:
        sample = response.read(80).decode("utf-8", "replace")
        print(json.dumps({
            "reachable": True,
            "status": getattr(response, "status", None),
            "sample": sample,
        }))
        sys.exit(0)
except Exception as exc:
    print(json.dumps({
        "reachable": False,
        "error_type": exc.__class__.__name__,
        "error": str(exc)[:300],
    }))
    sys.exit(10)
PY
)"
  code=$?
  set -e

  echo "${label} probe result: ${output}"
  if [ "${code}" -eq 10 ]; then
    pass "${service} cannot directly reach ${label}"
  else
    fail "${service} unexpectedly reached ${label}"
  fi
}

probe_billing_to_order() {
  local output
  local code

  set +e
  output="$(compose exec -T billing-service python - <<'PY'
import json
import sys
import urllib.request

url = "http://order-service:8000/api/v1/orders/health"
try:
    with urllib.request.urlopen(url, timeout=3) as response:
        body = response.read(120).decode("utf-8", "replace")
        status = getattr(response, "status", None)
        print(json.dumps({"reachable": True, "status": status, "body": body}))
        sys.exit(0 if status == 200 else 20)
except Exception as exc:
    print(json.dumps({
        "reachable": False,
        "error_type": exc.__class__.__name__,
        "error": str(exc)[:300],
    }))
    sys.exit(21)
PY
)"
  code=$?
  set -e

  echo "billing-service -> order-service probe result: ${output}"
  if [ "${code}" -eq 0 ]; then
    pass "billing-service can reach order-service over the approved internal S2S path"
  else
    fail "billing-service cannot reach order-service over the approved internal S2S path"
  fi
}

echo "============================================================"
echo "Docker Network Egress Control Runtime Evidence"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Compose file: ${COMPOSE_FILE}"
echo "Evidence file: ${EVIDENCE_FILE}"
echo "============================================================"
echo ""

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker is required"
  exit 1
fi

for service in kong user-service order-service billing-service admin-service keycloak opa; do
  assert_service_running "${service}"
done

ADMIN_CID="$(container_id admin-service)"
USER_CID="$(container_id user-service)"
ORDER_CID="$(container_id order-service)"
BILLING_CID="$(container_id billing-service)"

echo ""
echo "===== Backend network isolation ====="
assert_only_internal_networks "user-service" "${USER_CID}"
assert_only_internal_networks "order-service" "${ORDER_CID}"
assert_only_internal_networks "billing-service" "${BILLING_CID}"
assert_only_internal_networks "admin-service" "${ADMIN_CID}"
assert_billing_order_s2s_network "${BILLING_CID}" "${ORDER_CID}"

echo ""
echo "===== Direct egress probes from admin-service ====="
probe_blocked_url "admin-service" "http://169.254.169.254/latest/meta-data/" "cloud metadata 169.254.169.254"
probe_blocked_url "admin-service" "https://example.com" "public Internet https://example.com"

echo ""
echo "===== Approved internal service-to-service probe ====="
probe_billing_to_order

echo ""
echo "============================================================"
echo "Summary: ${PASSED}/${TOTAL} assertions passed, ${FAILED} failed"
echo "============================================================"

if [ "${FAILED}" -gt 0 ]; then
  exit 1
fi
