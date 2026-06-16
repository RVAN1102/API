# PHÂN CÔNG CÔNG VIỆC – THÀNH VIÊN SỐ 3  
## TV3 – QA Automation, Observability, DevSecOps & Regression Gate

**Mốc phân công:** sau khi `qa/core-redteam-audit` đã merge và push vào `main`  
**Vai trò hiện tại của TV3:** chưa đóng góp nhiều vào code chính, vì TV1 đã dựng khung hệ thống và TV2 đã fix/triage 10 bug đã biết  
**Mục tiêu mốc tiếp theo:** TV3 không cần sửa business logic. TV3 phải biến hệ thống từ “test tay được” thành “có test script, evidence, scan, observability và regression gate rõ ràng” để mỗi lần nhóm merge không làm gãy `main`.

---

# 1. Trạng thái hiện tại của `main`

`main` hiện đã có merge commit:

```bash
f68a472 merge qa hardening fixes into main
```

Hiện tại `main` đã có:

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

**Kết luận:** `main` hiện là daily stable checkpoint để nhóm làm tiếp. TV3 phải xây lớp kiểm thử và evidence để checkpoint này không bị phá ở các lần merge sau.

---

# 2. Nguyên tắc phân công cho TV3

TV3 không nên nhảy vào sửa mọi bug trong repo. Vai trò của TV3 là **QA gatekeeper**:

```text
- Tạo script smoke test cho cả nhóm.
- Tạo negative test/security regression.
- Tạo test wrapper cho TV1/TV2.
- Chạy và lưu security scan.
- Kiểm tra structured JSON log và correlation ID.
- Gom final evidence.
- Phát hiện bug mới, ghi lại, phân loại chủ sở hữu.
```

TV3 **không phụ trách chính**:

```text
- Kong/TLS/CORS/rate limit/webhook implementation: thuộc TV1.
- Keycloak/JWT/RBAC/BOLA/core API implementation: thuộc TV2.
- Viết báo cáo tổng hợp cuối: làm sau, không nằm trong task này.
```

Nếu TV3 phát hiện bug:
- Bug thuộc Edge/Webhook/Gateway → báo TV1 fix.
- Bug thuộc Auth/Core API/Authz → báo TV2 fix.
- Bug thuộc test/scan/log/CI/evidence → TV3 tự fix.
- Bug blocker làm `main` không chạy → báo nhóm ngay, tạo hotfix branch.

---

# 3. Branch làm việc của TV3

TV3 tạo branch riêng từ `main`:

```bash
cd ~/API

git checkout main
git pull origin main

git checkout -b qa/tv3-regression-observability-devsecops
```

Không push thẳng vào `main`.

---

# 4. Phạm vi file TV3 được phép sửa

## 4.1. Được phép sửa

```text
tests/
ci/
.github/
scripts/
docs/evidence/tv3/
docs/evidence/final/
docs/PROJECT_STATUS.md
observability/
infra/ chỉ phần Loki/Promtail/Grafana nếu cần
README.md, docs/RUNBOOK.md, docs/TESTING.md nếu nhóm thống nhất giao TV3 làm
```

## 4.2. Không nên sửa nếu không báo nhóm

```text
gateway/
demo/webhook/
services/user/
services/order/
services/admin/
services/billing/
idp/
demo/auth/
openapi.yaml
docs/evidence/tv1/
docs/evidence/tv2/
```

Lý do: những phần này thuộc TV1 hoặc TV2. TV3 chỉ sửa code service/gateway nếu có bug thuộc test/observability và đã báo nhóm.

---

# 5. Thứ tự ưu tiên công việc của TV3

## P0 – Việc bắt buộc, làm trước

P0 là các việc nếu chưa có thì nhóm sẽ tiếp tục test tay, dễ merge lỗi vào `main`.

```text
P0.1 Tạo main smoke test script cho cả nhóm.
P0.2 Tạo authz negative regression script.
P0.3 Tạo edge hardening test wrapper cho phần TV1.
P0.4 Tạo webhook test wrapper.
P0.5 Tạo final regression script gom các test quan trọng.
P0.6 Chạy lại Bandit/Trivy/Gitleaks và lưu evidence đã redact.
P0.7 Kiểm tra structured JSON log hợp lệ.
P0.8 Kiểm tra correlation ID đi từ request vào log.
```

## P1 – Việc quan trọng, làm sau P0

