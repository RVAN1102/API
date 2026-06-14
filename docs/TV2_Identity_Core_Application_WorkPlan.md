# TV2 – Identity & Core Application Architect: Work Plan & Merge Contract

**Dự án:** SME Cloud-Native Microservices API Security – Topic 10  
**Thành viên phụ trách:** TV2 – Nhóm trưởng, Identity & Core Application Architect  
**Branch làm việc:** `feat/tv2-idp-authz-core-services`  
**Branch nền:** `setup/project-contracts`  
**Mục tiêu:** triển khai phần xác thực, phân quyền, User API, Order API, BOLA vulnerable/fixed, Vault secret contract, OpenAPI contract và bằng chứng kiểm thử để khi merge với TV1 và TV3 không bị lệch route, lệch token, lệch role, lệch file hoặc lệch quy trình demo.

---

## 1. Nguyên tắc làm việc bắt buộc

TV2 không làm trực tiếp trên `main` hoặc `setup/project-contracts`. Toàn bộ phần việc phải được thực hiện trên branch riêng:

```bash
cd ~/API
git switch setup/project-contracts
git pull
git switch -c feat/tv2-idp-authz-core-services
git push -u origin feat/tv2-idp-authz-core-services
```

Các lần làm sau:

```bash
cd ~/API
git switch feat/tv2-idp-authz-core-services
git pull
```

Sau khi hoàn thành một nhóm việc nhỏ, phải commit và push:

```bash
git status
git add .
git commit -m "<message rõ nội dung>"
git push
```

Không được commit các dữ liệu sau:

```text
.env
*.key
*.pem
*.p12
*.pfx
token thật
password thật
client secret thật
private key
log quá lớn
```

Nếu cần ghi token/secret vào evidence, phải che bớt:

```text
eyJhbGciOi...<redacted>
client_secret=<redacted>
```

---

## 2. Phạm vi phụ trách của TV2

TV2 chịu trách nhiệm chính cho các thư mục và file sau:

```text
idp/
vault/
services/user/
services/order/
demo/auth/
tests/auth/
tests/attack/bola-object-access.sh
docs/openapi/
docs/evidence/tv2/
docs/chapter3/
docs/chapter4/
docs/api-contract.md
docs/integration-checklist.md
openapi.yaml
```

TV2 không sửa sâu vào các thư mục sau nếu chưa thống nhất với nhóm:

```text
gateway/
services/billing/
services/admin/
observability/
ci/
.github/workflows/
```

Trường hợp cần sửa file chung như `infra/docker-compose.yml`, `gateway/kong.yml`, `docs/api-contract.md`, `openapi.yaml`, phải ghi rõ trong commit và báo cho nhóm vì đây là các file dễ gây conflict.

---

## 3. Quy ước tên file và thư mục bắt buộc

### 3.1. File Identity Provider

```text
idp/README.md
idp/pkce-flow.md
idp/client-credentials-flow.md
idp/jwt-claims.md
idp/realm-export/topic10-realm.json
```

### 3.2. File User Service

```text
services/user/main.py
services/user/auth.py
services/user/authz.py
services/user/policy.md
services/user/README.md
```

### 3.3. File Order Service

```text
services/order/main.py
services/order/auth.py
services/order/authz.py
services/order/policy.md
services/order/bola.md
services/order/README.md
```

### 3.4. File Vault

```text
vault/README.md
vault/scripts/init-dev-vault.sh
vault/policies/app-policy.hcl
```

### 3.5. File demo và test

```text
demo/auth/get-user-token.sh
demo/auth/get-service-token.sh
demo/auth/pkce-token-request.sh
demo/auth/client-credentials-token.sh

tests/auth/test-user-profile.sh
tests/auth/test-order-access.sh
tests/attack/bola-object-access.sh
```

### 3.6. File tài liệu và evidence

