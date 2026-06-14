# Order Service RBAC Policy (TV2)

## Authorization Rules

| Role    | /health | /orders | /orders/{id} | /vulnerable | /fixed |
|---------|---------|---------|-------------|-------------|--------|
| (none)  | ✅       | ❌       | ❌           | ❌           | ❌      |
| user    | ✅       | ✅ (own) | ✅ (own)     | ✅           | ✅ (own)|
| admin   | ✅       | ✅ (all) | ✅ (all)     | ✅           | ✅ (all)|

## Ownership Check Logic

For `GET /orders/{orderId}` and `GET /orders/{orderId}/fixed`:
1. Validate JWT (`auth.py`)
2. Check role is `user` or `admin` (`authz.py:require_user_or_admin`)
3. Look up order by ID
4. Call `check_order_ownership(payload, order.owner_id)`
   - Admin → always allowed
   - Other → `preferred_username` must equal `order.owner_id`
   - Mismatch → raise HTTP 403