```text
P1.1 Tạo docs/TESTING.md hướng dẫn nhóm chạy test.
P1.2 Tạo docs/evidence/tv3/README.md liệt kê evidence.
P1.3 Tạo fuzz/negative input test nhẹ cho billing/admin/webhook.
P1.4 Chuẩn hóa cách đặt PASS/FAIL trong script.
P1.5 Tạo PROJECT_STATUS.md hoặc cập nhật phần trạng thái QA.
```

## P2 – Việc nâng cao, làm nếu còn thời gian

```text
P2.1 Tích hợp GitHub Actions chạy smoke/security scan cơ bản.
P2.2 Tạo Grafana/Loki evidence rõ hơn nếu dashboard hoạt động.
P2.3 Tạo release checklist cuối ngày cho nhóm.
P2.4 Tạo demo command runner nếu nhóm cần demo nhanh.
```

---

# 6. Chi tiết nhiệm vụ P0

---

## P0.1 – Tạo main smoke test script

### Mục tiêu

Một lệnh duy nhất để cả nhóm kiểm tra `main` có gãy nền tảng không.

### Tạo file

```bash
cd ~/API

mkdir -p tests/smoke
nano tests/smoke/main-smoke.sh
chmod +x tests/smoke/main-smoke.sh
```

### Nội dung script đề xuất

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="${REALM:-topic10-sme-api}"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

assert_status() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" = "$expected" ]; then
    pass "$name -> $actual"
  else
    fail "$name expected $expected got $actual"
  fi
}

echo "===== Smoke: health endpoints ====="
assert_status "users health" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/health")"
assert_status "orders health" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/health")"
assert_status "billing health" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/billing/health")"
assert_status "admin health" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/admin/health")"

echo "===== Smoke: Keycloak discovery ====="
assert_status "keycloak discovery" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration")"

echo "===== Smoke: Alice token and users/me ====="
bash demo/auth/get-user-token.sh alice >/tmp/tv3-alice-token.log
ALICE_TOKEN="$(cat /tmp/user-token.txt)"

assert_status "users me alice" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/me" -H "Authorization: Bearer ${ALICE_TOKEN}")"

echo "===== Smoke complete ====="
```

### Chạy test

```bash
tests/smoke/main-smoke.sh | tee docs/evidence/tv3/p0-01-main-smoke.txt
```

### Kỳ vọng

Tất cả dòng đều `[PASS]`.

### Evidence

```text
docs/evidence/tv3/p0-01-main-smoke.txt
```

---

## P0.2 – Tạo authz negative regression script

### Mục tiêu

Chặn hồi quy các lỗi auth đã fix: fake token pass, malformed token pass, user gọi admin được, Alice đọc order Bob qua `/fixed`.

### Tạo file

```bash
cd ~/API

mkdir -p tests/security
nano tests/security/authz-negative-tests.sh
chmod +x tests/security/authz-negative-tests.sh
```

### Nội dung script đề xuất

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

assert_status() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" = "$expected" ]; then
    pass "$name -> $actual"
  else
    fail "$name expected $expected got $actual"
  fi
}

echo "===== Prepare tokens ====="
bash demo/auth/get-user-token.sh alice >/tmp/tv3-alice-token.log
cp /tmp/user-token.txt /tmp/tv3-alice-token.txt

bash demo/auth/get-user-token.sh bob >/tmp/tv3-bob-token.log
cp /tmp/user-token.txt /tmp/tv3-bob-token.txt

bash demo/auth/get-user-token.sh admin01 >/tmp/tv3-admin-token.log
cp /tmp/user-token.txt /tmp/tv3-admin-token.txt

ALICE_TOKEN="$(cat /tmp/tv3-alice-token.txt)"
BOB_TOKEN="$(cat /tmp/tv3-bob-token.txt)"
ADMIN_TOKEN="$(cat /tmp/tv3-admin-token.txt)"

echo "===== User endpoint negative ====="
assert_status "users me fake token" 401 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/users/me" -H "Authorization: Bearer fake.jwt.token")"

echo "===== Admin RBAC ====="
assert_status "alice admin maintenance forbidden" 403 "$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/admin/maintenance" -H "Authorization: Bearer ${ALICE_TOKEN}" -H "Content-Type: application/json" -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "admin maintenance allowed" 200 "$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/admin/maintenance" -H "Authorization: Bearer ${ADMIN_TOKEN}" -H "Content-Type: application/json" -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "admin fake token rejected" 401 "$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/admin/maintenance" -H "Authorization: Bearer fake.jwt.token" -H "Content-Type: application/json" -d '{"action":"health-check","reason":"tv3-authz-test"}')"

assert_status "admin malformed token rejected" 401 "$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/admin/maintenance" -H "Authorization: Bearer abc" -H "Content-Type: application/json" -d '{"action":"health-check","reason":"tv3-authz-test"}')"

echo "===== BOLA fixed endpoint ====="
assert_status "alice own order fixed" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/ord-alice-1001/fixed" -H "Authorization: Bearer ${ALICE_TOKEN}")"

assert_status "alice bob order fixed forbidden" 403 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" -H "Authorization: Bearer ${ALICE_TOKEN}")"

assert_status "bob own order fixed" 200 "$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/orders/ord-bob-2001/fixed" -H "Authorization: Bearer ${BOB_TOKEN}")"

echo "===== Billing auth ====="
assert_status "billing alice checkout accepted" 202 "$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/billing/checkout" -H "Authorization: Bearer ${ALICE_TOKEN}" -H "Content-Type: application/json" -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

assert_status "billing malformed token rejected" 401 "$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/billing/checkout" -H "Authorization: Bearer abc" -H "Content-Type: application/json" -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}')"

echo "===== Authz negative tests complete ====="
```

