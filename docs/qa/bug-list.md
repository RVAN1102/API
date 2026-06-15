# Core QA Bug List

## BUG-001: Admin maintenance endpoint accepts fake token

* Severity: Critical
* Area: Admin/Authz
* Found by: TV2 QA
* Endpoint: `POST /api/v1/admin/maintenance`
* Command:

```bash
curl -i -X POST http://localhost:8000/api/v1/admin/maintenance \
  -H "Authorization: Bearer fake.jwt.token" \
  -H "Content-Type: application/json" \
  -d '{"action":"reindex"}'
```

* Expected:

  * `401 Unauthorized` nếu token không hợp lệ.
  * Hoặc `403 Forbidden` nếu token hợp lệ nhưng không có role `admin`.

* Actual:

  * `200 OK`
  * Response cho thấy action vẫn được thực thi:

```json
{"status":"executed","action":"reindex","correlation_id":"..."}
```

* Evidence:

  * `docs/evidence/qa/fake-token-checks.txt`

* Root cause:

  * Admin maintenance endpoint chưa enforce JWT validation và chưa kiểm tra role `admin`.

* Suggested fix:

  * Bắt buộc kiểm tra `Authorization: Bearer <token>`.
  * Verify JWT signature, issuer, expiration.
  * Kiểm tra role `admin`.
  * Chỉ cho phép request hợp lệ thực thi action quản trị.

* Status: Open

## BUG-002: Billing checkout accepts malformed fake token

* Severity: High
* Area: Billing/Auth
* Endpoint: `POST /api/v1/billing/checkout`
* Found by: TV2 QA
* Command:

```bash
curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Authorization: Bearer fake.jwt.token" \
  -H "Content-Type: application/json" \
  -d '{"order_id":"ord-alice-1001","amount":120000,"currency":"VND"}'
```

* Expected:

  * `401 Unauthorized` vì `fake.jwt.token` không phải JWT hợp lệ.
  * Request không được tạo payment/checkout.

* Actual:

  * `202 Accepted`
  * Response cho thấy payment vẫn được tạo:

```json
{"payment_id":"pay-9a5ed563","order_id":"ord-alice-1001","status":"accepted","amount":120000.0,"currency":"VND","correlation_id":"eeaa16ab-c13b-4aa7-a684-f60a480876b0"}
```

* Evidence:

  * `docs/evidence/qa/billing-auth-checks.txt`

* Root cause:

  * Billing checkout endpoint có thể chỉ kiểm tra sự tồn tại của `Authorization` header, nhưng chưa verify JWT signature, issuer, expiration, audience hoặc role/scope.

* Security impact:

  * Attacker có thể gửi bất kỳ chuỗi token giả nào trong header `Authorization` để tạo checkout/payment.
  * Điều này làm sai mô hình centralized authentication/authorization của hệ thống.

* Suggested fix:

  * Bắt buộc verify Bearer JWT bằng JWKS của Keycloak.
  * Reject token malformed/invalid/expired bằng `401 Unauthorized`.
  * Kiểm tra role/scope phù hợp, ví dụ `user`, `billing-service` hoặc rule cụ thể cho checkout.
  * Không tạo `payment_id` nếu token chưa được xác thực hợp lệ.

* Status: Open

### Additional evidence

File evidence bổ sung:

- `docs/evidence/qa/billing-malformed-token-variants.txt`

Kết quả kiểm thử cho thấy endpoint chỉ reject khi thiếu token, token rỗng hoặc sai scheme, nhưng lại chấp nhận mọi chuỗi Bearer không rỗng:

```text
Authorization: Bearer abc              → 202 Accepted
Authorization: Bearer fake.jwt.token   → 202 Accepted
Authorization: Bearer                  → 403 Forbidden
Authorization: Basic abc123            → 403 Forbidden
No Authorization header                → 403 Forbidden
