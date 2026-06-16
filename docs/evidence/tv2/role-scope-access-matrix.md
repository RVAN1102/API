# Role/scope access matrix

| Endpoint | No token | user | admin | Note |
|---|---:|---:|---:|---|
| GET /api/v1/users/me | 401/403 | 200 | 200 if token has compatible profile claim | Requires valid token |
| POST /api/v1/admin/maintenance | 401/403 | 403 | 200 | Admin-only RBAC |
| GET /api/v1/orders/{order_id}/vulnerable | 401/403 | 200 for demo cross-owner read | 200 if authenticated | Intentional BOLA demo endpoint |
| GET /api/v1/orders/{order_id}/fixed | 401/403 | owner=200, non-owner=403 | 200 if admin is allowed by policy | Ownership check mitigation |
| POST /api/v1/billing/checkout | 401/403 | 202 | 202 if admin is allowed by policy | Authenticated checkout |
