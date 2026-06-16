# TV1 P0.9 – Webhook mTLS Status

## Hiện Trạng

**Trạng thái: ⚠️ LIMITATION – mTLS chưa triển khai**

---

## Kiểm Tra Thực Tế

Lệnh kiểm tra:
```bash
grep -RIn "mtls\|client certificate\|ssl_verify_client\|client_cert\|ca.crt\|client.crt" . \
  --include="*.yml" --include="*.yaml" --include="*.conf" --include="*.py" \
  | grep -v ".git"
```

Kết quả: **Không tìm thấy cấu hình mTLS** trong codebase.

---

## Bảo Vệ Hiện Có (Tầng Ứng Dụng)

Thay vì mTLS, webhook channel hiện được bảo vệ bằng 3 lớp ở tầng ứng dụng:

| Cơ chế | Header | Mô tả |
|--------|--------|-------|
| HMAC-SHA256 | `X-Webhook-Signature` | Xác thực tính toàn vẹn và nguồn gốc của payload |
| Nonce | `X-Webhook-Nonce` | Chống replay attack |
| Timestamp | `X-Webhook-Timestamp` | Giới hạn cửa sổ hợp lệ 300 giây |

---

## Sự Khác Biệt: HMAC vs mTLS

| | HMAC (hiện có) | mTLS (chưa có) |
|-|---------------|---------------|
| Tầng | Application (HTTP) | Transport (TLS) |
| Xác thực gì | Tính toàn vẹn payload | Identity của client |
| Cần gì | Shared secret | Client certificate + CA |
| Reject khi nào | Sai signature / replay / timestamp | Không có cert / cert không hợp lệ |

**HMAC và mTLS là hai cơ chế bổ sung cho nhau, không thay thế nhau.**

---

## Hướng Triển Khai mTLS (Nếu Cần)

Nếu hệ thống cần triển khai mTLS thật sự:

1. **Tạo CA và client certificate:**
```bash
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -out ca.crt -days 365
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -out client.crt
```

2. **Cấu hình Kong để yêu cầu client cert:**
```yaml
# kong.yml service config
tls_client_auth:
  ca_certificates: [<ca-cert-id>]
```

3. **Client gửi request với cert:**
```bash
curl --cert client.crt --key client.key \
  https://localhost:8443/api/v1/webhooks/payment
```

---

## Kết Luận

> Prototype đồ án hiện triển khai bảo vệ webhook ở tầng ứng dụng (HMAC-SHA256 + nonce + timestamp).  
> mTLS ở tầng transport là hướng hardening tiếp theo, phù hợp khi hệ thống chuyển sang production.  
> Không được gọi HMAC là mTLS. Đây là hai cơ chế khác nhau.
