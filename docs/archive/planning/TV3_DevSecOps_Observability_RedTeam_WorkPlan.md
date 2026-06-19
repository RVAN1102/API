# Historical Planning Notice

This document is historical planning material from an earlier implementation
phase. It is superseded by the current final evidence index, final regression
11-suite result, and runtime documentation. TODO/placeholder wording below is
preserved as planning context, not as the current project status.

# TV3 – DevSecOps, Observability & Red Team Analyst: Work Plan & Merge Contract

**Dự án:** SME Cloud-Native Microservices API Security – Topic 10  
**Thành viên phụ trách:** TV3 – DevSecOps, Observability & Red Team Analyst  
**Branch làm việc:** `feat/tv3-devsecops-observability-redteam`  
**Branch nền:** `setup/project-contracts`  
**Mục tiêu:** triển khai Billing/Admin API, SSRF vulnerable/fixed, structured logging, Loki/Promtail/Grafana, alert rules, attack simulation, ZAP/RESTler, CI security scan, MTTD/MTTR và bằng chứng kiểm thử. File này quy định rõ tên file, thư mục, commit point và integration contract để khi merge với TV1/TV2 không bị lệch route, lệch log schema, lệch attack script hoặc lệch evidence.

---

## 1. Nguyên tắc làm việc bắt buộc

TV3 không làm trực tiếp trên `main` hoặc `setup/project-contracts`. Toàn bộ phần việc phải làm trên branch riêng:

```bash
git clone https://github.com/RVAN1102/API.git
cd API
git switch setup/project-contracts
git pull
git switch -c feat/tv3-devsecops-observability-redteam
git push -u origin feat/tv3-devsecops-observability-redteam
```

Các lần làm sau:

```bash
cd ~/API
git switch feat/tv3-devsecops-observability-redteam
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
log quá lớn
report quá lớn không cần thiết
```

Nếu evidence có token/header nhạy cảm, phải che bớt:

```text
Authorization: Bearer eyJhbGciOi...<redacted>
client_secret=<redacted>
```

---

## 2. Phạm vi phụ trách của TV3

TV3 chịu trách nhiệm chính cho các thư mục và file sau:

```text
services/billing/
services/admin/
observability/
ci/
.github/workflows/
tests/attack/
tests/zap/
tests/restler/
tests/metrics/
docs/evidence/tv3/
docs/chapter5/
```

TV3 không sửa sâu vào các thư mục sau nếu chưa thống nhất với nhóm:

```text
gateway/
idp/
vault/
services/user/
services/order/
```

Trường hợp cần sửa file chung như `infra/docker-compose.yml`, `docs/api-contract.md`, `openapi.yaml`, `docs/integration-checklist.md`, phải ghi rõ trong commit và báo nhóm vì đây là các file dễ gây conflict.

---

## 3. Quy ước tên file và thư mục bắt buộc

### 3.1. Billing Service

```text
services/billing/main.py
services/billing/README.md
```

### 3.2. Admin Service

```text
services/admin/main.py
services/admin/README.md
services/admin/ssrf-protection.md
```

### 3.3. Observability

```text
observability/README.md
observability/log-schema.md
observability/loki/loki-config.yml
observability/promtail/promtail-config.yml
observability/grafana/provisioning/datasources/loki.yml
observability/grafana/provisioning/dashboards/dashboard.yml
observability/grafana/dashboards/api-security-overview.json
observability/alerts/api-security-alerts.md
observability/alerts/loki-alert-rules.yml
```

### 3.4. Attack simulation

```text
tests/attack/README.md
tests/attack/ssrf-attack.sh
tests/attack/token-replay.sh
tests/attack/webhook-forgery.sh
tests/attack/bola-object-access.sh
tests/attack/rate-limit-trigger.sh
```

### 3.5. OWASP ZAP Active Scan/API Scan

```text
tests/security/zap-active-scan.sh
docs/evidence/tv3/zap/zap-active-run.log
docs/evidence/tv3/zap/zap-active-summary.md
docs/evidence/tv3/zap/zap-active-report.html
docs/evidence/tv3/zap/zap-active-report.json
```

