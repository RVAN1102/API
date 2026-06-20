#!/usr/bin/env bash
# Alert/log-query based MTTD/MTTR measurement.
#
# MTTD = logql_detection_time - attack_start
# MTTR = remediation_done - logql_detection_time
#
# Detection source is Loki LogQL threshold polling. This script does not use HTTP
# response latency as detection time and does not claim Grafana alert firing.

set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
REPORT_DIR="docs/evidence/tv3/metrics"
CSV="${REPORT_DIR}/mttd-mttr-alert-based-results.csv"
ANALYSIS="${REPORT_DIR}/mttd-mttr-alert-based-analysis.md"
LABELS_JSON="${REPORT_DIR}/loki-labels.json"
LABEL_VALUES_JSON="${REPORT_DIR}/loki-label-values.json"
SAMPLE_LOGS="${REPORT_DIR}/loki-sample-recent-logs.md"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-5}"
DETECTION_TIMEOUT_SECONDS="${DETECTION_TIMEOUT_SECONDS:-180}"
LOKI_READY_TIMEOUT_SECONDS="${LOKI_READY_TIMEOUT_SECONDS:-60}"
MTTD_401_THRESHOLD="${MTTD_401_THRESHOLD:-5}"
MTTD_403_THRESHOLD="${MTTD_403_THRESHOLD:-3}"
MTTD_429_THRESHOLD="${MTTD_429_THRESHOLD:-3}"

mkdir -p "${REPORT_DIR}"

now_epoch() { date -u +%s; }
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

SELECTORS=(
  '{service="user-service"}'
  '{service_name="user-service"}'
  '{container="/infra-user-service-1"}'
  '{container=~".*user.*"}'
  '{job="docker"}'
  '{container=~".*kong.*"}'
  '{container_name=~".*kong.*"}'
  '{compose_service="kong"}'
  '{service_name="kong"}'
  '{filename=~".*kong.*"}'
  '{}'
)

SELECTORS_401=(
  '{service="user-service"}'
  '{service_name="user-service"}'
  '{container="/infra-user-service-1"}'
  '{container=~".*user.*"}'
  '{job="docker"}'
  '{container=~".*kong.*"}'
  '{container_name=~".*kong.*"}'
  '{compose_service="kong"}'
  '{service_name="kong"}'
  '{filename=~".*user.*"}'
  '{}'
)

SELECTORS_429=(
  '{job="docker"}'
  '{container=~".*kong.*"}'
  '{container_name=~".*kong.*"}'
  '{compose_service="kong"}'
  '{service_name="kong"}'
  '{filename=~".*kong.*"}'
  '{}'
)

SELECTORS_403=(
  '{service="order-service"}'
  '{service_name="order-service"}'
  '{container="/infra-order-service-1"}'
  '{container=~".*order.*"}'
  '{job="docker"}'
  '{container=~".*kong.*"}'
  '{container_name=~".*kong.*"}'
  '{compose_service="kong"}'
  '{service_name="kong"}'
  '{filename=~".*order.*"}'
  '{}'
)

PATTERNS_401=(
  'auth_failure'
  'invalid_token'
  '"status_code": 401'
  '"status_code":401'
  '"status": 401'
  '"status":401'
  '401'
)

PATTERNS_403=(
  '"event_type": "bola_attempt"'
  '"event_type": "authz_forbidden"'
  'event_type":"bola_attempt'
  'event_type":"authz_forbidden'
  'bola_attempt'
  'authz_forbidden'
  '"status_code": 403'
  '"status_code":403'
  '"status": 403'
  '"status":403'
  ' 403 '
  '403'
)

PATTERNS_429=(
  '"status_code":429'
  '"status":429'
  ' 429 '
  'status=429'
  '"HTTP/1.1" 429'
  ' 429'
)

urlencode() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
}

logql_escape() {
  python3 - "$1" <<'PY'
import sys
value = sys.argv[1].replace("\\", "\\\\").replace('"', '\\"')
print(value)
PY
}

loki_get() {
  local path="$1"
  curl -fsS "${LOKI_URL}${path}"
}

