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

## BUG-003: Billing/Admin services use HTTPBearer as authentication instead of JWT verification

- Severity: Critical
- Area: Billing/Admin/Auth
- Affected files:
  - `services/billing/main.py`
  - `services/admin/main.py`

- Evidence:
  - `docs/evidence/qa/fake-token-checks.txt`
  - `docs/evidence/qa/billing-auth-checks.txt`
  - `docs/evidence/qa/billing-malformed-token-variants.txt`

- Root cause:
  - Billing and Admin use `HTTPBearer(auto_error=True)` and `credentials = Depends(security)` as if it were JWT authentication.
  - `HTTPBearer` only validates that the request has an Authorization header using the Bearer scheme. It does not verify JWT signature, issuer, expiration, audience, realm, role, or scope.
  - As a result, any non-empty Bearer token such as `Bearer abc` or `Bearer fake.jwt.token` can pass the dependency.

- Expected:
  - Malformed token must return `401 Unauthorized`.
  - Expired token must return `401 Unauthorized`.
  - Valid token without required role must return `403 Forbidden`.
  - Admin maintenance must require role `admin`.
  - Billing checkout must require a valid user token or valid service token, depending on the intended flow.

- Actual:
  - Billing checkout accepts `Authorization: Bearer abc` and creates a payment.
  - Admin maintenance accepts `Authorization: Bearer fake.jwt.token` and executes the action.

- Security impact:
  - Broken Authentication.
  - Broken Function Level Authorization.
  - Payment/checkout action can be triggered with fake credentials.
  - Admin maintenance action can be triggered with fake credentials.
  - This contradicts the project requirement of centralized IdP and backend-side authorization.

- Suggested fix:
  - Reuse the JWT validation logic from `services/user/auth.py` or `services/order/auth.py`.
  - Create a shared auth helper if possible.
  - Billing checkout should call `require_user_or_service_token`.
  - Admin maintenance should call `require_admin`.
  - Reject malformed/invalid/expired tokens with `401`.
  - Reject valid but unauthorized tokens with `403`.

### Additional evidence: Admin SSRF endpoints also accept fake Bearer token

File evidence:

- `docs/evidence/qa/admin-ssrf-fake-token-checks.txt`

Observed behavior:

```text
POST /api/v1/admin/metadata-fetch/vulnerable
Authorization: Bearer abc
→ 200 OK

POST /api/v1/admin/metadata-fetch/fixed
Authorization: Bearer abc
→ 200 OK
### Impact

* Admin SSRF demo endpoints are accessible with malformed Bearer tokens.
* Even the "fixed" SSRF endpoint only validates the target URL, not the caller identity.
* This means the Admin service has broken authentication/authorization across multiple protected endpoints.
* An attacker can call admin-level SSRF functionality by sending any non-empty Bearer token such as `Authorization: Bearer abc`.
* This contradicts the project security requirement that admin functions must be protected by centralized authentication and authorization.


- Status: Open

## BUG-004: Webhook HMAC demo scripts call `python` instead of `python3`

* Severity: Medium

* Area: Webhook/Test Automation

* Affected files:

  * `demo/webhook/send-valid-webhook.sh`
  * `demo/webhook/send-invalid-signature.sh`
  * `demo/webhook/send-replay-webhook.sh`

* Evidence:

  * `docs/evidence/qa/webhook-hmac-checks.txt`

* Expected:

  * Webhook test scripts should run successfully on Ubuntu using the default Python 3 interpreter.
  * Valid webhook should reach the service.
  * Invalid signature and replay tests should produce security rejection evidence.

* Actual:

  * All webhook test scripts fail before sending requests because they call `python`, but the system only has `python3`.

* Security/QA impact:

  * Webhook HMAC cannot be verified through the provided test scripts.
  * The project currently has webhook demo files, but the evidence is not reproducible on a clean Ubuntu environment.

* Suggested fix:

  * Replace `python` with `python3` in webhook shell scripts.
  * Optionally use `#!/usr/bin/env python3` in Python scripts.
  * Re-run valid, invalid signature, and replay webhook tests after fixing.

* Status: Open