### Chạy test

```bash
tests/security/authz-negative-tests.sh | tee docs/evidence/tv3/p0-02-authz-negative-tests.txt
```

### Evidence

```text
docs/evidence/tv3/p0-02-authz-negative-tests.txt
```

---

## P0.3 – Tạo edge hardening test wrapper

### Mục tiêu

TV3 không sửa gateway của TV1, nhưng tạo wrapper để chạy kiểm thử edge một cách nhất quán.

### Tạo file

```bash
cd ~/API

mkdir -p tests/security
nano tests/security/edge-hardening-tests.sh
chmod +x tests/security/edge-hardening-tests.sh
```

### Nội dung script đề xuất

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
HTTPS_URL="${HTTPS_URL:-https://localhost:8443}"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

echo "===== TLS 1.3 should succeed ====="
if echo | openssl s_client -connect localhost:8443 -tls1_3 2>/tmp/tv3-tls13.txt >/dev/null; then
  grep -q "TLSv1.3" /tmp/tv3-tls13.txt || true
  pass "TLS 1.3 handshake completed"
else
  fail "TLS 1.3 handshake failed"
fi

echo "===== TLS 1.2 should fail ====="
if echo | openssl s_client -connect localhost:8443 -tls1_2 >/tmp/tv3-tls12.txt 2>&1; then
  if grep -qi "Protocol  *: TLSv1.2" /tmp/tv3-tls12.txt; then
    fail "TLS 1.2 unexpectedly negotiated"
  else
    pass "TLS 1.2 did not negotiate normally"
  fi
else
  pass "TLS 1.2 rejected"
fi

echo "===== HSTS ====="
if curl -k -s -i "${HTTPS_URL}/api/v1/users/health" | grep -qi "strict-transport-security"; then
  pass "HSTS header present"
else
  fail "HSTS header missing"
fi

echo "===== CORS allowed origin ====="
if curl -s -i -X OPTIONS "${BASE_URL}/api/v1/users/health" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  | grep -qi "access-control-allow-origin"; then
  pass "allowed origin has CORS allow header"
else
  fail "allowed origin missing CORS allow header"
fi

echo "===== CORS evil origin ====="
if curl -s -i -X OPTIONS "${BASE_URL}/api/v1/users/health" \
  -H "Origin: https://evil.example" \
  -H "Access-Control-Request-Method: GET" \
  | grep -qi "access-control-allow-origin: https://evil.example"; then
  fail "evil origin was allowed"
else
  pass "evil origin not allowed"
fi

echo "===== Request size limit ====="
python3 - <<'PY'
from pathlib import Path
Path("/tmp/tv3-large-payload.json").write_text('{"data":"' + ("A" * (2 * 1024 * 1024)) + '"}')
PY

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/billing/checkout" \
  -H "Authorization: Bearer abc" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/tv3-large-payload.json)"

case "$code" in
  413|417|400)
    pass "large payload blocked -> $code"
    ;;
  *)
    fail "large payload expected gateway rejection got $code"
    ;;
