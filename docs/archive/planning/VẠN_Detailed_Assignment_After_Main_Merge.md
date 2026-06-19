# Historical Planning Notice

This document is historical assignment material from an earlier post-merge
phase. It is superseded by the current final evidence index, final regression
11-suite result, and runtime documentation. TODO/limitation wording below is
preserved as planning context, not as the current project status.

# PHÂN CÔNG CÔNG VIỆC – THÀNH VIÊN SỐ 2  
## TV2 – Identity, Authentication, Authorization & Core API

**Mốc phân công:** sau khi `qa/core-redteam-audit` đã merge và push vào `main`  
**Vai trò hiện tại của TV2:** người đã thực hiện đợt QA hardening và fix/triage 10 bug đã biết  
**Mục tiêu mốc tiếp theo:** không tiếp tục “săn bug lan man”; tập trung chốt chắc phần Identity/Auth/Authz/Core API, lưu evidence cuối, chuẩn hóa auth contract và không làm chồng chéo sang TV1/TV3.

---

# 1. Trạng thái hiện tại của `main`

`main` hiện đã có merge commit:

```bash
f68a472 merge qa hardening fixes into main
```

Các phần quan trọng đã có trên `main`:

```text
- Docker Compose stack cho Kong, Keycloak, Vault, Grafana, Loki/Promtail và 4 service chính.
- Kong Gateway route tới user-service, order-service, billing-service, admin-service.
- Health endpoint qua Kong:
  /api/v1/users/health
  /api/v1/orders/health
  /api/v1/billing/health
  /api/v1/admin/health
- Keycloak realm/client/user/token flow.
- JWT validation cho user/order/admin/billing.
- RBAC user/admin.
- Admin/Billing đã chặn fake hoặc malformed token.
- User/Order đã fix lỗi issuer/JWKS mismatch.
- BOLA vulnerable endpoint được giữ cố ý để demo lỗi.
- BOLA fixed endpoint đã chặn truy cập sai owner.
- Webhook HMAC đã fix lỗi secret mismatch.
- Webhook replay check đã có.
- Kong đã có TLS 1.3, HSTS, CORS, rate limit, request size limit.
- User/Order đã có structured JSON log hợp lệ.
- Security scan đã chạy: Bandit/Trivy/Gitleaks.
- python-jose đã upgrade lên 3.4.0 để xử lý CVE do Trivy phát hiện.
- 10 bug đã biết đã fix hoặc triage.
```

**Kết luận:** `main` hiện là daily stable checkpoint để cả nhóm pull về làm tiếp, chưa phải bản nộp cuối.

---

# 2. Nguyên tắc phân công cho TV2

TV2 đã làm phần fix bug lớn nhất trong mốc trước. Vì vậy mốc này không nên giao TV2 tiếp tục ôm “mọi lỗi trong repo”. TV2 chỉ chịu trách nhiệm phần:

```text
- Keycloak / Identity Provider
- JWT validation contract
- Authentication flow
- RBAC / authorization model
- User API
- Order API authorization và BOLA mitigation
- Admin API role enforcement
- Billing API authentication
- Evidence cho phần Identity/Auth/Authz/Core API
```

TV2 **không phụ trách chính**:

```text
- Kong/TLS/CORS/rate limit/webhook network hardening: giao TV1.
- Security scan, regression script, fuzzing, observability tổng thể: giao TV3.
- Viết báo cáo tổng hợp: làm sau, không nằm trong task này.
```

---

# 3. Branch làm việc của TV2

TV2 tạo branch riêng từ `main`:

```bash
cd ~/API

git checkout main
git pull origin main

git checkout -b feat/tv2-authz-core-closeout
```

Không push thẳng vào `main`.

---

# 4. Phạm vi file TV2 được phép sửa

## 4.1. Được phép sửa

```text
idp/
demo/auth/
services/user/
services/order/
services/admin/
services/billing/ nếu sửa phần auth của billing
docs/evidence/tv2/
openapi.yaml nếu cần cập nhật API contract
docs/PROJECT_STATUS.md nếu cần cập nhật trạng thái phần TV2
```

## 4.2. Không nên sửa nếu không báo nhóm