```text
docs/evidence/tv2/
docs/chapter3/tv2-idp-authz-core-design.md
docs/chapter4/tv2-idp-user-order-vault-implementation.md
docs/api-contract.md
docs/integration-checklist.md
docs/openapi/openapi.yaml
openapi.yaml
```

Không tự đặt tên file evidence theo kiểu tùy ý như `test1.txt`, `result.txt`, `abc.md`. Tên file phải nói rõ nội dung để sau này đưa vào báo cáo và review.

---

## 4. Contract dùng chung để tránh lệch với TV1 và TV3

### 4.1. Realm và role chuẩn

Realm chuẩn:

```text
topic10-sme-api
```

Role chuẩn:

```text
user
admin
billing-service
internal-service
```

Test user chuẩn:

```text
alice    role: user
bob      role: user
admin01  role: admin
```

### 4.2. Client chuẩn

Public client cho luồng user login:

```text
client_id: sme-web-client
type: public
flow: Authorization Code + PKCE
pkce: S256
```

Confidential client cho service-to-service:

```text
client_id: sme-service-client
type: confidential
flow: Client Credentials
roles: billing-service, internal-service
```

Không commit client secret thật. Nếu cần ghi vào tài liệu, ghi:

```text
client_secret=<redacted>
```

### 4.3. JWT claims backend sử dụng

Backend User/Order đọc tối thiểu các claim sau:

```text
sub
preferred_username
email
realm_access.roles
resource_access
scope
azp
exp
iss
aud nếu cấu hình được
```

### 4.4. Header chuẩn

Các request protected API phải dùng:

```text
Authorization: Bearer <access_token>
Content-Type: application/json
X-Correlation-ID: <request-id>
```

TV2 phải đảm bảo User/Order service nhận và trả lại `X-Correlation-ID` trong response JSON hoặc log/evidence.

### 4.5. Endpoint chuẩn của TV2

User API:

```text
GET /api/v1/users/health
GET /api/v1/users/profile
GET /api/v1/users/me
```

Order API:

```text
GET /api/v1/orders/health
GET /api/v1/orders
GET /api/v1/orders/{orderId}
GET /api/v1/orders/{orderId}/vulnerable
GET /api/v1/orders/{orderId}/fixed
```

TV2 không tự đổi route nếu chưa cập nhật đồng thời:

```text
openapi.yaml
docs/openapi/openapi.yaml
docs/api-contract.md
docs/integration-checklist.md
gateway/kong.yml nếu ảnh hưởng TV1
tests/attack/bola-object-access.sh nếu ảnh hưởng TV3
```

### 4.6. Dữ liệu mẫu Order chuẩn

Dùng dữ liệu mẫu thống nhất để demo BOLA:

```text
ord-alice-1001  owner: alice
ord-alice-1002  owner: alice
ord-bob-2001    owner: bob
ord-bob-2002    owner: bob
```

Kịch bản BOLA chuẩn:

```text
Alice dùng token của Alice gọi order của Bob.
Endpoint vulnerable trả 200.
Endpoint fixed trả 403.
Admin có role admin có thể xem nếu chính sách cho phép.
```

### 4.7. Vault secret path chuẩn

```text
secret/data/api/webhook
secret/data/api/service-clients
secret/data/api/order-service
secret/data/api/user-service
```

TV2 phải ghi rõ secret nào do service nào đọc, nhưng không commit giá trị secret thật.

---

## 5. Giai đoạn 0 – Kiểm tra baseline

### Việc cần làm

- Đảm bảo branch hiện tại là `feat/tv2-idp-authz-core-services`.
- Chạy lại Docker Compose.
- Kiểm tra User/Order/Keycloak/Vault.
- Lưu evidence baseline cho TV2.

### Lệnh

```bash
cd ~/API
git status

docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps

mkdir -p docs/evidence/tv2

{
  echo "===== users health ====="
  curl -i http://localhost:8000/api/v1/users/health
  echo
  echo "===== orders health ====="
  curl -i http://localhost:8000/api/v1/orders/health
  echo
  echo "===== keycloak ====="
  curl -i http://localhost:8080
  echo
  echo "===== vault health ====="
  curl -i http://localhost:8200/v1/sys/health
} > docs/evidence/tv2/initial-idp-user-order-health.txt
```

