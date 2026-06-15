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
