# Client Credentials Flow (TV2)

## Overview

The Client Credentials flow is an OAuth2 flow for machine-to-machine (M2M)
authentication. It allows backend services to obtain tokens without user interaction.

Used in this prototype for:
- Billing service authenticating as a service account
- Internal service-to-service calls

---

## Flow Diagram

```
Service / Script               Keycloak IdP
     |                              |
     |  POST /token                 |
     |  grant_type=client_credentials|
     |  client_id=sme-service-client|
     |  client_secret=<redacted>  ──>|
     |                              |
     |  Receives: access_token  <───|
     |                              |
     |  API call with Bearer token  |
     |  ──────────────────────────> |
```

---

## Token Request

```bash
curl -s -X POST \
  http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=sme-service-client" \
  -d "client_secret=${SERVICE_CLIENT_SECRET}"
```

Response:
```json
{
  "access_token": "eyJhbGciOi...<redacted>",
  "expires_in": 300,
  "token_type": "Bearer",
  "scope": "billing-service internal-service"
}
```

---

## Service Client Configuration

| Parameter     | Value                     |
|---------------|---------------------------|
| `client_id`   | `sme-service-client`      |
| `type`        | confidential              |
| `flow`        | Client Credentials        |
| `roles`       | billing-service, internal-service |
| `secret`      | Set in Keycloak Admin UI  |

> **Never commit `client_secret` to git.** Store in environment variable or Vault:
> `secret/data/api/service-clients`

---

## JWT Claims in Service Token

```json
{
  "sub": "<service-account-uuid>",
  "azp": "sme-service-client",
  "realm_access": {
    "roles": ["billing-service", "internal-service"]
  },
  "scope": "billing-service internal-service",
  "iss": "http://localhost:8080/realms/topic10-sme-api",
  "exp": 1718272800
}
```

---

## Vault Secret Path

```text
secret/data/api/service-clients
```

Contains: `client_id`, `client_secret` (not committed to git).

---

## References

- Script: `demo/auth/client-credentials-token.sh`
- Vault: `vault/README.md`