### 3.6. RESTler/Fuzzing

```text
tests/restler/README.md
tests/restler/restler-settings.json
tests/restler/run-restler-check.sh
docs/evidence/tv3/restler-check-summary.txt
```

### 3.7. Metrics

```text
tests/metrics/README.md
tests/metrics/measure-mttd-mttr.sh
docs/evidence/tv3/mttd-mttr-results.csv
docs/evidence/tv3/mttd-mttr-analysis.md
```

### 3.8. CI Security Scan

```text
.github/workflows/security-scan.yml
ci/security-scan.md
ci/run-local-security-scan.sh
docs/evidence/tv3/security-scan-local.txt
```

### 3.9. Tài liệu và evidence

```text
docs/evidence/tv3/
docs/chapter5/tv3-devsecops-observability-redteam.md
docs/integration-checklist.md
```

Không đặt file evidence tùy ý như `test.txt`, `result1.txt`, `scan.txt`. Tên file phải mô tả rõ nội dung để nhóm trưởng dễ review và đưa vào báo cáo.

---

## 4. Contract dùng chung để tránh lệch với TV1 và TV2

### 4.1. Endpoint Billing chuẩn

```text
GET  /api/v1/billing/health
POST /api/v1/billing/checkout
POST /api/v1/webhooks/payment
```

Nếu webhook được thống nhất đặt ở Billing, TV3 phải phối hợp với TV1 về HMAC header và với TV2 về Vault secret path.

### 4.2. Endpoint Admin chuẩn

```text
GET  /api/v1/admin/health
POST /api/v1/admin/maintenance
POST /api/v1/admin/metadata-fetch/vulnerable
POST /api/v1/admin/metadata-fetch/fixed
```

Endpoint SSRF chỉ dùng cho demo lab/local, không dùng để tấn công hệ thống thật.

### 4.3. Header chuẩn

Các request test phải dùng các header sau khi cần:

```text
Authorization: Bearer <access_token>
Content-Type: application/json
X-Correlation-ID: <request-id>
```

Webhook dùng header do TV1 chuẩn hóa:

```text
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

HMAC message format thống nhất với TV1:

```text
timestamp + "." + nonce + "." + raw_body
```

Thuật toán:

```text
HMAC-SHA256
```

### 4.4. Log schema chuẩn

Billing/Admin service phải log JSON tối thiểu các trường sau:

```text
timestamp
level
service
method
path
status_code
client_ip
correlation_id
event_type
message
```

Nếu là event bảo mật, bổ sung:

```text
security_event
actor
target
decision
reason
```

Không log token đầy đủ, password, secret, private key hoặc client secret.

### 4.5. Security event type chuẩn

TV3 dùng các `event_type` sau để TV2/TV1 có thể phối hợp:

```text
api_request
auth_failed
authz_forbidden
rate_limit_triggered
ssrf_attempt
ssrf_blocked
webhook_invalid_signature
webhook_replay_detected
bola_attempt
zap_scan_finding
ci_security_finding
```

### 4.6. Attack scenario chuẩn

Các attack script phải chạy trên `localhost` và target mặc định:

```text
http://localhost:8000
```

Không scan hoặc tấn công domain ngoài Internet.

---

## 5. Giai đoạn 0 – Kiểm tra baseline

### Mục tiêu

Đảm bảo TV3 bắt đầu từ branch nền đã chạy được và không phá vỡ Gateway/service skeleton.

### Việc cần làm

- Đảm bảo đang ở branch `feat/tv3-devsecops-observability-redteam`.
- Chạy Docker Compose.
- Kiểm tra Billing/Admin health qua Gateway.
- Lưu evidence baseline.

### Lệnh

```bash
cd ~/API
git status

docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps

mkdir -p docs/evidence/tv3

