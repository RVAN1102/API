#!/usr/bin/env bash
# Contract checks for excessive data exposure on selected API responses.

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/topic10-openapi-contract.XXXXXX)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_cmd curl
require_cmd python3

echo "=============================================="
echo "  OPENAPI / EXCESSIVE DATA CONTRACT TESTS"
echo "  $(date)"
echo "=============================================="
echo ""

echo "===== Prepare ci-alice token ====="
bash "${PROJECT_ROOT}/demo/auth/get-user-token.sh" ci-alice > "${TMP_DIR}/get-user-token.log" 2>&1
CI_ALICE_TOKEN="$(cat /tmp/user-token.txt)"
if [ -z "${CI_ALICE_TOKEN}" ]; then
  fail "ci-alice token helper did not create a token"
fi
pass "ci-alice automation token obtained"

request_json() {
  local name="$1"
  local url="$2"
  local output="$3"
  local expected_status="$4"
  local status

  status="$(curl -sS -o "${output}" -w "%{http_code}" \
    "${url}" \
    -H "Authorization: Bearer ${CI_ALICE_TOKEN}" \
    -H "X-Correlation-ID: openapi-contract-${name}")"

  if [ "${status}" != "${expected_status}" ]; then
    echo "--- response body for ${name} ---"
    cat "${output}" || true
    fail "${name} expected HTTP ${expected_status}, got ${status}"
  fi
  pass "${name} returned HTTP ${expected_status}"
}

assert_contract() {
  local name="$1"
  local file="$2"
  shift 2

  python3 - "${name}" "${file}" "$@" <<'PY'
import json
import re
import sys

name = sys.argv[1]
path = sys.argv[2]
allowed_keys = set(sys.argv[3:])

with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

if not isinstance(data, dict):
    raise SystemExit(f"{name}: response is not a JSON object")

actual_keys = set(data)
extra = sorted(actual_keys - allowed_keys)
missing = sorted(allowed_keys - actual_keys)
if extra:
    raise SystemExit(f"{name}: unexpected keys exposed: {', '.join(extra)}")
if missing:
    raise SystemExit(f"{name}: expected keys missing: {', '.join(missing)}")

forbidden_key_patterns = [
    "_".join(["access", "token"]),
    "_".join(["refresh", "token"]),
    "_".join(["id", "token"]),
    "_".join(["client", "secret"]),
    "secret",
    "password",
    "private_key",
    "raw_jwt",
    "jwt",
    "debug",
    "config",
    "owner_map",
    "internal_owner",
    "authorization",
    "_".join(["vault", "token"]),
    "_".join(["webhook", "secret"]),
]

forbidden_value_patterns = [
    re.compile(r"eyJ[A-Za-z0-9_-]{10,}"),
    re.compile("PRIVATE" + " KEY"),
    re.compile("BEGIN" + " CERTIFICATE"),
    re.compile("_".join(["access", "token"]), re.IGNORECASE),
    re.compile("_".join(["refresh", "token"]), re.IGNORECASE),
    re.compile("_".join(["client", "secret"]), re.IGNORECASE),
    re.compile("_".join(["webhook", "secret"]), re.IGNORECASE),
]

violations = []

def walk(value, location="$"):
    if isinstance(value, dict):
        for key, child in value.items():
            lowered = key.lower()
            for pattern in forbidden_key_patterns:
                if pattern in lowered:
                    violations.append(f"{location}.{key}: forbidden key pattern {pattern}")
            walk(child, f"{location}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, f"{location}[{index}]")
    elif isinstance(value, str):
        for pattern in forbidden_value_patterns:
            if pattern.search(value):
                violations.append(f"{location}: forbidden sensitive-looking value")

walk(data)

if violations:
    raise SystemExit(f"{name}: " + "; ".join(violations))

print(f"[PASS] {name} exposes only expected contract fields and no sensitive patterns")
PY
}

USERS_ME_BODY="${TMP_DIR}/users-me.json"
ORDER_BODY="${TMP_DIR}/order-detail.json"

request_json "users-me" "${BASE_URL}/api/v1/users/me" "${USERS_ME_BODY}" "200"
assert_contract "users-me" "${USERS_ME_BODY}" \
  user_id username email roles correlation_id

request_json "order-detail" "${BASE_URL}/api/v1/orders/ord-alice-1001/fixed" "${ORDER_BODY}" "200"
assert_contract "order-detail" "${ORDER_BODY}" \
  order_id owner_id amount status currency note correlation_id

echo ""
echo "[OK] OpenAPI/excessive-data contract tests passed"
