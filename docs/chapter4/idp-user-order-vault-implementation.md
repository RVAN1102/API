# Chapter 4: Implementation - Identity, Core Services, Vault

## 4.1 Keycloak Implementation

Keycloak is deployed via Docker Compose. The realm configuration is codified in `idp/realm-export/topic10-realm.json`.

### 4.1.1 Realm Configuration (`topic10-sme-api`)
- **Clients:** `sme-web-client` (Public, PKCE), `billing-service-client`
  (`order-ownership-read`), and `admin-service-client`
  (`admin-maintenance`).
- **Users:** Test accounts `alice`, `bob` (users) and `admin01` (admin).
- **MFA:** `CONFIGURE_TOTP` is assigned as a required action for lab human
  users (`alice`, `bob`, `admin01`). CI automation uses dedicated lab accounts.

## 4.2 Core Services (User & Order)

The services are built using **FastAPI**.

### 4.2.1 JWT Validation (`auth.py`)
Both services use `python-jose` to validate incoming Bearer tokens.
1. Extract token from `Authorization` header.
2. Fetch JWKS from Keycloak (cached in memory).
3. Verify RS256 signature, `exp`, and `iss`.
4. Return decoded payload.

### 4.2.2 Order Service & BOLA Demo
The Order service provides two endpoints to demonstrate BOLA:
- `/api/v1/orders/{id}/vulnerable`: Only checks token validity. Susceptible to IDOR/BOLA.
- `/api/v1/orders/{id}/fixed`: Implements `check_order_ownership` to ensure the caller matches the resource owner.

## 4.3 Vault Implementation

HashiCorp Vault is deployed in dev mode for the prototype.

### 4.3.1 Initialization
The script `vault/scripts/init-dev-vault.sh` runs automatically to:
1. Enable KV v2 secrets engine.
2. Inject placeholder secrets (e.g., `secret/data/api/webhook`).
3. Apply access policies (`vault/policies/app-policy.hcl`).

### 4.3.2 Secret Usage
In a production environment, services would authenticate with Vault (e.g., via AppRole or Kubernetes auth) to retrieve their specific secrets. For this prototype, the paths and policies are defined to demonstrate the architecture.

## 4.4 Testing Evidence

Automated bash scripts in `tests/auth/` validate the implementation:
- `test-user-profile.sh`: Verifies 401 on unauthenticated access and 200 on authenticated access.
- `test-order-access.sh`: Verifies RBAC logic for listing orders.
- `bola-object-access.sh`: Demonstrates that Alice can access Bob's order via the vulnerable endpoint, but receives a 403 Forbidden on the fixed endpoint.
