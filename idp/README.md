# IDP - Keycloak Identity Provider

## Overview

The runtime uses Keycloak 26.0 as the OpenID Connect / OAuth2 identity
provider. Backend services validate JWTs themselves; Kong does not perform JWT
verification.

## Realm

```text
Name: topic10-sme-api
Internal URL: https://keycloak:8443/realms/topic10-sme-api
Local host URL: https://localhost:8446/realms/topic10-sme-api
Expected issuer: https://localhost:8446/realms/topic10-sme-api
```

Backend containers use `https://keycloak:8443` for discovery, JWKS, token, and
introspection calls. The issuer remains the local host URL because Keycloak is
started with `--hostname=https://localhost:8446`.

## Roles

| Role | Description |
|---|---|
| `user` | Standard authenticated user |
| `admin` | Administrative user with elevated access |
| `billing-service` | Service account role for billing service |
| `internal-service` | Service account role for internal service access |
| `order-ownership-read` | Billing service permission for Order ownership verification |
| `admin-maintenance` | Admin service maintenance permission |

## Test Users

| Username | Purpose | Roles |
|---|---|---|
| `alice` | human demo user | `user` |
| `bob` | human demo user | `user` |
| `admin01` | human admin demo user | `user`, `admin` |
| `ci-alice` | repeatable automation user | `user` |
| `ci-bob` | repeatable automation user | `user` |

Do not commit passwords or access tokens.

## Clients

### `sme-web-client`

```text
type: public
flow: Authorization Code + PKCE
pkce_method: S256
redirect_uris:
  - https://localhost:3000/*
  - https://localhost:5173/*
  - https://app.localhost/*
```

### `billing-service-client`

```text
type: confidential
flow: Client Credentials
secret: supplied from ignored local runtime values
roles: order-ownership-read
```

### `admin-service-client`

```text
type: confidential
flow: Client Credentials
secret: supplied from ignored local runtime values
roles: admin-maintenance
```

## OIDC Endpoints

| Endpoint | URL |
|---|---|
| Authorization | `https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/auth` |
| Token | `https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/token` |
| UserInfo | `https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/userinfo` |
| JWKS | `https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/certs` |
| End Session | `https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/logout` |
| Discovery | `https://localhost:8446/realms/topic10-sme-api/.well-known/openid-configuration` |

Backend services use the same paths on `https://keycloak:8443`.

## JWT Claims

The backend services read claims like:

```json
{
  "sub": "unique user id",
  "preferred_username": "alice",
  "email": "alice@example.local",
  "realm_access": {
    "roles": ["user", "offline_access", "uma_authorization"]
  },
  "resource_access": {},
  "scope": "openid profile email",
  "azp": "sme-web-client",
  "iss": "https://localhost:8446/realms/topic10-sme-api",
  "exp": 1718272800,
  "iat": 1718272500
}
```

## MFA / OTP Requirement

MFA setup is enforced for the demo human users in the imported realm. The realm
assigns the `CONFIGURE_TOTP` required action to `alice`, `bob`, and `admin01`,
so an interactive password-only login is not considered sufficient for these
accounts. CI/regression automation uses dedicated lab accounts/scripts so tests
remain reproducible without weakening the human-user MFA requirement.

To verify runtime MFA status:

```bash
bash demo/auth/check-keycloak-mfa-status.sh
```

To re-apply MFA required actions after a fresh realm import:

```bash
bash demo/auth/enforce-keycloak-mfa.sh
```

## Import / Export Realm

Compose starts Keycloak with `--import-realm`. The realm template at
`idp/realm-export/topic10-realm.json` is mounted read-only, and Compose injects
ignored local service-client secrets into the runtime import copy.

Manual Admin UI access:

```text
https://localhost:8446/admin
```

## Token Helpers

Use the scripts under `demo/auth/` for repeatable local tokens:

```bash
bash demo/auth/get-user-token.sh ci-alice
bash demo/auth/get-billing-service-token.sh
bash demo/auth/get-admin-service-token.sh
```

Do not print or commit token values.

## References

- `idp/pkce-flow.md` - Authorization Code + PKCE flow.
- `idp/client-credentials-flow.md` - Client Credentials flow.
- `idp/jwt-claims.md` - JWT claims contract.
- `demo/auth/` - Demo token scripts.
