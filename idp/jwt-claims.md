# JWT Claims Contract

## Overview

All backend services (user, order, billing, admin) validate JWT access tokens
issued by Keycloak. This document defines the claim contract.

---

## Required Claims

| Claim                   | Type   | Description                              |
|-------------------------|--------|------------------------------------------|
| `sub`                   | string | Unique user/service identifier (UUID)    |
| `preferred_username`    | string | Human-readable username (alice, bob)     |
| `email`                 | string | User email address                       |
| `realm_access.roles`    | array  | List of realm-level roles                |
| `resource_access`       | object | Client-specific roles (optional)         |
| `scope`                 | string | Granted scopes                           |
| `azp`                   | string | Authorized party (client_id)             |
| `exp`                   | int    | Expiration Unix timestamp                |
| `iss`                   | string | Issuer URL (must match Keycloak realm)   |
| `aud`                   | array  | Audience claim; used as fallback for token-client allowlist checks |

---

## Example Access Token (User)

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
  "iss": "http://keycloak:8080/realms/topic10-sme-api",
  "exp": 1718272800,
  "iat": 1718272500
}
```

---

## Validation Steps (Backend)

All services perform these steps in `auth.py`:

1. Extract Bearer token from `Authorization` header.
2. Decode header (unverified) to get `kid`.
3. Fetch JWKS from `{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs`.
4. Find matching key by `kid`.
5. Verify JWT signature with RS256.
6. Verify `exp` (not expired).
7. Verify `iss` == `http://keycloak:8080/realms/topic10-sme-api`.
8. Enforce token-client binding with `azp` / `client_id` and audience
   fallback against each service's allowed client set.
9. Extract `realm_access.roles` for RBAC.
10. Return identity object to route handler.

---

## RBAC Role Mapping

| Role              | Permission                                        |
|-------------------|---------------------------------------------------|
| `user`            | Access own profile, own orders                    |
| `admin`           | Access profile, all orders, admin endpoints       |
| `billing-service` | Service-to-service billing calls                  |
| `internal-service`| Internal service calls                            |

---

## Security Notes

- Tokens expire in 300 seconds (5 minutes) by default.
- JWKS is cached in-memory; refreshed when a new `kid` is encountered.
- User-facing calls use human-client allowlists, while service-to-service calls
  use dedicated service-client allowlists and roles.
- Do NOT log full access tokens. Log only `sub` and `preferred_username`.