{
  echo "===== billing health ====="
  curl -i http://localhost:8000/api/v1/billing/health
  echo
  echo "===== admin health ====="
  curl -i http://localhost:8000/api/v1/admin/health
} > docs/evidence/tv3/initial-billing-admin-health.txt
```

### File phải có

```text
docs/evidence/tv3/initial-billing-admin-health.txt
```

### Commit

```bash
git add docs/evidence/tv3/initial-billing-admin-health.txt
git commit -m "test: record initial billing and admin health checks"
git push
```

---

## 6. Giai đoạn 1 – Hoàn thiện Billing API

### Mục tiêu

Billing service có endpoint rõ ràng để phục vụ demo checkout, webhook và log.

### Endpoint bắt buộc

```text
GET  /api/v1/billing/health
POST /api/v1/billing/checkout
POST /api/v1/webhooks/payment
```

### Việc cần làm

- Sửa `services/billing/main.py`.
- Cập nhật `services/billing/README.md`.
- `checkout` nhận JSON gồm `order_id`, `amount`, `currency` nếu cần.
- Response phải có `payment_id`, `order_id`, `status`, `correlation_id`.
- Nếu có webhook endpoint, chưa cần kiểm HMAC đầy đủ nếu TV1 chưa chốt, nhưng phải để sẵn integration note.
- Giữ `X-Correlation-ID`.

### File phải có

```text
services/billing/main.py
services/billing/README.md
docs/evidence/tv3/billing-api-result.txt
```

### Test mẫu

```bash
curl -i http://localhost:8000/api/v1/billing/health

curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: tv3-billing-001" \
  -d '{"order_id":"ord-alice-1001","amount":120000,"currency":"VND"}'
```

### Commit

```bash
git add services/billing/main.py services/billing/README.md docs/evidence/tv3/billing-api-result.txt
git commit -m "billing: implement checkout api skeleton"
git push
```

### Thông tin cần báo cho TV1/TV2

```text
Billing endpoint mới
Webhook endpoint nếu có
Header cần đi qua Gateway
Role/scope cần từ TV2 nếu protected
```

---

## 7. Giai đoạn 2 – Hoàn thiện Admin API

### Mục tiêu

Admin service có endpoint quản trị và endpoint phục vụ demo SSRF.

### Endpoint bắt buộc

```text
GET  /api/v1/admin/health
POST /api/v1/admin/maintenance
POST /api/v1/admin/metadata-fetch/vulnerable
POST /api/v1/admin/metadata-fetch/fixed
```

### Việc cần làm

- Sửa `services/admin/main.py`.
- Cập nhật `services/admin/README.md`.
- `maintenance` nhận `action`.
- `metadata-fetch/vulnerable` nhận `url` và mô phỏng fetch không kiểm soát.
- `metadata-fetch/fixed` nhận `url` nhưng chặn URL nguy hiểm.
- Giữ `X-Correlation-ID`.

### File phải có

```text
services/admin/main.py
services/admin/README.md
docs/evidence/tv3/admin-api-result.txt
```

### Test mẫu

```bash
curl -i http://localhost:8000/api/v1/admin/health

curl -i -X POST http://localhost:8000/api/v1/admin/maintenance \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: tv3-admin-001" \
  -d '{"action":"reindex"}'
