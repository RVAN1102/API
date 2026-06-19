# Historical Planning Notice

This document is historical planning material from an earlier implementation
phase. It is superseded by the current final evidence index, final regression
11-suite result, and runtime documentation. TODO/placeholder wording below is
preserved as planning context, not as the current project status.

# TV1 – Edge, Network & Webhook Security Engineer: Work Plan & Merge Contract

**Dự án:** SME Cloud-Native Microservices API Security – Topic 10  
**Thành viên phụ trách:** TV1 – Edge, Network & Webhook Security Engineer  
**Branch làm việc:** `feat/tv1-gateway-edge-security`  
**Branch nền:** `setup/project-contracts`  
**Mục tiêu:** triển khai lớp bảo vệ biên cho prototype gồm API Gateway, routing, CORS, rate limiting, TLS/HSTS, WAF/filter, mTLS design, webhook HMAC + nonce/timestamp, correlation ID, k6 benchmark và evidence. File này quy định rõ tên file, thư mục, commit point và integration contract để khi merge với TV2/TV3 không bị lệch route, lệch header, lệch webhook format, lệch benchmark hoặc lệch evidence.

---

## 1. Nguyên tắc làm việc bắt buộc

TV1 không làm trực tiếp trên `main` hoặc `setup/project-contracts`. Toàn bộ phần việc phải làm trên branch riêng:

```bash
git clone https://github.com/RVAN1102/API.git
cd API
git switch setup/project-contracts
git pull
git switch -c feat/tv1-gateway-edge-security
git push -u origin feat/tv1-gateway-edge-security
```

Các lần làm sau:

```bash
cd ~/API
git switch feat/tv1-gateway-edge-security
git pull
```

Sau khi hoàn thành một nhóm việc nhỏ, phải commit và push:

```bash
git status
git add .
git commit -m "<message rõ nội dung>"
git push
```

Không commit các dữ liệu sau:

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
certificate private key thật
log quá lớn
```

Nếu cần có chứng chỉ/cert cho demo, ưu tiên commit script sinh cert, không commit private key thật. Nếu cần lưu file mẫu, dùng hậu tố rõ ràng:

```text
*.example.crt
*.example.conf
```

---

## 2. Phạm vi phụ trách của TV1

TV1 chịu trách nhiệm chính cho các thư mục và file sau:

```text
gateway/
infra/
demo/curl/
demo/tls/
demo/mtls/
demo/webhook/
demo/k6/
docs/evidence/tv1/
docs/chapter3/
```

TV1 có thể sửa `infra/docker-compose.yml` nếu cần gắn thêm volume/cert/plugin cho Kong, nhưng đây là file chung nên phải báo nhóm trước khi push thay đổi lớn.

TV1 không sửa sâu vào các thư mục sau nếu chưa thống nhất với nhóm:

```text
idp/
vault/
services/user/
services/order/
services/billing/
services/admin/
observability/
ci/
.github/workflows/
tests/auth/
```

Nếu cần thay đổi endpoint hoặc header ảnh hưởng service, phải cập nhật:

```text
docs/api-contract.md
docs/integration-checklist.md
gateway/README.md
```

---

## 3. Quy ước tên file và thư mục bắt buộc

### 3.1. Gateway

```text
gateway/kong.yml
gateway/README.md
gateway/rate-limit-policy.md
gateway/waf-rules.md
gateway/tls.md
gateway/mtls.md
gateway/webhook-security.md
gateway/correlation-id.md
```

### 3.2. Curl demo scripts

```text
demo/curl/test-gateway-routes.sh
demo/curl/test-cors.sh
demo/curl/test-rate-limit.sh
demo/curl/test-waf-filter.sh
demo/curl/test-https.sh
demo/curl/test-hsts.sh
demo/curl/test-correlation-id.sh
```

### 3.3. TLS/mTLS scripts

```text
demo/tls/README.md
demo/tls/generate-dev-certs.sh