loki_query_raw() {
  local query="$1"
  local encoded
  encoded="$(urlencode "${query}")"
  curl -sS "${LOKI_URL}/loki/api/v1/query?query=${encoded}" 2>&1 || true
}

loki_query_range_raw() {
  local query="$1"
  local encoded
  encoded="$(urlencode "${query}")"
  curl -sS "${LOKI_URL}/loki/api/v1/query_range?query=${encoded}&limit=20&direction=BACKWARD" 2>&1 || true
}

json_query_count() {
  python3 -c 'import json,sys
raw=sys.stdin.read()
try:
    data=json.loads(raw)
    if data.get("status") != "success":
        print("")
        raise SystemExit
    result=data.get("data",{}).get("result",[])
    if not result:
        print("0")
        raise SystemExit
    print(float(result[0].get("value",[0,"0"])[1]))
except Exception:
    print("")'
}

json_success() {
  python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    raise SystemExit(0 if data.get("status") == "success" else 1)
except Exception:
    raise SystemExit(1)'
}

meets_threshold() {
  python3 - "$1" "$2" <<'PY'
import sys
try:
    value = float(sys.argv[1])
    threshold = float(sys.argv[2])
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if value >= threshold else 1)
PY
}

build_count_query() {
  local selector="$1"
  local pattern="$2"
  local escaped
  escaped="$(logql_escape "${pattern}")"
  printf 'sum(count_over_time(%s |= "%s" [5m]))' "${selector}" "${escaped}"
}

csv_escape() {
  local value="${1:-}"
  value="${value//\"/\"\"}"
  printf '"%s"' "${value}"
}

write_row() {
  local scenario="$1"
  local attack_start="$2"
  local detection_time="$3"
  local remediation_done="$4"
  local mttd="$5"
  local mttr="$6"
  local source="$7"
  local selector="$8"
  local pattern="$9"
  local query="${10}"
  local threshold="${11}"
  local observed_count="${12}"
  local attack_statuses="${13}"
  local containment_status="${14}"
  local note="${15}"
  local diagnostics_file="${16}"

  {
    csv_escape "${scenario}"; printf ','
    csv_escape "${attack_start}"; printf ','
    csv_escape "${detection_time}"; printf ','
    csv_escape "${remediation_done}"; printf ','
    printf '%s,%s,' "${mttd}" "${mttr}"
    csv_escape "${source}"; printf ','
    csv_escape "${selector}"; printf ','
    csv_escape "${pattern}"; printf ','
    csv_escape "${query}"; printf ','
    printf '%s,' "${threshold}"
    csv_escape "${observed_count}"; printf ','
    csv_escape "${attack_statuses}"; printf ','
    csv_escape "${containment_status}"; printf ','
    csv_escape "${note}"; printf ','
    csv_escape "${diagnostics_file}"; printf '\n'
  } >> "${CSV}"
}

require_loki() {
  local deadline status
  deadline=$(( $(now_epoch) + LOKI_READY_TIMEOUT_SECONDS ))

  while [ "$(now_epoch)" -le "${deadline}" ]; do
    if curl -fsS "${LOKI_URL}/ready" >/dev/null 2>&1; then
      return 0
    fi
    if curl -fsS "${LOKI_URL}/loki/api/v1/labels" >/dev/null 2>&1; then
      return 0
    fi

    status="$(curl -sS -o /dev/null -w "%{http_code}" "${LOKI_URL}/ready" 2>/dev/null || echo "000")"
    if [ "${status}" = "503" ]; then
      echo "[INFO] Loki is reachable but not ready yet (HTTP 503); retrying..."
    fi
    sleep 2
  done

  echo "[ERROR] Loki is not reachable or ready at ${LOKI_URL} after ${LOKI_READY_TIMEOUT_SECONDS}s." >&2
  exit 1
}