```

### Commit

```bash
git add services/admin/main.py services/admin/README.md docs/evidence/tv3/admin-api-result.txt
git commit -m "admin: implement maintenance api skeleton"
git push
```

---

## 8. Giai đoạn 3 – SSRF vulnerable/fixed

### Mục tiêu

Tạo demo SSRF có kiểm soát để chứng minh lỗ hổng và bản vá.

### Rule bản vulnerable

```text
Nhận URL từ request body.
Không validate scheme/host/IP.
Mô phỏng backend fetch URL.
Cho thấy request tới metadata endpoint có thể được gọi.
```

### Rule bản fixed

Phải chặn:

```text
169.254.169.254
localhost
127.0.0.1
0.0.0.0
::1
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
file://
gopher://
ftp:// nếu không cần
scheme không phải http/https
domain resolve về private IP
```

### File phải có

```text
services/admin/main.py
services/admin/ssrf-protection.md
tests/attack/ssrf-vulnerable.sh
tests/attack/ssrf-fixed.sh
docs/evidence/tv3/ssrf-vulnerable-result.txt
docs/evidence/tv3/ssrf-fixed-result.txt
```

### Test mẫu

```bash
bash tests/attack/ssrf-vulnerable.sh
bash tests/attack/ssrf-fixed.sh
```

### Expected result

```text
vulnerable endpoint: request nguy hiểm được xử lý hoặc mô phỏng xử lý
fixed endpoint: request tới 169.254.169.254 bị chặn, trả 400 hoặc 403
```

### Commit

```bash
git add services/admin/main.py services/admin/ssrf-protection.md tests/attack/ssrf-*.sh docs/evidence/tv3/ssrf-*.txt
git commit -m "admin: add ssrf vulnerable and fixed demo"
git push
```

### Thông tin cần báo cho nhóm

```text
Endpoint vulnerable
Endpoint fixed
Payload mẫu
Expected HTTP status
Event type log: ssrf_attempt, ssrf_blocked
```

---

## 9. Giai đoạn 4 – Structured JSON logging cho Billing/Admin

### Mục tiêu

Billing/Admin log được dưới dạng JSON để Promtail/Loki/Grafana thu và phân tích.

### Log field bắt buộc

```text
timestamp
level
service
method
path
status_code
client_ip
correlation_id
event_type
message
```

### Security log field nếu có

```text
security_event
actor
target
decision
reason
```

### Việc cần làm

- Sửa `services/billing/main.py`.
- Sửa `services/admin/main.py`.
- Tạo middleware hoặc helper log thống nhất.
- Không log token/secret.
- Viết `observability/log-schema.md`.
- Lưu sample log.

### File phải có

```text
services/billing/main.py
services/admin/main.py
observability/log-schema.md
docs/evidence/tv3/json-log-sample.txt
```

### Lệnh lấy evidence

```bash
docker logs billing-service --tail=50 > /tmp/billing-log.txt
docker logs admin-service --tail=50 > /tmp/admin-log.txt

