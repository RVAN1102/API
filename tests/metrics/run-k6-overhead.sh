#!/usr/bin/env bash
# Compare direct backend and Kong edge latency for the same authenticated endpoint.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/infra/docker-compose.yml"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv3/metrics"
DEFAULT_TOKEN_FILE="/tmp/user-token.txt"
TOKEN_FILE="${TOKEN_FILE:-/tmp/user-token.txt}"
K6_IMAGE="${K6_IMAGE:-grafana/k6:0.49.0}"
PREFLIGHT_IMAGE="${PREFLIGHT_IMAGE:-curlimages/curl:8.10.1}"
BASELINE_URL="https://user-service:8443"
EDGE_BASE_URL="${EDGE_BASE_URL:-https://kong:8443}"
RUN_DIR="$(mktemp -d /tmp/topic10-k6-overhead.XXXXXX)"

BASELINE_SUMMARY="${RUN_DIR}/k6-baseline-users-me-summary.json"
BASELINE_RESULT="${RUN_DIR}/k6-baseline-users-me-result.txt"
EDGE_SUMMARY="${RUN_DIR}/k6-edge-users-me-summary.json"
EDGE_RESULT="${RUN_DIR}/k6-edge-users-me-result.txt"
ANALYSIS_FILE="${RUN_DIR}/k6-users-me-overhead-analysis.md"

mkdir -p "${EVIDENCE_DIR}"

cleanup() {
  rm -rf "${RUN_DIR}"
}
trap cleanup EXIT

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_cmd docker
require_cmd python3

refresh_token() {
  echo "[INFO] Refreshing ci-alice token for k6 overhead run." >&2
  bash "${REPO_ROOT}/demo/auth/get-user-token.sh" ci-alice >/dev/null
  if [ "${TOKEN_FILE}" != "${DEFAULT_TOKEN_FILE}" ]; then
    cp "${DEFAULT_TOKEN_FILE}" "${TOKEN_FILE}"
    chmod 0600 "${TOKEN_FILE}" 2>/dev/null || true
  fi
}

user_container="$(docker compose -f "${COMPOSE_FILE}" ps -q user-service)"
[ -n "${user_container}" ] || die "user-service container is not running. Start the stack before running this measurement."

internal_network="$(
  docker inspect "${user_container}" \
    --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' |
    grep 'kong-user-internal' |
    head -n 1
)"
[ -n "${internal_network}" ] || die "Could not find a user-service Docker network containing kong-user-internal."

EDGE_DOCKER_NETWORK="${EDGE_DOCKER_NETWORK:-${internal_network}}"

preflight_endpoint() {
  local name="$1"
  local network="$2"
  local url="$3"
  local tls_mode="${4:-edge}"
  local output_file
  local status
  local body

  output_file="$(mktemp)"
  if ! docker run --rm \
    --network "${network}" \
    -v "${TOKEN_FILE}:/token/user-token.txt:ro" \
    -v "${REPO_ROOT}/infra/certs/gateway-backend:/client-certs:ro" \
    --entrypoint sh \
    "${PREFLIGHT_IMAGE}" -c '
      token="$(cat /token/user-token.txt)"
      body_file="$(mktemp)"
      auth_header="Authorization:"
      tls_args="-k"
      if [ "$2" = "direct-mtls" ]; then
        tls_args="--cacert /client-certs/ca.crt --cert /client-certs/kong-client.crt --key /client-certs/kong-client.key"
      fi
      status="$(curl ${tls_args} -sS -o "${body_file}" -w "%{http_code}" \
        -H "${auth_header} Bearer ${token}" \
        -H "X-Correlation-ID: k6-overhead-preflight" \
        "$1" 2>/dev/null || true)"
      [ -n "${status}" ] || status="000"
      printf "%s\n" "${status}"
      head -c 500 "${body_file}" || true
      rm -f "${body_file}"
      [ "${status}" = "200" ]
    ' sh "${url}" "${tls_mode}" >"${output_file}"
  then
    status="$(sed -n '1p' "${output_file}" || true)"
    body="$(sed -n '2,$p' "${output_file}" | head -c 500 || true)"
    rm -f "${output_file}"
    echo "[ERROR] ${name} preflight failed with HTTP ${status:-unknown}." >&2
    echo "[ERROR] ${name} preflight response body: ${body:-<empty>}" >&2
    exit 1
  fi

  status="$(sed -n '1p' "${output_file}" || true)"
  rm -f "${output_file}"
  echo "[INFO] ${name} preflight passed with HTTP ${status}."
}