discover_loki_labels() {
  local generated_at
  generated_at="$(now_iso)"

  loki_get "/loki/api/v1/labels" > "${LABELS_JSON}"

  python3 - "${LOKI_URL}" "${LABEL_VALUES_JSON}" "${generated_at}" <<'PY'
import json
import sys
import urllib.request
from urllib.parse import quote

loki_url, output, generated_at = sys.argv[1:4]
names = ["container", "container_name", "compose_service", "service", "service_name", "job", "filename"]
payload = {"generated_at": generated_at, "source": f"{loki_url}/loki/api/v1/label/<name>/values", "values": {}}
for name in names:
    url = f"{loki_url}/loki/api/v1/label/{quote(name, safe='')}/values"
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            payload["values"][name] = json.loads(response.read().decode("utf-8"))
    except Exception as exc:
        payload["values"][name] = {"status": "error", "error": str(exc)}
with open(output, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2, sort_keys=True)
    f.write("\n")
PY
}

write_sample_recent_logs() {
  {
    echo "# Loki Sample Recent Logs"
    echo ""
    echo "**Generated:** $(now_iso)"
    echo "**Purpose:** Diagnostic samples used only when status-code detection cannot match Kong/service logs."
    echo ""
  } > "${SAMPLE_LOGS}"

  local selector raw ok
  for selector in "${SELECTORS[@]}"; do
    raw="$(loki_query_range_raw "${selector}")"
    ok="false"
    if printf '%s' "${raw}" | json_success; then
      ok="true"
    fi
    {
      echo "## Selector \`${selector}\`"
      echo ""
      echo "accepted_by_loki=${ok}"
      echo ""
      echo '```json'
      printf '%s\n' "${raw}" | python3 -c 'import json,sys
raw=sys.stdin.read()
try:
    data=json.loads(raw)
    streams=data.get("data",{}).get("result",[])
    lines=[]
    for stream in streams:
        for _, line in stream.get("values",[])[:5]:
            lines.append(line)
    print(json.dumps(lines[:10], indent=2))
except Exception:
    print(json.dumps({"raw": raw[:2000]}, indent=2))'
      echo '```'
      echo ""
    } >> "${SAMPLE_LOGS}"
  done
}

wait_for_gateway_readiness() {
  local health_url="${BASE_URL}/api/v1/users/health"
  local code

  for _attempt in $(seq 1 30); do
    if code="$(curl -sS -o /dev/null -w "%{http_code}" "${health_url}" 2>/dev/null)"; then
      :
    else
      code="000"
    fi
    [ "${code}" = "200" ] && return 0
    sleep 2
  done

  echo "[ERROR] Kong did not return HTTP 200 from ${health_url} within 60s." >&2
  return 1
}

reset_kong_before_forbidden_scenario() {
  if [ -f "infra/docker-compose.yml" ] && command -v docker >/dev/null 2>&1; then
    echo "[INFO] Resetting Kong before 403 scenario to avoid rate-limit contamination"
    docker compose -f infra/docker-compose.yml restart kong >/dev/null
    wait_for_gateway_readiness
  else
    echo "[INFO] Docker compose not available; waiting for gateway readiness before 403 scenario"
    wait_for_gateway_readiness
  fi
}

get_ci_alice_token() {
  bash demo/auth/get-user-token.sh ci-alice >/tmp/mttd-ci-alice-token.log 2>&1 \
    || {
      echo "[ERROR] Could not obtain ci-alice token; see /tmp/mttd-ci-alice-token.log" >&2
      return 1
    }
  [ -s /tmp/user-token.txt ] \
    || {
      echo "[ERROR] ci-alice token file was not produced." >&2
      return 1
    }
  cat /tmp/user-token.txt
}

