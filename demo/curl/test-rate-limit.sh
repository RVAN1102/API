#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
TARGET="${BASE_URL}/api/v1/admin/maintenance"
seen_429=0

for request_number in $(seq 1 25); do
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --request POST "${TARGET}" \
    --header "Content-Type: application/json" \
    --data '{"fetch_url":"https://example.com/health"}')"
  printf 'request=%02d status=%s\n' "${request_number}" "${status}"
  [[ "${status}" == "429" ]] && seen_429=1
done

[[ "${seen_429}" == "1" ]] || {
  echo "Expected at least one HTTP 429 response" >&2
  exit 1
}