demo/mtls/README.md
demo/mtls/generate-mtls-certs.sh
```

### 3.4. Webhook HMAC

```text
demo/webhook/README.md
demo/webhook/sign_webhook.py
demo/webhook/send-valid-webhook.sh
demo/webhook/send-invalid-signature.sh
demo/webhook/send-replay-webhook.sh
```

### 3.5. k6 benchmark

```text
demo/k6/README.md
demo/k6/gateway-latency.js
docs/evidence/tv1/k6-gateway-summary.txt
```

### 3.6. Tài liệu và evidence

```text
docs/evidence/tv1/
docs/chapter3/tv1-edge-gateway-design.md
docs/integration-checklist.md
```

Không đặt file evidence tùy ý như `test.txt`, `result.txt`, `curl.txt`. Tên file phải nói rõ nội dung để nhóm trưởng dễ review và đưa vào báo cáo.

---

## 4. Contract dùng chung để tránh lệch với TV2 và TV3

### 4.1. Gateway base URL chuẩn

Gateway HTTP:

```text
http://localhost:8000
```

Gateway HTTPS nếu bật TLS:

```text
https://localhost:8443
```

Kong Admin API nếu dùng local:

```text
http://localhost:8001
```

Không đổi port nếu chưa thống nhất với nhóm.

### 4.2. Route chuẩn qua Gateway

User service do TV2 phụ trách:

```text
/api/v1/users
```

Order service do TV2 phụ trách:

```text
/api/v1/orders
```

Billing service do TV3 phụ trách:

```text
/api/v1/billing
```

Admin service do TV3 phụ trách:

```text
/api/v1/admin
```

Webhook nếu đặt qua Gateway:

```text
/api/v1/webhooks
```

Endpoint health phải đi qua Gateway được:

```text
GET /api/v1/users/health
GET /api/v1/orders/health
GET /api/v1/billing/health
GET /api/v1/admin/health
```

### 4.3. Header chuẩn phải được Gateway cho đi qua

```text
Authorization
Content-Type
X-Correlation-ID
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

Nếu TV2/TV3 thêm header bảo mật mới, TV1 phải cập nhật CORS/gateway config và ghi trong `gateway/README.md`.

### 4.4. CORS origin chuẩn

Origin mặc định cần hỗ trợ:

```text
http://localhost:3000
http://localhost:5173
https://app.localhost
```

Method cần cho phép:

```text
GET
POST
PUT
DELETE
OPTIONS
```

### 4.5. Webhook HMAC contract

Header bắt buộc:

```text
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

Message format:

```text
timestamp + "." + nonce + "." + raw_body
```

Thuật toán:

```text
HMAC-SHA256
```

Điều kiện reject:

```text
Thiếu timestamp
Thiếu nonce
Thiếu signature
Signature sai
Timestamp quá cũ
Replay nonce
```

Secret không hard-code trong script. Nếu cần dùng secret demo, đọc từ biến môi trường:

```bash
WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret}"
```

Secret path do TV2/Vault thống nhất:

```text
secret/data/api/webhook
```

### 4.6. Correlation ID contract

Header chuẩn:

```text
X-Correlation-ID
```

Nếu request có `X-Correlation-ID`, Gateway phải cho header này đi qua backend.

Nếu request không có `X-Correlation-ID`, TV1 phải ghi rõ hướng xử lý trong `gateway/correlation-id.md`. Nếu chưa generate tự động tại Gateway, ghi rõ: backend hoặc client demo sẽ gửi header này.

### 4.7. Rate limit contract

Rate limit mặc định đề xuất:

```text
60 requests/minute cho route bình thường
10 requests/minute cho route nhạy cảm nếu cấu hình theo route được
```

Endpoint nhạy cảm:

```text
/api/v1/users
/api/v1/orders
/api/v1/admin
/api/v1/webhooks
```

Rate limit test phải tạo được HTTP status:

```text
429 Too Many Requests
```

### 4.8. WAF/filter contract

Nếu dùng Kong OSS, không được ghi mơ hồ là đã triển khai full enterprise WAF nếu thực tế chỉ có gateway-level filtering. Phải ghi rõ phạm vi:

```text
Gateway-level filtering
Request validation
Payload size limit nếu cấu hình được
Method restriction
Header validation
Rate limiting
Pattern-based blocking nếu có plugin/config phù hợp
```

---

## 5. Giai đoạn 0 – Kiểm tra baseline

### Mục tiêu

Đảm bảo TV1 bắt đầu từ branch nền chạy được, Gateway route hiện tại hoạt động, service health check qua Kong không lỗi.

### Việc cần làm

- Đảm bảo đang ở branch `feat/tv1-gateway-edge-security`.
- Chạy Docker Compose.
- Kiểm tra Gateway và 4 service health.
- Lưu evidence baseline.

### Lệnh

```bash
cd ~/API
git status

docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps

mkdir -p docs/evidence/tv1

{
  echo "===== users health ====="
  curl -i http://localhost:8000/api/v1/users/health
  echo
  echo "===== orders health ====="
  curl -i http://localhost:8000/api/v1/orders/health
  echo
  echo "===== billing health ====="
  curl -i http://localhost:8000/api/v1/billing/health
  echo
  echo "===== admin health ====="
  curl -i http://localhost:8000/api/v1/admin/health
} > docs/evidence/tv1/initial-gateway-health.txt
```

### File phải có

```text
docs/evidence/tv1/initial-gateway-health.txt
```

### Commit

```bash
git add docs/evidence/tv1/initial-gateway-health.txt
git commit -m "test: record initial gateway health checks"
git push
```

---

## 6. Giai đoạn 1 – Chuẩn hóa Kong Gateway routes

### Mục tiêu

Kong Gateway trở thành điểm vào duy nhất cho client, định tuyến request tới User/Order/Billing/Admin/Webhook service.

### Việc cần làm

- Kiểm tra và hoàn thiện `gateway/kong.yml`.
- Đảm bảo route không strip sai path.
- Đảm bảo mỗi service route có tên rõ ràng.
- Cập nhật `gateway/README.md`.
- Tạo script test route.
- Lưu evidence route.

### Route bắt buộc

```text
/api/v1/users    -> user-service
/api/v1/orders   -> order-service
/api/v1/billing  -> billing-service
/api/v1/admin    -> admin-service
/api/v1/webhooks -> billing-service hoặc service được nhóm thống nhất
```

### File phải có

```text
gateway/kong.yml
gateway/README.md
demo/curl/test-gateway-routes.sh
docs/evidence/tv1/gateway-routes.txt
```

### Nội dung script `demo/curl/test-gateway-routes.sh`

Script phải test tối thiểu:

```text
GET /api/v1/users/health
GET /api/v1/orders/health
GET /api/v1/billing/health
GET /api/v1/admin/health
```

Script phải có `set -euo pipefail` và target mặc định:

```bash
BASE_URL="${BASE_URL:-http://localhost:8000}"
```

### Commit

```bash
git add gateway/kong.yml gateway/README.md demo/curl/test-gateway-routes.sh docs/evidence/tv1/gateway-routes.txt
git commit -m "gateway: define and verify service routes"
git push
```

### Thông tin cần báo cho TV2/TV3

```text
Gateway base URL
Route prefix
Route nào public/protected nếu có
Có strip_path hay không
```

---

## 7. Giai đoạn 2 – CORS policy

### Mục tiêu

Gateway xử lý CORS thống nhất cho frontend/local demo và cho phép các header bảo mật cần thiết.

### Việc cần làm

- Cấu hình CORS trong `gateway/kong.yml`.
- Cho phép origin, method, header theo contract.
- Tạo script preflight.
- Lưu evidence response header.

### Origin bắt buộc

```text
http://localhost:3000
http://localhost:5173
https://app.localhost
```

### Header bắt buộc

```text
Authorization
Content-Type
X-Correlation-ID
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