{
  echo "===== billing logs ====="
  cat /tmp/billing-log.txt
  echo
  echo "===== admin logs ====="
  cat /tmp/admin-log.txt
} > docs/evidence/tv3/json-log-sample.txt
```

### Commit

```bash
git add services/billing/main.py services/admin/main.py observability/log-schema.md docs/evidence/tv3/json-log-sample.txt
git commit -m "observability: add structured json logging for billing and admin"
git push
```

---

## 10. Giai đoạn 5 – Loki, Promtail, Grafana

### Mục tiêu

Tạo stack quan sát log container phục vụ SecOps.

### Thành phần bắt buộc

```text
loki
promtail
grafana
```

### Việc cần làm

- Cập nhật `infra/docker-compose.yml`.
- Tạo config Loki.
- Tạo config Promtail.
- Tạo datasource Grafana.
- Tạo dashboard hoặc dashboard placeholder.
- Cập nhật `observability/README.md`.
- Kiểm tra Compose không làm hỏng Kong/User/Order/Billing/Admin/Keycloak/Vault.

### File phải có

```text
infra/docker-compose.yml
observability/loki/loki-config.yml
observability/promtail/promtail-config.yml
observability/grafana/provisioning/datasources/loki.yml
observability/grafana/provisioning/dashboards/dashboard.yml
observability/grafana/dashboards/api-security-overview.json
observability/README.md
docs/evidence/tv3/observability-compose-ps.txt
```

### Lệnh test

```bash
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps > docs/evidence/tv3/observability-compose-ps.txt
```

Cần thấy thêm:

```text
loki
promtail
grafana
```

### Commit

```bash
git add infra/docker-compose.yml observability docs/evidence/tv3/observability-compose-ps.txt
git commit -m "observability: add loki promtail grafana stack"
git push
```

### Lưu ý merge

`infra/docker-compose.yml` là file chung. Khi sửa file này, TV3 phải báo nhóm vì TV1 hoặc TV2 cũng có thể cần sửa Compose.

---

## 11. Giai đoạn 6 – Alert rules

### Mục tiêu

Định nghĩa cảnh báo bảo mật cho API.

### Alert bắt buộc

```text
Spike HTTP 401/403
Spike HTTP 429
BOLA attempt
SSRF blocked
Webhook invalid signature
Webhook replay detected
```

### Việc cần làm

- Tạo tài liệu alert rule.
- Nếu đủ thời gian, tạo file rule cho Loki/Grafana.
- Nếu chưa tích hợp alert runtime, ghi rõ đây là rule design + query mẫu.

### File phải có

```text
observability/alerts/api-security-alerts.md
observability/alerts/loki-alert-rules.yml
docs/evidence/tv3/alert-rule-notes.txt
```

### Commit

```bash
git add observability/alerts docs/evidence/tv3/alert-rule-notes.txt
git commit -m "observability: define api security alert rules"
git push
```

### Thông tin cần đồng bộ

```text
TV1: HTTP 429/rate-limit event format
TV2: BOLA event format, user identity claim
TV3: SSRF/webhook/scan event format
```

---

## 12. Giai đoạn 7 – Attack simulation scripts

### Mục tiêu

Tạo các script tấn công có kiểm soát để phục vụ đánh giá Chương 5.

### Script bắt buộc

```text
tests/attack/README.md
tests/attack/ssrf-attack.sh
tests/attack/token-replay.sh
tests/attack/webhook-forgery.sh
tests/attack/bola-object-access.sh
tests/attack/rate-limit-trigger.sh
```

### Quy tắc script

- Chỉ target `localhost`.
- Có comment giải thích mục tiêu.
- Không hard-code token thật.
- Nếu cần token, đọc từ biến môi trường:

```bash
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
```

- Nếu thiếu token, script phải báo lỗi rõ ràng.
- BOLA script cần đồng bộ với TV2.
- Rate-limit script cần đồng bộ với TV1.
- Webhook forgery cần đồng bộ với TV1/TV2 nếu secret lấy từ Vault.

### Evidence bắt buộc

```text
docs/evidence/tv3/attack-ssrf.txt
docs/evidence/tv3/attack-token-replay.txt
docs/evidence/tv3/attack-webhook-forgery.txt
docs/evidence/tv3/attack-bola.txt
docs/evidence/tv3/attack-rate-limit.txt
```

### Commit

```bash
git add tests/attack docs/evidence/tv3/attack-*.txt
git commit -m "test: add api attack simulation scripts"
git push
```

---

## 13. Giai đoạn 8 – OWASP ZAP Active Scan/API Scan

### Mục tiêu

Tạo workflow OWASP ZAP Active Scan/API Scan cho API Gateway.

### Target chuẩn

```text
http://localhost:8000
```

### Việc cần làm

- Dùng `tests/security/zap-active-scan.sh`.
- Chạy OWASP ZAP Active Scan/API Scan qua OpenAPI definition.
- Lưu run log, summary, HTML report và JSON report trong `docs/evidence/tv3/zap/`.
- Ghi rõ retired passive-only workflow không phải bằng chứng DAST cuối cùng.
- Không scan domain ngoài Internet.

### File phải có

```text
tests/security/zap-active-scan.sh
docs/evidence/tv3/zap/zap-active-run.log
docs/evidence/tv3/zap/zap-active-summary.md
docs/evidence/tv3/zap/zap-active-report.html
docs/evidence/tv3/zap/zap-active-report.json
```

### Commit

```bash
git add tests/security/zap-active-scan.sh docs/evidence/tv3/zap
git commit -m "test: add zap active api scan workflow"
git push
```

---

## 14. Giai đoạn 9 – RESTler/Fuzzapi test plan

### Mục tiêu

Tạo kế hoạch fuzzing từ OpenAPI contract.

### Việc cần làm

- Tạo `tests/restler/README.md`.
- Tạo `tests/restler/restler-settings.json`.
- Tạo `tests/restler/run-restler-check.sh`.
- Dùng `openapi.yaml` làm input.
- Nếu chưa chạy được RESTler thật, phải ghi rõ limitation.
- Nếu chạy được, lưu summary.

### File phải có

```text
tests/restler/README.md
tests/restler/restler-settings.json
tests/restler/run-restler-check.sh
docs/evidence/tv3/restler-check-summary.txt
```

### Commit

```bash
git add tests/restler docs/evidence/tv3/restler-check-summary.txt
git commit -m "test: add restler api fuzzing plan"
git push
```

### Phụ thuộc TV2

RESTler phụ thuộc OpenAPI của TV2. Nếu TV2 chưa hoàn tất OpenAPI, TV3 tạo plan trước và cập nhật sau khi TV2 push contract mới.

---

## 15. Giai đoạn 10 – CI security scan

### Mục tiêu

Tạo pipeline kiểm tra bảo mật source code và dependency.

### Tool tối thiểu

```text
Bandit cho Python
Gitleaks hoặc secret scan
Trivy filesystem hoặc Docker image scan
```

### Tool optional

```text
Snyk nếu có account/token riêng
ESLint nếu repo có JavaScript/Node.js thật
```

### File phải có

```text
.github/workflows/security-scan.yml
ci/security-scan.md
ci/run-local-security-scan.sh
docs/evidence/tv3/security-scan-local.txt
```

### Lưu ý token GitHub

Nếu push `.github/workflows/security-scan.yml`, token GitHub của TV3 có thể cần quyền:

```text
Workflows: Read and write
```

Không hard-code bất kỳ token nào vào workflow.

### Commit

```bash
git add .github/workflows/security-scan.yml ci docs/evidence/tv3/security-scan-local.txt
git commit -m "ci: add security scan workflow"
git push
```

---

## 16. Giai đoạn 11 – MTTD/MTTR measurement

### Mục tiêu

Có số liệu đánh giá khả năng phát hiện và phản ứng với sự kiện bảo mật.

### Định nghĩa

```text
MTTD: thời gian từ lúc attack script chạy đến lúc log/alert phát hiện.
MTTR: thời gian từ lúc phát hiện đến lúc request bị chặn hoặc cấu hình/code được sửa.
```

### Case đo tối thiểu

```text
SSRF blocked
Rate limit 429
Invalid webhook signature
BOLA attempt nếu TV2 đã sẵn sàng
```

### File phải có

```text
tests/metrics/README.md
tests/metrics/measure-mttd-mttr.sh
docs/evidence/tv3/mttd-mttr-results.csv
docs/evidence/tv3/mttd-mttr-analysis.md
```

### Format CSV đề xuất

```csv
scenario,start_time,detection_time,response_time,mttd_seconds,mttr_seconds,note
ssrf_blocked,...
rate_limit_429,...
webhook_invalid_signature,...
bola_attempt,...
```

### Commit

```bash
git add tests/metrics docs/evidence/tv3/mttd-mttr-results.csv docs/evidence/tv3/mttd-mttr-analysis.md
git commit -m "test: record mttd mttr security metrics"
git push
```

---

## 17. Giai đoạn 12 – Tích hợp với TV1

### Mục tiêu

Đảm bảo Gateway, rate limit, webhook, CORS và correlation ID của TV1 tương thích với test/attack/observability của TV3.

### Việc cần kiểm tra

```text
Gateway route Billing/Admin đúng.
CORS cho phép header webhook/correlation ID.
Rate limit threshold đủ để trigger 429.
Webhook HMAC format thống nhất.
TLS/HTTPS nếu có không làm hỏng ZAP/k6 script.
```

### File phải có

```text
docs/evidence/tv3/tv1-gateway-integration-note.txt
docs/integration-checklist.md
```

### Commit

```bash
git add docs/evidence/tv3/tv1-gateway-integration-note.txt docs/integration-checklist.md
git commit -m "docs: record gateway integration requirements for observability tests"
git push
```

---

## 18. Giai đoạn 13 – Tích hợp với TV2

### Mục tiêu

Đảm bảo attack script, logging, alert và CI test dùng đúng token/role/endpoint của TV2.

### Việc cần lấy từ TV2

```text
Realm name
User token method
Service token method
JWT claims
Role/scope chuẩn
Order ID mẫu cho BOLA
Endpoint BOLA vulnerable/fixed
Expected response code
Vault secret path cho webhook nếu cần
```

### File phải có

```text
docs/evidence/tv3/tv2-authz-integration-note.txt
docs/integration-checklist.md
```

### Commit

```bash
git add docs/evidence/tv3/tv2-authz-integration-note.txt docs/integration-checklist.md
git commit -m "docs: record authz integration requirements for attack tests"
git push
```

---

## 19. Giai đoạn 14 – Tài liệu Chương 5

### Mục tiêu

Viết phần đánh giá, mô phỏng tấn công, DevSecOps, observability và trade-off.

### Nội dung bắt buộc

```text
Billing/Admin API trong prototype
SSRF vulnerable/fixed
Structured JSON logging
Loki/Promtail/Grafana
Security alert rules
Attack simulation
OWASP ZAP Active Scan/API Scan
RESTler/Fuzzapi plan
CI security scan
MTTD/MTTR
Trade-off open-source self-host vs managed cloud services
```

### Trade-off bắt buộc

So sánh:

```text
Keycloak OSS vs AWS Cognito/Auth0
Vault OSS vs AWS KMS/Secrets Manager
Kong OSS vs managed API Gateway/WAF
Loki/Grafana self-host vs CloudWatch/Datadog
```

Theo tiêu chí:

```text
Chi phí
Độ phức tạp vận hành
Bảo mật
Khả năng mở rộng
Phù hợp với công ty nhỏ
```

### File bắt buộc

```text
docs/chapter5/tv3-devsecops-observability-redteam.md
```

### Commit

```bash
git add docs/chapter5/tv3-devsecops-observability-redteam.md
git commit -m "docs: add devsecops observability and red team analysis"
git push
```

---

## 20. Giai đoạn 15 – Evidence tổng hợp

### Mục tiêu

Đủ bằng chứng thực nghiệm để đưa vào báo cáo.

### File evidence tối thiểu

```text
docs/evidence/tv3/initial-billing-admin-health.txt
docs/evidence/tv3/billing-api-result.txt
docs/evidence/tv3/admin-api-result.txt
docs/evidence/tv3/ssrf-vulnerable-result.txt
docs/evidence/tv3/ssrf-fixed-result.txt
docs/evidence/tv3/json-log-sample.txt
docs/evidence/tv3/observability-compose-ps.txt
docs/evidence/tv3/alert-rule-notes.txt
docs/evidence/tv3/attack-ssrf.txt
docs/evidence/tv3/attack-token-replay.txt
docs/evidence/tv3/attack-webhook-forgery.txt
docs/evidence/tv3/attack-bola.txt
docs/evidence/tv3/attack-rate-limit.txt
docs/evidence/tv3/zap/zap-active-summary.md
docs/evidence/tv3/restler-check-summary.txt
docs/evidence/tv3/security-scan-local.txt
docs/evidence/tv3/mttd-mttr-results.csv
docs/evidence/tv3/mttd-mttr-analysis.md
```

### Commit

```bash
git add docs/evidence/tv3
git commit -m "test: collect tv3 devsecops observability evidence"
git push
```

---

## 21. Giai đoạn 16 – Final self-check trước khi tạo PR

### Lệnh kiểm tra

```bash
cd ~/API
git status

docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps

curl -i http://localhost:8000/api/v1/billing/health
curl -i http://localhost:8000/api/v1/admin/health
```

Nếu có script test:

```bash
bash tests/attack/ssrf-attack.sh
bash tests/attack/rate-limit-trigger.sh
```

Nếu TV2 đã có BOLA endpoint:

```bash
bash tests/attack/bola-object-access.sh
```

### Checklist file phải có

```text
services/billing/main.py
services/billing/README.md

services/admin/main.py
services/admin/README.md
services/admin/ssrf-protection.md

observability/README.md
observability/log-schema.md
observability/loki/loki-config.yml
observability/promtail/promtail-config.yml
observability/grafana/provisioning/datasources/loki.yml
observability/grafana/provisioning/dashboards/dashboard.yml
observability/grafana/dashboards/api-security-overview.json
observability/alerts/api-security-alerts.md
observability/alerts/loki-alert-rules.yml

tests/attack/README.md
tests/attack/ssrf-attack.sh
tests/attack/token-replay.sh
tests/attack/webhook-forgery.sh
tests/attack/bola-object-access.sh
tests/attack/rate-limit-trigger.sh

tests/security/zap-active-scan.sh

tests/restler/README.md
tests/restler/restler-settings.json
tests/restler/run-restler-check.sh

