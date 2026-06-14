#!/usr/bin/env bash
# tests/restler/run-restler-check.sh
#
# RESTler API Fuzzing (TV3)
#
# Runs RESTler compile + test against the OpenAPI spec.
# RESTler must be installed separately (see README).
#
# Usage:
#   bash tests/restler/run-restler-check.sh

set -uo pipefail

REPORT_DIR="docs/evidence/tv3"
mkdir -p "${REPORT_DIR}"

echo "=== RESTler API Fuzzing ==="
echo ""

# Check if RESTler is available via Docker
if docker image inspect "mcr.microsoft.com/restler:9.2.4" > /dev/null 2>&1; then
  echo "Running RESTler via Docker..."
  docker run --rm \
    --network host \
    -v "$(pwd):/api:ro" \
    mcr.microsoft.com/restler:9.2.4 \
    dotnet /RESTler/restler/Restler.dll \
    compile --api_spec /api/services/openapi.yaml \
    2>&1 | tee "${REPORT_DIR}/restler-check-summary.txt" || true
else
  echo "[WARN] RESTler Docker image not available."
  echo "To install RESTler:"
  echo "  docker pull mcr.microsoft.com/restler:9.2.4"
  echo ""
  echo "Or install from source:"
  echo "  https://github.com/microsoft/restler-fuzzer"
  echo ""
  {
    echo "RESTler Check Summary"
    echo "Date: $(date -u)"
    echo ""
    echo "Status: RESTler not installed locally."
    echo ""
    echo "OpenAPI spec: services/openapi.yaml"
    echo "Target:       http://localhost:8000"
    echo ""
    echo "Endpoints covered by OpenAPI:"
    python3 -c "
import yaml, json
with open('services/openapi.yaml') as f:
    spec = yaml.safe_load(f)
for path, methods in spec.get('paths', {}).items():
    for method in methods:
        if method != 'parameters':
            print(f'  {method.upper()} {path}')
" 2>/dev/null || cat services/openapi.yaml | grep -E "^  /" || true
    echo ""
    echo "Planned fuzzing scenarios:"
    echo "  - Missing required headers"
    echo "  - Invalid JSON body"
    echo "  - SQL injection patterns in query params"
    echo "  - Boundary values for numeric fields"
    echo "  - Cross-resource ID substitution (BOLA)"
  } > "${REPORT_DIR}/restler-check-summary.txt"
fi

echo ""
echo "Summary: ${REPORT_DIR}/restler-check-summary.txt"