### File phải có

```text
gateway/kong.yml
gateway/README.md
demo/curl/test-cors.sh
docs/evidence/tv1/cors-preflight.txt
```

### Test mẫu

```bash
curl -i -X OPTIONS http://localhost:8000/api/v1/users/me \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization,Content-Type,X-Correlation-ID"
```

### Commit

```bash
git add gateway/kong.yml gateway/README.md demo/curl/test-cors.sh docs/evidence/tv1/cors-preflight.txt
git commit -m "gateway: configure cors policy"
git push
```

---

## 8. Giai đoạn 3 – Rate limiting

### Mục tiêu

Gateway có cơ chế hạn chế request để chống brute force/credential stuffing/rate abuse ở mức biên.

### Việc cần làm

- Cấu hình Kong rate-limiting plugin.
- Tạo policy document.
- Tạo script trigger 429.
- Lưu evidence.
- Không đặt ngưỡng quá thấp làm hỏng demo bình thường.

### Threshold đề xuất

```text
Global route: 60 requests/minute
Sensitive route nếu cấu hình được: 10 requests/minute
```

### File phải có

```text
gateway/kong.yml
gateway/rate-limit-policy.md
demo/curl/test-rate-limit.sh
docs/evidence/tv1/rate-limit-result.txt
```

### Expected result

```text
Gửi nhiều request liên tục.
Gateway trả HTTP 429 Too Many Requests.
Evidence phải lưu được response chứa 429.
```

### Commit

```bash
git add gateway/kong.yml gateway/rate-limit-policy.md demo/curl/test-rate-limit.sh docs/evidence/tv1/rate-limit-result.txt
git commit -m "gateway: add rate limiting controls"
git push
```

### Thông tin cần báo cho TV3

```text
Endpoint nào dùng để trigger 429
Threshold là bao nhiêu
Expected status code
Log/response có dấu hiệu gì
```

---

## 9. Giai đoạn 4 – WAF/filter cơ bản tại biên

### Mục tiêu

Tạo lớp lọc request bất thường ở Gateway và tài liệu hóa rõ phạm vi bảo vệ.

### Việc cần làm

- Viết `gateway/waf-rules.md`.
- Cấu hình trong `gateway/kong.yml` nếu có thể.
- Tạo script test.
- Lưu evidence.
- Ghi rõ giới hạn nếu Kong OSS không có full WAF.

### Nhóm rule tối thiểu

```text
Method không hợp lệ
Payload quá lớn nếu cấu hình được
Header bắt buộc bị thiếu nếu endpoint yêu cầu
Pattern SQLi/XSS mẫu nếu có rule phù hợp
Request bất thường bị reject hoặc bị limit
```

### File phải có

```text
gateway/kong.yml
gateway/waf-rules.md
demo/curl/test-waf-filter.sh
docs/evidence/tv1/waf-filter-result.txt
```

### Expected result

```text
Request hợp lệ đi qua.
Request bất thường bị reject/filter/rate-limit theo cấu hình.
Nếu chỉ document được rule, phải ghi rõ limitation.
```

### Commit

```bash
git add gateway/kong.yml gateway/waf-rules.md demo/curl/test-waf-filter.sh docs/evidence/tv1/waf-filter-result.txt
git commit -m "gateway: document and test edge filtering rules"
git push
```

---

## 10. Giai đoạn 5 – HTTPS/TLS termination

### Mục tiêu

Chuẩn bị hoặc triển khai TLS termination tại Gateway cho demo HTTPS.

### Việc cần làm

- Viết `gateway/tls.md`.
- Tạo `demo/tls/generate-dev-certs.sh`.
- Tạo `demo/tls/README.md`.
- Nếu cấu hình được Kong HTTPS với cert demo, cập nhật Compose/Kong config.
- Không commit private key thật.
- Tạo script test HTTPS.
- Lưu evidence.

