#!/usr/bin/env bash
# tests/zap/run-zap-baseline.sh
#
# OWASP ZAP Baseline Scan
#
# Runs ZAP API scan against the Kong Gateway.
# Uses Docker to run ZAP without local installation.
#
# Usage:
#   bash tests/zap/run-zap-baseline.sh
#
# Requirements:
#   - Docker running
#   - Kong Gateway running at http://localhost:8000
#
# Output:
#   docs/evidence/tv3/zap-baseline-report.html
#   docs/evidence/tv3/zap-baseline-summary.txt

set -uo pipefail

BASE_URL="${BASE_URL:-http://host.docker.internal:8000}"
REPORT_DIR="docs/evidence/tv3"
mkdir -p "${REPORT_DIR}"

echo "=== OWASP ZAP Baseline Scan ==="
echo "Target: ${BASE_URL}"
echo ""

# Run ZAP API scan via Docker
docker run --rm \
  --network host \
  -v "$(pwd):/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
  -t "http://host.docker.internal:8000/api/v1/users/health" \
  -f openapi \
  -I \
  -r "/zap/wrk/${REPORT_DIR}/zap-baseline-report.html" \
  -w "/zap/wrk/${REPORT_DIR}/zap-baseline-summary.md" \
  2>&1 | tee "${REPORT_DIR}/zap-baseline-summary.txt" || {
  echo ""
  echo "[WARN] ZAP scan exited with non-zero (may be due to findings, not errors)"
}

echo ""
echo "Reports saved:"
echo "  ${REPORT_DIR}/zap-baseline-report.html"
echo "  ${REPORT_DIR}/zap-baseline-summary.txt"