### File phải có

```text
docs/evidence/tv2/initial-idp-user-order-health.txt
```

### Commit

```bash
git add docs/evidence/tv2/initial-idp-user-order-health.txt
git commit -m "test: record initial idp user order health checks"
git push
```

---

## 6. Giai đoạn 1 – Chuẩn hóa Keycloak realm contract

### Mục tiêu

Thiết kế cấu hình Keycloak để cả nhóm thống nhất realm, role, client, user, token flow, JWT claims và MFA.

### Việc cần làm

- Viết `idp/README.md`.
- Tạo thư mục `idp/realm-export/`.
- Tạo file `idp/realm-export/topic10-realm.json` nếu đã export được realm từ Keycloak.
- Nếu chưa export được ngay, tạo file note mô tả trạng thái và yêu cầu export sau.
- Cập nhật `docs/api-contract.md`.
- Cập nhật `docs/integration-checklist.md`.
- Ghi rõ MFA/OTP là bắt buộc cho luồng đăng nhập user, không chỉ username/password.

### Nội dung bắt buộc trong `idp/README.md`

```text
Realm name
Clients
Roles
Test users
Scopes
Authorization Code + PKCE flow
Client Credentials flow
MFA/OTP requirement
Token endpoint
JWKS endpoint
JWT claims
Cách import/export realm
Cách test token
```

### File phải có

```text
idp/README.md
idp/realm-export/topic10-realm.json
docs/evidence/tv2/keycloak-realm-note.txt
docs/api-contract.md
docs/integration-checklist.md
```

### Commit

```bash
git add idp docs/api-contract.md docs/integration-checklist.md docs/evidence/tv2/keycloak-realm-note.txt
git commit -m "idp: define keycloak realm clients roles and mfa contract"
git push
```

### Thông tin cần báo cho TV1 và TV3

```text
Realm name
Client ID
Role names
Token endpoint
JWKS endpoint
Claim chứa role
Test users
```

---

## 7. Giai đoạn 2 – Authorization Code + PKCE

### Mục tiêu

Chuẩn hóa luồng đăng nhập người dùng bằng OAuth2/OIDC Authorization Code + PKCE.

### Việc cần làm

- Viết `idp/pkce-flow.md`.
- Viết script hoặc note request token tại `demo/auth/pkce-token-request.sh`.
- Ghi rõ authorization URL.
- Ghi rõ token endpoint.
- Ghi rõ code verifier/code challenge dùng `S256`.
- Ghi rõ MFA/OTP xảy ra ở bước đăng nhập người dùng.
- Lưu evidence đã che token.

### File phải có

```text
idp/pkce-flow.md
demo/auth/pkce-token-request.sh
docs/evidence/tv2/pkce-token-result.txt
```

### Commit

```bash
git add idp/pkce-flow.md demo/auth/pkce-token-request.sh docs/evidence/tv2/pkce-token-result.txt
git commit -m "idp: document authorization code pkce flow"
git push
```

---

## 8. Giai đoạn 3 – Client Credentials cho service-to-service

### Mục tiêu

Chuẩn hóa luồng lấy token cho backend/service client.

### Việc cần làm

- Viết `idp/client-credentials-flow.md`.
- Viết script `demo/auth/client-credentials-token.sh`.
- Dùng confidential client.
- Ghi rõ role/scope `billing-service`, `internal-service`.
- Không commit client secret thật.
- Evidence phải che secret/token nếu cần.

### File phải có

```text
idp/client-credentials-flow.md
demo/auth/client-credentials-token.sh
docs/evidence/tv2/client-credentials-result.txt
docs/api-contract.md
```

### Commit

```bash
git add idp/client-credentials-flow.md demo/auth/client-credentials-token.sh docs/api-contract.md docs/evidence/tv2/client-credentials-result.txt
git commit -m "idp: document client credentials flow for service clients"
git push
```