tests/metrics/README.md
tests/metrics/measure-mttd-mttr.sh

.github/workflows/security-scan.yml
ci/security-scan.md
ci/run-local-security-scan.sh

docs/evidence/tv3/
docs/chapter5/tv3-devsecops-observability-redteam.md
```

### Push cuối

```bash
git status
git push
```

---

## 22. Pull Request

Khi hoàn thành một mốc lớn hoặc toàn bộ phần TV3, tạo Pull Request trên GitHub.

PR chuẩn:

```text
base: setup/project-contracts
compare: feat/tv3-devsecops-observability-redteam
```

Không merge trực tiếp nếu:

```text
- Docker Compose đang lỗi.
- Billing/Admin health check lỗi.
- Observability stack làm hỏng service khác.
- Attack script scan ra ngoài localhost.
- Có token/secret trong commit.
- Evidence thiếu.
- Conflict với TV1/TV2 chưa xử lý.
```

Nội dung PR cần ghi:

```text
1. Đã làm gì
2. File chính đã thay đổi
3. Cách chạy test
4. Evidence nằm ở đâu
5. Cần TV1/TV2 chú ý gì
```

---

## 23. Thứ tự ưu tiên nếu thiếu thời gian

Nếu không đủ thời gian làm hết, ưu tiên theo thứ tự:

### Bắt buộc

```text
1. Billing API
2. Admin API
3. SSRF vulnerable/fixed
4. Structured JSON logging
5. Attack script SSRF/rate-limit/BOLA placeholder
6. Evidence cơ bản
7. Chapter 5 draft
```

### Quan trọng

```text
8. Loki/Promtail/Grafana
9. Alert rules
10. OWASP ZAP Active Scan/API Scan workflow
11. CI security scan
12. MTTD/MTTR measurement
```

### Hoàn thiện thêm

```text
13. RESTler chạy thực tế
14. Grafana dashboard đẹp
15. Alert runtime hoàn chỉnh
16. Token replay/webhook forgery fully integrated
17. Trivy image scan nâng cao
```

---

## 24. Definition of Done của TV3

TV3 được xem là hoàn thành khi đạt đủ điều kiện:

```text
- Branch feat/tv3-devsecops-observability-redteam đã push lên GitHub.
- Billing API chạy được qua Gateway.
- Admin API chạy được qua Gateway.
- Có SSRF vulnerable/fixed demo và evidence.
- Billing/Admin có structured JSON logging.
- Có log schema rõ ràng.
- Loki/Promtail/Grafana có config hoặc tài liệu triển khai rõ.
- Có alert rules cho 401/403, 429, SSRF, BOLA, webhook.
- Có attack scripts cho SSRF, token replay, webhook forgery, BOLA, rate limit.
- Có OWASP ZAP Active Scan/API Scan workflow chạy được.
- Có RESTler/Fuzzapi test plan.
- Có CI security scan workflow/local script.
- Có MTTD/MTTR result hoặc measurement plan rõ ràng.
- Có evidence trong docs/evidence/tv3.
- Có tài liệu Chương 5.
- Không commit secret thật.
- Docker Compose vẫn build/chạy được.
- PR được tạo để merge vào setup/project-contracts.
```