probe_candidates() {
  local status_code="$1"
  local diagnostics_file="$2"
  local patterns_name="PATTERNS_${status_code}[@]"
  local selectors_name="SELECTORS_${status_code}[@]"
  local selectors_tried=0
  local selector pattern query raw count raw_file

  SELECTED_SELECTOR=""
  SELECTED_PATTERN=""
  SELECTED_QUERY=""
  SELECTED_COUNT="0"
  SELECTED_RAW_FILE=""

  {
    echo "# MTTD Candidate Query Diagnostics: ${status_code}"
    echo ""
    echo "**Generated:** $(now_iso)"
    echo "**Loki:** \`${LOKI_URL}\`"
    echo ""
    echo "## Label Evidence"
    echo ""
    echo "- Labels API: \`${LABELS_JSON}\`"
    echo "- Label values: \`${LABEL_VALUES_JSON}\`"
    echo ""
    echo "## Candidate Results"
    echo ""
    echo "| Selector | Pattern | Count | Selected |"
    echo "|---|---|---:|---|"
  } >> "${diagnostics_file}"

  for selector in "${!selectors_name}"; do
    selectors_tried=$((selectors_tried + 1))
    for pattern in "${!patterns_name}"; do
      query="$(build_count_query "${selector}" "${pattern}")"
      raw="$(loki_query_raw "${query}")"
      count="$(printf '%s' "${raw}" | json_query_count)"
      [ -n "${count}" ] || count="query_error"
      printf '| `%s` | `%s` | `%s` | %s |\n' "${selector}" "${pattern}" "${count}" "no" >> "${diagnostics_file}"

      if [ "${count}" != "query_error" ] && meets_threshold "${count}" "1"; then
        raw_file="${REPORT_DIR}/$(basename "${diagnostics_file}" .md)-selected-raw.json"
        printf '%s\n' "${raw}" > "${raw_file}"
        SELECTED_SELECTOR="${selector}"
        SELECTED_PATTERN="${pattern}"
        SELECTED_QUERY="${query}"
        SELECTED_COUNT="${count}"
        SELECTED_RAW_FILE="${raw_file}"
        {
          echo ""
          echo "## Selected Query"
          echo ""
          echo "- selector: \`${SELECTED_SELECTOR}\`"
          echo "- pattern: \`${SELECTED_PATTERN}\`"
          echo "- initial_count: \`${SELECTED_COUNT}\`"
          echo "- raw_response: \`${SELECTED_RAW_FILE}\`"
          echo ""
          echo '```logql'
          echo "${SELECTED_QUERY}"
          echo '```'
        } >> "${diagnostics_file}"
        return 0
      fi
    done
  done

  {
    echo ""
    echo "## No Matching Query"
    echo ""
    echo "Tried ${selectors_tried} selectors with status ${status_code} patterns. Loki was reachable, but no candidate returned observed status-code events."
    echo "Sample recent logs were written to \`${SAMPLE_LOGS}\`."
  } >> "${diagnostics_file}"
  return 1
}

write_matched_sample_logs() {
  local diagnostics_file="$1"
  local status_code="$2"
  local sample_query raw sample_file escaped
  escaped="$(logql_escape "${SELECTED_PATTERN}")"
  sample_query="${SELECTED_SELECTOR} |= \"${escaped}\""
  raw="$(loki_query_range_raw "${sample_query}")"
  sample_file="${REPORT_DIR}/$(basename "${diagnostics_file}" .md)-matched-samples.json"
  printf '%s\n' "${raw}" > "${sample_file}"

  {
    echo ""
    echo "## Sample Matched Log Lines"
    echo ""
    echo "- sample_source: \`/loki/api/v1/query_range\`"
    echo "- sample_selector: \`${SELECTED_SELECTOR}\`"
    echo "- sample_pattern: \`${SELECTED_PATTERN}\`"
    echo "- sample_query: \`${sample_query}\`"
    echo "- raw_sample_response: \`${sample_file}\`"
    echo ""
    echo '```json'
    printf '%s\n' "${raw}" | python3 -c 'import json
import sys

status_code = sys.argv[1]
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    print(json.dumps({"raw": raw[:2000]}, indent=2))
    raise SystemExit

if data.get("status") != "success":
    print(json.dumps(data, indent=2)[:4000])
    raise SystemExit

lines = []
for stream in data.get("data", {}).get("result", []):
    for _, line in stream.get("values", [])[:10]:
        if status_code in line or "auth_failure" in line or "invalid_token" in line or "bola_attempt" in line or "authz_forbidden" in line:
            lines.append(line)
print(json.dumps(lines[:10], indent=2))' "${status_code}"
    echo '```'
  } >> "${diagnostics_file}"
}