status_distribution() {
  local summary_path="$1"
  python3 - "${summary_path}" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        metrics = json.load(f).get("metrics", {})
except Exception:
    print("unavailable")
    raise SystemExit

mapping = {
    "200": "users_me_status_200",
    "401": "users_me_status_401",
    "403": "users_me_status_403",
    "429": "users_me_status_429",
    "502": "users_me_status_502",
    "other": "users_me_status_other",
}
dist = {}
for label, metric_name in mapping.items():
    value = metrics.get(metric_name, {}).get("values", {}).get("count", 0)
    if value:
        dist[label] = int(value)

print(" ".join(f"{status}={count}" for status, count in sorted(dist.items())) or "unavailable")
PY
}

status_count() {
  local summary_path="$1"
  local wanted_status="$2"
  python3 - "${summary_path}" "${wanted_status}" <<'PY'
import json
import sys

path, wanted = sys.argv[1:3]
try:
    with open(path, encoding="utf-8") as f:
        metrics = json.load(f).get("metrics", {})
except Exception:
    print(0)
    raise SystemExit

metric_name = f"users_me_status_{wanted}" if wanted != "other" else "users_me_status_other"
print(int(metrics.get(metric_name, {}).get("values", {}).get("count", 0)))
PY
}

run_k6() {
  local scenario="$1"
  local network="$2"
  local base_url="$3"
  local summary_path="$4"
  local result_path="$5"
  local tls_mode="${6:-edge}"
  local client_tls_args=()

  if [ "${tls_mode}" = "direct-mtls" ]; then
    client_tls_args=(
      -e "CLIENT_CERT_FILE=/client-certs/kong-client.crt"
      -e "CLIENT_KEY_FILE=/client-certs/kong-client.key"
      -e "CLIENT_CERT_DOMAINS=user-service"
      -v "${REPO_ROOT}/infra/certs/gateway-backend:/client-certs:ro"
    )
  fi

  rm -f "${summary_path}" "${result_path}"
  echo "[INFO] Running ${scenario}: ${base_url}" | tee "${result_path}"

  docker run --rm \
    --network "${network}" \
    -u "$(id -u):$(id -g)" \
    -e "BASE_URL=${base_url}" \
    -e "TOKEN_FILE=/token/user-token.txt" \
    -v "${TOKEN_FILE}:/token/user-token.txt:ro" \
    -v "${SCRIPT_DIR}:/scripts:ro" \
    -v "${RUN_DIR}:/out" \
    "${client_tls_args[@]}" \
    "${K6_IMAGE}" run \
      --insecure-skip-tls-verify \
      --summary-export "/out/$(basename "${summary_path}")" \
      /scripts/k6-users-me-overhead.js 2>&1 | tee -a "${result_path}"
}

refresh_token
[ -s "${TOKEN_FILE}" ] || die "Token helper did not create a non-empty ${TOKEN_FILE} before direct phase."
preflight_endpoint "direct users/me" "${internal_network}" "${BASELINE_URL}/api/v1/users/me" "direct-mtls"
if ! run_k6 \
  "direct backend baseline on Docker internal network ${internal_network}" \
  "${internal_network}" \
  "${BASELINE_URL}" \
  "${BASELINE_SUMMARY}" \
  "${BASELINE_RESULT}" \
  "direct-mtls"; then
  echo "[ERROR] Direct k6 run failed. Status distribution: $(status_distribution "${BASELINE_SUMMARY}")" >&2
  die "Direct k6 run failed; latency overhead evidence was not generated."
fi

refresh_token
[ -s "${TOKEN_FILE}" ] || die "Token helper did not create a non-empty ${TOKEN_FILE} before edge phase."
preflight_endpoint "edge users/me" "${internal_network}" "${EDGE_BASE_URL}/api/v1/users/me"
echo "[INFO] Running edge scenario with Docker network ${EDGE_DOCKER_NETWORK} and EDGE_BASE_URL=${EDGE_BASE_URL}." >&2
if ! run_k6 \
  "edge protected via Kong using Docker network ${EDGE_DOCKER_NETWORK}" \
  "${EDGE_DOCKER_NETWORK}" \
  "${EDGE_BASE_URL}" \
  "${EDGE_SUMMARY}" \
  "${EDGE_RESULT}"; then
  echo "[ERROR] Edge k6 run failed. Status distribution: $(status_distribution "${EDGE_SUMMARY}")" >&2
  die "Edge k6 run failed. If status 429 appears, the run hit Kong rate limiting and is not valid latency overhead evidence."
fi

edge_429_count="$(status_count "${EDGE_SUMMARY}" "429")"
if [ "${edge_429_count}" -gt 0 ]; then
  echo "[ERROR] Edge k6 returned HTTP 429. Status distribution: $(status_distribution "${EDGE_SUMMARY}")" >&2
  die "Edge k6 hit Kong rate limiting; latency overhead evidence was not generated."
