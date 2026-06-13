#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"

curl --silent --show-error --include --request OPTIONS \
  "${BASE_URL}/api/v1/users/profile" \
  --header "Origin: http://localhost:5173" \
  --header "Access-Control-Request-Method: GET" \
  --header "Access-Control-Request-Headers: Authorization,X-Correlation-ID"

