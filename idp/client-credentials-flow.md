# Client Credentials Flow

## Overview

The Client Credentials flow is used for machine-to-machine authentication.
Billing and Admin each use a dedicated confidential client with least-privilege
roles.

Used in this runtime for:

- Billing service authenticating as `billing-service-client` for
  `order-ownership-read`.
- Admin service authenticating as `admin-service-client` for
  `admin-maintenance`.

## Token Request

```bash
curl -k -s -X POST \
  https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=billing-service-client" \
  -d "client_secret=${BILLING_SERVICE_CLIENT_SECRET}"
```

Response values include an access token, expiry, token type, and scope. Do not
print or commit token values.

## Service Client Configuration

| Parameter | Value |
|---|---|
| `client_id` | `billing-service-client` / `admin-service-client` |
| `type` | confidential |
| `flow` | Client Credentials |
| `roles` | `order-ownership-read` / `admin-maintenance` |
| `secret` | supplied from ignored local runtime values |

Never commit `client_secret` values. Use local environment variables or the
documented lab secret workflow.

## JWT Claims In Service Token

```json
{
  "sub": "<service-account-uuid>",
  "azp": "billing-service-client",
  "realm_access": {
    "roles": ["order-ownership-read"]
  },
  "scope": "order-ownership-read",
  "iss": "https://localhost:8446/realms/topic10-sme-api",
  "exp": 1718272800
}
```

## References

- Script: `demo/auth/get-billing-service-token.sh`.
- Script: `demo/auth/get-admin-service-token.sh`.
