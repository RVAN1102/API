# IDP – Keycloak Identity Provider

## Overview

The prototype uses **Keycloak 26.0** as the OpenID Connect / OAuth2 Identity Provider.
All API services (user, order, billing, admin) delegate authentication to Keycloak.
Kong Gateway does **not** verify JWTs – verification is performed by the backend services.

---

## Realm

```text
Name:    topic10-sme-api
URL:     http://localhost:8080/realms/topic10-sme-api
```

---

## Roles

| Role              | Description                                      |
|-------------------|--------------------------------------------------|
| `user`            | Standard authenticated user                      |
| `admin`           | Administrative user with elevated access         |
| `billing-service` | Service account role for billing service         |
| `internal-service`| Service account role for internal services       |

---

## Test Users

| Username | Password            | Roles        |
|----------|---------------------|--------------|
| alice    | alice-password-123  | user         |
| bob      | bob-password-123    | user         |
| admin01  | admin-password-123  | user, admin  |

---

## Clients

### sme-web-client (Public – Authorization Code + PKCE)

```text
client_id:   sme-web-client
type:        public
flow:        Authorization Code + PKCE
pkce_method: S256
redirect_uris:
  - http://localhost:3000/*
  - http://localhost:5173/*
  - https://app.localhost/*
```

### billing-service-client (Confidential – Client Credentials)

```text
client_id:    billing-service-client
type:         confidential
flow:         Client Credentials
client_secret: <redacted>
roles:        order-ownership-read
```

### admin-service-client (Confidential – Client Credentials)

```text
client_id:    admin-service-client
type:         confidential
flow:         Client Credentials
client_secret: <redacted>
roles:        admin-maintenance
```

---

## Endpoints

| Endpoint                | URL |
|------------------------|-----|
| Authorization           | `http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/auth` |
| Token                   | `http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/token` |
| UserInfo                | `http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/userinfo` |
| JWKS                    | `http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/certs` |
| End Session             | `http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/logout` |
| Discovery               | `http://localhost:8080/realms/topic10-sme-api/.well-known/openid-configuration` |

---

## JWT Claims (Access Token)

The backend services read the following claims:

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
  "iss": "http://keycloak:8080/realms/topic10-sme-api",
  "exp": 1718272800,
  "iat": 1718272500
}
```

---

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

Manual check: open Keycloak Admin UI → Users → alice/bob/admin01 → Required
Actions and verify `Configure OTP` / `CONFIGURE_TOTP` is present.

---

## Import / Export Realm

### Import (first run via Docker Compose volume mount)
Keycloak is configured with `--import-realm`. The realm JSON at
`idp/realm-export/topic10-realm.json` is mounted to `/opt/keycloak/data/import/`.

### Manual import via Admin UI
1. Open `http://localhost:8080/admin`
2. Login: admin / admin
3. Create realm → Import from file → select `idp/realm-export/topic10-realm.json`

### Export realm
```bash
docker exec -it infra-keycloak-1 \
  /opt/keycloak/bin/kc.sh export \
  --dir /tmp/realm-export \
  --realm topic10-sme-api

docker cp infra-keycloak-1:/tmp/realm-export/topic10-sme-api-realm.json \
  idp/realm-export/topic10-realm.json
```

---

## Test Token (Password Grant – dev only)

> **Note**: password-grant login is disabled for normal human users in the realm.
> For demo token testing, use the `demo/auth/` scripts or the Admin UI token generation.

```bash
# Get token using password grant (if enabled for testing)
curl -s -X POST \
  http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=sme-web-client&username=alice&password=alice-password-123&scope=openid"
```

---

## References

- `idp/pkce-flow.md` – Authorization Code + PKCE flow
- `idp/client-credentials-flow.md` – Client Credentials flow
- `idp/jwt-claims.md` – JWT claims spec
- `demo/auth/` – Demo token scripts
