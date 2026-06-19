# Chapter 3: Architecture & Design (TV2 - Identity & Core Services)

## 3.1 Overview

The TV2 responsibilities cover the core identity provider (IdP), centralized secret management, and the implementation of the primary backend services (User and Order). The design adheres to a decentralized authorization model where the API Gateway handles routing and edge filtering, but the actual backend services validate tokens and enforce Role-Based Access Control (RBAC).

## 3.2 Identity Provider (IdP) Design

**Component:** Keycloak
**Role:** Centralized Identity and Access Management (IAM)

### 3.2.1 OAuth2/OIDC Flows
We employ two primary OAuth2 flows based on the client type:
1. **Authorization Code + PKCE:** Used for public clients (e.g., single-page apps, mobile apps). PKCE prevents authorization code interception attacks without requiring a hardcoded client secret.
2. **Client Credentials:** Used for confidential machine-to-machine (M2M) communication (e.g., the Billing service making internal API calls).

### 3.2.2 Token Architecture
Keycloak issues signed JSON Web Tokens (JWTs) using the RS256 algorithm.
- **Stateless Validation:** Backend services do not need to call Keycloak on every request. They fetch the JSON Web Key Set (JWKS) once and use it to cryptographically verify the JWT signature locally.
- **Claims:** The token payload includes standard claims (`sub`, `iss`, `exp`) and custom claims (`realm_access.roles` for RBAC, `preferred_username` for BOLA defense).

## 3.3 Authorization & Access Control (RBAC)

Authorization is enforced at the backend service layer (`authz.py`), completely decoupled from the API Gateway.

### 3.3.1 Role Definitions
- `user`: Standard access to own resources.
- `admin`: Elevated access to all resources.
- `billing-service`: Service account role for internal billing operations.

### 3.3.2 Policy Enforcement
Each FastAPI endpoint explicitly declares its required roles:
```python
def require_user_or_admin(payload: Dict[str, Any]) -> None:
    require_role(payload, "user", "admin")
```

## 3.4 BOLA Defense Design

Broken Object Level Authorization (BOLA) is mitigated by enforcing ownership checks on resource access. The Order service implements a specific check:

```python
def check_order_ownership(payload: Dict[str, Any], order_owner: str) -> None:
    # Admins bypass ownership check
    if has_role(payload, "admin"): return
    # Normal users must own the resource
    if payload.get("preferred_username") != order_owner:
        raise HTTPException(status_code=403, detail="Forbidden")
```

## 3.5 Secret Management

**Component:** HashiCorp Vault / production secret manager
**Role:** Centralized secret-management architecture

In the lab prototype, `infra/.env` is a generated local compatibility file and Docker Compose injects runtime secrets into containers via environment variables. Vault OSS dev mode demonstrates the secret paths, policies, rotation workflow, and production architecture, but the prototype does **not** claim that every service fetches every runtime secret directly from Vault.

For production, use Vault HA, cloud KMS plus a managed Secrets Manager, or an equivalent secret store. Runtime workloads should receive secrets through platform secret injection or fetch them with a least-privilege workload identity. Production evidence should include audit logs, rotation proof, policy review, and recovery testing.
