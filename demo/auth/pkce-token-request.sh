#!/usr/bin/env bash
# demo/auth/pkce-token-request.sh
#
# Demonstrates Authorization Code + PKCE flow steps.
# Because the browser redirect step is interactive, this script prints
# the authorization URL and then provides a helper to exchange the code.
#
# Usage:
#   Step 1: bash demo/auth/pkce-token-request.sh url
#   Step 2: Open the URL in a browser, login, copy the ?code= from redirect
#   Step 3: bash demo/auth/pkce-token-request.sh exchange <code> <code_verifier>

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYCLOAK_CACERT="${KEYCLOAK_CACERT:-${PROJECT_ROOT}/infra/certs/gateway-backend/ca.crt}"
CURL_TLS_ARGS=()
if [ -s "${KEYCLOAK_CACERT}" ]; then
  CURL_TLS_ARGS=(--cacert "${KEYCLOAK_CACERT}")
fi


KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8446}"
REALM="topic10-sme-api"
CLIENT_ID="sme-web-client"
REDIRECT_URI="https://localhost:5173/callback"

ACTION="${1:-url}"

case "${ACTION}" in
  url)
    # Generate a simple code verifier (43-128 chars, URL-safe)
    CODE_VERIFIER=$(python3 -c "
import base64, os
verifier = base64.urlsafe_b64encode(os.urandom(32)).rstrip(b'=').decode()
print(verifier)
")

    CODE_CHALLENGE=$(python3 -c "
import base64, hashlib
verifier = '${CODE_VERIFIER}'
digest = hashlib.sha256(verifier.encode()).digest()
challenge = base64.urlsafe_b64encode(digest).rstrip(b'=').decode()
print(challenge)
")

    echo "=== PKCE Authorization Code Flow ==="
    echo ""
    echo "Code verifier (save this!): ${CODE_VERIFIER}"
    echo "Code challenge:             ${CODE_CHALLENGE}"
    echo ""
    AUTH_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth"
    AUTH_URL="${AUTH_URL}?client_id=${CLIENT_ID}"
    AUTH_URL="${AUTH_URL}&response_type=code"
    AUTH_URL="${AUTH_URL}&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REDIRECT_URI}'))")"
    AUTH_URL="${AUTH_URL}&scope=openid+profile+email"
    AUTH_URL="${AUTH_URL}&code_challenge=${CODE_CHALLENGE}"
    AUTH_URL="${AUTH_URL}&code_challenge_method=S256"
    echo "Step 1 – Open this URL in your browser:"
    echo ""
    echo "  ${AUTH_URL}"
    echo ""
    echo "Step 2 – After login, copy the 'code' param from the redirect URL."
    echo "Step 3 – Run:"
    echo "  bash demo/auth/pkce-token-request.sh exchange <code> ${CODE_VERIFIER}"
    ;;

  exchange)
    AUTH_CODE="${2:-}"
    CODE_VERIFIER="${3:-}"
    if [ -z "${AUTH_CODE}" ] || [ -z "${CODE_VERIFIER}" ]; then
      echo "Usage: $0 exchange <auth_code> <code_verifier>"
      exit 1
    fi
    TOKEN_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
    echo "=== Exchanging authorization code for tokens ==="
    RESPONSE=$(curl "${CURL_TLS_ARGS[@]}" -sf -X POST "${TOKEN_URL}" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=authorization_code" \
      -d "client_id=${CLIENT_ID}" \
      -d "redirect_uri=${REDIRECT_URI}" \
      -d "code=${AUTH_CODE}" \
      -d "code_verifier=${CODE_VERIFIER}")
    echo "${RESPONSE}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('access_token:', data.get('access_token','')[:60], '...<redacted>')
print('expires_in:', data.get('expires_in'))
print('token_type:', data.get('token_type'))
"
    ;;

  *)
    echo "Usage: $0 [url|exchange <code> <verifier>]"
    exit 1
    ;;
esac
