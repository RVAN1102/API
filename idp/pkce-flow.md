# Authorization Code + PKCE Flow

## Overview

The Authorization Code + PKCE (Proof Key for Code Exchange) flow is the
recommended OAuth2 flow for public clients (web/mobile apps). It prevents
authorization code interception attacks.

---

## Flow Diagram

```
Browser / SPA                  Kong Gateway           Keycloak IdP
     |                              |                      |
     |  1. Generate code_verifier   |                      |
     |     code_challenge = S256(code_verifier)            |
     |                              |                      |
     |  2. GET /auth?client_id=sme-web-client              |
     |         &response_type=code                         |
     |         &redirect_uri=https://localhost:5173/callback|
     |         &scope=openid profile email                 |
     |         &code_challenge=<B64URL(SHA256(verifier))>  |
     |         &code_challenge_method=S256  ───────────────>|
     |                              |                      |
     |  (User logs in + optional MFA)                      |
     |                              |                      |
     |  3. Keycloak redirects back: |                      |
     |  redirect_uri?code=<auth_code>  <───────────────────|
     |                              |                      |
     |  4. POST /token              |                      |
     |     grant_type=authorization_code                   |
     |     code=<auth_code>                                |
     |     redirect_uri=<same as step 2>                   |
     |     code_verifier=<original verifier>  ────────────>|
     |                              |                      |
     |  5. Receives: access_token, refresh_token, id_token |
     |  <──────────────────────────────────────────────────|
     |                              |                      |
     |  6. API call with Bearer access_token               |
     |  ──────────────────────────> |                      |
     |                              | forward to service   |
     |                              | (service validates   |
     |                              |  token via JWKS)     |
```

---

## Parameters

| Parameter              | Value                                         |
|------------------------|-----------------------------------------------|
| `client_id`            | `sme-web-client`                              |
| `response_type`        | `code`                                        |
| `redirect_uri`         | `https://localhost:5173/callback`              |
| `scope`                | `openid profile email`                        |
| `code_challenge_method`| `S256`                                        |
| `code_challenge`       | `BASE64URL(SHA256(code_verifier))`            |

---

## Authorization URL

```
http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/auth
```

Full example:
```
http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/auth
  ?client_id=sme-web-client
  &response_type=code
  &redirect_uri=http%3A%2F%2Flocalhost%3A5173%2Fcallback
  &scope=openid+profile+email
  &code_challenge=<B64URL_SHA256_verifier>
  &code_challenge_method=S256
```

---

## Token Exchange

```bash
curl -s -X POST \
  http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=sme-web-client" \
  -d "redirect_uri=https://localhost:5173/callback" \
  -d "code=<AUTHORIZATION_CODE>" \
  -d "code_verifier=<CODE_VERIFIER>"
```

Response:
```json
{
  "access_token": "eyJhbGciOi...<redacted>",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOi...<redacted>",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOi...<redacted>",
  "scope": "openid profile email"
}
```

---

## MFA / OTP

When MFA is enabled for a user, step 2 in the flow adds an OTP challenge screen
between username/password entry and authorization code issuance.

To configure: Keycloak Admin UI → Users → alice → Required Actions → Configure OTP.

---

## References

- Script: `demo/auth/pkce-token-request.sh`
- Keycloak docs: https://www.keycloak.org/docs/latest/securing_apps/