### Thông tin cần báo cho TV3

```text
Service client ID
Role/scope dùng cho Billing/Admin
Cách lấy service token
Claim nào xác định service identity
```

---

## 9. Giai đoạn 4 – JWT claims và token validation contract

### Mục tiêu

Chuẩn hóa cách User/Order service kiểm tra access token.

### Việc cần làm

- Viết `idp/jwt-claims.md`.
- Tạo `services/user/auth.py`.
- Tạo `services/order/auth.py`.
- Code phải có cấu trúc rõ:
  - Lấy bearer token từ header.
  - Decode/validate token.
  - Kiểm tra `iss`, `exp`, role/scope.
  - Trả identity object cho API.
- Nếu chưa verify JWKS runtime đầy đủ, phải có skeleton và ghi rõ TODO.

### File phải có

```text
idp/jwt-claims.md
services/user/auth.py
services/order/auth.py
docs/evidence/tv2/jwt-claims-note.txt
docs/api-contract.md
```

### Commit

```bash
git add idp/jwt-claims.md services/user/auth.py services/order/auth.py docs/api-contract.md docs/evidence/tv2/jwt-claims-note.txt
git commit -m "auth: define jwt claims and validation contract"
git push
```

---

## 10. Giai đoạn 5 – User API có xác thực

### Mục tiêu

Hoàn thiện User service để demo protected API.

### Endpoint bắt buộc

```text
GET /api/v1/users/health
GET /api/v1/users/profile
GET /api/v1/users/me
```

### Rule

```text
/health public
/profile protected
/me protected
```

### Việc cần làm

- Sửa `services/user/main.py`.
- Dùng `services/user/auth.py`.
- Tạo `services/user/authz.py` nếu cần.
- Ghi `services/user/README.md`.
- Phải giữ `X-Correlation-ID`.
- Protected endpoint thiếu token phải trả `401`.
- Token không đủ quyền phải trả `403`.

### File phải có

```text
services/user/main.py
services/user/auth.py
services/user/authz.py
services/user/policy.md
services/user/README.md
docs/evidence/tv2/user-profile-authorized.txt
docs/evidence/tv2/user-profile-unauthorized.txt
```

### Test mẫu

```bash
curl -i http://localhost:8000/api/v1/users/health

curl -i http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer <access_token>" \
  -H "X-Correlation-ID: tv2-user-001"

curl -i http://localhost:8000/api/v1/users/me \
  -H "X-Correlation-ID: tv2-user-no-token"
```

### Commit

```bash
git add services/user docs/evidence/tv2/user-profile-authorized.txt docs/evidence/tv2/user-profile-unauthorized.txt
git commit -m "user: implement authenticated user profile api"
git push
```

---

## 11. Giai đoạn 6 – Order API nền tảng

### Mục tiêu

Hoàn thiện Order service với dữ liệu ownership để phục vụ demo phân quyền và BOLA.

### Endpoint bắt buộc

```text
GET /api/v1/orders/health
GET /api/v1/orders
GET /api/v1/orders/{orderId}
```

### Dữ liệu mẫu bắt buộc

```text
ord-alice-1001  owner: alice
ord-alice-1002  owner: alice
ord-bob-2001    owner: bob
ord-bob-2002    owner: bob
```

### Việc cần làm

- Sửa `services/order/main.py`.
- Dùng `services/order/auth.py`.
- Dùng `services/order/authz.py`.
- Viết `services/order/README.md`.
- Phải giữ `X-Correlation-ID`.
- Response order phải có `order_id`, `owner_id`, `amount`, `status`.

### File phải có

```text
services/order/main.py
services/order/auth.py
services/order/authz.py
services/order/README.md
docs/evidence/tv2/order-list-authorized.txt
docs/evidence/tv2/order-api-result.txt
```

### Commit

