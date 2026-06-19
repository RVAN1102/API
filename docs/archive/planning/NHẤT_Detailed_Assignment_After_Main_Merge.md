# Historical Planning Notice

This document is historical assignment material from an earlier post-merge
phase. It is superseded by the current final evidence index, final regression
11-suite result, and runtime documentation. TODO/limitation wording below is
preserved as planning context, not as the current project status.

# PHÂN CÔNG CÔNG VIỆC – THÀNH VIÊN SỐ 1  
## TV1 – Edge Gateway, Network Hardening & Webhook Security

**Mốc phân công:** sau khi `qa/core-redteam-audit` đã merge vào `main`  
**Vai trò hiện tại của TV1:** người đã dựng phần lớn khung hệ thống ban đầu  
**Mục tiêu mốc tiếp theo:** không tiếp tục ôm toàn bộ dự án; tập trung đóng chắc phần Edge/Gateway/Webhook, bổ sung phần còn thiếu, lưu evidence và tránh hồi quy.

---

# 1. Trạng thái hiện tại của `main`

`main` hiện đã có merge commit:

```bash
f68a472 merge qa hardening fixes into main
```

Hiện tại `main` đã có các phần quan trọng sau:

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

**Kết luận:** `main` hiện là daily stable checkpoint để nhóm làm tiếp, chưa phải bản nộp cuối.

---

# 2. Nguyên tắc phân công cho TV1

TV1 đã build được khung chính của hệ thống nên không nên tiếp tục ôm thêm toàn bộ phần còn lại. Từ mốc này, TV1 chỉ tập trung vào:

```text
- Edge/API Gateway
- Network hardening
- TLS/HSTS/CORS/rate limit/request size limit
- Webhook secure channel
- Evidence cho phần TV1
- Summary kỹ thuật ngắn cho phần TV1
```

TV1 **không phụ trách chính**:

```text
- Keycloak/JWT/RBAC/BOLA core API: giao TV2.
- Security scan, regression script, fuzzing, observability tổng thể: giao TV3.
- Viết báo cáo tổng hợp: làm sau, không nằm trong task này.
```

---

# 3. Branch làm việc của TV1

TV1 tạo branch riêng từ `main`:

```bash
cd ~/API

git checkout main
git pull origin main

git checkout -b feat/tv1-edge-webhook-closeout
```

Không push thẳng vào `main`.

---

# 4. Phạm vi file TV1 được phép sửa

## 4.1. Được phép sửa

```text
gateway/
infra/
demo/webhook/
docs/evidence/tv1/
docs/PROJECT_STATUS.md nếu cần cập nhật trạng thái phần TV1
services/billing/ chỉ khi sửa trực tiếp webhook endpoint
```

## 4.2. Không nên sửa nếu không báo nhóm

```text
services/user/
services/order/
services/admin/
demo/auth/
idp/
tests/final/
tests/security/authz*
ci/
.github/
```

Lý do: các phần này thuộc TV2 hoặc TV3. TV1 sửa chéo dễ gây conflict hoặc làm người khác khó theo dõi.

---

# 5. Thứ tự ưu tiên công việc của TV1

## P0 – Việc bắt buộc, làm trước

P0 là các việc nếu chưa xong thì phần TV1 chưa được coi là ổn định.

```text
P0.1 Retest Kong route và health qua gateway.
P0.2 Retest TLS 1.3 pass và TLS 1.2 fail.
P0.3 Retest HSTS trên HTTPS response.
P0.4 Retest CORS allowed origin và evil origin.
P0.5 Retest rate limit có 429 khi vượt ngưỡng.
P0.6 Retest request size limit.
P0.7 Retest webhook HMAC valid/invalid/replay.
P0.8 Kiểm tra webhook timestamp freshness.
P0.9 Kiểm tra trạng thái webhook mTLS.
```

## P1 – Việc quan trọng, làm sau P0

```text
P1.1 Viết summary kỹ thuật ngắn cho phần Edge/Webhook.
P1.2 Gom evidence vào docs/evidence/tv1/.
P1.3 Ghi rõ limitation nếu mTLS chưa triển khai thật.
P1.4 Đề xuất hướng hardening tiếp theo cho TV1.
```

## P2 – Việc nâng cao, làm nếu còn thời gian

```text
P2.1 Triển khai mTLS thật cho webhook nếu hiện chưa có.
P2.2 Tạo script tự động chạy toàn bộ test TV1.
P2.3 Bổ sung diagram luồng Kong/Webhook nếu nhóm cần đưa vào báo cáo.
```

---

# 6. Chi tiết nhiệm vụ P0

---