### File phải có

```text
gateway/tls.md
demo/tls/README.md
demo/tls/generate-dev-certs.sh
demo/curl/test-https.sh
docs/evidence/tv1/https-result.txt
```

Nếu cần sửa Compose:

```text
infra/docker-compose.yml
gateway/kong.yml
```

### Test mẫu

```bash
curl -k -i https://localhost:8443/api/v1/users/health
```

### Commit

```bash
git add gateway/tls.md demo/tls/README.md demo/tls/generate-dev-certs.sh demo/curl/test-https.sh docs/evidence/tv1/https-result.txt
git commit -m "gateway: prepare tls termination for demo"
git push
```

Nếu có sửa Compose/Kong:

```bash
git add infra/docker-compose.yml gateway/kong.yml
git commit -m "gateway: wire tls configuration into compose"
git push
```

### Lưu ý merge

`infra/docker-compose.yml` là file chung. Nếu TV1 sửa file này, phải báo cho nhóm trước khi PR.

---

## 11. Giai đoạn 6 – HSTS header

### Mục tiêu

Gateway trả header HSTS cho HTTPS response để thể hiện chính sách ép HTTPS.

### Header chuẩn

```text
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### Việc cần làm

- Cấu hình response header tại Gateway nếu làm được.
- Tài liệu hóa trong `gateway/tls.md`.
- Tạo script test.
- Lưu evidence.

### File phải có

```text
gateway/kong.yml
gateway/tls.md
demo/curl/test-hsts.sh
docs/evidence/tv1/hsts-header.txt
```

### Test mẫu

```bash
curl -k -i https://localhost:8443/api/v1/users/health | grep -i strict-transport-security
```

### Commit

```bash
git add gateway/kong.yml gateway/tls.md demo/curl/test-hsts.sh docs/evidence/tv1/hsts-header.txt
git commit -m "gateway: add hsts response header"
git push
```

---

## 12. Giai đoạn 7 – mTLS Gateway-to-Backend design

### Mục tiêu

Thiết kế hoặc chuẩn bị mTLS giữa Gateway và backend service, không làm vỡ Docker Compose mặc định.

### Việc cần làm

- Viết `gateway/mtls.md`.
- Tạo script sinh cert demo.
- Tạo tài liệu CA, Gateway cert, Backend cert.
- Không bật mTLS runtime nếu backend của TV2/TV3 chưa hỗ trợ TLS.
- Nếu chưa runtime đầy đủ, ghi rõ trạng thái là `documented + script + integration note`.

### File phải có

```text
gateway/mtls.md
demo/mtls/README.md
demo/mtls/generate-mtls-certs.sh
docs/evidence/tv1/mtls-design-note.txt
```

### Nội dung `gateway/mtls.md` phải có

```text
Mục tiêu mTLS
CA demo
Gateway certificate
Backend certificate
Luồng xác minh certificate
Cách tích hợp vào Kong
Cách backend cần cấu hình sau này
Giới hạn hiện tại nếu chưa bật runtime
```

### Commit

```bash
git add gateway/mtls.md demo/mtls/README.md demo/mtls/generate-mtls-certs.sh docs/evidence/tv1/mtls-design-note.txt
git commit -m "gateway: prepare mtls design and certificate scripts"
git push
```

### Thông tin cần báo cho TV2/TV3

```text
Backend cần hỗ trợ TLS/mTLS như thế nào nếu bật runtime
Port/backend URL có thay đổi không
Cert mount path dự kiến
```

---

## 13. Giai đoạn 8 – Webhook HMAC + Nonce + Timestamp

### Mục tiêu

Chuẩn hóa cơ chế bảo vệ webhook để chống giả mạo và replay.

### Việc cần làm

- Viết `gateway/webhook-security.md`.
- Tạo script ký webhook.
- Tạo script gửi webhook hợp lệ.
- Tạo script gửi webhook sai chữ ký.
- Tạo script gửi replay webhook.
- Lưu evidence.
- Không hard-code secret thật.

### Header bắt buộc

```text
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