```bash
git add services/order docs/evidence/tv2/order-list-authorized.txt docs/evidence/tv2/order-api-result.txt
git commit -m "order: implement order api skeleton with ownership data"
git push
```

---

## 12. Giai đoạn 7 – BOLA vulnerable/fixed

### Mục tiêu

Tạo case BOLA có kiểm soát để phục vụ Chương 5 và attack script của TV3.

### Endpoint bắt buộc

```text
GET /api/v1/orders/{orderId}/vulnerable
GET /api/v1/orders/{orderId}/fixed
```

### Logic

Vulnerable endpoint:

```text
Chỉ kiểm tra token hợp lệ.
Không kiểm tra owner_id.
Alice có thể xem order của Bob nếu biết orderId.
```

Fixed endpoint:

```text
Kiểm tra token hợp lệ.
Kiểm tra owner_id == preferred_username hoặc sub tương ứng.
Nếu không đúng owner thì trả 403.
Admin role có thể được phép xem nếu chính sách cho phép.
```

### Kịch bản evidence

```text
Alice token gọi /ord-bob-2001/vulnerable → 200
Alice token gọi /ord-bob-2001/fixed → 403
Bob token gọi /ord-bob-2001/fixed → 200
```

### File phải có

```text
services/order/main.py
services/order/auth.py
services/order/authz.py
services/order/bola.md
tests/attack/bola-object-access.sh
docs/evidence/tv2/bola-vulnerable-result.txt
docs/evidence/tv2/bola-fixed-result.txt
```

### Commit

```bash
git add services/order tests/attack/bola-object-access.sh docs/evidence/tv2/bola-*.txt
git commit -m "order: add bola vulnerable and fixed access control demo"
git push
```

### Thông tin cần báo cho TV3

```text
Endpoint BOLA vulnerable
Endpoint BOLA fixed
Order ID mẫu
User dùng để test
Expected status code
```

---

## 13. Giai đoạn 8 – RBAC hoặc OPA policy

### Mục tiêu

Backend phải tự kiểm tra quyền, không chỉ tin API Gateway.

### Rule bắt buộc

```text
user:
  - xem profile của chính mình
  - xem order của chính mình

admin:
  - xem được tài nguyên quản trị hoặc nhiều order nếu policy cho phép

billing-service:
  - dùng cho luồng billing/service-to-service

internal-service:
  - dùng cho service nội bộ
```

### Việc cần làm

- Tạo `services/user/policy.md`.
- Tạo `services/order/policy.md`.
- Tạo `services/user/authz.py`.
- Tạo `services/order/authz.py`.
- Nếu dùng OPA, tạo file `.rego`.
- Nếu dùng RBAC code-level, ghi rõ rule trong `policy.md`.

### File phải có

```text
services/user/authz.py
services/user/policy.md
services/order/authz.py
services/order/policy.md
docs/evidence/tv2/rbac-policy-result.txt
docs/evidence/tv2/rbac-forbidden-result.txt
```

Nếu dùng OPA:

```text
services/user/opa/user_policy.rego
services/order/opa/order_policy.rego
```

### Commit

```bash
git add services/user services/order docs/evidence/tv2/rbac-policy-result.txt docs/evidence/tv2/rbac-forbidden-result.txt
git commit -m "authz: add backend rbac authorization policy"
git push
```

---

## 14. Giai đoạn 9 – Vault secret management

### Mục tiêu

Thiết kế cách quản lý secret tập trung cho prototype.

### Secret path bắt buộc

```text
secret/data/api/webhook
secret/data/api/service-clients
secret/data/api/order-service
secret/data/api/user-service
```

### Việc cần làm

- Viết `vault/README.md`.
- Viết `vault/scripts/init-dev-vault.sh`.
- Viết `vault/policies/app-policy.hcl`.
- Không hard-code secret thật.
- Tạo evidence Vault health và init note.

### File phải có

```text
vault/README.md
vault/scripts/init-dev-vault.sh
vault/policies/app-policy.hcl
docs/evidence/tv2/vault-health.txt
docs/evidence/tv2/vault-secret-result.txt
```