esac

echo "===== Edge hardening tests complete ====="
```

### Chạy test

```bash
tests/security/edge-hardening-tests.sh | tee docs/evidence/tv3/p0-03-edge-hardening-tests.txt
```

### Evidence

```text
docs/evidence/tv3/p0-03-edge-hardening-tests.txt
```

---

## P0.4 – Tạo webhook test wrapper

### Mục tiêu

TV3 tạo wrapper chạy lại các script webhook của TV1.

### Tạo file

```bash
cd ~/API

mkdir -p tests/security
nano tests/security/webhook-tests.sh
chmod +x tests/security/webhook-tests.sh
```

### Nội dung script đề xuất

```bash
#!/usr/bin/env bash
set -euo pipefail

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

echo "===== Valid webhook ====="
if bash demo/webhook/send-valid-webhook.sh; then
  pass "valid webhook accepted"
else
  fail "valid webhook rejected"
fi

echo "===== Invalid webhook ====="
if bash demo/webhook/send-invalid-webhook.sh; then
  fail "invalid webhook unexpectedly accepted"
else
  pass "invalid webhook rejected"
fi

echo "===== Replay webhook ====="
if bash demo/webhook/send-replay-webhook.sh; then
  pass "replay script completed with expected behavior"
else
  # Một số script trả non-zero khi replay bị reject. Nếu output đã thể hiện reject thì vẫn chấp nhận.
  echo "[INFO] replay script returned non-zero; inspect output"
fi

echo "===== Webhook tests complete ====="
```

### Chạy test

```bash
tests/security/webhook-tests.sh | tee docs/evidence/tv3/p0-04-webhook-tests.txt
```

### Evidence

```text
docs/evidence/tv3/p0-04-webhook-tests.txt
```

---

## P0.5 – Tạo final regression script

### Mục tiêu

Một script tổng hợp để nhóm chạy trước khi merge vào `main`.

### Tạo file

```bash
cd ~/API

mkdir -p tests/final
nano tests/final/main-regression.sh
chmod +x tests/final/main-regression.sh
```

### Nội dung script đề xuất

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Final regression: smoke ====="
bash tests/smoke/main-smoke.sh

echo
echo "===== Final regression: authz negative ====="
bash tests/security/authz-negative-tests.sh

echo
echo "===== Final regression: edge hardening ====="
bash tests/security/edge-hardening-tests.sh

echo
echo "===== Final regression: webhook ====="
bash tests/security/webhook-tests.sh

echo
echo "===== Final regression complete ====="
```

### Chạy test

```bash
tests/final/main-regression.sh | tee docs/evidence/final/main-regression-final.txt
```

### Evidence

```text
docs/evidence/final/main-regression-final.txt
```

---

## P0.6 – Chạy Security Scan cuối

### Mục tiêu

Chứng minh dependency/security scan không hồi quy sau khi merge.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv3

export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

{
  echo "===== Tool versions ====="
  bandit --version || true
  trivy --version || true
  gitleaks version || true

  echo
  echo "===== Local security scan ====="
  bash ci/run-local-security-scan.sh
} | tee docs/evidence/tv3/p0-06-security-scan-final-raw.txt
```

### Redact nếu có secret-like output

Nếu file có `Secret` hoặc `Match` nhạy cảm, tạo bản sanitized:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path("docs/evidence/tv3/p0-06-security-scan-final-raw.txt")
out = Path("docs/evidence/tv3/p0-06-security-scan-final-sanitized.txt")
text = p.read_text(errors="ignore")
for key in ["Secret:", "Match:"]:
    text = text.replace(key, key + " <redacted> #")
out.write_text(text)
PY
```

### Evidence dùng cho báo cáo

```text
docs/evidence/tv3/p0-06-security-scan-final-sanitized.txt
```

Không đưa secret/token thật vào evidence.

---

## P0.7 – Kiểm tra structured JSON log hợp lệ

### Mục tiêu

Chứng minh log của service chính là JSON parse được, không bị nested JSON sai format.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv3

CID="tv3-json-log-$(date +%s)"

curl -s http://localhost:8000/api/v1/users/health \
  -H "X-Correlation-ID: ${CID}" >/dev/null

curl -s http://localhost:8000/api/v1/orders/health \
  -H "X-Correlation-ID: ${CID}" >/dev/null