poll_selected_query_until_threshold() {
  local threshold="$1"
  local raw_file="$2"
  local diagnostics_file="$3"
  local deadline raw count
  deadline=$(( $(now_epoch) + DETECTION_TIMEOUT_SECONDS ))

  while [ "$(now_epoch)" -le "${deadline}" ]; do
    raw="$(loki_query_raw "${SELECTED_QUERY}")"
    printf '%s\n' "${raw}" > "${raw_file}"
    count="$(printf '%s' "${raw}" | json_query_count)"
    [ -n "${count}" ] || count="query_error"
    {
      echo ""
      echo "- poll_time=$(now_iso) count=${count} threshold=${threshold}"
    } >> "${diagnostics_file}"

    if [ "${count}" != "query_error" ] && meets_threshold "${count}" "${threshold}"; then
      SELECTED_COUNT="${count}"
      return 0
    fi
    sleep "${POLL_INTERVAL_SECONDS}"
  done

  SELECTED_COUNT="${count:-0}"
  return 1
}

trigger_401_spike() {
  local statuses=""
  local status
  for i in $(seq 1 12); do
    status="$(curl -s -o /dev/null -w "%{http_code}" \
      "${BASE_URL}/api/v1/users/me" \
      -H "Authorization: Bearer invalid.mttd.${i}" \
      -H "X-Correlation-ID: mttd-401-${i}" || echo "000")"
    statuses="${statuses}${statuses:+ }${status}"
  done
  echo "${statuses}"
}

trigger_429_spike() {
  local statuses=""
  local status
  for i in $(seq 1 20); do
    status="$(curl -s -o /dev/null -w "%{http_code}" \
      "${BASE_URL}/api/v1/users" \
      -H "Authorization: Bearer invalid-rate-limit-${i}" \
      -H "X-Correlation-ID: mttd-429-${i}" || echo "000")"
    statuses="${statuses}${statuses:+ }${status}"
  done
  echo "${statuses}"
}

trigger_403_spike() {
  local statuses=""
  local status token first_status

  reset_kong_before_forbidden_scenario
  token="$(get_ci_alice_token)"

  for i in $(seq 1 5); do
    status="$(curl -s -o /dev/null -w "%{http_code}" \
      "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" \
      -H "Authorization: Bearer ${token}" \
      -H "X-Correlation-ID: mttd-403-bola-${i}" || echo "000")"
    statuses="${statuses}${statuses:+ }${status}"
  done

  first_status="${statuses%% *}"
  if [ "${first_status}" != "403" ]; then
    echo "[ERROR] 403 scenario did not produce a real 403 response before any rate-limit noise; statuses=${statuses}" >&2
    return 1
  fi

  echo "${statuses}"
}

verify_401_containment() {
  curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users/me" \
    -H "Authorization: Bearer invalid.mttd.verify" \
    -H "X-Correlation-ID: mttd-401-verify" || echo "000"
}

verify_403_containment() {
  local token
  token="$(get_ci_alice_token)"
  curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" \
    -H "Authorization: Bearer ${token}" \
    -H "X-Correlation-ID: mttd-403-bola-verify" || echo "000"
}

verify_429_containment() {
  curl -s -o /dev/null -w "%{http_code}" \
    "${BASE_URL}/api/v1/users" \
    -H "Authorization: Bearer invalid-rate-limit-verify" \
    -H "X-Correlation-ID: mttd-429-verify" || echo "000"
}

