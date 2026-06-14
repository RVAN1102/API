# Order Service (TV2)

## Overview

FastAPI-based Order Service with BOLA demo endpoints.

## Endpoints

| Method | Path                              | Auth Required | Description                    |
|--------|-----------------------------------|---------------|--------------------------------|
| GET    | /api/v1/orders/health             | No            | Health check                   |
| GET    | /api/v1/orders                    | Yes (Bearer)  | List caller's orders           |
| GET    | /api/v1/orders/{orderId}          | Yes (Bearer)  | Get order (ownership check)    |
| GET    | /api/v1/orders/{orderId}/vulnerable | Yes (Bearer) | BOLA vulnerable (no ownership) |
| GET    | /api/v1/orders/{orderId}/fixed    | Yes (Bearer)  | BOLA fixed (ownership check)   |

## Sample Data

| Order ID         | Owner |
|-----------------|-------|
| ord-alice-1001  | alice |
| ord-alice-1002  | alice |
| ord-bob-2001    | bob   |
| ord-bob-2002    | bob   |

## BOLA Demo

```bash
# BOLA Vulnerable: Alice reads Bob's order → 200 (flaw)
curl http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable \
  -H "Authorization: Bearer ${ALICE_TOKEN}"

# BOLA Fixed: Alice reads Bob's order → 403 (protected)
curl http://localhost:8000/api/v1/orders/ord-bob-2001/fixed \
  -H "Authorization: Bearer ${ALICE_TOKEN}"
```