fi

python3 - "${BASELINE_SUMMARY}" "${EDGE_SUMMARY}" "${ANALYSIS_FILE}" <<'PY'
import json
import os
import sys

baseline_path, edge_path, output_path = sys.argv[1:4]

def metric_values(metrics, name):
    metric = metrics.get(name)
    if not isinstance(metric, dict):
        return {}
    values = metric.get("values")
    return values if isinstance(values, dict) else metric

def metric_number(metrics, name, key):
    values = metric_values(metrics, name)
    value = values.get(key)
    if value is None:
        return None
    return float(value)

def require_thresholds_pass(metrics, path):
    checks = metric_number(metrics, "checks", "value")
    error_rate = metric_number(metrics, "users_me_error_rate", "value")
    if checks is None or checks <= 0.99:
        raise SystemExit(f"checks threshold did not pass in {path}")
    if error_rate is None or error_rate >= 0.01:
        raise SystemExit(f"users_me_error_rate threshold did not pass in {path}")

def read_metrics(path):
    if not os.path.isfile(path):
        raise SystemExit(f"k6 summary does not exist: {path}")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    metrics = data.get("metrics", {})
    require_thresholds_pass(metrics, path)

    trend = metric_values(metrics, "users_me_latency_ms")
    med = trend.get("med")
    p95 = trend.get("p(95)")
    latency_source = "users_me_latency_ms"
    if med is None or p95 is None:
        trend = metric_values(metrics, "http_req_duration")
        med = trend.get("med")
        p95 = trend.get("p(95)")
        latency_source = "http_req_duration"
    if med is None or p95 is None:
        raise SystemExit(f"missing latency med or p(95) in {path}")

    reqs = metric_values(metrics, "http_reqs").get("count")
    if reqs is None:
        checks_values = metric_values(metrics, "checks")
        reqs = int(checks_values.get("passes", 0)) + int(checks_values.get("fails", 0))
    return {
        "requests": int(reqs) if reqs is not None else "unknown",
        "p50": float(med),
        "p95": float(p95),
        "latency_source": latency_source,
    }

baseline = read_metrics(baseline_path)
edge = read_metrics(edge_path)
added = {
    "requests": "n/a",
    "p50": edge["p50"] - baseline["p50"],
    "p95": edge["p95"] - baseline["p95"],
}

def fmt(value):
    return value if isinstance(value, str) else f"{value:.2f}"

with open(output_path, "w", encoding="utf-8") as f:
    f.write("# k6 Users Me Edge Overhead Analysis\n\n")
    f.write("## Requirement Proven\n\n")
    f.write("Measures low-load controlled edge path overhead compared with direct backend path for the same authenticated `/api/v1/users/me` endpoint.\n\n")
    f.write("## Command Or Evidence Source\n\n")
    f.write("`bash tests/metrics/run-k6-overhead.sh`\n\n")
    f.write("## Methodology\n\n")
    f.write("Both direct and edge runs use the same constant-arrival-rate scenario: 6 requests per minute for 3 minutes, with 1 pre-allocated VU and 2 maximum VUs. The direct phase presents the generated Kong client certificate because the backend is mTLS-only; the edge phase enters through HTTPS Kong. This should produce about 18 requests per run, intentionally runs below the observed Kong rate-limit threshold, and is not a stress test.\n\n")
    f.write("## Observed Result\n\n")
    f.write("| Scenario | Requests | p50 ms | p95 ms |\n")
    f.write("|---|---:|---:|---:|\n")
    f.write(f"| Direct backend baseline | {baseline['requests']} | {fmt(baseline['p50'])} | {fmt(baseline['p95'])} |\n")
    f.write(f"| Edge protected via Kong | {edge['requests']} | {fmt(edge['p50'])} | {fmt(edge['p95'])} |\n")
    f.write(f"| Added latency | {added['requests']} | {fmt(added['p50'])} | {fmt(added['p95'])} |\n\n")
    f.write("## Scope And Limitation\n\n")
    f.write(f"Latency source: direct `{baseline['latency_source']}`, edge `{edge['latency_source']}`. This compares the Kong-protected edge path with the direct backend path for one authenticated endpoint. It does not isolate mTLS overhead from other gateway, TLS, policy, network, or container-runtime effects.\n")
PY

for evidence_file in \
  "${BASELINE_SUMMARY}" \
  "${BASELINE_RESULT}" \
  "${EDGE_SUMMARY}" \
  "${EDGE_RESULT}" \
  "${ANALYSIS_FILE}"; do
  cp "${evidence_file}" "${EVIDENCE_DIR}/$(basename "${evidence_file}")"
done

echo "[INFO] k6 overhead evidence written under ${EVIDENCE_DIR}"
