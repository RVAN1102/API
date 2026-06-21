# TV1 – Edge Gateway, Network Hardening & Webhook Security
## Technical Summary

**Branch:** `feat/tv1-edge-webhook-closeout`  
**Date:** 2026-06-16  
**Author:** TV1

---

## 1. Gateway Routing via Kong

Kong API Gateway routes tất cả traffic từ clients vào các microservice nội bộ:

| Route | Upstream Service | Port |
|-------|-----------------|------|
| `/api/v1/users/*` | user-service | 8001 |
| `/api/v1/orders/*` | order-service | 8002 |
| `/api/v1/billing/*` | billing-service | 8003 |
| `/api/v1/admin/*` | admin-service | 8004 |
| `/api/v1/webhooks/*` | billing-service | 8003 |

Evidence: `p0-01-kong-route-smoke.txt`

---

## 2. TLS 1.3 Termination

Kong được cấu hình chỉ chấp nhận TLS 1.3 trên port 8443. TLS 1.2 và thấp hơn bị từ chối.

```text
ssl_protocols TLSv1.3;
```

Evidence: `p0-02-kong-tls13-only.txt`

---

## 3. HSTS (HTTP Strict Transport Security)

HTTPS response bao gồm header:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

Điều này buộc browser tự động dùng HTTPS cho tất cả request sau đó.

Evidence: `p0-03-kong-hsts.txt`

---

## 4. Strict CORS Policy

Chỉ các origin được whitelist mới được phép:

- `http://localhost:3000`
- `http://localhost:3002`

Origin lạ (e.g., `https://evil.example`) không nhận được `Access-Control-Allow-Origin` header.

Evidence: `p0-04-kong-cors.txt`

---

## 5. Rate Limiting

Kong giới hạn số request per minute trên tất cả các route để giảm thiểu brute force và credential stuffing.

Khi vượt ngưỡng: **HTTP 429 Too Many Requests**

Evidence: `p0-05-kong-rate-limit.txt`

---

## 6. Request Size Limiting

Kong chặn payload lớn hơn 1MB tại tầng gateway trước khi forward vào upstream service.

- Payload nhỏ (<1MB): đi qua, upstream xử lý (401 nếu không có auth)
- Payload lớn (>1MB): bị chặn **HTTP 413 Request Entity Too Large**

Evidence: `p0-06-kong-request-size-limit.txt`

---

## 7. Webhook HMAC Verification

Endpoint `/api/v1/webhooks/payment` thực hiện xác thực HMAC-SHA256:

```
Message = timestamp + "." + nonce + "." + raw_body
Signature header = "sha256=<hex_digest>"
Algorithm = HMAC-SHA256
Secret = WEBHOOK_SECRET (env var, không hardcode)
```

- ✅ Valid signature → 200 Accepted
- ❌ Invalid signature → 401 Unauthorized
- ❌ Tampered body → 401 Unauthorized

Evidence: `p0-07-webhook-hmac-replay.txt`

---

## 8. Replay Protection

Mỗi webhook request phải có header `X-Webhook-Nonce` duy nhất. Nonce đã dùng được lưu in-memory và từ chối ở lần gửi lại:

- Lần 1 (nonce mới): 200 Accepted
- Lần 2 (cùng nonce): **403 Forbidden** – `replayed_nonce`

Evidence: `p0-07-webhook-hmac-replay.txt`

---

## 9. Timestamp Freshness Status

Billing service kiểm tra `X-Webhook-Timestamp` không được cũ hơn `WEBHOOK_MAX_AGE_SECONDS` (mặc định 300 giây):

```python
WEBHOOK_MAX_AGE_SECONDS: int = int(os.environ.get("WEBHOOK_MAX_AGE_SECONDS", "300"))
age = abs(now - timestamp)
if age > WEBHOOK_MAX_AGE_SECONDS:
    raise HTTPException(status_code=403, detail={"error": "timestamp_expired"})
```

- ✅ Timestamp hiện tại → Accepted
- ❌ Timestamp >300s cũ → **403 Forbidden** – `timestamp_expired`

Evidence: `p0-08-webhook-timestamp-freshness.txt`

---

## 10. mTLS Status

**Implemented for webhook ingress:** Webhook channel mTLS is enforced at Kong and verified by Billing through the gateway-injected `X-Mtls-Client-Verified: SUCCESS` signal.

Evidence:
- Valid webhook client certificate → accepted with HTTP 200.
- Missing client certificate → rejected with HTTP 401.
- mTLS is separate from the application-layer HMAC signature, timestamp freshness, and replay nonce controls.

Bảo vệ webhook hiện tại gồm:
- Kong-side webhook mTLS client certificate verification
- HMAC-SHA256 signature verification
- Redis-backed nonce replay protection
- Timestamp freshness check

Gateway-to-backend mTLS is a separate control from webhook ingress mTLS. The default Docker Compose runtime routes Kong to User/Order/Billing/Admin through HTTPS/mTLS Nginx sidecars. Runtime evidence proves that Kong presents an internal client certificate, callers without a valid client certificate are rejected, wrong/self-signed certificates are rejected, and the valid Kong client certificate is accepted. Billing-to-Order ownership verification also uses the Order mTLS sidecar with a Billing client certificate plus short-lived Keycloak Client Credentials and least-privilege service roles, while webhook ingress uses a separate mTLS channel plus HMAC/timestamp/nonce.

Chi tiết: `p0-09-webhook-mtls-status.md`

---

## 11. Limitations

| # | Limitation | Hướng xử lý |
|---|-----------|-------------|
| L1 | Gateway-to-backend mTLS hiện đã bật trong default Compose nhưng vẫn là sidecar-based lab PKI, chưa phải full service mesh | Production nên dùng service mesh/internal PKI với tự động rotation, workload identity và policy enforcement toàn bộ east-west traffic |
| L2 | Webhook nonce store dùng Redis TTL trong lab, không bảo vệ ngoài timestamp/TTL window | Production dùng managed Redis/DB TTL với monitoring |
| L3 | Kong Admin API (port 8001) không nên expose public | Nên bind vào internal network only |
| L4 | WAF module (ModSecurity/OWASP CRS) chưa tích hợp vào Kong | Kong hiện dùng pre-function plugin thủ công |
| L5 | Rate limit per-IP, chưa per-user | Cần key-based rate limiting cho authenticated routes |

---

## 12. Evidence Files

| File | Nội dung | Trạng thái |
|------|----------|-----------|
| `p0-01-kong-route-smoke.txt` | Kong route & health check | Xem file |
| `p0-02-kong-tls13-only.txt` | TLS 1.3 pass, TLS 1.2 fail | Xem file |
| `p0-03-kong-hsts.txt` | HSTS header | Xem file |
| `p0-04-kong-cors.txt` | CORS allowed/evil origin | Xem file |
| `p0-05-kong-rate-limit.txt` | Rate limit 429 | Xem file |
| `p0-06-kong-request-size-limit.txt` | Request size 413 | Xem file |
| `p0-07-webhook-hmac-replay.txt` | HMAC valid/invalid/replay | Xem file |
| `p0-08-webhook-timestamp-freshness.txt` | Timestamp freshness | Xem file |
| `p0-09-webhook-mtls-status.md` + `gateway-backend-mtls/` | Webhook mTLS implemented; Gateway-to-backend mTLS enforced by default through sidecars | Implemented/default runtime |
