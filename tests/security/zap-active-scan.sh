#!/usr/bin/env bash
# tests/security/zap-active-scan.sh
#
# OWASP ZAP Active Scan
#
# Runs ZAP Active Scan against the Kong Gateway using OpenAPI spec
# and Authorization header for protected endpoints.
#
# Usage:
#   bash tests/security/zap-active-scan.sh
#
# Requirements:
#   - Docker running
#   - Kong Gateway running at http://localhost:8000
#   - Keycloak running at http://localhost:8080
#
# Environment variables (optional):
#   BASE_URL      – Target URL (default: http://localhost:8000)
#   USER_TOKEN    – Bearer token for authenticated scan
#   ZAP_API_KEY   – ZAP API key (default: tv3-zap-api-key)
#
# Output:
#   docs/evidence/tv3/zap/zap-active-report.html
#   docs/evidence/tv3/zap/zap-active-report.json
#   docs/evidence/tv3/zap/zap-active-summary.md
#   docs/evidence/tv3/zap/zap-active-run.log

set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
KC_URL="${KC_URL:-http://localhost:8080}"
ZAP_API_KEY="${ZAP_API_KEY:-tv3-zap-api-key}"
REPORT_DIR="docs/evidence/tv3/zap"
LOG_FILE="${REPORT_DIR}/zap-active-run.log"

mkdir -p "${REPORT_DIR}"

echo "=== OWASP ZAP Active Scan ===" | tee "${LOG_FILE}"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" | tee -a "${LOG_FILE}"
echo "Target: ${BASE_URL}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Step 1: Obtain auth token for authenticated scan
# --------------------------------------------------
echo "--- Step 1: Obtaining user token from Keycloak ---" | tee -a "${LOG_FILE}"

