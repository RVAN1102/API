# User Service RBAC Policy (TV2)

## Authorization Rules

| Role    | /health | /me | /profile |
|---------|---------|-----|----------|
| (none)  | ✅       | ❌   | ❌        |
| user    | ✅       | ✅   | ✅        |
| admin   | ✅       | ✅   | ✅        |

## Implementation

RBAC is enforced at the service level via `authz.py`.
The service validates JWT and checks `realm_access.roles`.

Gateway (Kong) does NOT enforce authorization – it only routes.
Authorization is a backend responsibility.

## Rules

- `/health` – public, no token required
- `/me` – requires role `user` OR `admin` (any authenticated user)
- `/profile` – requires role `user` OR `admin` (any authenticated user)

## Error Responses

- `401 Unauthorized` – missing or invalid JWT
- `403 Forbidden` – valid JWT but insufficient role
