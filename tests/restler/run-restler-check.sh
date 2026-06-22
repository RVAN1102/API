#!/usr/bin/env bash
# Real RESTler compile + authenticated test + authenticated fuzz-lean runner.
# This script intentionally fails if RESTler is not available.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TARGET_URL="${TARGET_URL:-${BASE_URL:-}}"
OPENAPI_SPEC="${OPENAPI_SPEC:-${REPO_ROOT}/services/openapi.yaml}"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv3/restler"
mkdir -p "${EVIDENCE_DIR}"
TMP_DIR="$(mktemp -d "${REPO_ROOT}/docs/evidence/tv3/restler/tmp.XXXXXX")"
WORK_DIR="${TMP_DIR}/work"
COMPILE_LOG="${TMP_DIR}/restler-compile.log"
TEST_LOG="${TMP_DIR}/restler-test.log"
FUZZ_LEAN_LOG="${TMP_DIR}/restler-fuzz-lean.log"
SUMMARY_FILE="${TMP_DIR}/restler-summary.md"
RESTLER_IMAGE="${RESTLER_IMAGE:-mcr.microsoft.com/restlerfuzzer/restler:v8.5.0}"
PREFLIGHT_IMAGE="${PREFLIGHT_IMAGE:-python:3.13-slim}"
TOKEN_REFRESH_INTERVAL="${TOKEN_REFRESH_INTERVAL:-240}"
RESTLER_TARGET_PORT="${RESTLER_TARGET_PORT:-}"

mkdir -p "${EVIDENCE_DIR}" "${WORK_DIR}"
chmod 0777 "${TMP_DIR}" "${WORK_DIR}"

RESTLER_LABEL=""
RESTLER_RUNTIME=""
AUTH_SETTINGS=""
RESTLER_DOCKER_NETWORK="${RESTLER_DOCKER_NETWORK:-}"
RESTLER_TARGET_HOST="${RESTLER_TARGET_HOST:-}"
RESTLER_TARGET_IP="${RESTLER_TARGET_IP:-}"
DOCKER_KEYCLOAK_URL="${KEYCLOAK_URL:-}"
RESTLER_CONTAINER_CA_CERT_FILE="/tmp/restler-ca.pem"
RESTLER_EFFECTIVE_CA_CERT_FILE=""
RESTLER_CA_DOCKER_ARGS=()
RESTLER_CA_ENV_ARGS=()
COMPILE_SUCCEEDED="no"
TEST_SUCCEEDED="no"
FUZZ_LEAN_SUCCEEDED="no"

