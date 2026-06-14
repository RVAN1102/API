#!/usr/bin/env bash
# vault/scripts/init-dev-vault.sh
#
# Initializes Vault dev server with required secret paths for the prototype.
# Run once after 'docker compose up'.
#
# Usage:
#   bash vault/scripts/init-dev-vault.sh
#
# Requirements:
#   - Vault running at http://localhost:8200 (dev mode)
#   - VAULT_TOKEN=dev-root-token (dev mode default)

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-dev-root-token}"

echo "=== Vault Dev Init Script ==="
echo "Target: ${VAULT_ADDR}"

# Check connectivity
if ! curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null; then
  echo "ERROR: Cannot reach Vault at ${VAULT_ADDR}. Is Docker Compose running?"
  exit 1
fi

export VAULT_ADDR
export VAULT_TOKEN

# Enable KV v2 secrets engine (may already be enabled in dev mode)
vault secrets enable -version=2 -path=secret kv 2>/dev/null || echo "KV v2 already enabled at 'secret/'"

echo ""
echo "--- Writing secret paths ---"

# Webhook secret (shared with billing service and TV1 webhook demo)
vault kv put secret/api/webhook \
  webhook_secret="dev-webhook-secret-change-me"
echo "[OK] secret/api/webhook"

# Service client credentials (confidential client)
vault kv put secret/api/service-clients \
  client_id="sme-service-client" \
  client_secret="<redacted-set-in-keycloak>"
echo "[OK] secret/api/service-clients"

# Order service config
vault kv put secret/api/order-service \
  keycloak_url="http://keycloak:8080" \
  keycloak_realm="topic10-sme-api"
echo "[OK] secret/api/order-service"

# User service config
vault kv put secret/api/user-service \
  keycloak_url="http://keycloak:8080" \
  keycloak_realm="topic10-sme-api"
echo "[OK] secret/api/user-service"

echo ""
echo "--- Applying app policy ---"
vault policy write app-policy vault/policies/app-policy.hcl
echo "[OK] policy: app-policy"

echo ""
echo "=== Vault init complete ==="
echo "Access UI at: ${VAULT_ADDR}/ui"
echo "Token: dev-root-token (DEV ONLY - never use in production)"