### Message format

```text
timestamp + "." + nonce + "." + raw_body
```

### Thuật toán

```text
HMAC-SHA256
```

### File phải có

```text
gateway/webhook-security.md
demo/webhook/README.md
demo/webhook/sign_webhook.py
demo/webhook/send-valid-webhook.sh
demo/webhook/send-invalid-signature.sh
demo/webhook/send-replay-webhook.sh
docs/evidence/tv1/webhook-valid.txt
docs/evidence/tv1/webhook-invalid-signature.txt
docs/evidence/tv1/webhook-replay.txt
```

### Commit

```bash
git add gateway/webhook-security.md demo/webhook docs/evidence/tv1/webhook-*.txt
git commit -m "gateway: define webhook hmac replay protection"
git push
```

### Thông tin cần báo cho TV2/TV3

```text
Header webhook
HMAC message format
Secret path cần lấy từ Vault
Expected response valid/invalid/replay
TV3 cần endpoint xử lý webhook nếu đặt ở Billing
```

---

## 14. Giai đoạn 9 – Correlation ID

### Mục tiêu

Đảm bảo request ID/correlation ID đi xuyên qua Gateway để phục vụ log, tracing và evidence.

### Việc cần làm

- Cập nhật CORS/header nếu cần.
- Viết `gateway/correlation-id.md`.
- Tạo script test.
- Lưu evidence.
- Nếu Gateway chưa tự generate ID, ghi rõ client/backend chịu trách nhiệm tạo.

### File phải có

```text
gateway/kong.yml
gateway/correlation-id.md
demo/curl/test-correlation-id.sh
docs/evidence/tv1/correlation-id-result.txt
```

### Test mẫu

```bash
curl -i http://localhost:8000/api/v1/users/profile \
  -H "X-Correlation-ID: tv1-correlation-001"
```

### Commit

```bash
git add gateway/kong.yml gateway/correlation-id.md demo/curl/test-correlation-id.sh docs/evidence/tv1/correlation-id-result.txt
git commit -m "gateway: preserve correlation id across requests"
git push
```

### Thông tin cần báo cho TV3

```text
Correlation header name
Gateway có generate ID không
Backend/log nên đọc header nào
```

---

## 15. Giai đoạn 10 – k6 Gateway latency benchmark

### Mục tiêu

Đo overhead/latency cơ bản của Gateway để phục vụ đánh giá.

### Metric bắt buộc

```text
p50 latency
p95 latency
request rate
failed request rate
```

### Endpoint test tối thiểu

```text
GET /api/v1/users/health
GET /api/v1/orders/health
GET /api/v1/billing/health
GET /api/v1/admin/health
```

### File phải có

```text
demo/k6/README.md
demo/k6/gateway-latency.js
docs/evidence/tv1/k6-gateway-summary.txt
```

### Lệnh test mẫu

```bash
k6 run demo/k6/gateway-latency.js | tee docs/evidence/tv1/k6-gateway-summary.txt
```

Nếu chưa cài k6, tài liệu phải ghi rõ cách cài hoặc cách chạy bằng Docker.

### Commit

```bash
git add demo/k6 docs/evidence/tv1/k6-gateway-summary.txt
git commit -m "test: add gateway latency benchmark"
git push
```

---

## 16. Giai đoạn 11 – Tích hợp với TV2

### Mục tiêu

Đảm bảo Gateway không làm hỏng luồng auth của TV2.

### Việc cần kiểm tra với TV2

```text
Authorization header đi qua Gateway.
X-Correlation-ID đi qua Gateway.
CORS cho phép Authorization header.
Route User/Order khớp OpenAPI.
Rate limit không quá thấp làm hỏng token/API demo.
Webhook secret path nếu dùng Vault.
```

### File phải có

```text
docs/evidence/tv1/tv2-auth-gateway-integration-note.txt
docs/integration-checklist.md
```