## P0.1 – Retest Kong route và health qua gateway

### Mục tiêu

Xác nhận Kong vẫn forward đúng tới 4 service chính sau khi merge `main`.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

{
  echo "===== TV1 P0.1 Kong route smoke ====="
  date
  git branch --show-current
  git log --oneline -5

  echo
  echo "===== Health via Kong ====="
  curl -i http://localhost:8000/api/v1/users/health
  curl -i http://localhost:8000/api/v1/orders/health
  curl -i http://localhost:8000/api/v1/billing/health
  curl -i http://localhost:8000/api/v1/admin/health

  echo
  echo "===== Kong services ====="
  curl -s http://localhost:8001/services | jq '.data[] | {name,host,port,path}'

  echo
  echo "===== Kong routes ====="
  curl -s http://localhost:8001/routes | jq '.data[] | {name,paths,strip_path}'
} | tee docs/evidence/tv1/p0-01-kong-route-smoke.txt
```

### Kỳ vọng

```text
/api/v1/users/health    -> 200
/api/v1/orders/health   -> 200
/api/v1/billing/health  -> 200
/api/v1/admin/health    -> 200
```

### Evidence

```text
docs/evidence/tv1/p0-01-kong-route-smoke.txt
```

---

## P0.2 – Retest TLS 1.3 pass, TLS 1.2 fail

### Mục tiêu

Chứng minh Kong HTTPS listener chỉ chấp nhận TLS 1.3.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

{
  echo "===== TV1 P0.2 TLS 1.3 should succeed ====="
  echo | openssl s_client -connect localhost:8443 -tls1_3 2>&1 \
    | grep -E "Protocol|Cipher|Verify return code|New,"

  echo
  echo "===== TV1 P0.2 TLS 1.2 should fail ====="
  echo | openssl s_client -connect localhost:8443 -tls1_2 2>&1 \
    | grep -E "Protocol|Cipher|alert|wrong version|no protocols|New," || true
} | tee docs/evidence/tv1/p0-02-kong-tls13-only.txt
```

### Kỳ vọng

TLS 1.3:

```text
Protocol  : TLSv1.3
Cipher    : TLS_AES_...
```

TLS 1.2:

```text
alert protocol version
```

hoặc không negotiate được cipher.

### Evidence

```text
docs/evidence/tv1/p0-02-kong-tls13-only.txt
```

---

## P0.3 – Retest HSTS

### Mục tiêu

Chứng minh HTTPS response có HSTS.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

{
  echo "===== TV1 P0.3 HSTS header ====="
  curl -k -i https://localhost:8443/api/v1/users/health \
    | grep -i "HTTP/\|strict-transport-security"
} | tee docs/evidence/tv1/p0-03-kong-hsts.txt
```

### Kỳ vọng

Có header:

```text
Strict-Transport-Security: ...
```

### Evidence

```text
docs/evidence/tv1/p0-03-kong-hsts.txt
```

---

## P0.4 – Retest strict CORS

### Mục tiêu

Chứng minh hệ thống chỉ allow origin hợp lệ, không allow origin lạ.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

{
  echo "===== TV1 P0.4 Allowed origin ====="
  curl -i -X OPTIONS http://localhost:8000/api/v1/users/health \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" \
    | grep -i "HTTP/\|access-control-allow-origin\|access-control-allow-methods\|vary"

  echo
  echo "===== TV1 P0.4 Evil origin ====="
  curl -i -X OPTIONS http://localhost:8000/api/v1/users/health \
    -H "Origin: https://evil.example" \
    -H "Access-Control-Request-Method: GET" \
    | grep -i "HTTP/\|access-control-allow-origin\|access-control-allow-methods\|vary" || true
} | tee docs/evidence/tv1/p0-04-kong-cors.txt
```

### Kỳ vọng

Allowed origin có:

```text
Access-Control-Allow-Origin: http://localhost:3000
```

Evil origin không được allow:

```text
Không có Access-Control-Allow-Origin: https://evil.example
```

### Evidence

```text
docs/evidence/tv1/p0-04-kong-cors.txt
```

---

## P0.5 – Retest rate limit

### Mục tiêu

Chứng minh gateway có rate limit để giảm brute force/credential stuffing.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