```text
gateway/
demo/webhook/
infra/ phần Kong/TLS/CORS/rate limit
observability/
ci/
.github/
tests/final/
tests/security/edge*
docs/evidence/tv1/
docs/evidence/tv3/
```

Lý do: những phần này thuộc TV1 hoặc TV3. TV2 sửa chéo dễ gây conflict và phá phạm vi trách nhiệm.

---

# 5. Thứ tự ưu tiên công việc của TV2

## P0 – Việc bắt buộc, làm trước

P0 là các việc phải hoàn thành để phần Identity/Auth/Core API được coi là ổn định.

```text
P0.1 Retest Keycloak OIDC discovery và token flow.
P0.2 Retest /users/me với token hợp lệ, thiếu token, fake token.
P0.3 Retest Admin RBAC: user bị 403, admin pass, fake/malformed token bị 401.
P0.4 Retest Order/BOLA: vulnerable endpoint là intentionally vulnerable, fixed endpoint chặn sai owner.
P0.5 Retest Billing checkout auth: token hợp lệ pass, malformed/fake token fail.
P0.6 Xác nhận JWT issuer/JWKS validation không bị hồi quy.
P0.7 Xác nhận trạng thái MFA/2FA của Keycloak theo yêu cầu đồ án.
P0.8 Lưu evidence đầy đủ dưới docs/evidence/tv2/.
```

## P1 – Việc quan trọng, làm sau P0

```text
P1.1 Viết authz model summary: hệ thống dùng RBAC hay OPA, role nào, claim nào, endpoint nào yêu cầu role nào.
P1.2 Cập nhật OpenAPI nếu route/request/response khác với code hiện tại.
P1.3 Chuẩn hóa tài khoản demo Alice/Bob/Admin trong docs/evidence/tv2/.
P1.4 Ghi rõ BOLA /vulnerable là intentional demo, không phải bug chưa fix.
P1.5 Ghi rõ các bug auth đã fix trong mốc QA hardening.
```

## P2 – Việc nâng cao, làm nếu còn thời gian

```text
P2.1 Bổ sung service-client credentials flow evidence nếu demo cần machine-to-machine token.
P2.2 Bổ sung role/scope matrix chi tiết hơn.
P2.3 Nếu đề yêu cầu fine-grained authorization mạnh hơn RBAC, cân nhắc OPA hoặc ghi limitation rõ.
P2.4 Tạo script riêng của TV2 để chạy toàn bộ auth/core checks, nếu TV3 chưa làm kịp.
```

---

# 6. Chi tiết nhiệm vụ P0

---

## P0.1 – Retest Keycloak OIDC discovery và token flow

### Mục tiêu

Chứng minh Keycloak dùng được thật, không chỉ container `Up`.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv2

{
  echo "===== TV2 P0.1 Keycloak discovery ====="
  date
  git branch --show-current
  git log --oneline -5

  echo
  curl -s -o /dev/null -w "oidc_discovery=%{http_code}\n" \
    http://localhost:8080/realms/topic10-sme-api/.well-known/openid-configuration

  echo
  echo "===== Alice token ====="
  bash demo/auth/get-user-token.sh alice

  echo
  echo "===== Bob token ====="
  bash demo/auth/get-user-token.sh bob

  echo
  echo "===== Admin token ====="
  bash demo/auth/get-user-token.sh admin01
} | tee docs/evidence/tv2/p0-01-keycloak-token-flow.txt
```

### Kỳ vọng

```text
oidc_discovery=200
alice token lấy được
bob token lấy được
admin01 token lấy được
```

### Evidence

```text
docs/evidence/tv2/p0-01-keycloak-token-flow.txt
```

---

## P0.2 – Retest User API authentication

### Mục tiêu

Chứng minh `/api/v1/users/me` chỉ chấp nhận JWT hợp lệ.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv2

bash demo/auth/get-user-token.sh alice
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

{
  echo "===== TV2 P0.2 users/me with Alice token ====="
  curl -i http://localhost:8000/api/v1/users/me \
    -H "Authorization: Bearer ${ALICE_TOKEN}"

  echo
  echo "===== TV2 P0.2 users/me without token ====="
  curl -i http://localhost:8000/api/v1/users/me

  echo
  echo "===== TV2 P0.2 users/me with fake token ====="
  curl -i http://localhost:8000/api/v1/users/me \
    -H "Authorization: Bearer fake.jwt.token"
} | tee docs/evidence/tv2/p0-02-user-auth.txt
```

