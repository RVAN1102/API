#!/usr/bin/env bash
# Obtain a Billing service token using OAuth2 Client Credentials.
# Writes the raw token to /tmp/billing-service-token.txt and prints metadata only.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export SERVICE_CLIENT_ID="${BILLING_SERVICE_CLIENT_ID:-billing-service-client}"
export SERVICE_CLIENT_SECRET="${BILLING_SERVICE_CLIENT_SECRET:-${SERVICE_CLIENT_SECRET:-}}"
export SERVICE_TOKEN_FILE="${BILLING_SERVICE_TOKEN_FILE:-/tmp/billing-service-token.txt}"

exec bash "${SCRIPT_DIR}/get-service-token.sh"