{
  echo "===== TV1 P0.5 Rate limit on protected route ====="
  for i in $(seq 1 15); do
    code="$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST http://localhost:8000/api/v1/admin/maintenance \
      -H "Authorization: Bearer fake.jwt.token" \
      -H "Content-Type: application/json" \
      -d '{"action":"health-check","reason":"rate-limit-test"}')"
    echo "request=$i status=$code"
  done
} | tee docs/evidence/tv1/p0-05-kong-rate-limit.txt
```

### Kỳ vọng

```text
Các request đầu: 401
Khi vượt ngưỡng: 429
```

### Evidence

```text
docs/evidence/tv1/p0-05-kong-rate-limit.txt
```

---

## P0.6 – Retest request size limit

### Mục tiêu

Chứng minh payload lớn bị gateway chặn.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

python3 - <<'PY'
from pathlib import Path
Path("/tmp/large-payload.json").write_text('{"data":"' + ("A" * (2 * 1024 * 1024)) + '"}')
PY

{
  echo "===== TV1 P0.6 Small payload reaches upstream ====="
  curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'

  echo
  echo "===== TV1 P0.6 Large payload blocked by gateway ====="
  curl -i -X POST http://localhost:8000/api/v1/billing/checkout \
    -H "Authorization: Bearer abc" \
    -H "Content-Type: application/json" \
    --data-binary @/tmp/large-payload.json
} | tee docs/evidence/tv1/p0-06-kong-request-size-limit.txt
```

### Kỳ vọng

```text
Small payload: 401 do token sai, nghĩa là request tới upstream.
Large payload: 413 hoặc 417 do Kong chặn.
```

### Evidence

```text
docs/evidence/tv1/p0-06-kong-request-size-limit.txt
```

---

## P0.7 – Retest webhook HMAC valid/invalid/replay

### Mục tiêu

Chứng minh webhook không còn lỗi secret mismatch và có replay protection.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv1

{
  echo "===== TV1 P0.7 Valid webhook ====="
  bash demo/webhook/send-valid-webhook.sh

  echo
  echo "===== TV1 P0.7 Invalid webhook ====="
  bash demo/webhook/send-invalid-webhook.sh || true

  echo
  echo "===== TV1 P0.7 Replay webhook ====="
  bash demo/webhook/send-replay-webhook.sh || true
} | tee docs/evidence/tv1/p0-07-webhook-hmac-replay.txt
```

### Kỳ vọng

```text
Valid webhook: accepted
Invalid webhook: rejected
Replay lần 1: accepted
Replay lần 2: rejected
```

### Evidence

```text
docs/evidence/tv1/p0-07-webhook-hmac-replay.txt
```

---

## P0.8 – Kiểm tra webhook timestamp freshness

### Mục tiêu

HMAC đúng nhưng timestamp quá cũ vẫn phải bị reject. Đây là phần cần xác nhận, không được mặc định là đã có.

### Lệnh kiểm tra code

```bash
cd ~/API

grep -RIn "timestamp\|fresh\|replay\|nonce\|signature\|hmac" services demo | head -100
```

### Nếu đã có timestamp freshness

TV1 tạo evidence:

```text
docs/evidence/tv1/p0-08-webhook-timestamp-freshness.txt
```

Nội dung evidence cần chứng minh:

```text
- request timestamp hiện tại + HMAC đúng -> pass
- request timestamp cũ + HMAC đúng -> fail
```

### Nếu chưa có timestamp freshness

TV1 có 2 lựa chọn:

```text
Lựa chọn A: bổ sung timestamp freshness check.
Lựa chọn B: ghi limitation rõ vào docs/evidence/tv1/p0-08-webhook-timestamp-freshness.md.
```

Không được viết trong báo cáo rằng webhook đã chống replay/timestamp đầy đủ nếu chưa có evidence.

---

## P0.9 – Kiểm tra webhook mTLS

### Mục tiêu

Yêu cầu đồ án có nhắc webhook secure channel/mTLS. TV1 phải xác định hiện trạng thật.

### Lệnh kiểm tra

```bash
cd ~/API

