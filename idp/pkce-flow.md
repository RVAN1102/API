# Authorization Code + PKCE Flow

## Overview

Authorization Code + PKCE is the runtime flow for the public web client. It
prevents authorization code interception by binding the token exchange to a
per-request verifier.

## Parameters

| Parameter | Value |
|---|---|
| `client_id` | `sme-web-client` |
| `response_type` | `code` |
| `redirect_uri` | `https://localhost:5173/callback` |
| `scope` | `openid profile email` |
| `code_challenge_method` | `S256` |
| `code_challenge` | `BASE64URL(SHA256(code_verifier))` |

## Authorization URL

```text
https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/auth
```

Full example:

```text
https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/auth
  ?client_id=sme-web-client
  &response_type=code
  &redirect_uri=https%3A%2F%2Flocalhost%3A5173%2Fcallback
  &scope=openid+profile+email
  &code_challenge=<B64URL_SHA256_verifier>
  &code_challenge_method=S256
```

## Token Exchange

```bash
curl -k -s -X POST \
  https://localhost:8446/realms/topic10-sme-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=sme-web-client" \
  -d "redirect_uri=https://localhost:5173/callback" \
  -d "code=<AUTHORIZATION_CODE>" \
  -d "code_verifier=<CODE_VERIFIER>"
```

Response values include an access token, refresh token, ID token, expiry, token
type, and scopes. Do not commit token values.

## MFA / OTP

Human demo users have the `CONFIGURE_TOTP` required action in the realm export.
Interactive login may prompt for OTP setup before issuing an authorization
code.

## References

- Script: `demo/auth/pkce-token-request.sh`.
- Keycloak docs: `https://www.keycloak.org/docs/latest/securing_apps/`.
