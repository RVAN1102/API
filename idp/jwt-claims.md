# JWT Claims Contract

## Overview

All backend services validate JWT access tokens issued by Keycloak. This
document defines the claim contract for the final HTTPS runtime.

## Required Claims

| Claim | Type | Description |
|---|---|---|
| `sub` | string | Unique user/service identifier |
| `preferred_username` | string | Human-readable username for user tokens |
| `email` | string | User email address when present |
| `realm_access.roles` | array | Realm-level roles |
| `resource_access` | object | Client-specific roles when present |
| `scope` | string | Granted scopes |
| `azp` | string | Authorized party / client id |
| `exp` | int | Expiration Unix timestamp |
| `iss` | string | Issuer URL |
| `aud` | array/string | Audience; fallback for token-client allowlist checks |

Expected issuer:

```text
https://localhost:8446/realms/topic10-sme-api
```

## Example Access Token Claims

```json
{
  "sub": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "preferred_username": "alice",
  "email": "alice@example.local",
  "realm_access": {
    "roles": [
      "user",
      "offline_access",
      "uma_authorization"
    ]
  },
  "resource_access": {
    "account": {
      "roles": ["manage-account", "view-profile"]
    }
  },
  "scope": "openid profile email",
  "azp": "sme-web-client",
  "iss": "https://localhost:8446/realms/topic10-sme-api",
  "exp": 1718272800,
  "iat": 1718272500
}
```

## Validation Steps

All services perform these steps:

1. Extract Bearer token from `Authorization` header.
2. Decode header without trust to get `kid`.
3. Fetch JWKS from `{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs`.
4. Find matching key by `kid`.
5. Verify JWT signature from JWKS: RS256 with RSA-4096 signing key. RS256 is
   the JWT/JWS algorithm, and RSA-4096 is the RSA modulus size.
6. Verify `exp`.
7. Verify `iss` equals `https://localhost:8446/realms/topic10-sme-api`.
8. Enforce token-client binding with `azp` / `client_id` and audience fallback
   against each service's allowed client set.
9. Extract `realm_access.roles` for RBAC.
10. Return identity object to the route handler.

## RBAC Role Mapping

| Role | Permission |
|---|---|
| `user` | Access own profile and own orders |
| `admin` | Access profile, all orders, and admin endpoints |
| `billing-service` | Billing service identity |
| `internal-service` | Internal service access |
| `order-ownership-read` | Order ownership verification |
| `admin-maintenance` | Admin maintenance action |

## Security Notes

- Tokens expire in 300 seconds by default.
- JWKS is cached in memory and refreshed when a new `kid` is encountered.
- User-facing calls use human-client allowlists.
- Service-to-service calls use dedicated service-client allowlists and roles.
- Do not log full access tokens. Log only stable non-secret identifiers such as
  `sub` and `preferred_username`.