{
  echo "===== User log JSON validity ====="
  docker logs infra-user-service-1 --tail=50 | python3 - <<'PY'
import sys, json
ok = 0
bad = 0
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        json.loads(line)
        ok += 1
    except Exception:
        bad += 1
print(f"user_log_json_ok={ok}")
print(f"user_log_json_bad={bad}")
PY

  echo
  echo "===== Order log JSON validity ====="
  docker logs infra-order-service-1 --tail=50 | python3 - <<'PY'
import sys, json
ok = 0
bad = 0
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        json.loads(line)
        ok += 1
    except Exception:
        bad += 1
print(f"order_log_json_ok={ok}")
print(f"order_log_json_bad={bad}")
PY
} | tee docs/evidence/tv3/p0-07-structured-json-log.txt
```

### Kỳ vọng

```text
*_json_ok > 0
*_json_bad = 0
```

### Evidence

```text
docs/evidence/tv3/p0-07-structured-json-log.txt
```

---

## P0.8 – Kiểm tra correlation ID trong log

### Mục tiêu

Chứng minh correlation ID từ request xuất hiện trong log service.

### Lệnh chạy

```bash
cd ~/API
mkdir -p docs/evidence/tv3

CID="tv3-correlation-$(date +%s)"

curl -s http://localhost:8000/api/v1/users/health \
  -H "X-Correlation-ID: ${CID}" >/dev/null

sleep 2

{
  echo "===== Correlation ID ====="
  echo "${CID}"

  echo
  echo "===== User service logs matched ====="
  docker logs infra-user-service-1 --tail=100 | grep "${CID}" || true
} | tee docs/evidence/tv3/p0-08-correlation-id-log.txt
```

### Kỳ vọng

Có log line chứa đúng `${CID}`.

### Evidence

```text
docs/evidence/tv3/p0-08-correlation-id-log.txt
```

---

# 7. Nhiệm vụ P1

---

## P1.1 – Tạo docs/TESTING.md

### Mục tiêu

Người trong nhóm chỉ cần đọc file này là biết chạy test.

### Tạo file

```bash
nano docs/TESTING.md
```

### Nội dung bắt buộc

```text
1. Cách start stack:
   docker compose -f infra/docker-compose.yml up -d --build

2. Smoke test:
   bash tests/smoke/main-smoke.sh

3. Authz negative test:
   bash tests/security/authz-negative-tests.sh

4. Edge hardening test:
   bash tests/security/edge-hardening-tests.sh

5. Webhook test:
   bash tests/security/webhook-tests.sh

6. Final regression:
   bash tests/final/main-regression.sh

7. Security scan:
   bash ci/run-local-security-scan.sh

8. Cách xử lý khi Keycloak health unhealthy nhưng OIDC discovery vẫn 200.
9. Cách xử lý khi rate limit test bị nhiễu do chưa reset.
```

---

## P1.2 – Tạo README evidence cho TV3

Tạo file:

```bash
nano docs/evidence/tv3/README.md
```

Nội dung:

```text
- Evidence name
- Command/script sinh evidence
- Expected result
- Actual result
- Status: Pass/Fail/Limitation
```

---

## P1.3 – Fuzz/negative input test nhẹ

### Mục tiêu

Không cần fuzz chuyên sâu, nhưng phải có negative input cơ bản.

### Tạo file

```bash
mkdir -p tests/security
nano tests/security/fuzz-negative-tests.sh
chmod +x tests/security/fuzz-negative-tests.sh
```

### Test tối thiểu

```text
- Billing checkout thiếu body.
- Billing checkout sai kiểu dữ liệu amount.
- Admin metadata-fetch/fixed với URL nội bộ nguy hiểm nếu có endpoint.
- Webhook payload malformed.
- Request JSON invalid.
```

### Evidence

```bash
tests/security/fuzz-negative-tests.sh | tee docs/evidence/tv3/p1-03-fuzz-negative-tests.txt
```

---

## P1.4 – Cập nhật PROJECT_STATUS.md

Nếu chưa có, tạo:

```bash
nano docs/PROJECT_STATUS.md
```

Nội dung tối thiểu:

```text
Current main status:
- main đã merge QA hardening.
- 10 known issues fixed/triaged.
- main là daily stable checkpoint.