### Test mẫu

```bash
curl -i http://localhost:8200/v1/sys/health
```

### Commit

```bash
git add vault docs/evidence/tv2/vault-health.txt docs/evidence/tv2/vault-secret-result.txt
git commit -m "vault: define dev secret paths and access policy"
git push
```

---

## 15. Giai đoạn 10 – Vault integration với webhook/service secret

### Mục tiêu

Đồng bộ với TV1 và TV3 về secret dùng cho webhook HMAC và service-to-service.

### Việc cần làm

- Ghi rõ webhook secret nằm ở path nào.
- Ghi rõ ai đọc secret.
- Ghi rõ secret dùng cho endpoint nào.
- Phối hợp với TV1 về format HMAC.
- Phối hợp với TV3 nếu Billing xử lý webhook.
- Nếu chưa tích hợp runtime đầy đủ, phải ghi rõ trạng thái là `documented integration contract`.

### File phải có

```text
vault/README.md
vault/scripts/init-dev-vault.sh
docs/integration-checklist.md
docs/evidence/tv2/vault-webhook-secret-note.txt
```

### Commit

```bash
git add vault docs/integration-checklist.md docs/evidence/tv2/vault-webhook-secret-note.txt
git commit -m "vault: document webhook and service secret integration"
git push
```

---

## 16. Giai đoạn 11 – OpenAPI contract

### Mục tiêu

Giữ API contract khớp với code thật để TV1 route đúng, TV3 scan/test đúng.

### Việc cần làm

- Cập nhật `openapi.yaml`.
- Cập nhật `docs/openapi/openapi.yaml`.
- Thêm security scheme Bearer JWT.
- Thêm schemas:
  - `UserProfile`
  - `Order`
  - `ErrorResponse`
- Thêm response:
  - `200`
  - `400`
  - `401`
  - `403`
  - `404`
  - `429`
- Thêm endpoint User/Order/BOLA.

### File phải có

```text
openapi.yaml
docs/openapi/openapi.yaml
docs/evidence/tv2/openapi-validation-note.txt
```

### Commit

```bash
git add openapi.yaml docs/openapi/openapi.yaml docs/evidence/tv2/openapi-validation-note.txt
git commit -m "api: update openapi contract for user and order auth flows"
git push
```

### Thông tin cần báo cho TV1 và TV3

```text
Endpoint mới
Endpoint protected
Endpoint public
Response code
Schema thay đổi
```

---

## 17. Giai đoạn 12 – Script test auth và BOLA

### Mục tiêu

Tạo script để người khác chạy lại được mà không cần đoán lệnh.

### Script bắt buộc

```text
demo/auth/get-user-token.sh
demo/auth/get-service-token.sh
demo/auth/pkce-token-request.sh
demo/auth/client-credentials-token.sh

tests/auth/test-user-profile.sh
tests/auth/test-order-access.sh
tests/attack/bola-object-access.sh
```

### Quy tắc viết script

- Chỉ chạy với `localhost`.
- Có comment giải thích.
- Không hard-code token thật.
- Nếu cần token, đọc từ biến môi trường:

```bash
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
```

- Nếu thiếu token, script phải báo lỗi dễ hiểu.

### File evidence

```text
docs/evidence/tv2/auth-script-result.txt
```

### Commit

```bash
git add demo/auth tests/auth tests/attack/bola-object-access.sh docs/evidence/tv2/auth-script-result.txt
git commit -m "test: add auth and bola verification scripts"
git push
```

---

## 18. Giai đoạn 13 – Tích hợp với TV1

### Mục tiêu

Đảm bảo Gateway của TV1 route đúng và không làm hỏng auth flow.

### Việc cần kiểm tra

- `Authorization` header đi qua Gateway.
- `X-Correlation-ID` đi qua Gateway.
- CORS không chặn Authorization header.
- Rate limit không làm hỏng demo token/API.
- Route `/api/v1/users` và `/api/v1/orders` khớp OpenAPI.
- Webhook HMAC secret có đường dẫn Vault nếu cần.

