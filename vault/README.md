# Vault Secret Management

## Overview

HashiCorp Vault is used as a persistent, sealed lab secret store for the prototype.
In production this would be Vault cluster or a managed service (AWS KMS / Secrets Manager).

Vault runs at `https://localhost:8200` from the host and
`https://vault:8200` inside Compose. Both paths trust the generated local CA.

---

## Secret Paths

| Path                            | Contents                         | Reader              |
|---------------------------------|----------------------------------|---------------------|
| `secret/data/api/webhook`       | `webhook_secret` (HMAC key)      | billing-service / webhook demo |

---

## Init Script

Run after generating certificates and starting Vault:

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d vault
bash vault/scripts/ensure-vault-ready.sh
```

This script:
1. Initializes Vault only when needed.
2. Unseals Vault when needed.
3. Enables the required KV v2 mount and seeds only `secret/data/api/webhook`.
4. Stores init material only in ignored `infra/.vault-init.json` with mode `0600`.

The script does not print the root token, unseal key, or secret value. Supply
`VAULT_TOKEN` and `VAULT_UNSEAL_KEY` explicitly only when recovering an
already-initialized Vault whose ignored init file is unavailable.

---

## Access Policy

See `vault/policies/app-policy.hcl` for path-level read permissions.

---

## Integration with Services

- `WEBHOOK_SECRET` env var in billing-service can be seeded from Vault in production.
- For this prototype, secrets are passed via Docker Compose environment variables.
- The Vault secret paths document **where** secrets would live in a real deployment.