### Commit

```bash
git add docs/evidence/tv1/tv2-auth-gateway-integration-note.txt docs/integration-checklist.md
git commit -m "docs: record auth gateway integration requirements"
git push
```

---

## 17. Giai đoạn 12 – Tích hợp với TV3

### Mục tiêu

Đảm bảo Gateway, rate limit, webhook, CORS và correlation ID tương thích với test/attack/observability của TV3.

### Việc cần kiểm tra với TV3

```text
Billing/Admin route đúng.
Webhook route đúng nếu đặt ở Billing.
Rate limit trigger tạo được 429 cho attack script.
CORS cho phép webhook/correlation headers.
Gateway response đủ để TV3 tạo alert/evidence.
```

### File phải có

```text
docs/evidence/tv1/tv3-observability-gateway-integration-note.txt
docs/integration-checklist.md
```

### Commit

```bash
git add docs/evidence/tv1/tv3-observability-gateway-integration-note.txt docs/integration-checklist.md
git commit -m "docs: record observability gateway integration requirements"
git push
```

---

## 18. Giai đoạn 13 – Tài liệu Chương 3

### Mục tiêu

Viết phần thiết kế chốt chặn biên cho báo cáo Chương 3.

### Nội dung bắt buộc

```text
Vai trò API Gateway trong kiến trúc
Service routing
TLS termination
HSTS
CORS
Rate limiting
WAF/filter
mTLS Gateway-to-Backend
Webhook HMAC + nonce/timestamp
Correlation ID
Giới hạn của prototype nếu có
```

### File bắt buộc

```text
docs/chapter3/tv1-edge-gateway-design.md
```

### Commit

```bash
git add docs/chapter3/tv1-edge-gateway-design.md
git commit -m "docs: describe gateway edge security design"
git push
```

---

## 19. Giai đoạn 14 – Evidence tổng hợp

### Mục tiêu

Có đủ bằng chứng thực nghiệm để đưa vào báo cáo.

### File evidence tối thiểu

```text
docs/evidence/tv1/initial-gateway-health.txt
docs/evidence/tv1/gateway-routes.txt
docs/evidence/tv1/cors-preflight.txt
docs/evidence/tv1/rate-limit-result.txt
docs/evidence/tv1/waf-filter-result.txt
docs/evidence/tv1/https-result.txt
docs/evidence/tv1/hsts-header.txt
docs/evidence/tv1/mtls-design-note.txt
docs/evidence/tv1/webhook-valid.txt
docs/evidence/tv1/webhook-invalid-signature.txt
docs/evidence/tv1/webhook-replay.txt
docs/evidence/tv1/correlation-id-result.txt
docs/evidence/tv1/k6-gateway-summary.txt
docs/evidence/tv1/tv2-auth-gateway-integration-note.txt
docs/evidence/tv1/tv3-observability-gateway-integration-note.txt
```

### Commit

```bash
git add docs/evidence/tv1
git commit -m "test: collect tv1 gateway edge security evidence"
git push
```

---

## 20. Giai đoạn 15 – Final self-check trước khi tạo PR

### Lệnh kiểm tra

```bash
cd ~/API
git status

docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps

curl -i http://localhost:8000/api/v1/users/health
curl -i http://localhost:8000/api/v1/orders/health
curl -i http://localhost:8000/api/v1/billing/health
curl -i http://localhost:8000/api/v1/admin/health
```

Nếu script đã có:

```bash
bash demo/curl/test-gateway-routes.sh
bash demo/curl/test-cors.sh
bash demo/curl/test-rate-limit.sh
bash demo/curl/test-correlation-id.sh
```

Nếu TLS đã bật:

```bash
bash demo/curl/test-https.sh
bash demo/curl/test-hsts.sh
```

Nếu webhook demo đã có:

```bash
bash demo/webhook/send-valid-webhook.sh
bash demo/webhook/send-invalid-signature.sh
bash demo/webhook/send-replay-webhook.sh
```