### Kỳ vọng

```text
Alice token      -> 200
No token         -> 401 hoặc 403 tùy middleware hiện tại, nhưng phải bị chặn
Fake token       -> 401
```

### Evidence

```text
docs/evidence/tv2/p0-02-user-auth.txt
```

---

## P0.3 – Retest Admin RBAC

### Mục tiêu

Chứng minh Admin API yêu cầu role `admin`.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv2

bash demo/auth/get-user-token.sh alice
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

bash demo/auth/get-user-token.sh admin01
ADMIN_TOKEN="$(cat /tmp/user-token.txt)"

{
  echo "===== TV2 P0.3 Alice calls admin maintenance ====="
  curl -i -X POST http://localhost:8000/api/v1/admin/maintenance \
    -H "Authorization: Bearer ${ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv2-rbac-test"}'

  echo
  echo "===== TV2 P0.3 Admin calls admin maintenance ====="
  curl -i -X POST http://localhost:8000/api/v1/admin/maintenance \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv2-rbac-test"}'

  echo
  echo "===== TV2 P0.3 Fake token calls admin maintenance ====="
  curl -i -X POST http://localhost:8000/api/v1/admin/maintenance \
    -H "Authorization: Bearer fake.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv2-rbac-test"}'

  echo
  echo "===== TV2 P0.3 Malformed token calls admin maintenance ====="
  curl -i -X POST http://localhost:8000/api/v1/admin/maintenance \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    -d '{"action":"health-check","reason":"tv2-rbac-test"}'
} | tee docs/evidence/tv2/p0-03-admin-rbac.txt
```

### Kỳ vọng

```text
Alice token      -> 403
Admin token      -> 200
Fake token       -> 401
Malformed token  -> 401
```

### Evidence

```text
docs/evidence/tv2/p0-03-admin-rbac.txt
```

---

## P0.4 – Retest Order/BOLA authorization

### Mục tiêu

Chứng minh rõ ràng:
- endpoint `/vulnerable` cố ý tồn tại để demo BOLA;
- endpoint `/fixed` là bản mitigation đúng.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv2

bash demo/auth/get-user-token.sh alice
cp /tmp/user-token.txt /tmp/alice-token.txt

bash demo/auth/get-user-token.sh bob
cp /tmp/user-token.txt /tmp/bob-token.txt

ALICE_TOKEN="$(cat /tmp/alice-token.txt)"
BOB_TOKEN="$(cat /tmp/bob-token.txt)"

{
  echo "===== TV2 P0.4 Alice own order fixed ====="
  curl -i http://localhost:8000/api/v1/orders/ord-alice-1001/fixed \
    -H "Authorization: Bearer ${ALICE_TOKEN}"

  echo
  echo "===== TV2 P0.4 Alice reads Bob order through vulnerable endpoint ====="
  curl -i http://localhost:8000/api/v1/orders/ord-bob-2001/vulnerable \
    -H "Authorization: Bearer ${ALICE_TOKEN}"

  echo
  echo "===== TV2 P0.4 Alice reads Bob order through fixed endpoint ====="
  curl -i http://localhost:8000/api/v1/orders/ord-bob-2001/fixed \
    -H "Authorization: Bearer ${ALICE_TOKEN}"

  echo
  echo "===== TV2 P0.4 Bob reads Bob order through fixed endpoint ====="
  curl -i http://localhost:8000/api/v1/orders/ord-bob-2001/fixed \
    -H "Authorization: Bearer ${BOB_TOKEN}"
} | tee docs/evidence/tv2/p0-04-order-bola.txt
```

### Kỳ vọng

```text
Alice own order /fixed        -> 200
Alice Bob order /vulnerable   -> 200, intentional vulnerability demo
Alice Bob order /fixed        -> 403
Bob Bob order /fixed          -> 200
```

### Evidence

```text
docs/evidence/tv2/p0-04-order-bola.txt
```