### File phải có

```text
docs/evidence/tv2/tv1-gateway-integration-note.txt
docs/integration-checklist.md
```

### Commit

```bash
git add docs/evidence/tv2/tv1-gateway-integration-note.txt docs/integration-checklist.md
git commit -m "docs: record gateway integration requirements for auth services"
git push
```

---

## 19. Giai đoạn 14 – Tích hợp với TV3

### Mục tiêu

Đảm bảo Observability, attack script, Billing/Admin của TV3 dùng đúng token/role/endpoint.

### Việc cần cung cấp cho TV3

```text
Role/scope chuẩn
JWT claims chuẩn
Cách lấy user token
Cách lấy service token
Order ID mẫu cho BOLA
Expected response của BOLA vulnerable/fixed
Quy tắc không log token đầy đủ
```

### File phải có

```text
docs/evidence/tv2/tv3-observability-integration-note.txt
docs/integration-checklist.md
```

### Commit

```bash
git add docs/evidence/tv2/tv3-observability-integration-note.txt docs/integration-checklist.md
git commit -m "docs: record observability and attack integration requirements"
git push
```

---

## 20. Giai đoạn 15 – Tài liệu Chương 3

### Mục tiêu

Viết phần thiết kế xác thực và phân quyền tập trung cho báo cáo.

### Nội dung bắt buộc

```text
Keycloak trong kiến trúc
OAuth2/OIDC
Authorization Code + PKCE
MFA/OTP
Client Credentials
JWT claims
Token validation
RBAC/OPA backend authorization
User API
Order API
BOLA vulnerable/fixed design
Vault secret management
```

### File bắt buộc

```text
docs/chapter3/tv2-idp-authz-core-design.md
```

### Commit

```bash
git add docs/chapter3/tv2-idp-authz-core-design.md
git commit -m "docs: describe identity authorization and core service design"
git push
```

---

## 21. Giai đoạn 16 – Tài liệu Chương 4

### Mục tiêu

Viết phần triển khai thực tế.

### Nội dung bắt buộc

```text
Cách chạy Docker Compose
Cách truy cập Keycloak
Cách import/export realm
Cách lấy token PKCE
Cách lấy token Client Credentials
Cách test User API
Cách test Order API
Cách test BOLA
Cách init Vault dev
Cách kiểm tra evidence
```

### File bắt buộc

```text
docs/chapter4/tv2-idp-user-order-vault-implementation.md
```

### Commit

```bash
git add docs/chapter4/tv2-idp-user-order-vault-implementation.md
git commit -m "docs: add idp user order vault implementation guide"
git push
```

---

## 22. Giai đoạn 17 – Evidence tổng hợp

### Mục tiêu

Có đủ bằng chứng thực nghiệm để đưa vào báo cáo.

### File evidence tối thiểu

```text
docs/evidence/tv2/keycloak-health.txt
docs/evidence/tv2/vault-health.txt
docs/evidence/tv2/user-profile-authorized.txt
docs/evidence/tv2/user-profile-unauthorized.txt
docs/evidence/tv2/order-list-authorized.txt
docs/evidence/tv2/bola-vulnerable-result.txt
docs/evidence/tv2/bola-fixed-result.txt
docs/evidence/tv2/rbac-forbidden-result.txt
docs/evidence/tv2/client-credentials-result.txt
docs/evidence/tv2/pkce-token-result.txt
docs/evidence/tv2/openapi-validation-note.txt
```

### Commit

```bash
git add docs/evidence/tv2
git commit -m "test: collect tv2 identity authorization evidence"
git push
```

---

## 23. Giai đoạn 18 – Final self-check trước khi tạo PR

### Lệnh kiểm tra

```bash
cd ~/API
git status

docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps

curl -i http://localhost:8000/api/v1/users/health
curl -i http://localhost:8000/api/v1/orders/health
curl -i http://localhost:8080
curl -i http://localhost:8200/v1/sys/health
```

