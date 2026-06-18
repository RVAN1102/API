#!/usr/bin/env bash
# tests/restler/run-restler-check.sh
#
# Real RESTler compile + test + fuzz-lean runner.
# This script intentionally fails if RESTler is not available.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TARGET_URL="${TARGET_URL:-${BASE_URL:-http://localhost:8000}}"
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

mkdir -p "${WORK_DIR}"
chmod 0777 "${TMP_DIR}" "${WORK_DIR}"

RESTLER_LABEL=""
RESTLER_RUNTIME=""

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
      --network host \
      -v "${REPO_ROOT}:/api:ro" \
      -v "${WORK_DIR}:/work" \
      -w /work \
      "${RESTLER_IMAGE}" \
      dotnet /RESTler/restler/Restler.dll "${translated_args[@]}"
    return
  fi

  die "RESTler runtime was not selected."
}

copy_if_exists() {
  local src="$1"
  local dest_name="$2"
  if [ -f "${src}" ]; then
    cp "${src}" "${TMP_DIR}/${dest_name}"
  fi
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
count = 0
for methods in spec.get("paths", {}).values():
    for method in methods:
        if str(method).lower() in {"get", "put", "post", "delete", "patch", "head", "options", "trace"}:
            count += 1
print(count)
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
    data = json.load(open(path, encoding="utf-8"))
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

[ -f "${OPENAPI_SPEC}" ] || die "OpenAPI spec not found: ${OPENAPI_SPEC}"
select_restler

echo "=== RESTler compile ===" | tee "${COMPILE_LOG}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${COMPILE_LOG}"
echo "RESTler: ${RESTLER_LABEL:-auto-detect}" | tee -a "${COMPILE_LOG}"
echo "OpenAPI: ${OPENAPI_SPEC}" | tee -a "${COMPILE_LOG}"
echo "Target: ${TARGET_URL}" | tee -a "${COMPILE_LOG}"

run_restler compile --api_spec "${OPENAPI_SPEC}" 2>&1 | tee -a "${COMPILE_LOG}"

GRAMMAR_FILE="$(find_first "grammar.py")"
DICT_FILE="$(find_first "dict.json")"
ENGINE_SETTINGS="$(find_first "engine_settings.json")"
[ -f "${GRAMMAR_FILE}" ] || die "RESTler compile did not produce grammar.py"

TEST_ARGS=(test --grammar_file "${GRAMMAR_FILE}" --target_ip 127.0.0.1 --target_port 8000 --no_ssl --host localhost)
FUZZ_ARGS=(fuzz-lean --grammar_file "${GRAMMAR_FILE}" --target_ip 127.0.0.1 --target_port 8000 --no_ssl --host localhost)
[ -f "${DICT_FILE}" ] && TEST_ARGS+=(--dictionary_file "${DICT_FILE}") && FUZZ_ARGS+=(--dictionary_file "${DICT_FILE}")
[ -f "${ENGINE_SETTINGS}" ] && TEST_ARGS+=(--settings "${ENGINE_SETTINGS}") && FUZZ_ARGS+=(--settings "${ENGINE_SETTINGS}")

echo "=== RESTler test ===" | tee "${TEST_LOG}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${TEST_LOG}"
run_restler "${TEST_ARGS[@]}" 2>&1 | tee -a "${TEST_LOG}"

echo "=== RESTler fuzz-lean ===" | tee "${FUZZ_LEAN_LOG}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${FUZZ_LEAN_LOG}"
run_restler "${FUZZ_ARGS[@]}" 2>&1 | tee -a "${FUZZ_LEAN_LOG}"

for name in testing_summary.json bug_buckets.txt runSummary.json errorBuckets.json; do
  found="$(find_first "${name}")"
  [ -n "${found}" ] && copy_if_exists "${found}" "${name}"
done

OPERATIONS="$(count_openapi_operations)"
REQUESTS_RENDERED="unknown"
BUGS_FOUND="unknown"
STATUS_CODES="see RESTler logs"

TESTING_SUMMARY="$(find_first "testing_summary.json")"
RUN_SUMMARY="$(find_first "runSummary.json")"
BUG_BUCKETS="$(find_first "bug_buckets.txt")"
ERROR_BUCKETS="$(find_first "errorBuckets.json")"

if [ -n "${TESTING_SUMMARY}" ]; then
  REQUESTS_RENDERED="$(json_value "${TESTING_SUMMARY}" "total_requests_sent")"
  [ -z "${REQUESTS_RENDERED}" ] && REQUESTS_RENDERED="$(json_value "${TESTING_SUMMARY}" "final_spec_coverage")"
fi
if [ -n "${RUN_SUMMARY}" ]; then
  [ "${REQUESTS_RENDERED}" = "unknown" ] && REQUESTS_RENDERED="$(json_value "${RUN_SUMMARY}" "total_requests_sent")"
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
if [ -n "${ERROR_BUCKETS}" ] && [ "${BUGS_FOUND}" = "unknown" ]; then
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

{
  echo "# RESTler Execution Summary"
  echo ""
  echo "**Date:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "**RESTler:** ${RESTLER_LABEL}"
  echo "**OpenAPI path:** \`${OPENAPI_SPEC}\`"
  echo "**Target URL:** \`${TARGET_URL}\`"
  echo "**Auth/token handling:** No token is printed. Set \`RESTLER_TOKEN\` only if a local RESTler dictionary/settings flow consumes it; this runner does not synthesize auth evidence."
  echo ""
  echo "## Results"
  echo ""
  echo "| Metric | Value |"
  echo "|---|---:|"
  echo "| OpenAPI operations covered by spec | ${OPERATIONS} |"
  echo "| Rendered/sent requests | ${REQUESTS_RENDERED:-unknown} |"
  echo "| Bugs found | ${BUGS_FOUND:-unknown} |"
  echo ""
  echo "## Status Codes"
  echo ""
  echo "${STATUS_CODES}"
  echo ""
  echo "401, 403, and 429 responses on protected or rate-limited routes are expected fail-closed behavior when RESTler does not provide a valid token or intentionally exercises negative cases."
  echo ""
  echo "## Evidence Files"
  echo ""
  echo "- \`restler-compile.log\`"
  echo "- \`restler-test.log\`"
  echo "- \`restler-fuzz-lean.log\`"
  for name in testing_summary.json bug_buckets.txt runSummary.json errorBuckets.json; do
    [ -f "${EVIDENCE_DIR}/${name}" ] && echo "- \`${name}\`"
  done
  echo ""
  echo "RESTler evidence is valid only when compile, test, and fuzz-lean all complete successfully."
} > "${SUMMARY_FILE}"

mkdir -p "${EVIDENCE_DIR}"
cp "${COMPILE_LOG}" "${EVIDENCE_DIR}/restler-compile.log"
cp "${TEST_LOG}" "${EVIDENCE_DIR}/restler-test.log"
cp "${FUZZ_LEAN_LOG}" "${EVIDENCE_DIR}/restler-fuzz-lean.log"
cp "${SUMMARY_FILE}" "${EVIDENCE_DIR}/restler-summary.md"
for name in testing_summary.json bug_buckets.txt runSummary.json errorBuckets.json; do
  [ -f "${TMP_DIR}/${name}" ] && cp "${TMP_DIR}/${name}" "${EVIDENCE_DIR}/${name}"
done

echo "RESTler evidence written to ${EVIDENCE_DIR}"
