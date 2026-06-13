#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
routes=(
  "/api/v1/users/health"
  "/api/v1/orders/health"
  "/api/v1/billing/health"
  "/api/v1/admin/health"
)

for route in "${routes[@]}"; do
  status="$(curl --silent --show-error --output /tmp/tv1-route-body.txt \
    --write-out '%{http_code}' "${BASE_URL}${route}")"
  printf '%-32s HTTP %s\n' "${route}" "${status}"
  cat /tmp/tv1-route-body.txt
  printf '\n'
  [[ "${status}" == "200" ]]
done