run_scenario() {
  local scenario="$1"
  local status_code="$2"
  local threshold="$3"
  local trigger_fn="$4"
  local verify_fn="$5"
  local expected_containment_regex="$6"

  local attack_start_iso attack_start_epoch statuses diagnostics_file raw_file detection_time_iso detection_time_epoch containment_status remediation_done_iso remediation_done_epoch mttd mttr note

  echo "--- ${scenario} ---"
  diagnostics_file="${REPORT_DIR}/${scenario}-diagnostics.md"
  raw_file="${REPORT_DIR}/${scenario}-selected-query-response.json"
  : > "${diagnostics_file}"
  attack_start_iso="$(now_iso)"
  attack_start_epoch="$(now_epoch)"
  if ! statuses="$("${trigger_fn}")"; then
    statuses="${statuses:-trigger_failed}"
    note="attack_trigger_failed"
    {
      echo ""
      echo "## Attack Traffic"
      echo ""
      echo "- attack_start: \`${attack_start_iso}\`"
      echo "- attack_statuses: \`${statuses}\`"
      echo "- detection_threshold: \`${threshold}\`"
      echo "- trigger_result: failed"
    } >> "${diagnostics_file}"
    write_row "${scenario}" "${attack_start_iso}" "" "" "" "" "loki_logql_threshold" "" "" "" "${threshold}" "0" "${statuses}" "" "${note}" "${diagnostics_file}"
    echo "[FAIL] ${scenario}: trigger failed"
    return 1
  fi

  {
    echo ""
    echo "## Attack Traffic"
    echo ""
    echo "- attack_start: \`${attack_start_iso}\`"
    echo "- attack_statuses: \`${statuses}\`"
    echo "- detection_threshold: \`${threshold}\`"
  } >> "${diagnostics_file}"

  if ! probe_candidates "${status_code}" "${diagnostics_file}"; then
    write_sample_recent_logs
    note="Loki reachable but no matching Kong/service status logs found"
    write_row "${scenario}" "${attack_start_iso}" "" "" "" "" "loki_logql_threshold" "" "" "" "${threshold}" "0" "${statuses}" "" "${note}" "${diagnostics_file}"
    echo "[FAIL] ${scenario}: ${note}"
    return 1
  fi

  write_matched_sample_logs "${diagnostics_file}" "${status_code}"

  {
    echo ""
    echo "## Detection Polling"
    echo ""
    echo "- selected_selector: \`${SELECTED_SELECTOR}\`"
    echo "- selected_pattern: \`${SELECTED_PATTERN}\`"
    echo "- selected_query: \`${SELECTED_QUERY}\`"
    echo "- threshold: \`${threshold}\`"
    echo "- raw_response_file: \`${raw_file}\`"
  } >> "${diagnostics_file}"

  if poll_selected_query_until_threshold "${threshold}" "${raw_file}" "${diagnostics_file}"; then
    detection_time_iso="$(now_iso)"
    detection_time_epoch="$(now_epoch)"
    containment_status="$("${verify_fn}")"
    remediation_done_iso="$(now_iso)"
    remediation_done_epoch="$(now_epoch)"
    mttd=$((detection_time_epoch - attack_start_epoch))
    mttr=$((remediation_done_epoch - detection_time_epoch))
    if [[ "${containment_status}" =~ ${expected_containment_regex} ]]; then
      note="logql_threshold_observed_value_${SELECTED_COUNT}; containment_verified"
    else
      note="logql_threshold_observed_value_${SELECTED_COUNT}; containment_unexpected_status"
    fi
    write_row "${scenario}" "${attack_start_iso}" "${detection_time_iso}" "${remediation_done_iso}" "${mttd}" "${mttr}" "loki_logql_threshold" "${SELECTED_SELECTOR}" "${SELECTED_PATTERN}" "${SELECTED_QUERY}" "${threshold}" "${SELECTED_COUNT}" "${statuses}" "${containment_status}" "${note}" "${diagnostics_file}"
    echo "[PASS] ${scenario}: MTTD=${mttd}s MTTR=${mttr}s detection_value=${SELECTED_COUNT} containment=${containment_status}"
  else
    note="threshold_not_observed_within_${DETECTION_TIMEOUT_SECONDS}s; latest_count_${SELECTED_COUNT}"
    write_row "${scenario}" "${attack_start_iso}" "" "" "" "" "loki_logql_threshold" "${SELECTED_SELECTOR}" "${SELECTED_PATTERN}" "${SELECTED_QUERY}" "${threshold}" "${SELECTED_COUNT}" "${statuses}" "" "${note}" "${diagnostics_file}"
    echo "[FAIL] ${scenario}: threshold not observed within ${DETECTION_TIMEOUT_SECONDS}s"
    return 1
  fi
}

