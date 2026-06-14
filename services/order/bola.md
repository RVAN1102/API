# BOLA (Broken Object Level Authorization) Design (TV2)

## Overview

BOLA (also known as IDOR – Insecure Direct Object Reference) is the #1 API
security risk in the OWASP API Security Top 10.

This service demonstrates both the vulnerability and the fix.

## Vulnerable Endpoint

`GET /api/v1/orders/{orderId}/vulnerable`

**Flaw**: Only checks that a valid JWT exists. Does NOT verify that the
caller is the owner of the requested order.

```python
# Only checks token validity – no ownership check
require_user_or_admin(payload)
order = ORDERS.get(order_id)
return order  # Any authenticated user can see any order!
```

## Fixed Endpoint

`GET /api/v1/orders/{orderId}/fixed`

**Fix**: Checks token validity AND compares `preferred_username` against
the order's `owner_id`.

```python
require_user_or_admin(payload)
order = ORDERS.get(order_id)
check_order_ownership(payload, order["owner_id"])  # Raises 403 if not owner
return order
```

## Demo Scenarios

| User  | Order          | Endpoint   | Expected Result |
|-------|----------------|------------|-----------------|
| alice | ord-bob-2001   | /vulnerable | 200 (BOLA flaw) |
| alice | ord-bob-2001   | /fixed      | 403 (blocked)   |
| bob   | ord-bob-2001   | /fixed      | 200 (owner)     |
| admin01 | ord-bob-2001 | /fixed    | 200 (admin role)|

## References

- OWASP API Security Top 10: API1:2023 BOLA
- `authz.py` – `check_order_ownership()` function
- `tests/attack/bola-object-access.sh` – attack simulation script
