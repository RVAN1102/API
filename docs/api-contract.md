# API Contract

## Overview

This document defines the shared API contract between the gateway layer and backend services.

---

## Base URLs

| Protocol | URL                         |
|----------|-----------------------------|
| HTTP     | `http://localhost:8000`     |
| HTTPS    | `https://localhost:8443`    |
| Admin    | `http://127.0.0.1:8001`     |

---

## Endpoints

### User Service

| Method | Path                    | Auth | Description            |
|--------|-------------------------|------|------------------------|
| GET    | /api/v1/users/health    | No   | Health check           |
| GET    | /api/v1/users/me        | Yes  | Current user identity  |
| GET    | /api/v1/users/profile   | Yes  | User profile           |

### Order Service

| Method | Path                              | Auth | Description                    |
|--------|-----------------------------------|------|--------------------------------|
| GET    | /api/v1/orders/health             | No   | Health check                   |
| GET    | /api/v1/orders                    | Yes  | List caller's orders           |
| GET    | /api/v1/orders/{orderId}          | Yes  | Get order (ownership check)    |
| GET    | /api/v1/orders/{orderId}/vulnerable | Yes | BOLA vulnerable endpoint      |
| GET    | /api/v1/orders/{orderId}/fixed    | Yes  | BOLA fixed endpoint            |

### Billing Service

| Method | Path                       | Auth | Description             |
|--------|----------------------------|------|-------------------------|
| GET    | /api/v1/billing/health     | No   | Health check            |
| POST   | /api/v1/billing/checkout   | Yes  | Initiate checkout       |
| POST   | /api/v1/webhooks/payment   | HMAC | Payment webhook callback|

### Admin Service

| Method | Path                                    | Auth | Description              |
|--------|-----------------------------------------|------|--------------------------|
| GET    | /api/v1/admin/health                    | No   | Health check             |
| POST   | /api/v1/admin/maintenance               | Yes  | Maintenance action       |
| POST   | /api/v1/admin/metadata-fetch/vulnerable | Yes  | SSRF vulnerable          |
| POST   | /api/v1/admin/metadata-fetch/fixed      | Yes  | SSRF fixed               |

---

## Required Headers

```
Authorization: Bearer <access_token>
Content-Type: application/json
X-Correlation-ID: <unique-request-id>
```

Webhook headers:
```
X-Webhook-Timestamp: <unix_timestamp>
X-Webhook-Nonce: <unique_nonce>
X-Webhook-Signature: sha256=<hex>
```

---

## JWT Claims Contract

See `idp/jwt-claims.md`.

Realm: `topic10-sme-api`  
Issuer: `http://keycloak:8080/realms/topic10-sme-api`  
JWKS: `http://keycloak:8080/realms/topic10-sme-api/protocol/openid-connect/certs`

---

## Vault Secret Paths

```
secret/data/api/webhook
secret/data/api/service-clients
secret/data/api/order-service
secret/data/api/user-service
```

---

## Sample Order Data

```
ord-alice-1001  owner: alice
ord-alice-1002  owner: alice
ord-bob-2001    owner: bob
ord-bob-2002    owner: bob
```
