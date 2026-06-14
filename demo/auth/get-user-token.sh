#!/usr/bin/env bash
# demo/auth/get-user-token.sh
#
# Get an access token for a test user using Keycloak Direct Grant (password flow).
# This is for DEMO/DEV purposes only.
#
# Usage:
#   bash demo/auth/get-user-token.sh [alice|bob|admin01]
#
# Environment variables:
#   KEYCLOAK_URL   – default: http://localhost:8080
#   USERNAME       – default: alice
#   PASSWORD       – default: alice-password-123

set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="topic10-sme-api"
CLIENT_ID="sme-web-client"
USERNAME="${1:-${USERNAME:-alice}}"

# Map username to password (dev only)
case "${USERNAME}" in
  alice)   PASSWORD="${PASSWORD:-alice-password-123}" ;;
  bob)     PASSWORD="${PASSWORD:-bob-password-123}" ;;
  admin01) PASSWORD="${PASSWORD:-admin-password-123}" ;;
  *)       PASSWORD="${PASSWORD:-}" ;;
esac

if [ -z "${PASSWORD}" ]; then
  echo "ERROR: No password for user '${USERNAME}'. Set PASSWORD env var."
  exit 1
fi

TOKEN_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"

echo "=== Getting token for user: ${USERNAME} ==="
echo "Token URL: ${TOKEN_URL}"
echo ""

RESPONSE=$(curl -sf -X POST "${TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "scope=openid profile email")

ACCESS_TOKEN=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Access token (first 60 chars):"
echo "${ACCESS_TOKEN:0:60}..."
echo ""
echo "Full token saved to /tmp/user-token.txt"
echo "${ACCESS_TOKEN}" > /tmp/user-token.txt
echo ""
echo "To use in curl:"
echo "  ACCESS_TOKEN=\$(cat /tmp/user-token.txt)"
echo "  curl -H \"Authorization: Bearer \${ACCESS_TOKEN}\" http://localhost:8000/api/v1/users/me"