### Ghi chú bắt buộc

Trong summary không được ghi “BOLA chưa fix”. Phải ghi:

```text
/vulnerable được giữ cố ý để demo BOLA.
/fixed là endpoint mitigation dùng ownership check hoặc admin role.
```

---

## P0.5 – Retest Billing checkout authentication

### Mục tiêu

Chứng minh Billing checkout không còn auth bypass.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv2

bash demo/auth/get-user-token.sh alice
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

{
  echo "===== TV2 P0.5 Billing checkout with Alice token ====="
  curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
    -H "Authorization: Bearer ${ALICE_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'

  echo
  echo "===== TV2 P0.5 Billing checkout with fake token ====="
  curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
    -H "Authorization: Bearer fake.jwt.token" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'

  echo
  echo "===== TV2 P0.5 Billing checkout with malformed token ====="
  curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'
} | tee docs/evidence/tv2/p0-05-billing-auth.txt
```

### Kỳ vọng

```text
Alice token      -> 202
Fake token       -> 401
Malformed token  -> 401
```

### Evidence

```text
docs/evidence/tv2/p0-05-billing-auth.txt
```

---

## P0.6 – Xác nhận JWT issuer/JWKS validation

### Mục tiêu

Chứng minh bug issuer/JWKS mismatch đã fix và không hồi quy.

### Lệnh kiểm tra code/config

```bash
cd ~/API
mkdir -p docs/evidence/tv2

{
  echo "===== TV2 P0.6 JWT issuer/JWKS config grep ====="

  echo
  echo "===== user auth ====="
  grep -n "KEYCLOAK_URL\|KEYCLOAK_ISSUER\|JWKS_URL\|EXPECTED_ISSUER" services/user/auth.py

  echo
  echo "===== order auth ====="
  grep -n "KEYCLOAK_URL\|KEYCLOAK_ISSUER\|JWKS_URL\|EXPECTED_ISSUER" services/order/auth.py

  echo
  echo "===== compose env ====="
  grep -n "KEYCLOAK_URL\|KEYCLOAK_ISSUER" -n infra/docker-compose.yml
} | tee docs/evidence/tv2/p0-06-jwt-issuer-jwks-config.txt
```

### Kỳ vọng

Có tách rõ:
- `KEYCLOAK_URL` dùng để fetch JWKS nội bộ;
- `KEYCLOAK_ISSUER` dùng để validate `iss` của token.

### Evidence

```text
docs/evidence/tv2/p0-06-jwt-issuer-jwks-config.txt
```

---

## P0.7 – Xác nhận trạng thái MFA/2FA của Keycloak

### Mục tiêu

Yêu cầu bảo mật của đồ án có phần xác thực mạnh; không nên trình bày hệ thống như chỉ có password nếu chưa có MFA hoặc ít nhất MFA contract.

### Việc cần làm

TV2 kiểm tra trong repo hiện đã có cấu hình/tài liệu MFA chưa:

```bash
cd ~/API
mkdir -p docs/evidence/tv2

