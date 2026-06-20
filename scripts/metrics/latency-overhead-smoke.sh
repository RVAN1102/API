#!/usr/bin/env bash
set -u

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }
HTTPS_BASE_URL="${HTTPS_BASE_URL:-}"
DIRECT_BASE_URL="${DIRECT_BASE_URL:-}"
REQUESTS="${REQUESTS:-5}"
PAUSE_SEC="${PAUSE_SEC:-0.2}"
CURL_MAX_TIME="${CURL_MAX_TIME:-5}"
OUT_DIR="${OUT_DIR:-.artifacts/test-runs/metrics}"
PATHS="${PATHS:-/api/v1/users/health /api/v1/orders/health /api/v1/billing/health /api/v1/admin/health}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for latency smoke measurement" >&2
  exit 2
fi

case "${REQUESTS}" in
  ''|*[!0-9]*)
    echo "REQUESTS must be a positive integer" >&2
    exit 2
    ;;
esac

if [ "${REQUESTS}" -lt 1 ]; then
  echo "REQUESTS must be at least 1" >&2
  exit 2
fi

mkdir -p "${OUT_DIR}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
CSV_FILE="${OUT_DIR}/latency-overhead-smoke-${RUN_ID}.csv"
SUMMARY_FILE="${OUT_DIR}/latency-overhead-smoke-${RUN_ID}.md"

printf 'target,path,request,http_status,latency_ms\n' > "${CSV_FILE}"

measure_target() {
  target_name="$1"
  target_base="$2"

  [ -n "${target_base}" ] || return 0
  for path in ${PATHS}; do
    i=1
    while [ "${i}" -le "${REQUESTS}" ]; do
      url="${target_base%/}${path}"
      if ! result="$(curl -k -sS --max-time "${CURL_MAX_TIME}" -o /dev/null -w '%{http_code},%{time_total}' "${url}" 2>/dev/null)"; then
        result="000,0"
      fi
      status_code="${result%%,*}"
      time_total="${result#*,}"
      latency_ms="$(awk -v seconds="${time_total}" 'BEGIN { printf "%.3f", seconds * 1000 }')"
      printf '%s,%s,%s,%s,%s\n' "${target_name}" "${path}" "${i}" "${status_code}" "${latency_ms}" >> "${CSV_FILE}"
      i=$((i + 1))
      sleep "${PAUSE_SEC}"
    done
  done
}

percentile_for_target() {
  target_name="$1"
  percentile="$2"
  tmp_file="${OUT_DIR}/.${RUN_ID}-${target_name}-${percentile}.latencies"

  awk -F, -v target="${target_name}" 'NR > 1 && $1 == target && $4 ~ /^[23][0-9][0-9]$/ { print $5 }' "${CSV_FILE}" | sort -n > "${tmp_file}"
  count="$(wc -l < "${tmp_file}" | tr -d ' ')"
  if [ "${count}" = "0" ]; then
    rm -f "${tmp_file}"
    printf 'N/A'
    return 0
  fi

  index="$(awk -v count="${count}" -v pct="${percentile}" 'BEGIN { raw = (pct / 100) * count; idx = int(raw); if (idx < raw) idx++; if (idx < 1) idx = 1; if (idx > count) idx = count; print idx }')"
  sed -n "${index}p" "${tmp_file}"
  rm -f "${tmp_file}"
}

failure_count_for_target() {
  target_name="$1"
  awk -F, -v target="${target_name}" 'NR > 1 && $1 == target && $4 !~ /^[23][0-9][0-9]$/ { count++ } END { print count + 0 }' "${CSV_FILE}"
}

measure_target "gateway_http" "${BASE_URL}"
measure_target "gateway_https" "${HTTPS_BASE_URL}"
measure_target "direct_lab" "${DIRECT_BASE_URL}"

{
  echo "# Latency Overhead Smoke ${RUN_ID}"
  echo
  echo "| Target | Base URL | Requests Per Path | p50 ms | p95 ms | Non-2xx/3xx Responses |"
  echo "|---|---|---:|---:|---:|---:|"
  for target in gateway_http gateway_https direct_lab; do
    case "${target}" in
      gateway_http) base="${BASE_URL}" ;;
      gateway_https) base="${HTTPS_BASE_URL}" ;;
      direct_lab) base="${DIRECT_BASE_URL}" ;;
    esac
    [ -n "${base}" ] || continue
    p50="$(percentile_for_target "${target}" 50)"
    p95="$(percentile_for_target "${target}" 95)"
    failures="$(failure_count_for_target "${target}")"
    echo "| ${target} | ${base} | ${REQUESTS} | ${p50} | ${p95} | ${failures} |"
  done
  echo
  echo "Raw CSV: ${CSV_FILE}"
  echo
  echo "Notes:"
  echo "- This is a lab-only smoke measurement over health endpoints."
  echo "- To estimate Gateway overhead, set DIRECT_BASE_URL to a comparable direct service baseline and compare against gateway_http/gateway_https."
  echo "- Do not commit runtime output unless intentionally refreshing official evidence."
} > "${SUMMARY_FILE}"

cat "${SUMMARY_FILE}"