Nếu có script test:

```bash
bash tests/auth/test-user-profile.sh
bash tests/auth/test-order-access.sh
bash tests/attack/bola-object-access.sh
```

### Checklist file phải có

```text
idp/README.md
idp/pkce-flow.md
idp/client-credentials-flow.md
idp/jwt-claims.md
idp/realm-export/topic10-realm.json

services/user/main.py
services/user/auth.py
services/user/authz.py
services/user/policy.md
services/user/README.md

services/order/main.py
services/order/auth.py
services/order/authz.py
services/order/policy.md
services/order/bola.md
services/order/README.md

vault/README.md
vault/scripts/init-dev-vault.sh
vault/policies/app-policy.hcl

demo/auth/get-user-token.sh
demo/auth/get-service-token.sh
demo/auth/pkce-token-request.sh
demo/auth/client-credentials-token.sh

tests/auth/test-user-profile.sh
tests/auth/test-order-access.sh
tests/attack/bola-object-access.sh

openapi.yaml
docs/openapi/openapi.yaml
docs/api-contract.md
docs/integration-checklist.md

docs/evidence/tv2/
docs/chapter3/tv2-idp-authz-core-design.md
docs/chapter4/tv2-idp-user-order-vault-implementation.md
```

### Push cuối

```bash
git status
git push
```

---

## 24. Pull Request

Khi hoàn thành một mốc lớn hoặc toàn bộ phần TV2, tạo Pull Request trên GitHub.

PR chuẩn:

```text
base: setup/project-contracts
compare: feat/tv2-idp-authz-core-services
```

Không merge trực tiếp nếu:

```text
- Docker Compose đang lỗi.
- Health check lỗi.
- OpenAPI lệch code.
- Có secret/token trong commit.
- Conflict với TV1/TV3 chưa xử lý.
- Evidence thiếu.
```

Nội dung PR cần ghi:

```text
1. Đã làm gì
2. File chính đã thay đổi
3. Cách chạy test
4. Evidence nằm ở đâu
5. Cần TV1/TV3 chú ý gì
```

---

## 25. Thứ tự ưu tiên nếu thiếu thời gian

Nếu không đủ thời gian làm hết, ưu tiên theo thứ tự:

### Bắt buộc

```text
1. Keycloak realm contract
2. JWT claims contract
3. User API protected
4. Order API
5. BOLA vulnerable/fixed
6. RBAC backend
7. OpenAPI cập nhật
8. Evidence cơ bản
```

### Quan trọng

```text
9. Client Credentials
10. Vault secret paths
11. Auth/BOLA scripts
12. Chapter 3 design doc
13. Chapter 4 implementation doc
```

### Hoàn thiện thêm

```text
14. Runtime JWKS verification đầy đủ
15. OPA policy runtime
16. Vault runtime integration đầy đủ
17. PKCE script hoàn chỉnh
18. More negative tests
```

---

## 26. Definition of Done của TV2

TV2 được xem là hoàn thành khi đạt đủ các điều kiện:

```text
- Branch feat/tv2-idp-authz-core-services đã push lên GitHub.
- User API và Order API chạy được qua Gateway.
- Keycloak contract rõ realm, clients, roles, users, token flow.
- Có MFA/OTP requirement cho user login.
- Có Client Credentials contract cho service clients.
- Backend có logic xác thực hoặc skeleton xác thực rõ ràng.
- Backend có RBAC/authorization policy.
- BOLA vulnerable/fixed demo có evidence.
- Vault secret path và policy có tài liệu/script.
- OpenAPI khớp endpoint thực tế.
- Có script test auth/BOLA.
- Có evidence trong docs/evidence/tv2.
- Có tài liệu Chương 3 và Chương 4 cho phần TV2.
- Không commit secret thật.
- Docker Compose vẫn build/chạy được.
- PR được tạo để merge vào setup/project-contracts.
```
