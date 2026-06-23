#!/usr/bin/env bash
# Measure Vault secret-read overhead as a local proxy for KMS-style retrieval cost.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv3/metrics"
VAULT_ADDR="${VAULT_ADDR:-https://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-dev-root-token}"
SAMPLES="${SAMPLES:-30}"
CSV_FILE="${EVIDENCE_DIR}/vault-kms-overhead.csv"
SUMMARY_FILE="${EVIDENCE_DIR}/vault-kms-overhead-summary.md"
VAULT_PATH="/v1/secret/data/api/webhook"

mkdir -p "${EVIDENCE_DIR}"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || die "curl is required."
command -v python3 >/dev/null 2>&1 || die "python3 is required."

printf 'run,http_status,time_total_seconds,latency_ms\n' > "${CSV_FILE}"

for run in $(seq 1 "${SAMPLES}"); do
  result="$(
    curl -sS \
      -H "X-Vault-Token: ${VAULT_TOKEN}" \
      -o /dev/null \
      -w "%{http_code},%{time_total}" \
      "${VAULT_ADDR%/}${VAULT_PATH}" 2>/dev/null || printf '000,0'
  )"
  http_status="${result%%,*}"
  time_total="${result#*,}"
  latency_ms="$(python3 - "${time_total}" <<'PY'
import sys
try:
    print(f"{float(sys.argv[1]) * 1000:.3f}")
except Exception:
    print("0.000")
PY
)"
  printf '%s,%s,%s,%s\n' "${run}" "${http_status}" "${time_total}" "${latency_ms}" >> "${CSV_FILE}"
done

python3 - "${CSV_FILE}" "${SUMMARY_FILE}" "${VAULT_ADDR%/}${VAULT_PATH}" <<'PY'
import csv
import statistics
import sys

csv_path, summary_path, endpoint = sys.argv[1:4]

rows = list(csv.DictReader(open(csv_path, encoding="utf-8")))
success = [float(row["latency_ms"]) for row in rows if row["http_status"] == "200"]

def percentile(values, percentile_value):
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * percentile_value / 100
    lower = int(rank)
    upper = min(lower + 1, len(ordered) - 1)
    weight = rank - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight

p50 = percentile(success, 50)
p95 = percentile(success, 95)
avg = statistics.mean(success) if success else None

def fmt(value):
    return "n/a" if value is None else f"{value:.3f}"

with open(summary_path, "w", encoding="utf-8") as f:
    f.write("# Vault/KMS-style Secret Retrieval Overhead\n\n")
    f.write("## Requirement Proven\n\n")
    f.write("Measures HashiCorp Vault dev-mode KV secret-read latency as a lab proxy for KMS-style secret retrieval overhead.\n\n")
    f.write("## Command Or Evidence Source\n\n")
    f.write("`bash tests/metrics/measure-kms-overhead.sh`\n\n")
    f.write("## Observed Result\n\n")
    f.write("| Metric | Value |\n")
    f.write("|---|---:|\n")
    f.write(f"| endpoint | `{endpoint}` |\n")
    f.write(f"| attempted samples | {len(rows)} |\n")
    f.write(f"| successful HTTP 200 samples | {len(success)} |\n")
    f.write(f"| p50 latency ms | {fmt(p50)} |\n")
    f.write(f"| p95 latency ms | {fmt(p95)} |\n")
    f.write(f"| average latency ms | {fmt(avg)} |\n\n")
    f.write("## Scope And Limitation\n\n")
    f.write("This is not an AWS KMS measurement. It uses local HashiCorp Vault dev-mode secret reads as a lab proxy for secret-retrieval overhead. The script writes only HTTP status and timing data; no secret value or response body is written to evidence.\n")

if not success:
    raise SystemExit(5)
PY

echo "[INFO] Vault/KMS-style overhead evidence written under ${EVIDENCE_DIR}"
