# Vault Secret Management (TV2)

## Overview

HashiCorp Vault (dev mode) is used to centralize secrets for the prototype.
In production this would be Vault cluster or a managed service (AWS KMS / Secrets Manager).

Vault runs at: `http://localhost:8200`
Dev root token: `dev-root-token` (dev mode only, never commit to production)

---

## Secret Paths

| Path                            | Contents                         | Reader              |
|---------------------------------|----------------------------------|---------------------|
| `secret/data/api/webhook`       | `webhook_secret` (HMAC key)      | billing-service, TV1 |
| `secret/data/api/service-clients`| `client_id`, `client_secret`    | billing-service, admin-service |
| `secret/data/api/order-service` | Order service credentials        | order-service       |
| `secret/data/api/user-service`  | User service credentials         | user-service        |

---

## Init Script

Run after `docker compose up`:

```bash
bash vault/scripts/init-dev-vault.sh
```

This script:
1. Enables the KV v2 secrets engine.
2. Creates placeholder secrets at all required paths.
3. Applies the app policy from `vault/policies/app-policy.hcl`.

---

## Manual Operations

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=dev-root-token

# Health check
vault status

# Read webhook secret
vault kv get secret/api/webhook

# Write secret (dev only, never commit real values)
vault kv put secret/api/webhook webhook_secret="dev-webhook-secret-change-me"
```

---

## Access Policy

See `vault/policies/app-policy.hcl` for path-level read permissions.

---

## Integration with Services

- `WEBHOOK_SECRET` env var in billing-service can be seeded from Vault in production.
- For this prototype, secrets are passed via Docker Compose environment variables.
- The Vault secret paths document **where** secrets would live in a real deployment.
