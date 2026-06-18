# Runbook – Onboarding New Client / BFF Pattern (TV3 P1-04)

**Version:** 1.0  
**Owner:** TV3 (Huy)  
**Last updated:** 2026-06-17  
**Purpose:** Step-by-step guide for onboarding a new API client or BFF (Backend-For-Frontend)

---

## Client Types

| Client Type | OAuth Flow | Use Case |
|------------|-----------|---------|
| Public client (SPA, Mobile) | Authorization Code + PKCE | User-facing apps |
| Confidential client (BFF) | Authorization Code + secret | Server-side web app |
| Machine client (M2M) | Client Credentials | Service-to-service |

---

## 1. Public Client (SPA / Mobile) – Authorization Code + PKCE

### Step 1: Create Client in Keycloak

```bash
# Via Keycloak Admin Console: http://localhost:8080/admin
# Realm: myrealm
# Clients → Create client

# Key settings:
# - Client ID: my-spa-client
# - Client type: OpenID Connect
# - Client authentication: OFF (public)
# - Authorization Code + PKCE: ON
# - Standard flow: enabled
# - Redirect URIs: https://app.example.com/callback
# - Web origins: https://app.example.com (CORS)
```

**Via Admin API:**
```bash
curl -s -X POST \
  "http://localhost:8080/admin/realms/myrealm/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "my-spa-client",
    "publicClient": true,
    "standardFlowEnabled": true,
    "attributes": {"pkce.code.challenge.method": "S256"},
    "redirectUris": ["https://app.example.com/callback"],
    "webOrigins": ["https://app.example.com"],
    "protocol": "openid-connect"
  }'
echo "Public client created."
```

### Step 2: Assign Minimum Scopes/Roles

```bash
# Assign only required scopes (principle of least privilege):
# openid, profile, email – for user identity
# roles – for RBAC if needed

# Do NOT assign: admin scopes, service scopes
```

### Step 3: Configure Token TTL

```bash
# In Keycloak: Clients → my-spa-client → Advanced
# Access Token Lifespan: 300 seconds (5 minutes)
# Refresh Token Lifespan: 1800 seconds (30 minutes)
```

### Step 4: Test Auth Flow

```bash
# PKCE flow (client generates code_verifier + code_challenge)
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d '=+/' | cut -c -43)
CODE_CHALLENGE=$(echo -n "${CODE_VERIFIER}" | sha256sum | cut -d' ' -f1 | xxd -r -p | base64 | tr -d '=+/' | tr '/+' '_-')

echo "code_verifier length: ${#CODE_VERIFIER}"
echo "code_challenge: ${CODE_CHALLENGE}"
```

---

## 2. Confidential Client (BFF) – Authorization Code + Client Secret

### Step 1: Create Client

```bash
curl -s -X POST \
  "http://localhost:8080/admin/realms/myrealm/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "my-bff-client",
    "publicClient": false,
    "secret": null,
    "standardFlowEnabled": true,
    "redirectUris": ["https://bff.example.com/callback"],
    "webOrigins": ["https://bff.example.com"],
    "protocol": "openid-connect"
  }'
```

### Step 2: Get Generated Secret

```bash
CLIENT_UUID=$(curl -s "http://localhost:8080/admin/realms/myrealm/clients?clientId=my-bff-client" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

# Get secret (length only – don't log value)
SECRET_LEN=$(curl -s "http://localhost:8080/admin/realms/myrealm/clients/${CLIENT_UUID}/client-secret" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin)['value']))")
echo "Client secret length: ${SECRET_LEN}"

# Store in Vault immediately (not in code/env files)
# vault kv put secret/bff-client CLIENT_SECRET="<retrieved_value>"
```

### Step 3: Configure in BFF

```python
# In BFF application (not hardcoded – fetch from Vault/env):
import os
CLIENT_ID = os.getenv("BFF_CLIENT_ID", "my-bff-client")
CLIENT_SECRET = os.getenv("BFF_CLIENT_SECRET")  # From Vault injection
if not CLIENT_SECRET:
    raise ValueError("BFF_CLIENT_SECRET required – fetch from Vault")
```

---

## 3. Machine Client (M2M) – Client Credentials

### Step 1: Create Client

```bash
curl -s -X POST \
  "http://localhost:8080/admin/realms/myrealm/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "my-service-client",
    "publicClient": false,
    "serviceAccountsEnabled": true,
    "standardFlowEnabled": false,
    "directAccessGrantsEnabled": false,
    "protocol": "openid-connect"
  }'
echo "M2M client created."
```

### Step 2: Assign Service Role

```bash
# Assign only the role this service needs (e.g., "billing-reader")
# NOT admin or broad roles
```

### Step 3: Test Client Credentials Flow

```bash
# Get service token (length only logged)
RESP=$(curl -s -X POST \
  "http://localhost:8080/realms/myrealm/protocol/openid-connect/token" \
  -d "grant_type=client_credentials&client_id=my-service-client&client_secret=[SECRET]")
TOKEN_LEN=$(echo "${RESP}" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('access_token','')))")
echo "Service token obtained (length=${TOKEN_LEN})"
```

### Step 4: Configure Token TTL

```bash
# Machine tokens: shorter TTL = better (reduce blast radius)
# Recommended: 300 seconds (5 minutes)
# Set in Keycloak: Clients → my-service-client → Advanced → Access Token Lifespan
```

---

## Secret Storage

| Environment | Storage Method |
|-------------|---------------|
| Local dev | `.env` file (NOT committed to git, listed in `.gitignore`) |
| Lab | Vault OSS (`vault kv put`) |
| Production | AWS Secrets Manager / GCP Secret Manager / Azure Key Vault |

---

## Security Checklist (New Client)

- [ ] Client type matches use case (public/confidential/M2M)
- [ ] Minimum required scopes only
- [ ] Redirect URI whitelist configured (no wildcards `*`)
- [ ] CORS allowed origins set (no `*`)
- [ ] Token TTL: 300s access / 1800s refresh
- [ ] Client secret stored in Vault / secrets manager
- [ ] Client secret NOT in git / .env files committed
- [ ] Test checklist: auth flow, token refresh, token expiry
- [ ] Service roles assigned (principle of least privilege)

---

## Offboarding / Revoking a Client

```bash
# Step 1: Disable client (users can no longer obtain tokens)
curl -s -X PUT \
  "http://localhost:8080/admin/realms/myrealm/clients/${CLIENT_UUID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'
echo "Client disabled."

# Step 2: Revoke all active sessions
curl -s -X POST \
  "http://localhost:8080/admin/realms/myrealm/clients/${CLIENT_UUID}/client-secret" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
echo "Client secret regenerated (invalidates existing tokens at TTL)."

# Step 3: Delete client after confirmation
curl -s -X DELETE \
  "http://localhost:8080/admin/realms/myrealm/clients/${CLIENT_UUID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
echo "Client deleted."
```

---

## SME Managed-Services Recommendation

| Component | Self-hosted | Managed |
|-----------|------------|---------|
| Identity Provider | Keycloak (OSS) | AWS Cognito / Auth0 / Firebase Auth |
| Secret Storage | Vault OSS | AWS Secrets Manager ($5/month) |
| API Gateway | Kong OSS | AWS API Gateway / Apigee |
| Notes | Free but requires ops | Managed, SLA, lower ops overhead |

**Recommendation for SME:** Start with managed IdP (Cognito free tier) + managed secrets (AWS Secrets Manager) to reduce operational overhead.
