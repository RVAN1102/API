#!/usr/bin/env bash
# Obtain an Admin service token using OAuth2 Client Credentials.
# Writes the raw token to /tmp/admin-service-token.txt and prints metadata only.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export SERVICE_CLIENT_ID="${ADMIN_SERVICE_CLIENT_ID:-admin-service-client}"
export SERVICE_CLIENT_SECRET="${ADMIN_SERVICE_CLIENT_SECRET:-${SERVICE_CLIENT_SECRET:-}}"
export SERVICE_TOKEN_FILE="${ADMIN_SERVICE_TOKEN_FILE:-/tmp/admin-service-token.txt}"

exec bash "${SCRIPT_DIR}/get-service-token.sh"
