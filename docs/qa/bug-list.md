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

* Status: Fixed - Retest Passed 
- Retest evidence:
  - `docs/evidence/qa/auth-bypass-after-patch.txt`
  - `docs/evidence/qa/valid-token-authz-after-patch.txt`

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
Passed
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

* Status: Fixed - Retest Passed

- Retest evidence:
  - `docs/evidence/qa/auth-bypass-after-patch.txt`
  - `docs/evidence/qa/valid-token-authz-after-patch.txt`

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


- Status: Fixed - Retest Passed
- Retest evidence:
  - `docs/evidence/qa/auth-bypass-after-patch.txt`
  - `docs/evidence/qa/valid-token-authz-after-patch.txt`

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

## BUG-005: Valid webhook demo request is rejected with invalid HMAC signature

* Severity: High

* Area: Webhook/HMAC/Test Automation

* Affected endpoint:

  * `POST /api/v1/webhooks/payment`

* Affected files:

  * `demo/webhook/send-valid-webhook.sh`
  * `demo/webhook/send-invalid-signature.sh`
  * `demo/webhook/send-replay-webhook.sh`
  * `demo/webhook/sign_webhook.py`
  * `services/billing/main.py`

* Evidence:

  * `docs/evidence/qa/webhook-hmac-checks-after-python3-fix.txt`

* Expected:

  * `send-valid-webhook.sh` should return `200 OK`.
  * `send-invalid-signature.sh` should return `401 Unauthorized`.
  * `send-replay-webhook.sh` should return first request `200 OK`, second request `403 Forbidden`.

* Actual:

  * Valid webhook returns `401 Unauthorized`.
  * Invalid signature returns `401 Unauthorized`.
  * Replay attempt 1 already returns `401 Unauthorized`.

* Observed response:

```json
{"detail":{"error":"invalid_signature","message":"HMAC-SHA256 signature verification failed"}}
```

* Root cause hypothesis:

  * The signing script and backend do not compute HMAC over the exact same message.
  * Possible mismatch in raw body, JSON formatting, newline, timestamp, nonce, secret, or signature prefix format.
  * The script may sign one representation of the JSON body, while `curl` sends a different raw body.
  * The script and backend may use different `WEBHOOK_SECRET` values.
  * The script may send signature in a different format from what the backend expects, for example raw hex vs `sha256=<hex>`.
  * Replay protection cannot be verified because the first supposedly valid request is rejected before nonce storage.

* Security/QA impact:

  * The project currently cannot prove that webhook HMAC protection works.
  * Replay protection evidence is invalid because valid signature verification fails first.
  * This weakens the claim that webhook secure channel is implemented.
  * The current demo scripts are not sufficient evidence for webhook authenticity and replay protection.
  * If this remains unfixed, the report must clearly state that webhook HMAC was designed but the runnable validation evidence is failing.

* Suggested fix:

  * Ensure `sign_webhook.py` signs the exact raw body bytes that `curl` sends.
  * Store the request body in a variable or temporary file and use the same bytes for both signing and sending.
  * Ensure script and backend use the same `WEBHOOK_SECRET`.
  * Ensure the backend expects the same signature format that the script sends, for example `sha256=<hex>`.
  * Prefer `hmac.compare_digest()` for timing-safe signature comparison.
  * Re-run valid, invalid signature, and replay tests after fixing.
  * Valid request must pass before replay test is meaningful.

* Retest requirements:

  * Run `bash demo/webhook/send-valid-webhook.sh`.
  * Expected result: `200 OK`.
  * Run `bash demo/webhook/send-invalid-signature.sh`.
  * Expected result: `401 Unauthorized`.
  * Run `bash demo/webhook/send-replay-webhook.sh`.
  * Expected result: first request `200 OK`, second request `403 Forbidden`.
  * Save retest evidence to `docs/evidence/qa/webhook-hmac-checks-after-fix.txt`.

* Confirmed root cause:

  * The webhook demo scripts used default secret `local-demo-secret-change-me`.
  * The Billing service runtime uses `dev-webhook-secret-change-me`.
  * Because the signing script and backend used different secrets, even the valid webhook request was rejected with `401 invalid_signature`.

* Fix applied:

  * Updated webhook demo scripts to use `dev-webhook-secret-change-me` as the default `WEBHOOK_SECRET`, matching the Billing service runtime configuration.
  * Re-ran valid, invalid signature, and replay webhook tests.

* Retest evidence:

  * `docs/evidence/qa/webhook-hmac-checks-after-secret-fix.txt`

* Retest result:

  * `send-valid-webhook.sh` returned `200 OK`.
  * `send-invalid-signature.sh` returned `401 Unauthorized`.
  * `send-replay-webhook.sh` returned first request `200 OK`, second request `403 Forbidden`.

* Final assessment:

  * Webhook HMAC signing and verification now works.
  * Invalid signature rejection works.
  * Nonce replay protection works for the tested runtime session.

* Status: Fixed - Retest Passed

## BUG-006: Kong HTTPS endpoint allows TLS 1.2 although TLS 1.3-only hardening is expected

- Severity: Medium
- Area: Edge Security / TLS Hardening
- Affected component:
  - Kong HTTPS listener on port `8443`

- Evidence:
  - `docs/evidence/qa/tls-https-hsts-check.txt`
  - `docs/evidence/qa/tls-protocol-version-check.txt`

- Expected:
  - HTTPS endpoint should support TLS 1.3.
  - If the project claims TLS 1.3-only hardening, TLS 1.2 handshake should be rejected.

- Actual:
  - TLS 1.3 handshake succeeds.
  - TLS 1.2 handshake also succeeds.
  - HSTS header is present on HTTPS responses.

- Observed TLS 1.3 result:
  - `New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384`

- Observed TLS 1.2 result:
  - `New, TLSv1.2, Cipher is ECDHE-ECDSA-AES256-GCM-SHA384`

- Security impact:
  - The edge gateway supports HTTPS and HSTS, but it is not configured as TLS 1.3-only.
  - This weakens the strict TLS hardening claim.
  - The issue is not a complete TLS failure, because HTTPS still works and HSTS is enabled.

- Suggested fix:
  - Configure Kong to allow only TLS 1.3 on the HTTPS listener.
  - Re-run `openssl s_client -tls1_3` and `openssl s_client -tls1_2`.
  - Expected retest result: TLS 1.3 succeeds; TLS 1.2 fails.

- Fix applied:
  - Configured Kong proxy TLS listener to use TLS 1.3 only.
  - Added Kong TLS protocol hardening in `infra/docker-compose.yml`.
  - Verified generated Kong Nginx proxy configuration contains `ssl_protocols TLSv1.3`.

- Retest evidence:
  - `docs/evidence/qa/tls-protocol-version-after-fix.txt`
  - `docs/evidence/qa/tls-hsts-after-protocol-fix.txt`

- Retest result:
  - TLS 1.3 handshake succeeds with `TLS_AES_256_GCM_SHA384`.
  - TLS 1.2 handshake fails with `tlsv1 alert protocol version`.
  - HTTPS endpoint remains available.
  - HSTS header remains present.

- Status: Fixed - Retest Passed
