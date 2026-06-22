#!/usr/bin/env bash
# Thin wrapper around the Loki LogQL threshold-based MTTD/MTTR measurement.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/docs/evidence/tv3/metrics"
CONSOLE_FILE="${EVIDENCE_DIR}/mttd-mttr-run-console.txt"
SAMPLE_FILE="${EVIDENCE_DIR}/correlation-id-log-sample.json"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"

mkdir -p "${EVIDENCE_DIR}"

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

set +e
bash "${SCRIPT_DIR}/measure-mttd-mttr.sh" 2>&1 | tee "${CONSOLE_FILE}"
status="${PIPESTATUS[0]}"
set -e
[ "${status}" -eq 0 ] || die "measure-mttd-mttr.sh failed; see ${CONSOLE_FILE}."

python3 - "${LOKI_URL}" "${SAMPLE_FILE}" <<'PY'
import json
import sys
import time
import urllib.parse
import urllib.request

loki_url, sample_file = sys.argv[1:3]
patterns = ["mttd-403-bola", "mttd-401", "mttd-429"]
selectors = [
    '{job="docker"}',
    '{container=~".*kong.*"}',
    '{container=~".*user.*"}',
    '{container=~".*order.*"}',
    '{container=~".+"}',
    '{}',
]
end_ns = int(time.time() * 1_000_000_000)
start_ns = end_ns - 60 * 60 * 1_000_000_000

def query_loki(selector, pattern):
    query = f'{selector} |= "{pattern}"'
    params = urllib.parse.urlencode({
        "query": query,
        "limit": "5",
        "direction": "BACKWARD",
        "start": str(start_ns),
        "end": str(end_ns),
    })
    url = loki_url.rstrip("/") + "/loki/api/v1/query_range?" + params
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.load(response)

for pattern in patterns:
    for selector in selectors:
        try:
            payload = query_loki(selector, pattern)
        except Exception:
            continue
        result = payload.get("data", {}).get("result", [])
        if result:
            with open(sample_file, "w", encoding="utf-8") as f:
                json.dump({
                    "source": "Loki LogQL threshold polling",
                    "selector": selector,
                    "pattern": pattern,
                    "result": result[:1],
                    "scope": "correlation-ID sample for MTTD/MTTR scenario evidence; not Grafana alert firing evidence",
                }, f, indent=2)
                f.write("\n")
            print(f"[INFO] Wrote Loki correlation sample for {pattern} to {sample_file}")
            raise SystemExit(0)

raise SystemExit(4)
PY

if [ ! -s "${SAMPLE_FILE}" ]; then
  die "No Loki log sample found for mttd-403-bola, mttd-401, or mttd-429; no fake evidence was created."
fi