{
  echo "===== TV2 P0.7 MFA status grep ====="
  grep -RIn "MFA\|2FA\|OTP\|TOTP\|required action\|multi-factor\|multifactor" idp docs demo services || true
} | tee docs/evidence/tv2/p0-07-mfa-status-grep.txt
```

### Nếu đã có MFA contract nhưng chưa enforce runtime

Tạo file:

```bash
nano docs/evidence/tv2/p0-07-mfa-status.md
```

Ghi rõ:

```text
Hệ thống hiện đã có MFA contract trong IdP design, nhưng prototype local chưa chứng minh đầy đủ luồng OTP/TOTP runtime.
Trạng thái: limitation cần hoàn thiện nếu yêu cầu demo bắt buộc MFA.
```

### Nếu có thể cấu hình MFA thật trong Keycloak

TV2 nên bổ sung evidence:
- user được gắn required action OTP/TOTP;
- đăng nhập authorization code flow yêu cầu OTP;
- không chỉ password.

### Yêu cầu trung thực

Không được ghi “đã triển khai MFA” nếu chỉ có tài liệu nhưng chưa enforce được trong Keycloak runtime.

### Evidence

```text
docs/evidence/tv2/p0-07-mfa-status-grep.txt
docs/evidence/tv2/p0-07-mfa-status.md
```

---

## P0.8 – Lưu summary 10 bug auth/core đã fix

### Mục tiêu

Vì TV2 đã fix/triage 10 bug, cần có summary ngắn để nhóm biết các lỗi đã biết đang ở trạng thái nào.

### Tạo file

```bash
nano docs/evidence/tv2/p0-08-tv2-qa-hardening-summary.md
```

### Nội dung bắt buộc

```text
- Danh sách 10 bug đã phát hiện.
- Bug nào thuộc auth/core.
- Bug nào đã fix.
- Bug nào là intentional demo, ví dụ BOLA /vulnerable.
- Bug nào là documented limitation, ví dụ demo secret/Vault limitation nếu liên quan.
- Commit chính đã merge vào main.
```

### Lưu ý

Không ghi “hệ thống hết bug”. Chỉ ghi:

```text
10 known issues identified in the QA hardening pass were fixed or triaged.
```

---

# 7. Nhiệm vụ P1

---

## P1.1 – Viết authz model summary

Tạo file:

```bash
nano docs/evidence/tv2/tv2-authz-model-summary.md
```

Nội dung phải có:

```text
1. Identity Provider: Keycloak realm topic10-sme-api.
2. Client types:
   - public client cho user login/PKCE nếu có.
   - service client cho client credentials nếu có.
3. Users demo:
   - alice: role user.
   - bob: role user.
   - admin01: role admin.
4. JWT validation:
   - issuer validation.
   - JWKS validation.
   - signature validation.
   - role extraction.
5. Authorization:
   - user endpoint yêu cầu token hợp lệ.
   - admin endpoint yêu cầu role admin.
   - order fixed endpoint yêu cầu owner hoặc admin.
   - billing checkout yêu cầu token hợp lệ.
6. BOLA:
   - vulnerable endpoint là intentional demo.
   - fixed endpoint là mitigation.
7. OPA/RBAC decision:
   - Hệ thống hiện dùng RBAC/service-level ownership check.
   - Nếu không dùng OPA, ghi rõ lý do và limitation.
```

---

## P1.2 – Cập nhật OpenAPI contract nếu cần

### Kiểm tra nhanh

```bash
grep -n "/api/v1/users\|/api/v1/orders\|/api/v1/billing\|/api/v1/admin" openapi.yaml
```

### Yêu cầu

OpenAPI phải có hoặc ít nhất không mâu thuẫn với code hiện tại:

```text
/api/v1/users/health
/api/v1/users/me
/api/v1/orders/health
/api/v1/orders/{order_id}/vulnerable
/api/v1/orders/{order_id}/fixed
/api/v1/billing/checkout
/api/v1/admin/maintenance
```

Nếu thiếu route quan trọng, TV2 bổ sung.

---

## P1.3 – Chuẩn hóa tài khoản demo

Tạo file:

```bash
nano docs/evidence/tv2/demo-users-and-roles.md
```

Nội dung:

```text
alice:
- role: user
- dùng để test user profile, own order, billing checkout.

bob:
- role: user
- dùng để test BOLA ownership boundary.

admin01:
- role: admin
- dùng để test admin maintenance và admin-only access.
```

Không ghi password thật nếu password nằm trong secret hoặc không cần công khai. Nếu là demo password bắt buộc, phải ghi rõ là local demo credential, không dùng production.

---

# 8. Nhiệm vụ P2

---

## P2.1 – Service client credentials flow evidence

Nếu repo hiện có `demo/auth` cho client credentials, TV2 chạy và lưu evidence:

```bash
cd ~/API
mkdir -p docs/evidence/tv2