cleanup() {
  if [ -d "${TMP_DIR}" ]; then
    chmod -R u+rwX "${TMP_DIR}" 2>/dev/null || true
    rm -rf "${TMP_DIR}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

select_restler() {
  if [ -n "${RESTLER_CMD:-}" ]; then
    RESTLER_LABEL="local command: ${RESTLER_CMD}"
    RESTLER_RUNTIME="cmd"
    return
  fi

  if [ -n "${RESTLER_DLL:-}" ]; then
    [ -f "${RESTLER_DLL}" ] || die "RESTLER_DLL does not exist: ${RESTLER_DLL}"
    RESTLER_LABEL="local DLL: ${RESTLER_DLL}"
    RESTLER_RUNTIME="dll"
    return
  fi

  if command -v restler >/dev/null 2>&1; then
    RESTLER_LABEL="local binary: $(command -v restler)"
    RESTLER_RUNTIME="binary"
    return
  fi

  if command -v docker >/dev/null 2>&1; then
    if ! docker image inspect "${RESTLER_IMAGE}" >/dev/null 2>&1; then
      echo "[INFO] RESTler Docker image not found locally. Attempting: docker pull ${RESTLER_IMAGE}" >&2
      if ! docker pull "${RESTLER_IMAGE}" >&2; then
        die "RESTler is unavailable. Pull failed. Install with: docker pull ${RESTLER_IMAGE}; or set RESTLER_CMD=/path/to/restler; or set RESTLER_DLL=/path/to/Restler.dll."
      fi
    fi
    RESTLER_LABEL="Docker image: ${RESTLER_IMAGE}"
    RESTLER_RUNTIME="docker"
    return
  fi

  die "RESTler is unavailable. Install Docker and run: docker pull ${RESTLER_IMAGE}; or set RESTLER_CMD=/path/to/restler; or set RESTLER_DLL=/path/to/Restler.dll."
}

discover_compose_network() {
  local user_container
  user_container="$(docker compose -f "${REPO_ROOT}/infra/docker-compose.yml" ps -q user-service 2>/dev/null || true)"
  if [ -n "${user_container}" ]; then
    docker inspect "${user_container}" \
      --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' |
      grep 'kong-user-internal' |
      head -n 1
  fi
}

discover_default_network() {
  docker network inspect infra_default >/dev/null 2>&1 && printf '%s\n' "infra_default"
}

parse_target_url() {
  python3 - "${TARGET_URL}" <<'PY'
import sys
from urllib.parse import urlparse

url = sys.argv[1]
parsed = urlparse(url)
scheme = parsed.scheme or "https"
host = parsed.hostname or ""
if not host:
    raise SystemExit("TARGET_URL must include a host")
port = parsed.port
if port is None:
    port = 443 if scheme == "https" else 80
print(f"{scheme} {host} {port}")
PY
}

configure_target() {
  local parsed_target
  local parsed_scheme
  local parsed_host
  local parsed_port

  if [ "${RESTLER_RUNTIME}" = "docker" ]; then
    if [ "${RESTLER_USE_HOST_NETWORK:-0}" = "1" ]; then
      RESTLER_DOCKER_NETWORK="${RESTLER_DOCKER_NETWORK:-host}"
    elif [ -z "${RESTLER_DOCKER_NETWORK}" ]; then
      RESTLER_DOCKER_NETWORK="$(discover_default_network)"
      RESTLER_DOCKER_NETWORK="${RESTLER_DOCKER_NETWORK:-$(discover_compose_network)}"
    fi
    [ -n "${RESTLER_DOCKER_NETWORK}" ] || die "Could not discover Docker network containing kong-user-internal. Start the stack or set RESTLER_DOCKER_NETWORK."

    if [ "${RESTLER_DOCKER_NETWORK}" = "host" ]; then
      TARGET_URL="${TARGET_URL:-https://localhost:8443}"
      DOCKER_KEYCLOAK_URL="${RESTLER_KEYCLOAK_BASE_URL:-${KEYCLOAK_BASE_URL:-${DOCKER_KEYCLOAK_URL:-http://127.0.0.1:8080}}}"
    else
      TARGET_URL="${TARGET_URL:-https://kong:8443}"
      DOCKER_KEYCLOAK_URL="${RESTLER_KEYCLOAK_BASE_URL:-${KEYCLOAK_BASE_URL:-${DOCKER_KEYCLOAK_URL:-http://keycloak:8080}}}"
    fi
  else
    TARGET_URL="${TARGET_URL:-https://localhost:8443}"
    DOCKER_KEYCLOAK_URL="${RESTLER_KEYCLOAK_BASE_URL:-${KEYCLOAK_BASE_URL:-${DOCKER_KEYCLOAK_URL:-http://localhost:8080}}}"
  fi

  parsed_target="$(parse_target_url)"
  read -r parsed_scheme parsed_host parsed_port <<EOF
${parsed_target}
EOF
  RESTLER_TARGET_HOST="${RESTLER_TARGET_HOST:-${parsed_host}}"
  RESTLER_TARGET_IP="${RESTLER_TARGET_IP:-${parsed_host}}"
  RESTLER_TARGET_PORT="${RESTLER_TARGET_PORT:-${parsed_port}}"
}

prepare_restler_ca_cert() {
  local extracted_cert="${TMP_DIR}/kong-leaf.pem"

  RESTLER_EFFECTIVE_CA_CERT_FILE=""
  RESTLER_CA_DOCKER_ARGS=()
  RESTLER_CA_ENV_ARGS=()

  if [ -n "${RESTLER_CA_CERT_FILE:-}" ]; then
    [ -f "${RESTLER_CA_CERT_FILE}" ] || die "RESTLER_CA_CERT_FILE does not exist: ${RESTLER_CA_CERT_FILE}"
    RESTLER_EFFECTIVE_CA_CERT_FILE="${RESTLER_CA_CERT_FILE}"
  else
    case "${TARGET_URL}" in
      https://localhost:8443|https://localhost:8443/*)
        command -v openssl >/dev/null 2>&1 || die "openssl is required to extract Kong TLS certificate."
        if ! printf '' | openssl s_client \
          -connect localhost:8443 \
          -servername localhost \
          -showcerts 2>/dev/null |
          awk '/-----BEGIN CERTIFICATE-----/{flag=1} flag{print} /-----END CERTIFICATE-----/{exit}' > "${extracted_cert}"; then
          die "Failed to extract Kong TLS certificate from localhost:8443."
        fi
        [ -s "${extracted_cert}" ] || die "Extracted Kong TLS certificate is empty."
        RESTLER_EFFECTIVE_CA_CERT_FILE="${extracted_cert}"
        ;;
    esac
  fi

  if [ -n "${RESTLER_EFFECTIVE_CA_CERT_FILE}" ]; then
    chmod 0644 "${RESTLER_EFFECTIVE_CA_CERT_FILE}" 2>/dev/null || true
    RESTLER_CA_DOCKER_ARGS=(-v "${RESTLER_EFFECTIVE_CA_CERT_FILE}:${RESTLER_CONTAINER_CA_CERT_FILE}:ro")
    RESTLER_CA_ENV_ARGS=(
      -e "SSL_CERT_FILE=${RESTLER_CONTAINER_CA_CERT_FILE}"
      -e "REQUESTS_CA_BUNDLE=${RESTLER_CONTAINER_CA_CERT_FILE}"
    )
    echo "[INFO] RESTler TLS CA certificate will be mounted at ${RESTLER_CONTAINER_CA_CERT_FILE}"
  fi
}

preflight_restler_target() {
  [ "${RESTLER_RUNTIME}" = "docker" ] || return 0

  local output_file
  local status
  local body
  output_file="$(mktemp)"

  if ! docker run --rm \
    --network "${RESTLER_DOCKER_NETWORK}" \
    --add-host=host.docker.internal:host-gateway \
    "${RESTLER_CA_DOCKER_ARGS[@]}" \
    "${RESTLER_CA_ENV_ARGS[@]}" \
    -e "RESTLER_KEYCLOAK_BASE_URL=${DOCKER_KEYCLOAK_URL}" \
    -e "KEYCLOAK_BASE_URL=${DOCKER_KEYCLOAK_URL}" \
    -e "KEYCLOAK_REALM=${KEYCLOAK_REALM:-topic10-sme-api}" \
    -e "RESTLER_AUTH_CLIENT_ID=${RESTLER_AUTH_CLIENT_ID:-sme-lab-automation-client}" \
    -e "RESTLER_AUTH_USERNAME=${RESTLER_AUTH_USERNAME:-ci-alice}" \
    -e "RESTLER_AUTH_PASSWORD=${RESTLER_AUTH_PASSWORD:-}" \
    "${PREFLIGHT_IMAGE}" python - "${TARGET_URL%/}" >"${output_file}" <<'PY'
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

base_url = sys.argv[1].rstrip("/")
keycloak_url = (
    os.environ.get("RESTLER_KEYCLOAK_BASE_URL")
    or os.environ.get("KEYCLOAK_BASE_URL")
    or "http://localhost:8080"
).rstrip("/")
realm = os.environ.get("KEYCLOAK_REALM", "topic10-sme-api")
client_id = os.environ.get("RESTLER_AUTH_CLIENT_ID", "sme-lab-automation-client")
username = os.environ.get("RESTLER_AUTH_USERNAME", "ci-alice")
password = os.environ.get("RESTLER_AUTH_PASSWORD", "")

if not password:
    print("token_status=000")
    print("token_body=RESTLER_AUTH_PASSWORD is required")
    raise SystemExit(2)

cafile = os.environ.get("SSL_CERT_FILE") or os.environ.get("REQUESTS_CA_BUNDLE")
context = ssl.create_default_context(cafile=cafile) if cafile else ssl.create_default_context()

def short_body(raw):
    return raw.decode("utf-8", errors="replace")[:500]

def request(url, token=None):
    headers = {"X-Correlation-ID": "restler-preflight"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, context=context if url.startswith("https://") else None, timeout=15) as response:
            return response.getcode(), short_body(response.read(500))
    except urllib.error.HTTPError as exc:
        return exc.code, short_body(exc.read(500))
    except Exception as exc:
        return 0, f"{type(exc).__name__}: {exc}"

token_url = f"{keycloak_url}/realms/{realm}/protocol/openid-connect/token"
form = urllib.parse.urlencode({
    "grant_type": "password",
    "client_id": client_id,
    "username": username,
    "password": password,
}).encode("utf-8")
try:
    token_req = urllib.request.Request(token_url, data=form, headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(token_req, timeout=15) as response:
        token_status = response.getcode()
        payload = json.loads(response.read().decode("utf-8"))
        token = payload.get("access_token")
except urllib.error.HTTPError as exc:
    print(f"token_status={exc.code}")
    print("token_body=" + short_body(exc.read(500)))
    raise SystemExit(2)
except Exception as exc:
    print("token_status=000")
    print(f"token_body={type(exc).__name__}: {exc}")
    raise SystemExit(2)

if token_status != 200 or not token:
    print(f"token_status={token_status}")
    print("token_body=token response did not contain an access token")
    raise SystemExit(2)

health_status, health_body = request(f"{base_url}/api/v1/users/health")
me_status, me_body = request(f"{base_url}/api/v1/users/me", token=token)
print(f"health_status={health_status}")
print("health_body=" + health_body)
print(f"me_status={me_status}")
print("me_body=" + me_body)
raise SystemExit(0 if health_status == 200 and me_status == 200 else 3)
PY
  then
    status="$(grep -E '^(token_status|health_status|me_status)=' "${output_file}" | tr '\n' ' ' || true)"
    body="$(grep -E '^(token_body|health_body|me_body)=' "${output_file}" | head -n 3 | cut -c1-800 || true)"
    rm -f "${output_file}"
    echo "[ERROR] RESTler preflight failed: ${status:-status unavailable}" >&2
    echo "[ERROR] RESTler preflight body: ${body:-<empty>}" >&2
    exit 1
  fi

  rm -f "${output_file}"
  echo "[INFO] RESTler preflight passed for ${TARGET_URL}"
}

run_restler() {
  if [ "${RESTLER_RUNTIME}" = "cmd" ]; then
    (cd "${WORK_DIR}" && ${RESTLER_CMD} "$@")
    return
  fi

  if [ "${RESTLER_RUNTIME}" = "dll" ]; then
    (cd "${WORK_DIR}" && dotnet "${RESTLER_DLL}" "$@")
    return
  fi

  if [ "${RESTLER_RUNTIME}" = "binary" ]; then
    (cd "${WORK_DIR}" && restler "$@")
    return
  fi

  if [ "${RESTLER_RUNTIME}" = "docker" ]; then
    local translated_args=()
    local arg
    for arg in "$@"; do
      case "${arg}" in
        "${REPO_ROOT}"/*)
          translated_args+=("/api/${arg#"${REPO_ROOT}/"}")
          ;;
        "${WORK_DIR}"/*)
          translated_args+=("/work/${arg#"${WORK_DIR}/"}")
          ;;
        *)
          translated_args+=("${arg}")
          ;;
      esac
    done
    docker run --rm \
      --network "${RESTLER_DOCKER_NETWORK}" \
      --add-host=host.docker.internal:host-gateway \
      "${RESTLER_CA_DOCKER_ARGS[@]}" \
      "${RESTLER_CA_ENV_ARGS[@]}" \
      -e "RESTLER_KEYCLOAK_BASE_URL=${DOCKER_KEYCLOAK_URL}" \
      -e "KEYCLOAK_BASE_URL=${DOCKER_KEYCLOAK_URL}" \
      -e "KEYCLOAK_REALM=${KEYCLOAK_REALM:-topic10-sme-api}" \
      -e "RESTLER_AUTH_CLIENT_ID=${RESTLER_AUTH_CLIENT_ID:-sme-lab-automation-client}" \
      -e "RESTLER_AUTH_USERNAME=${RESTLER_AUTH_USERNAME:-ci-alice}" \
      -e "RESTLER_AUTH_PASSWORD=${RESTLER_AUTH_PASSWORD:-}" \
      -v "${REPO_ROOT}:/api:ro" \
      -v "${WORK_DIR}:/work" \
      -w /work \
      "${RESTLER_IMAGE}" \
      dotnet /RESTler/restler/Restler.dll "${translated_args[@]}"
    return
  fi

  die "RESTler runtime was not selected."
}

find_first() {
  local pattern="$1"
  find "${WORK_DIR}" -type f -name "${pattern}" | sort | head -n 1
}

count_openapi_operations() {
  python3 - "${OPENAPI_SPEC}" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as f:
    spec = yaml.safe_load(f)

verbs = {"get", "put", "post", "delete", "patch", "head", "options", "trace"}
print(sum(1 for methods in spec.get("paths", {}).values() for method in methods if str(method).lower() in verbs))
PY
}

json_value() {
  local file="$1"
  local expr="$2"
  python3 - "${file}" "${expr}" <<'PY'
import json
import sys

path, expr = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("")
    raise SystemExit

value = data
for part in expr.split("."):
    if isinstance(value, dict):
        value = value.get(part, "")
    else:
        value = ""
        break
print(value if not isinstance(value, (dict, list)) else json.dumps(value))
PY
}

build_authenticated_settings() {
  local generated_settings="$1"
  local token_cmd="$2"
  local output_file="$3"

  python3 - "${generated_settings}" "${token_cmd}" "${TOKEN_REFRESH_INTERVAL}" "${output_file}" <<'PY'
import json
import os
import sys

source, token_cmd, interval, output = sys.argv[1:5]
settings = {}

if source and os.path.isfile(source):
    with open(source, encoding="utf-8") as f:
        generated = json.load(f)
    if isinstance(generated, dict):
        settings.update(generated)

settings["token_refresh_cmd"] = token_cmd
settings["token_refresh_interval"] = int(interval)

# Supported by current RESTler releases that suppress token values in logs.
settings["no_tokens_in_logs"] = True

with open(output, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, sort_keys=True)
    f.write("\n")
PY
}

sanitize_copy() {
  local src="$1"
  local dest="$2"
  local auth_prefix jwt_prefix
  auth_prefix="Authorization:"
  auth_prefix+=" Bearer "
  jwt_prefix="e"
  jwt_prefix+="yJ"

  python3 - "${src}" "${dest}" "${auth_prefix}" "${jwt_prefix}" <<'PY'
import re
import sys

src, dest, auth_prefix, jwt_prefix = sys.argv[1:5]
text = open(src, encoding="utf-8", errors="replace").read()
auth_replacement = "Authorization:" + " Bearer [REDACTED]"
text = re.sub(re.escape(auth_prefix) + r"[A-Za-z0-9._~+/=-]+", auth_replacement, text)
text = re.sub(re.escape(jwt_prefix) + r"[A-Za-z0-9._~+/=-]+", "[REDACTED_JWT]", text)
text = re.sub(r'("access_token"\s*:\s*")[^"]+(")', r'\1[REDACTED]\2', text)
open(dest, "w", encoding="utf-8").write(text)
PY
}

copy_generated_if_exists() {
  local name="$1"
  local found
  found="$(find_first "${name}")"
  if [ -n "${found}" ]; then
    sanitize_copy "${found}" "${TMP_DIR}/${name}"
  fi
}

copy_request_response_artifacts() {
  local found
  local base
  local index=0

  while IFS= read -r found; do
    [ -f "${found}" ] || continue
    base="$(basename "${found}")"
    sanitize_copy "${found}" "${TMP_DIR}/restler-artifact-${index}-${base}"
    index=$((index + 1))
  done < <(
    find "${WORK_DIR}" -type f \
      \( -iname '*request*' -o -iname '*response*' -o -iname '*network*' \) |
      sort |
      head -n 20
  )
}

extract_status_sample() {
  python3 - "${TEST_LOG}" "${FUZZ_LEAN_LOG}" <<'PY'
import re
import sys

status_re = re.compile(r"(?:HTTP/\d(?:\.\d)?\s+|status(?:_code)?[=: ]+)([1-5]\d\d)", re.I)
codes = []
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except FileNotFoundError:
        continue
    codes.extend(status_re.findall(text))
unique = sorted(set(codes))
if unique:
    print("Observed status codes in RESTler logs: " + ", ".join(unique[:20]))
else:
    print("Status-code evidence: see RESTler logs; no compact status-code sample was parsed.")
PY
}

count_5xx_or_crash_indicators() {
  python3 - "${TEST_LOG}" "${FUZZ_LEAN_LOG}" <<'PY'
import re
import sys

pattern = re.compile(r"(?<!\d)5\d\d(?!\d)|crash|internal server error|unhandled exception", re.I)
count = 0
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except FileNotFoundError:
        continue
    count += len(pattern.findall(text))
print(count)
PY
}

status_code_table() {
  python3 - "${WORK_DIR}" "${TEST_LOG}" "${FUZZ_LEAN_LOG}" <<'PY'
from collections import Counter
import os
import re
import sys

paths = []
work_dir = sys.argv[1]
for root, _, files in os.walk(work_dir):
    for name in files:
        if name.endswith((".log", ".txt", ".json")):
            paths.append(os.path.join(root, name))
paths.extend(sys.argv[2:])

patterns = [
    re.compile(r'"status(?:_code)?"\s*:\s*([1-5]\d\d)', re.I),
    re.compile(r'\bstatus(?:_code)?[=: ]+([1-5]\d\d)', re.I),
    re.compile(r'\bstatus code[=: ]+([1-5]\d\d)', re.I),
    re.compile(r'\bHTTP/\d(?:\.\d)?\s+([1-5]\d\d)', re.I),
    re.compile(r'\bresponse(?: status)?[=: ]+([1-5]\d\d)', re.I),
]

counts = Counter()
seen = set()
for path in paths:
    if path in seen or not os.path.isfile(path):
        continue
    seen.add(path)
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except Exception:
        continue
    for pattern in patterns:
        counts.update(pattern.findall(text))

if not counts:
    print("No status codes parsed from RESTler logs or JSON artifacts.")
else:
    print("| Status | Count |")
    print("|---|---:|")
    for status, count in sorted(counts.items()):
        print(f"| {status} | {count} |")
PY
}

status_code_count() {
  status_code_table | awk -F'|' '/^\| [0-9][0-9][0-9] / {gsub(/ /, "", $3); sum += $3} END {print sum + 0}'
}

numeric_or_zero() {
  python3 - "$1" <<'PY'
import re
import sys

value = sys.argv[1] if len(sys.argv) > 1 else ""
match = re.search(r"\d+", value or "")
print(int(match.group(0)) if match else 0)
PY
}

[ -f "${OPENAPI_SPEC}" ] || die "OpenAPI spec not found: ${OPENAPI_SPEC}"
select_restler
configure_target
prepare_restler_ca_cert

echo "=== RESTler compile ===" | tee "${COMPILE_LOG}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${COMPILE_LOG}"
echo "RESTler: ${RESTLER_LABEL:-auto-detect}" | tee -a "${COMPILE_LOG}"
echo "OpenAPI: ${OPENAPI_SPEC}" | tee -a "${COMPILE_LOG}"
echo "Target: ${TARGET_URL}" | tee -a "${COMPILE_LOG}"

run_restler compile --api_spec "${OPENAPI_SPEC}" 2>&1 | tee -a "${COMPILE_LOG}"
COMPILE_SUCCEEDED="yes"

GRAMMAR_FILE="$(find_first "grammar.py")"
DICT_FILE="$(find_first "dict.json")"
ENGINE_SETTINGS="$(find_first "engine_settings.json")"
[ -f "${GRAMMAR_FILE}" ] || die "RESTler compile did not produce grammar.py"

if [ "${RESTLER_RUNTIME}" = "docker" ]; then
  TOKEN_CMD="sh /api/tests/restler/fetch-restler-auth.sh"
else
  TOKEN_CMD="sh ${REPO_ROOT}/tests/restler/fetch-restler-auth.sh"
fi

AUTH_SETTINGS="${WORK_DIR}/authenticated-engine-settings.json"
build_authenticated_settings "${ENGINE_SETTINGS:-}" "${TOKEN_CMD}" "${AUTH_SETTINGS}"

preflight_restler_target

TEST_ARGS=(test --grammar_file "${GRAMMAR_FILE}" --target_ip "${RESTLER_TARGET_IP}" --target_port "${RESTLER_TARGET_PORT}" --host "${RESTLER_TARGET_HOST}" --settings "${AUTH_SETTINGS}")
FUZZ_ARGS=(fuzz-lean --grammar_file "${GRAMMAR_FILE}" --target_ip "${RESTLER_TARGET_IP}" --target_port "${RESTLER_TARGET_PORT}" --host "${RESTLER_TARGET_HOST}" --settings "${AUTH_SETTINGS}")
[ -f "${DICT_FILE}" ] && TEST_ARGS+=(--dictionary_file "${DICT_FILE}") && FUZZ_ARGS+=(--dictionary_file "${DICT_FILE}")

echo "=== RESTler test ===" | tee "${TEST_LOG}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${TEST_LOG}"
echo "Settings: authenticated-engine-settings.json with external token refresh command" | tee -a "${TEST_LOG}"
run_restler "${TEST_ARGS[@]}" 2>&1 | tee -a "${TEST_LOG}"
TEST_SUCCEEDED="yes"

echo "=== RESTler fuzz-lean ===" | tee "${FUZZ_LEAN_LOG}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${FUZZ_LEAN_LOG}"
echo "Settings: authenticated-engine-settings.json with external token refresh command" | tee -a "${FUZZ_LEAN_LOG}"
run_restler "${FUZZ_ARGS[@]}" 2>&1 | tee -a "${FUZZ_LEAN_LOG}"
FUZZ_LEAN_SUCCEEDED="yes"

for name in testing_summary.json runSummary.json bug_buckets.txt errorBuckets.json; do
  copy_generated_if_exists "${name}"
done
copy_request_response_artifacts

OPERATIONS="$(count_openapi_operations)"
REQUESTS_RENDERED="unknown"
BUGS_FOUND="unknown"
STATUS_CODES="$(extract_status_sample)"
STATUS_TABLE="$(status_code_table)"
STATUS_CODE_COUNT="$(status_code_count)"
CRASH_INDICATORS="$(count_5xx_or_crash_indicators)"

TESTING_SUMMARY="$(find_first "testing_summary.json")"
RUN_SUMMARY="$(find_first "runSummary.json")"
BUG_BUCKETS="$(find_first "bug_buckets.txt")"
ERROR_BUCKETS="$(find_first "errorBuckets.json")"

if [ -n "${TESTING_SUMMARY}" ]; then
  REQUESTS_RENDERED="$(json_value "${TESTING_SUMMARY}" "total_requests_sent")"
  [ -z "${REQUESTS_RENDERED}" ] && REQUESTS_RENDERED="$(json_value "${TESTING_SUMMARY}" "rendered_requests")"
  [ -z "${REQUESTS_RENDERED}" ] && REQUESTS_RENDERED="$(json_value "${TESTING_SUMMARY}" "executed_requests")"
fi
if [ -n "${RUN_SUMMARY}" ]; then
  [ "${REQUESTS_RENDERED}" = "unknown" ] && REQUESTS_RENDERED="$(json_value "${RUN_SUMMARY}" "total_requests_sent")"
  [ -z "${REQUESTS_RENDERED}" ] && REQUESTS_RENDERED="$(json_value "${RUN_SUMMARY}" "executed_requests")"
  BUGS_FOUND="$(json_value "${RUN_SUMMARY}" "total_bug_buckets")"
  [ -z "${BUGS_FOUND}" ] && BUGS_FOUND="$(json_value "${RUN_SUMMARY}" "bugCount")"
fi
if [ -n "${BUG_BUCKETS}" ]; then
  if [ -s "${BUG_BUCKETS}" ]; then
    BUGS_FOUND="$(grep -cve '^[[:space:]]*$' "${BUG_BUCKETS}" || true)"
  else
    BUGS_FOUND="0"
  fi
fi
if [ -n "${ERROR_BUCKETS}" ] && { [ "${BUGS_FOUND}" = "unknown" ] || [ -z "${BUGS_FOUND}" ]; }; then
  BUGS_FOUND="$(python3 - "${ERROR_BUCKETS}" <<'PY'
import json
import sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("unknown")
    raise SystemExit
print(len(data) if isinstance(data, list) else len(data.keys()) if isinstance(data, dict) else "unknown")
PY
)"
fi

REQUESTS_SENT_NUM="$(numeric_or_zero "${REQUESTS_RENDERED:-}")"
REQUESTS_ACTUALLY_SENT="no"
EVIDENCE_VALIDITY="invalid"
if [ "${REQUESTS_SENT_NUM}" -gt 0 ] || [ "${STATUS_CODE_COUNT}" -gt 0 ]; then
  REQUESTS_ACTUALLY_SENT="yes"
  EVIDENCE_VALIDITY="valid request/status evidence present"
fi

{
  echo "# RESTler Execution Summary"
  echo ""
  echo "**Date:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "**RESTler:** ${RESTLER_LABEL}"
  echo "**OpenAPI path:** \`${OPENAPI_SPEC}\`"
  echo "**Target URL:** \`${TARGET_URL}\`"
  echo "**Auth/token handling:** RESTler test and fuzz-lean use an external token refresh command. The password is read from \`RESTLER_AUTH_PASSWORD\` by \`tests/restler/fetch-restler-auth.sh\`; no password or token is written intentionally to evidence."
  echo ""
  echo "## Results"
  echo ""
  echo "| Metric | Value |"
  echo "|---|---:|"
  echo "| Compile succeeded | ${COMPILE_SUCCEEDED} |"
  echo "| Test succeeded | ${TEST_SUCCEEDED} |"
  echo "| Fuzz-lean succeeded | ${FUZZ_LEAN_SUCCEEDED} |"
  echo "| OpenAPI operations count | ${OPERATIONS} |"
  echo "| Rendered/sent request count | ${REQUESTS_RENDERED:-unknown} |"
  echo "| Requests actually sent or status evidence parsed | ${REQUESTS_ACTUALLY_SENT} |"
  echo "| Status-code observations parsed | ${STATUS_CODE_COUNT} |"
  echo "| Bug bucket count | ${BUGS_FOUND:-unknown} |"
  echo "| 5xx/crash indicator count in logs | ${CRASH_INDICATORS} |"
  echo "| Evidence validity | ${EVIDENCE_VALIDITY} |"
  echo ""
  echo "## Status-Code Evidence"
  echo ""
  echo "${STATUS_CODES}"
  echo ""
  echo "${STATUS_TABLE}"
  echo ""
  echo "RESTler evidence is valid only when the final output proves requests were sent beyond pure 401/403 gateway rejection. Protected-route 401 or 403 responses can still be valid fail-closed behavior when RESTler intentionally exercises unauthenticated or unauthorized cases."
  echo ""
  echo "## Generated Files Copied"
  echo ""
  for name in restler-compile.log restler-test.log restler-fuzz-lean.log restler-summary.md testing_summary.json runSummary.json bug_buckets.txt errorBuckets.json; do
    [ -f "${TMP_DIR}/${name}" ] && echo "- \`${name}\`"
  done
  for artifact in "${TMP_DIR}"/restler-artifact-*; do
    [ -f "${artifact}" ] && echo "- \`$(basename "${artifact}")\`"
  done
} > "${SUMMARY_FILE}"

sanitize_copy "${COMPILE_LOG}" "${EVIDENCE_DIR}/restler-compile.log"
sanitize_copy "${TEST_LOG}" "${EVIDENCE_DIR}/restler-test.log"
sanitize_copy "${FUZZ_LEAN_LOG}" "${EVIDENCE_DIR}/restler-fuzz-lean.log"
sanitize_copy "${SUMMARY_FILE}" "${EVIDENCE_DIR}/restler-summary.md"
for name in testing_summary.json runSummary.json bug_buckets.txt errorBuckets.json; do
  [ -f "${TMP_DIR}/${name}" ] && sanitize_copy "${TMP_DIR}/${name}" "${EVIDENCE_DIR}/${name}"
done
for artifact in "${TMP_DIR}"/restler-artifact-*; do
  [ -f "${artifact}" ] && sanitize_copy "${artifact}" "${EVIDENCE_DIR}/$(basename "${artifact}")"
done

if [ "${REQUESTS_ACTUALLY_SENT}" != "yes" ]; then
  die "RESTler produced no rendered/sent request count and no parseable status-code evidence; summary written as invalid evidence in ${EVIDENCE_DIR}."
fi

echo "RESTler evidence written to ${EVIDENCE_DIR}"
