#!/usr/bin/env bash
# vault/scripts/init-dev-vault.sh
#
# Compatibility entry point for the idempotent HTTPS Vault readiness workflow.
#
# Usage:
#   bash vault/scripts/init-dev-vault.sh
#
set -euo pipefail

exec bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/ensure-vault-ready.sh"
