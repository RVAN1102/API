# Identity And Authorization

## Requirement

The API must authenticate callers, enforce roles, protect object ownership, and
separate human user access from service-client access.

## Keycloak

Source: `idp/realm-export/topic10-realm.json`.

- Realm: `topic10-sme-api`.
- Human demo users include `alice`, `bob`, and `admin01`.
- Human demo users have `CONFIGURE_TOTP` required action in the realm export.
- Automation users are separate lab accounts for repeatable tests.
- Service clients include `billing-service-client` and `admin-service-client`.

`http://localhost:8080` is the lab-local Keycloak endpoint.

## OIDC And PKCE

The user-facing web client supports Authorization Code + PKCE. Helper scripts
under `demo/auth/` obtain local test tokens without documentation needing to
store token values.

## Backend Enforcement

| Service | Enforcement |
|---|---|
| User | JWT validation and `user` or `admin` role for profile endpoints |
| Order | JWT validation, list scoping, protected order ownership, internal service-client ownership endpoint |
| Billing | JWT validation, checkout ownership verification through Order, idempotency handling |
| Admin | JWT validation, admin or service-client maintenance access, SSRF fixed endpoint authorization |

OPA is used for selected authorization decisions in Order, Billing, and Admin.
The docs claim OPA behavior only for paths supported by code and evidence.

## Service-To-Service Authorization

Billing uses `billing-service-client` for Order ownership verification.
Admin maintenance uses `admin-service-client`. Curated evidence records
least-privilege behavior: each service client is allowed only on its intended
service path and rejected from unrelated paths.

## Evidence

Rerunnable commands:

```bash
bash tests/security/client-credentials-tests.sh
bash tests/security/authz-negative-tests.sh
bash tests/security/opa-authz-tests.sh
bash tests/security/token-lifecycle-tests.sh
bash tests/security/s2s-ownership-tests.sh
```

The curated S2S evidence records `25/25` assertions passed.