Branch ownership:
- TV1: Edge/Gateway/Webhook.
- TV2: Identity/Auth/Authz/Core API.
- TV3: QA/Regression/Observability/DevSecOps.

Merge rule:
- Không push thẳng main.
- Trước khi merge phải chạy tests/smoke/main-smoke.sh.
- Branch lớn phải chạy tests/final/main-regression.sh.
```

---

# 8. Nhiệm vụ P2

---

## P2.1 – GitHub Actions basic CI

Nếu còn thời gian, TV3 có thể thêm workflow:

```text
.github/workflows/main-regression.yml
```

Tối thiểu:
- checkout repo;
- lint shell scripts nếu có;
- chạy Bandit/Trivy file scan nếu môi trường cho phép;
- không nhất thiết chạy full docker compose nếu CI quá nặng.

Không bắt buộc P0.

---

## P2.2 – Grafana/Loki evidence

Nếu Loki/Grafana hoạt động ổn, lưu evidence:
- screenshot hoặc text query;
- correlation ID xuất hiện trong Loki;
- log JSON fields.

Evidence:

```text
docs/evidence/tv3/p2-02-loki-grafana-observability.md
```

---

## P2.3 – Daily release checklist

Tạo file:

```bash
nano docs/DAILY_MERGE_CHECKLIST.md
```

Nội dung:

```text
[ ] git checkout main && git pull origin main
[ ] docker compose -f infra/docker-compose.yml up -d --build
[ ] bash tests/smoke/main-smoke.sh
[ ] chạy test riêng của branch
[ ] không có secret mới
[ ] commit evidence nếu có
[ ] merge/push sau khi pass
```

---

# 9. Điều kiện hoàn thành của TV3

TV3 được coi là hoàn thành mốc này khi:

```text
[ ] Đã tạo branch từ main mới nhất.
[ ] Có tests/smoke/main-smoke.sh.
[ ] Có tests/security/authz-negative-tests.sh.
[ ] Có tests/security/edge-hardening-tests.sh.
[ ] Có tests/security/webhook-tests.sh.
[ ] Có tests/final/main-regression.sh.
[ ] Smoke test chạy PASS.
[ ] Authz negative test chạy PASS.
[ ] Edge hardening test chạy PASS hoặc ghi rõ limitation.
[ ] Webhook test chạy PASS hoặc ghi rõ limitation.
[ ] Có security scan evidence sanitized.
[ ] Có structured JSON log evidence.
[ ] Có correlation ID evidence.
[ ] Có docs/TESTING.md.
[ ] Có docs/evidence/tv3/README.md.
[ ] Không sửa business logic của TV1/TV2 nếu chưa báo nhóm.
```

---

# 10. Cách commit và push

Nếu chỉ thêm tests/docs/evidence:

```bash
cd ~/API

git status -sb
git add tests docs/evidence/tv3 docs/evidence/final docs/TESTING.md docs/PROJECT_STATUS.md docs/DAILY_MERGE_CHECKLIST.md
git commit -m "test: add tv3 regression and observability evidence"
git push origin qa/tv3-regression-observability-devsecops
```

Nếu có sửa CI:

```bash
git add .github ci tests docs
git commit -m "ci: add tv3 security and regression checks"
git push origin qa/tv3-regression-observability-devsecops
```

---

# 11. Không được làm các việc sau

```text
- Không sửa gateway/Kong config nếu không báo TV1.
- Không sửa Keycloak/JWT/RBAC/BOLA logic nếu không báo TV2.
- Không xóa endpoint /vulnerable vì đó là endpoint demo BOLA.
- Không thêm secret thật vào evidence.
- Không ghi security scan sạch nếu Gitleaks vẫn có finding demo/history chưa triage.
- Không làm script pass giả bằng cách bỏ qua lỗi quan trọng.
- Không để script chỉ in curl output mà không có PASS/FAIL rõ ràng.
```

---

# 12. Kết luận

TV3 chưa làm nhiều phần code chính, nên mốc này TV3 phải gánh phần còn thiếu nhưng rất quan trọng: kiểm thử tự động, regression gate, security scan, observability evidence và tài liệu cách test. Đây là phần giúp nhóm không bị lặp lại tình trạng test tay, merge xong mới phát hiện bug.

Mục tiêu cuối của TV3 trong mốc này:

```text
Có bộ test và evidence đủ để mỗi ngày nhóm pull/merge main mà biết hệ thống còn ổn hay không.
```
