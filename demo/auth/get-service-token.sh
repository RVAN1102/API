#!/usr/bin/env bash
# demo/auth/get-service-token.sh
#
# Get an access token for the service account using Client Credentials flow.
# Used for service-to-service calls (billing, internal).
#
# Usage:
#   SERVICE_CLIENT_SECRET=<secret> bash demo/auth/get-service-token.sh
#
# Environment variables:
#   KEYCLOAK_URL            – default: http://localhost:8080
#   SERVICE_CLIENT_ID       – default: sme-service-client
#   SERVICE_CLIENT_SECRET   – REQUIRED (set in Keycloak Admin UI, stored in Vault)

set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="topic10-sme-api"
CLIENT_ID="${SERVICE_CLIENT_ID:-sme-service-client}"
CLIENT_SECRET="${SERVICE_CLIENT_SECRET:-}"

if [ -z "${CLIENT_SECRET}" ]; then
  echo "ERROR: SERVICE_CLIENT_SECRET is required."
  echo "Obtain it from Keycloak Admin UI: Clients → sme-service-client → Credentials"
  exit 1
fi

TOKEN_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"

echo "=== Getting service token (Client Credentials) ==="
echo "Token URL: ${TOKEN_URL}"
echo "Client ID: ${CLIENT_ID}"
echo ""

RESPONSE=$(curl -sf -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}")

ACCESS_TOKEN=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Service token (first 60 chars):"
echo "${ACCESS_TOKEN:0:60}..."
echo ""
echo "Token saved to /tmp/service-token.txt"
echo "${ACCESS_TOKEN}" > /tmp/service-token.txt
