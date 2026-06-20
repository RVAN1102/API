# TV1 Evidence – Edge Gateway & Webhook Security
## docs/evidence/tv1/

---

## Tổng Quan

Evidence này chứng minh các cơ chế bảo vệ tầng Edge/Gateway/Webhook của hệ thống.  
Tất cả lệnh được chạy từ thư mục gốc repo trên branch `feat/tv1-edge-webhook-closeout`.

---

## Danh Sách Evidence

| # | File | Lệnh sinh | Kỳ vọng | Trạng thái |
|---|------|-----------|---------|-----------|
| P0.1 | `p0-01-kong-route-smoke.txt` | `bash tests/security/tv1-edge-webhook-tests.sh` | 4 health → 200 | Xem file |
| P0.2 | `p0-02-kong-tls13-only.txt` | Script tự động | TLS 1.3 OK, TLS 1.2 fail | Xem file |
| P0.3 | `p0-03-kong-hsts.txt` | Script tự động | `Strict-Transport-Security` có trong response | Xem file |
| P0.4 | `p0-04-kong-cors.txt` | Script tự động | localhost → allow, evil.example → deny | Xem file |
| P0.5 | `p0-05-kong-rate-limit.txt` | Script tự động | Request >threshold → 429 | Xem file |
| P0.6 | `p0-06-kong-request-size-limit.txt` | Script tự động | Small=401, Large=413 | Xem file |
| P0.7 | `p0-07-webhook-hmac-replay.txt` | Script tự động | Valid=200, Invalid=401, Replay=403 | Xem file |
| P0.8 | `p0-08-webhook-timestamp-freshness.txt` | Script tự động | Fresh=200, Old(>300s)=403 | Xem file |
| P0.9 | `p0-09-webhook-mtls-status.md` | Manual doc | Limitation documented | ⚠️ Limitation |

---

## Cách Chạy Lại Toàn Bộ Test

```bash
cd /path/to/API
bash tests/security/tv1-edge-webhook-tests.sh
```

Kết quả được lưu tự động vào `docs/evidence/tv1/*.txt`

---

## Cách Chạy Từng Test Thủ Công

### P0.1 – Kong Route Smoke
```bash
curl -k -i https://localhost:8443/api/v1/users/health
curl -k -i https://localhost:8443/api/v1/orders/health
curl -k -i https://localhost:8443/api/v1/billing/health
curl -k -i https://localhost:8443/api/v1/admin/health
```

The lab gateway uses a local/self-signed TLS certificate, so manual curl
commands use `-k`. Production deployments must use a CA-trusted certificate.

### P0.4 – CORS
```bash
# Allowed origin
curl -k -i -X OPTIONS https://localhost:8443/api/v1/users/health \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET"

# Evil origin
curl -k -i -X OPTIONS https://localhost:8443/api/v1/users/health \
  -H "Origin: https://evil.example" \
  -H "Access-Control-Request-Method: GET"
```

### P0.5 – Rate Limit
```bash
for i in $(seq 1 15); do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -k -X POST https://localhost:8443/api/v1/admin/maintenance \
    -H "Authorization: Bearer fake.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"rate-limit-test"}')
  echo "request=$i status=$code"
done
```

### P0.7 – Webhook HMAC
```bash
bash demo/webhook/send-valid-webhook.sh
bash demo/webhook/send-invalid-signature.sh || true
bash demo/webhook/send-replay-webhook.sh || true
```

---

## Giải Thích Kết Quả

| Status Code | Ý nghĩa |
|-------------|---------|
| 200 | Request được chấp nhận bình thường |
| 401 | Thiếu hoặc sai authentication (token/signature) |
| 403 | Có authentication nhưng không đủ quyền / replay / timestamp expired |
| 413 | Payload quá lớn, bị Gateway chặn |
| 429 | Quá nhiều request, bị Rate Limit |

---

## Limitation Notes

### mTLS (P0.9)
Hệ thống prototype hiện bảo vệ webhook channel bằng:
- Webhook channel mTLS at Kong (valid client cert accepted; missing cert rejected)
- HMAC-SHA256 signature verification (tầng ứng dụng)
- Redis-backed nonce replay protection
- Timestamp freshness check (300s window)

Gateway-to-backend mTLS is enforced by default in `infra/docker-compose.yml`. Kong routes to `user/order/billing/admin` through HTTPS/mTLS Nginx sidecars, and the sidecars reject callers that do not present a valid Kong client certificate. Runtime test output is written to ignored `.artifacts/test-runs/` by default; the committed file under `docs/evidence/tv1/gateway-backend-mtls/` is the official review snapshot. Internal Billing-to-Order ownership is still protected with short-lived Keycloak Client Credentials and least-privilege service roles; webhook ingress uses a separate mTLS channel plus HMAC/timestamp/nonce.
