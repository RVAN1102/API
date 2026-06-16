#!/usr/bin/env bash
# Compatibility wrapper for the safe Client Credentials helper.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/get-service-token.sh"
