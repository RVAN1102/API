#!/usr/bin/env bash
# demo/auth/client-credentials-token.sh
#
# Get a service token using the Client Credentials flow.
# Alias for demo/auth/get-service-token.sh with more verbose output.
#
# Usage:
#   SERVICE_CLIENT_SECRET=<secret> bash demo/auth/client-credentials-token.sh

set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="topic10-sme-api"
CLIENT_ID="${SERVICE_CLIENT_ID:-sme-service-client}"
CLIENT_SECRET="${SERVICE_CLIENT_SECRET:-}"

if [ -z "${CLIENT_SECRET}" ]; then
  echo "ERROR: SERVICE_CLIENT_SECRET is not set."
  echo ""
  echo "Obtain the secret from Keycloak Admin UI:"
  echo "  1. Open http://localhost:8080/admin"
  echo "  2. Select realm: topic10-sme-api"
  echo "  3. Clients → sme-service-client → Credentials → Client secret"
  echo ""
  echo "Then run:"
  echo "  SERVICE_CLIENT_SECRET=<secret> bash demo/auth/client-credentials-token.sh"
  exit 1
fi

TOKEN_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"

echo "=== Client Credentials Flow ==="
echo "Token endpoint: ${TOKEN_URL}"
echo "Client ID:      ${CLIENT_ID}"
echo ""

RESPONSE=$(curl -sf -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}")

echo "Raw response (token redacted):"
echo "${RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['access_token'] = data.get('access_token','')[:40] + '...<redacted>'
print(json.dumps(data, indent=2))
"
echo ""

ACCESS_TOKEN=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "${ACCESS_TOKEN}" > /tmp/service-token.txt
echo "Full token saved to /tmp/service-token.txt"
