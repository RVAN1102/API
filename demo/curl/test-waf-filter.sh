#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
CURL_TLS_OPTS="${CURL_TLS_OPTS:---insecure}"

curl() { command curl ${CURL_TLS_OPTS} "$@"; }

echo "===== valid request ====="
curl --silent --show-error --include "${BASE_URL}/api/v1/users/health"

echo "===== SQLi probe (expected HTTP 403) ====="
curl --silent --show-error --include --get "${BASE_URL}/api/v1/users/profile" \
  --data-urlencode "search=' OR 1=1"

echo "===== invalid method (expected HTTP 404/405) ====="
curl --silent --show-error --include --request TRACE \
  "${BASE_URL}/api/v1/users/health"

echo "===== oversized body (expected edge rejection) ====="
head -c 1100000 /dev/zero | tr '\0' 'A' | \
  curl --silent --show-error --include --request POST \
    "${BASE_URL}/api/v1/billing/checkout" \
    --header "Content-Type: text/plain" \
    --data-binary @-
