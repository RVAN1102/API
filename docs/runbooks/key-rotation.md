# Runbook – Key Rotation

**Version:** 1.0  
**Maintainer:** Security/operations reviewer
**Last updated:** 2026-06-17  
**Purpose:** Step-by-step procedure for rotating secrets and cryptographic keys

---

## Overview

This runbook covers rotation of:
1. Webhook HMAC secret
2. Keycloak client secret (`kong-client`)
3. Vault / KMS root token (if applicable)
4. Service JWT signing key

**Security rule:** Never log secret values. Always verify after rotation.

---

## 1. Webhook HMAC Secret Rotation

### Prerequisites

- Access to Docker Compose environment
- Vault CLI or direct Vault API access
- Admin credentials (not logged in this runbook)

### Steps

```bash
# Step 1: Verify current system is healthy
curl -s https://localhost:8443/api/v1/users/health | python3 -c "import sys,json; print(json.load(sys.stdin))"
# Expected: {"status": "ok"}

# Step 2: Generate new HMAC secret (64 hex chars = 256-bit)
NEW_SECRET=$(openssl rand -hex 32)
echo "New secret length: ${#NEW_SECRET} chars"
# NEVER echo "${NEW_SECRET}" in logs

# Step 3: Store new secret in Vault
vault kv put secret/webhook WEBHOOK_SECRET="${NEW_SECRET}"
# Vault confirms: Success! Data written to secret/webhook

# Step 4: Restart webhook service to pick up new secret
docker compose -f infra/docker-compose.yml restart webhook-service
sleep 10

# Step 5: Test new secret works
TIMESTAMP=$(date +%s)
PAYLOAD='{"event":"test.rotation","order_id":"test-001"}'
NEW_SIG=$(echo -n "${TIMESTAMP}.${PAYLOAD}" | openssl dgst -sha256 -hmac "${NEW_SECRET}" -hex | cut -d' ' -f2)

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST https://localhost:8443/api/v1/auth/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Timestamp: ${TIMESTAMP}" \
  -H "X-Webhook-Signature: sha256=${NEW_SIG}" \
  -H "X-Webhook-Nonce: rotation-verify-$(date +%s)" \
  -d "${PAYLOAD}")
echo "New secret test: HTTP ${STATUS}"
# Expected: 200

# Step 6: Invalidate new secret variable
unset NEW_SECRET
echo "Secret cleared from memory."
```

### Post-Rotation Verification

```bash
# Verify old secret no longer works (optional – if you kept old secret for testing)
# Do NOT keep old secrets in environment

# Run smoke test
curl -s https://localhost:8443/api/v1/users/health
```

### Rollback

```bash
# If rotation fails, restore previous Vault version:
vault kv rollback secret/webhook
docker compose -f infra/docker-compose.yml restart webhook-service
```

---

## 2. Keycloak Client Secret Rotation (`kong-client`)

### Steps

```bash
# Step 1: Get admin token (admin credentials used in terminal only)
# ADMIN_TOKEN obtained via Keycloak admin console or API

# Step 2: Get client UUID
CLIENT_UUID=$(curl -s \
  "http://localhost:8080/admin/realms/myrealm/clients?clientId=kong-client" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "Client UUID: ${CLIENT_UUID}"

# Step 3: Regenerate client secret
NEW_SECRET_RESP=$(curl -s -X POST \
  "http://localhost:8080/admin/realms/myrealm/clients/${CLIENT_UUID}/client-secret" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
echo "New secret length: $(echo $NEW_SECRET_RESP | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["value"]))')"

# Step 4: Update Kong JWT plugin / environment with new secret
# (Kong reads client_secret from config or service env)
docker compose -f infra/docker-compose.yml restart kong billing-service order-service

# Step 5: Test auth flow
curl -s -X POST \
  "http://localhost:8080/realms/myrealm/protocol/openid-connect/token" \
  -d "grant_type=client_credentials&client_id=kong-client&client_secret=[NEW_SECRET]" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Token length: {len(d.get(\"access_token\",\"\"))}')"
```

---

## 3. Service JWT Signing Key (Keycloak realm key)

```bash
# Step 1: Generate new RSA key pair in Keycloak Admin Console
# Keycloak → Realm Settings → Keys → Add Keystore
# Set priority higher than current key

# Step 2: Wait for key propagation (Keycloak handles this automatically)

# Step 3: Test JWT validation still works
curl -s https://localhost:8443/api/v1/users/me \
  -H "Authorization: Bearer $NEW_TOKEN" | python3 -c "import sys,json; print('OK')"

# Step 4: (Optional) Retire old key after TTL expires (> 300s)
# Remove old key from Keycloak → Realm Settings → Keys
```

---

## Checklist (All Rotation Types)

- [ ] System healthy before rotation
- [ ] New secret/key generated with strong entropy
- [ ] Secret stored in Vault / secret manager (NOT in env file committed to repo)
- [ ] Services restarted / refreshed
- [ ] New secret verified working (HTTP 200)
- [ ] Old secret rejected if applicable (HTTP 401)
- [ ] Secret variable unset from shell (`unset SECRET`)
- [ ] No secret logged in terminal / evidence
- [ ] Smoke test passed
- [ ] Post-rotation evidence recorded (output log, not secret values)

---

## Security Rules

1. ❌ Never `echo $SECRET` in logs
2. ❌ Never commit secrets to git
3. ❌ Never store secrets in plaintext files
4. ✅ Always use Vault or environment injection
5. ✅ Always unset secret variables after use
6. ✅ Always verify old credentials are rejected after rotation
7. ✅ Log rotation event (not secret value): `vault kv metadata get secret/webhook`

---

## Evidence Template

After each rotation, record in `docs/evidence/tv3/resilience/key-rotation-output.txt`:

```
Date: YYYY-MM-DDTHH:MM:SSZ
Rotation type: webhook_hmac | client_secret | jwt_signing_key
Old secret: [NOT LOGGED]
New secret: [NOT LOGGED]
New secret length: <N> chars
Pre-rotation health: HTTP 200
Post-rotation health: HTTP 200
New credentials work: HTTP <code>
Old credentials rejected: HTTP <code>
Total time: <N> seconds
```