{
  echo "===== TV2 P2.1 client credentials flow ====="
  find demo/auth -maxdepth 2 -type f -iname "*client*" -o -iname "*service*"
  echo
  # Chạy script tương ứng nếu đã có
} | tee docs/evidence/tv2/p2-01-client-credentials-flow.txt
```

Nếu chưa có, ghi limitation hoặc giao mốc sau.

---

## P2.2 – Role/scope matrix

Tạo file:

```bash
nano docs/evidence/tv2/role-scope-access-matrix.md
```

Mẫu:

```text
| Endpoint | No token | user | admin | Ghi chú |
|---|---:|---:|---:|---|
| GET /api/v1/users/me | 401 | 200 | 200 hoặc 200 tùy claim | token hợp lệ |
| POST /api/v1/admin/maintenance | 401 | 403 | 200 | admin-only |
| GET /api/v1/orders/{id}/fixed | 401 | owner=200, non-owner=403 | 200 nếu admin allowed | ownership check |
| POST /api/v1/billing/checkout | 401 | 202 | 202 hoặc theo policy | authenticated |
```

---

## P2.3 – Script tự động test phần TV2

Nếu TV3 chưa làm kịp, TV2 có thể tạo tạm:

```bash
mkdir -p tests/security
nano tests/security/tv2-authz-core-tests.sh
chmod +x tests/security/tv2-authz-core-tests.sh
```

Script gom:
- Keycloak discovery;
- token Alice/Bob/Admin;
- users/me;
- admin RBAC;
- BOLA;
- billing auth.

Nếu TV3 đã làm regression chung, TV2 không cần làm script này, chỉ cần cung cấp command/evidence.

---

# 9. Điều kiện hoàn thành của TV2

TV2 được coi là hoàn thành mốc này khi:

```text
[ ] Đã tạo branch từ main mới nhất.
[ ] Keycloak OIDC discovery trả 200.
[ ] Alice/Bob/Admin token lấy được.
[ ] /users/me với Alice token trả 200.
[ ] /users/me với fake token bị chặn.
[ ] Admin endpoint: Alice 403, Admin 200, fake/malformed token 401.
[ ] BOLA vulnerable endpoint trả 200 cho Alice đọc Bob order và được ghi rõ intentional.
[ ] BOLA fixed endpoint trả 403 khi Alice đọc Bob order.
[ ] Billing checkout: Alice token 202, fake/malformed token 401.
[ ] JWT issuer/JWKS config có evidence.
[ ] MFA status có evidence hoặc limitation rõ.
[ ] Có authz model summary.
[ ] Có demo users/roles summary.
[ ] Có QA hardening summary cho 10 bug đã fix/triage.
[ ] Không sửa chéo sang phần TV1/TV3 nếu chưa báo nhóm.
```

---

# 10. Cách commit và push

Nếu chỉ thêm evidence/docs:

```bash
cd ~/API

git status -sb
git add docs/evidence/tv2 openapi.yaml
git commit -m "docs: capture tv2 authz core final evidence"
git push origin feat/tv2-authz-core-closeout
```

Nếu có sửa code/config thật:

```bash
git add idp demo/auth services/user services/order services/admin services/billing openapi.yaml
git commit -m "fix: harden tv2 authz and core api controls"

git add docs/evidence/tv2
git commit -m "docs: capture tv2 authz and core api evidence"

git push origin feat/tv2-authz-core-closeout
```

---

# 11. Không được làm các việc sau

```text
- Không sửa gateway/TLS/CORS/rate limit nếu không báo TV1.
- Không sửa CI/security scan/test final nếu không báo TV3.
- Không xóa endpoint /vulnerable vì đó là endpoint demo BOLA.
- Không ghi hệ thống đã hết bug.
- Không ghi MFA đã hoàn thành nếu chỉ có tài liệu nhưng chưa enforce runtime.
- Không commit secret thật hoặc token thật.
- Không đổi route/path mà không cập nhật OpenAPI và báo nhóm.
```

---

# 12. Kết luận

TV2 đã làm đợt fix bug lớn nhất nên mốc tiếp theo cần chuyển từ “fix bug” sang “chốt chắc Identity/Auth/Authz/Core API”. Việc chính là lưu evidence, chuẩn hóa authz model, xác nhận MFA status và đảm bảo các luồng user/admin/order/billing không hồi quy.

Mục tiêu cuối của TV2 trong mốc này:

```text
Identity, authentication, authorization và core API có evidence rõ ràng, không hồi quy sau merge main, và không làm chồng chéo sang phần TV1/TV3.
```