grep -RIn "mtls\|client certificate\|client_cert\|ssl_verify_client\|client-auth\|ca.crt\|client.crt\|client.key" .
```

### Nếu đã có mTLS

TV1 phải có evidence:

```text
- Có client certificate đúng -> pass
- Không có client certificate -> fail
- Client certificate sai -> fail
```

### Nếu chưa có mTLS

TV1 ghi limitation rõ:

```text
docs/evidence/tv1/p0-09-webhook-mtls-status.md
```

Mẫu nội dung:

```text
Webhook hiện có HMAC signature và replay protection ở tầng ứng dụng.
Prototype hiện chưa triển khai đầy đủ mTLS client certificate verification cho webhook channel.
Đây là limitation còn lại của TV1 hoặc hướng hardening tiếp theo.
```

### Yêu cầu trung thực

Không được gọi HMAC là mTLS. HMAC và mTLS là hai cơ chế khác nhau.

---

# 7. Nhiệm vụ P1

## P1.1 – Viết summary kỹ thuật cho TV1

Tạo file:

```bash
nano docs/evidence/tv1/tv1-edge-webhook-summary.md
```

Nội dung bắt buộc:

```text
1. Gateway routing qua Kong
2. TLS 1.3 termination
3. HSTS
4. Strict CORS
5. Rate limiting
6. Request size limiting
7. Webhook HMAC verification
8. Replay protection
9. Timestamp freshness status
10. mTLS status
11. Limitations
12. Evidence files
```

Lưu ý viết chính xác:

```text
Hệ thống triển khai các cơ chế gateway hardening bằng Kong như TLS 1.3, HSTS, strict CORS, rate limiting và request size limiting. Đây là lớp bảo vệ biên cho prototype đồ án, chưa thay thế hoàn toàn một WAF chuyên dụng nếu chưa tích hợp ModSecurity/CRS.
```

---

## P1.2 – Gom danh sách evidence của TV1

Tạo file:

```bash
nano docs/evidence/tv1/README.md
```

Nội dung gồm:

```text
- Tên evidence
- Lệnh sinh evidence
- Kết quả kỳ vọng
- Kết quả thực tế
- Trạng thái Pass/Fail/Limitation
```

---

# 8. Nhiệm vụ P2

## P2.1 – Tạo script tự động test phần TV1

Nếu còn thời gian, tạo:

```bash
mkdir -p tests/security
nano tests/security/tv1-edge-webhook-tests.sh
chmod +x tests/security/tv1-edge-webhook-tests.sh
```

Script nên gom:

```text
- Kong health
- TLS 1.3/TLS 1.2
- HSTS
- CORS
- Rate limit
- Request size limit
- Webhook valid/invalid/replay
```

Không bắt buộc P2 nếu TV3 sẽ làm test wrapper chung. Nhưng nếu TV1 làm được thì rất tốt.

---

# 9. Điều kiện hoàn thành của TV1

TV1 được coi là hoàn thành mốc này khi:

```text
[ ] Đã tạo branch từ main mới nhất.
[ ] 4 health endpoint qua Kong đều 200.
[ ] TLS 1.3 pass.
[ ] TLS 1.2 fail.
[ ] HSTS có evidence.
[ ] CORS allowed origin pass.
[ ] CORS evil origin không được allow.
[ ] Rate limit có 429 khi vượt ngưỡng.
[ ] Request size lớn bị gateway chặn.
[ ] Webhook valid pass.
[ ] Webhook invalid fail.
[ ] Webhook replay fail ở lần gửi lại.
[ ] Timestamp freshness có evidence hoặc limitation rõ.
[ ] mTLS có evidence hoặc limitation rõ.
[ ] Có summary kỹ thuật TV1.
[ ] Có README evidence TV1.
[ ] Không commit secret thật.
[ ] Không sửa chéo sang phần TV2/TV3 nếu chưa báo nhóm.
```

---

# 10. Cách commit và push

Nếu chỉ thêm evidence/docs:

```bash
cd ~/API

git status -sb
git add docs/evidence/tv1
git commit -m "docs: capture tv1 edge and webhook final evidence"
git push origin feat/tv1-edge-webhook-closeout
```

Nếu có sửa code/config thật:

```bash
git add gateway infra demo/webhook services/billing
git commit -m "fix: harden tv1 edge and webhook controls"

git add docs/evidence/tv1
git commit -m "docs: capture tv1 edge and webhook evidence"

git push origin feat/tv1-edge-webhook-closeout
```

---

# 11. Không được làm các việc sau

```text
- Không refactor toàn bộ compose.
- Không đổi route/path nếu không cập nhật Kong và báo TV2/TV3.
- Không sửa logic user/order/admin nếu không có bug thuộc TV1.
- Không xóa endpoint /vulnerable vì đó là endpoint demo BOLA của TV2.
- Không commit token thật, secret thật, cert private key production.
- Không ghi mTLS đã hoàn thành nếu chỉ mới có HMAC.
```

---

# 12. Kết luận

TV1 đã làm nhiều phần nền tảng nhất, nên mốc tiếp theo của TV1 không phải tiếp tục ôm cả đồ án. TV1 chỉ cần đóng chắc phần Edge/Gateway/Webhook, lưu evidence, xác định rõ phần còn thiếu như timestamp freshness/mTLS và bàn giao lại để nhóm tích hợp.

Mục tiêu cuối của TV1 trong mốc này:

```text
Edge và Webhook security có evidence rõ ràng, không hồi quy sau merge main, và không làm chồng chéo sang phần TV2/TV3.
```