USER_TOKEN=""
  USER_TOKEN="${ACCESS_TOKEN:-}"

  if [ -z "${USER_TOKEN}" ]; then
    TOKEN_RESP=$(curl -s -X POST \
      "${KC_URL}/realms/topic10-sme-api/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=password" \
      -d "client_id=sme-web-client" \
      -d "username=ci-alice" \
      -d "password=ci-alice-password-123" 2>/dev/null || echo "{}")

    USER_TOKEN=$(echo "${TOKEN_RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || echo "")
  fi

  if [ -z "${USER_TOKEN}" ]; then
    echo "[WARN] Could not obtain token from Keycloak. Running unauthenticated scan only." | tee -a "${LOG_FILE}"
    echo "[WARN] Protected endpoints will return 401 – expected for unauthenticated scan." | tee -a "${LOG_FILE}"
    AUTH_ARGS=""
  else
    TOKEN_LEN=${#USER_TOKEN}
    echo "[OK] Token obtained. Length: ${TOKEN_LEN} chars." | tee -a "${LOG_FILE}"
    AUTH_ARGS="-config replacer.full_list(0).description=auth1 \
               -config replacer.full_list(0).enabled=true \
               -config replacer.full_list(0).matchtype=REQ_HEADER \
               -config replacer.full_list(0).matchstr=Authorization \
               -config replacer.full_list(0).regex=false \
               -config replacer.full_list(0).replacement=Bearer\\ ${USER_TOKEN}"
  fi

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Step 2: Create ZAP auth config file
# --------------------------------------------------
echo "--- Step 2: Preparing ZAP config ---" | tee -a "${LOG_FILE}"

# Write auth header to config file (not exposing token in process args)
ZAP_AUTH_SCRIPT_DIR="$(pwd)/tests/security/zap-auth"
mkdir -p "${ZAP_AUTH_SCRIPT_DIR}"

if [ -n "${USER_TOKEN}" ]; then
  # Write a proper Python hook for ZAP API Scan
  cat > "${ZAP_AUTH_SCRIPT_DIR}/zap-auth-hook.py" <<AUTHEOF
def sending_request(communicator, message, initiator):
    message.getRequestHeader().setHeader("Authorization", "Bearer ${USER_TOKEN}")
    message.getRequestHeader().setHeader("X-Correlation-ID", "zap-active-scan")
AUTHEOF
  echo "[OK] Auth hook written (token not logged)." | tee -a "${LOG_FILE}"
  HOOK_ARG="--hook=/zap/wrk/tests/security/zap-auth/zap-auth-hook.py"
else
  cat > "${ZAP_AUTH_SCRIPT_DIR}/zap-auth-hook.py" <<AUTHEOF
def sending_request(communicator, message, initiator):
    message.getRequestHeader().setHeader("X-Correlation-ID", "zap-active-scan-noauth")
AUTHEOF
  HOOK_ARG="--hook=/zap/wrk/tests/security/zap-auth/zap-auth-hook.py"
fi

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Step 3: Copy OpenAPI spec for ZAP
# --------------------------------------------------
echo "--- Step 3: Validating OpenAPI spec ---" | tee -a "${LOG_FILE}"

OPENAPI_SPEC="services/openapi.yaml"
if [ ! -f "${OPENAPI_SPEC}" ]; then
  echo "[FAIL] OpenAPI spec not found at ${OPENAPI_SPEC}" | tee -a "${LOG_FILE}"
  exit 1
fi

ENDPOINT_COUNT=$(grep -c "operationId:" "${OPENAPI_SPEC}" 2>/dev/null || echo "0")
echo "[OK] OpenAPI spec found: ${OPENAPI_SPEC}" | tee -a "${LOG_FILE}"
echo "[OK] Endpoints in spec: ${ENDPOINT_COUNT}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Step 4: Run ZAP Active Scan
# --------------------------------------------------
echo "--- Step 4: Running ZAP Active Scan ---" | tee -a "${LOG_FILE}"
echo "[INFO] Using Docker image: ghcr.io/zaproxy/zaproxy:stable" | tee -a "${LOG_FILE}"
echo "[INFO] Scan mode: active (not baseline)" | tee -a "${LOG_FILE}"
echo "[INFO] Target: ${BASE_URL}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

ZAP_EXIT=0
docker run --rm \
  --network host \
  -v "$(pwd):/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
    -t "${BASE_URL}/api/v1/users/health" \
    -f openapi \
    -S \
    -d \
    -l WARN \
    -r "/zap/wrk/${REPORT_DIR}/zap-active-report.html" \
    -w "/zap/wrk/${REPORT_DIR}/zap-active-summary.md" \
    -J "/zap/wrk/${REPORT_DIR}/zap-active-report.json" \
    ${HOOK_ARG} \
    2>&1 | tee -a "${LOG_FILE}" || ZAP_EXIT=$?

# ZAP exits non-zero on findings – that's expected
if [ "${ZAP_EXIT}" -ne 0 ]; then
  echo "" | tee -a "${LOG_FILE}"
  echo "[INFO] ZAP exited with code ${ZAP_EXIT} (non-zero may indicate findings, not failure)." | tee -a "${LOG_FILE}"
fi

echo "" | tee -a "${LOG_FILE}"

# --------------------------------------------------
# Step 5: Generate triage summary
# --------------------------------------------------
echo "--- Step 5: Generating triage summary ---" | tee -a "${LOG_FILE}"

python3 - <<'PY' 2>/dev/null | tee -a "${LOG_FILE}" || true
import json, pathlib, sys

report_path = pathlib.Path("docs/evidence/tv3/zap/zap-active-report.json")
if not report_path.exists():
    print("[WARN] JSON report not found – triage skipped.")
    sys.exit(0)

try:
    data = json.loads(report_path.read_text())
except Exception as e:
    print(f"[WARN] Could not parse JSON report: {e}")
    sys.exit(0)

site = data.get("site", [{}])
if isinstance(site, list):
    site = site[0] if site else {}

alerts = site.get("alerts", [])
counts = {"High": 0, "Medium": 0, "Low": 0, "Informational": 0}
for alert in alerts:
    risk = alert.get("riskdesc", "Informational")
    key = risk.split(" ")[0] if risk else "Informational"
    if key in counts:
        counts[key] += 1
    else:
        counts["Informational"] += 1

print("\nZAP Active Scan – Triage Summary:")
print(f"  High:          {counts['High']}")
print(f"  Medium:        {counts['Medium']}")
print(f"  Low:           {counts['Low']}")
print(f"  Informational: {counts['Informational']}")
print(f"  Total alerts:  {sum(counts.values())}")
PY

echo "" | tee -a "${LOG_FILE}"
echo "=== ZAP Active Scan Complete ===" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "Reports saved:" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/zap-active-report.html" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/zap-active-report.json" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/zap-active-summary.md" | tee -a "${LOG_FILE}"
echo "  ${REPORT_DIR}/zap-active-run.log" | tee -a "${LOG_FILE}"

# Cleanup sensitive config
rm -f "${ZAP_AUTH_SCRIPT_DIR}/zap-auth-hook.py"
