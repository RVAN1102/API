# TV2 AuthN/AuthZ model summary

## Identity Provider

The prototype uses Keycloak as the Identity Provider for realm `topic10-sme-api`. Keycloak manages demo users, OIDC token issuance, client configuration, role assignment, and MFA required actions.

## Client model

The project design uses OAuth2/OIDC. Public user login is represented by the Authorization Code + PKCE contract. Backend or machine-to-machine integration can use a confidential service client with Client Credentials when the corresponding script and evidence are available.

## Demo identities

`alice` is a normal user account with role `user`. This identity is used to test user profile access, own-order access, and authenticated billing checkout.

`bob` is a normal user account with role `user`. This identity is used to test the BOLA ownership boundary.

`admin01` is an administrator account with role `admin`. This identity is used to test admin-only access control.

## JWT validation

Backend services validate JWTs server-side. The validation model requires signature verification through JWKS, issuer validation against the expected external issuer, and role extraction from trusted token claims. The system keeps a distinction between the internal Keycloak URL used to fetch JWKS and the issuer value used to validate the `iss` claim.

## Authorization model

The current prototype uses RBAC plus service-level ownership checks. `/api/v1/users/me` requires a valid token. `/api/v1/admin/maintenance` requires the `admin` role. `/api/v1/orders/{order_id}/fixed` requires the requester to be the resource owner or an authorized admin depending on the implemented service policy. `/api/v1/billing/checkout` requires a valid authenticated token.

## BOLA handling

`/api/v1/orders/{order_id}/vulnerable` is intentionally vulnerable and is retained only as a controlled demonstration of Broken Object Level Authorization. `/api/v1/orders/{order_id}/fixed` is the mitigation endpoint and blocks non-owner access.

## MFA enforcement

The local Keycloak runtime now enforces MFA setup for demo human users by assigning the `CONFIGURE_TOTP` required action to `alice`, `bob`, and `admin01`. This means password-only interactive login should not be treated as sufficient for these users.

## OPA/RBAC decision

The current closeout branch treats RBAC plus ownership checks as the implemented authorization model. If OPA is not implemented in the runtime prototype, the report must not claim OPA enforcement. OPA can be listed as a future improvement or optional fine-grained authorization extension.