### Checklist file phải có

```text
gateway/kong.yml
gateway/README.md
gateway/rate-limit-policy.md
gateway/waf-rules.md
gateway/tls.md
gateway/mtls.md
gateway/webhook-security.md
gateway/correlation-id.md

demo/curl/test-gateway-routes.sh
demo/curl/test-cors.sh
demo/curl/test-rate-limit.sh
demo/curl/test-waf-filter.sh
demo/curl/test-https.sh
demo/curl/test-hsts.sh
demo/curl/test-correlation-id.sh

demo/tls/README.md
demo/tls/generate-dev-certs.sh

demo/mtls/README.md
demo/mtls/generate-mtls-certs.sh

demo/webhook/README.md
demo/webhook/sign_webhook.py
demo/webhook/send-valid-webhook.sh
demo/webhook/send-invalid-signature.sh
demo/webhook/send-replay-webhook.sh

demo/k6/README.md
demo/k6/gateway-latency.js

docs/evidence/tv1/
docs/chapter3/tv1-edge-gateway-design.md
```

### Push cuối

```bash
git status
git push
```

---

## 21. Pull Request

Khi hoàn thành một mốc lớn hoặc toàn bộ phần TV1, tạo Pull Request trên GitHub.

PR chuẩn:

```text
base: setup/project-contracts
compare: feat/tv1-gateway-edge-security
```

Không merge trực tiếp nếu:

```text
- Docker Compose đang lỗi.
- Health check qua Gateway lỗi.
- CORS chặn Authorization hoặc X-Correlation-ID.
- Rate limit quá thấp làm hỏng demo.
- Có private key/cert secret trong commit.
- Evidence thiếu.
- Conflict với TV2/TV3 chưa xử lý.
```

Nội dung PR cần ghi:

```text
1. Đã làm gì
2. File chính đã thay đổi
3. Cách chạy test
4. Evidence nằm ở đâu
5. Cần TV2/TV3 chú ý gì
```

---

## 22. Thứ tự ưu tiên nếu thiếu thời gian

Nếu không đủ thời gian làm hết, ưu tiên theo thứ tự:

### Bắt buộc

```text
1. Gateway routes
2. CORS policy
3. Rate limiting
4. Correlation ID
5. Gateway README
6. Script test route/CORS/rate-limit
7. Evidence cơ bản
8. Chapter 3 edge gateway design
```

### Quan trọng

```text
9. Webhook HMAC contract + demo scripts
10. TLS/HSTS
11. WAF/filter document + test
12. k6 gateway benchmark
```

### Hoàn thiện thêm

```text
13. mTLS runtime đầy đủ
14. TLS certificate automation nâng cao
15. Gateway benchmark chi tiết
16. More negative tests cho WAF/filter
```

---

## 23. Definition of Done của TV1

TV1 được xem là hoàn thành khi đạt đủ điều kiện:

```text
- Branch feat/tv1-gateway-edge-security đã push lên GitHub.
- Kong Gateway route đúng User/Order/Billing/Admin.
- Health check qua Gateway chạy được.
- CORS cho phép Authorization, Content-Type, X-Correlation-ID và webhook headers.
- Rate limiting tạo được HTTP 429.
- WAF/filter có tài liệu rõ và test/evidence phù hợp.
- TLS/HTTPS được chuẩn bị hoặc triển khai, có evidence/note rõ.
- HSTS có cấu hình/evidence nếu TLS bật.
- mTLS có design và script sinh cert demo.
- Webhook HMAC + nonce/timestamp có contract và demo scripts.
- Correlation ID được preserve qua Gateway.
- k6 benchmark có script và summary.
- Có evidence trong docs/evidence/tv1.
- Có tài liệu Chương 3 cho phần edge gateway.
- Không commit private key/secret/token thật.
- Docker Compose vẫn build/chạy được.
- PR được tạo để merge vào setup/project-contracts.
```