write_analysis() {
  python3 - "${CSV}" "${ANALYSIS}" "${LOKI_URL}" "${BASE_URL}" "$(now_iso)" <<'PY'
import csv
import sys

csv_path, analysis_path, loki_url, base_url, generated = sys.argv[1:6]
rows = []
try:
    with open(csv_path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
except FileNotFoundError:
    rows = []

with open(analysis_path, "w", encoding="utf-8") as f:
    f.write("# Alert-Based MTTD/MTTR Analysis\n\n")
    f.write(f"**Generated:** {generated}\n")
    f.write(f"**Source of truth:** Loki LogQL threshold polling at `{loki_url}`\n")
    f.write(f"**Target:** `{base_url}`\n\n")
    f.write("## Methodology\n\n")
    f.write("- **MTTD** is measured as `logql_detection_time - attack_start`.\n")
    f.write("- **MTTR** is measured as `remediation_done - logql_detection_time`.\n")
    f.write("- Detection is Loki LogQL threshold-based evidence, not Grafana alert firing evidence.\n")
    f.write("- The script discovers Loki labels and probes multiple selectors/patterns before selecting a query.\n")
    f.write("- `logql_detection_time` is recorded only when the selected LogQL count meets or exceeds the scenario threshold.\n")
    f.write("- `remediation_done` is recorded after containment is verified with a follow-up blocked request.\n")
    f.write("- HTTP response latency is not used as MTTD.\n\n")
    f.write("## Results\n\n")
    f.write("| Scenario | MTTD (s) | MTTR (s) | Selector | Pattern | Count | Containment Status | Note |\n")
    f.write("|---|---:|---:|---|---|---:|---:|---|\n")
    for row in rows:
        f.write(
            f"| {row.get('scenario','')} | {row.get('mttd_seconds','')} | {row.get('mttr_seconds','')} | "
            f"`{row.get('selector','')}` | `{row.get('pattern','')}` | {row.get('observed_count','')} | "
            f"{row.get('containment_status','')} | {row.get('note','')} |\n"
        )
    f.write("\n## Evidence Files\n\n")
    f.write("- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-results.csv`\n")
    f.write("- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-analysis.md`\n")
    f.write("- `docs/evidence/tv3/metrics/loki-labels.json`\n")
    f.write("- `docs/evidence/tv3/metrics/loki-label-values.json`\n")
    f.write("- `docs/evidence/tv3/metrics/*-diagnostics.md`\n")
    f.write("- `docs/evidence/tv3/metrics/*-selected-query-response.json`\n")
    f.write("- `docs/evidence/tv3/metrics/loki-sample-recent-logs.md` when no candidate query matches logs\n")
PY
}

require_loki
discover_loki_labels

cat > "${CSV}" <<'EOF'
scenario,attack_start,logql_detection_time,remediation_done,mttd_seconds,mttr_seconds,detection_source,selector,pattern,logql_query,threshold,observed_count,attack_statuses,containment_status,note,diagnostics_file
EOF

FAILURES=0

run_scenario \
  "401_unauthorized_spike" \
  "401" \
  "${MTTD_401_THRESHOLD}" \
  trigger_401_spike \
  verify_401_containment \
  '^(401|403|429)$' || FAILURES=$((FAILURES + 1))

run_scenario \
  "403_forbidden_bola_spike" \
  "403" \
  "${MTTD_403_THRESHOLD}" \
  trigger_403_spike \
  verify_403_containment \
  '^403$' || FAILURES=$((FAILURES + 1))

run_scenario \
  "429_rate_limit_spike" \
  "429" \
  "${MTTD_429_THRESHOLD}" \
  trigger_429_spike \
  verify_429_containment \
  '^429$' || FAILURES=$((FAILURES + 1))

write_analysis

echo "CSV: ${CSV}"
echo "Analysis: ${ANALYSIS}"
echo "Labels: ${LABELS_JSON}"
echo "Label values: ${LABEL_VALUES_JSON}"

if [ "${FAILURES}" -gt 0 ]; then
  exit 1
fi
