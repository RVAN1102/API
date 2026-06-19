# Historical Planning Notice

This document is historical merge-planning material from an earlier integration
phase. It is superseded by the current final evidence index, final regression
11-suite result, and runtime documentation. TODO/limitation wording below is
preserved as planning context, not as the current project status.

# THỨ TỰ MERGE TIẾP THEO SAU KHI ĐÃ MERGE UI TV1

**Mốc hiện tại:** đã merge UI/dashboard của TV1 vào `main`  
**Vai trò của `main`:** daily stable checkpoint cho cả nhóm  
**Mục tiêu tài liệu:** quy định thứ tự merge tiếp theo để tránh chồng chéo, tránh branch bị lệch `main`, và giúp các thành viên biết phần nào làm xong thì cần merge sớm.

---

## 1. Trạng thái hiện tại của `main`

Sau các lần merge gần nhất, `main` hiện đã có:

```text
- QA hardening pass đã merge.
- 10 bug đã biết đã fix hoặc triage.
- Kong Gateway route tới user/order/billing/admin.
- Keycloak token flow.
- JWT issuer/JWKS fix.
- RBAC user/admin.
- BOLA vulnerable/fixed endpoints.
- Billing/Admin auth bypass fix.
- Webhook HMAC secret mismatch fix.
- TLS 1.3, HSTS, CORS, rate limit, request size limit.
- Structured JSON logs cho user/order.
- Security scan đã fix python-jose CVE.
- TV1 frontend dashboard đã merge.
- Frontend dashboard chạy ở http://localhost:3002.
- CORS và Keycloak web origin đã có localhost:3002.
```

**Kết luận:** `main` hiện là nền mới để TV1/TV2/TV3 tiếp tục làm. Không được làm việc tiếp trên branch cũ chưa pull `main`.

---

## 2. Nguyên tắc merge từ giờ trở đi

### 2.1. Phần nào phải merge sớm

Các phần sau làm xong và pass test thì nên merge sớm:

```text
- Script smoke/regression dùng chung cho cả nhóm.
- Sửa code runtime chung: gateway, auth, service API, webhook.
- Sửa route, port, CORS, Keycloak redirect/webOrigin.
- Sửa status code/logic mà UI hoặc test script phụ thuộc.
- Sửa lỗi làm docker compose hoặc health endpoint fail.
```

Lý do: các phần này là nền cho người khác làm tiếp. Nếu giữ ở branch riêng lâu, người khác sẽ test trên logic cũ và dễ bị conflict.

### 2.2. Phần nào không cần merge gấp

Các phần sau có thể gom lại cuối ngày hoặc cuối mốc:

```text
- Evidence .txt/.md.
- Screenshot note.
- Security scan output.
- Summary báo cáo theo từng TV.
- README bổ sung nhỏ không ảnh hưởng runtime.
```

Lý do: các phần này không làm thay đổi runtime. Không block người khác code/test.

### 2.3. Không merge nếu chưa đạt điều kiện tối thiểu

Không merge vào `main` nếu:

```text
- 4 health endpoint qua Kong chưa 200.
- /users/me với Alice token chưa 200.
- Có conflict chưa xử lý rõ.
- UI có lỗi CORS/Network/JS nghiêm trọng.
- Script test pass giả hoặc bỏ qua lỗi quan trọng.
- Có secret/token thật trong evidence.
- Branch chưa merge/pull `origin/main` mới nhất trước khi test.
```

---

## 3. Thứ tự merge ưu tiên tiếp theo

## MERGE 1 – TV3: Main smoke test nền

**Người phụ trách:** TV3  
**Branch đề xuất:** `qa/tv3-main-smoke-test`  
**Độ ưu tiên:** P0 – merge sớm nhất sau UI TV1  
**Lý do:** từ giờ mọi người cần một lệnh test chung trước khi merge, không tiếp tục test tay toàn bộ.

### Nội dung nên làm

```text
tests/smoke/main-smoke.sh
docs/TESTING.md
```

### `main-smoke.sh` phải test tối thiểu

```text
- GET /api/v1/users/health     -> 200
- GET /api/v1/orders/health    -> 200
- GET /api/v1/billing/health   -> 200
- GET /api/v1/admin/health     -> 200
- Keycloak OIDC discovery      -> 200
- Lấy Alice token              -> success
- GET /api/v1/users/me         -> 200
```

### Điều kiện merge

```bash
docker compose -f infra/docker-compose.yml up -d --build
bash tests/smoke/main-smoke.sh
```

Tất cả phải `[PASS]`.

---

## MERGE 2 – TV3: Regression test scripts

**Người phụ trách:** TV3  
**Branch đề xuất:** `qa/tv3-regression-tests`  
**Độ ưu tiên:** P0  
**Lý do:** sau smoke test, cần thêm test authz/edge/webhook để chặn lỗi cũ quay lại.

### Nội dung nên làm

```text
tests/security/authz-negative-tests.sh
tests/security/edge-hardening-tests.sh
tests/security/webhook-tests.sh
tests/final/main-regression.sh
```

### Nội dung từng script

#### `authz-negative-tests.sh`

```text
- fake token gọi /users/me        -> 401
- Alice gọi admin maintenance     -> 403
- Admin gọi admin maintenance     -> 200
- fake/malformed token admin      -> 401
- Alice đọc Bob order /fixed      -> 403
- Bob đọc Bob order /fixed        -> 200
- Billing fake/malformed token    -> 401
```

#### `edge-hardening-tests.sh`

```text
- TLS 1.3 pass
- TLS 1.2 fail
- HSTS header present
- CORS allowed origin localhost:3002 pass
- evil origin không được allow
- request size lớn bị chặn
- rate limit có 429
```

#### `webhook-tests.sh`

```text
- valid webhook pass
- invalid signature fail
- replay request fail ở lần gửi lại
```

#### `main-regression.sh`

```text
- Gọi smoke test
- Gọi authz negative test
- Gọi edge hardening test
- Gọi webhook test
```

### Điều kiện merge

```bash
bash tests/smoke/main-smoke.sh
bash tests/security/authz-negative-tests.sh
bash tests/security/edge-hardening-tests.sh
bash tests/security/webhook-tests.sh
bash tests/final/main-regression.sh
```

Nếu script nào còn flaky, phải ghi rõ limitation. Không được merge script pass giả.

---

## MERGE 3 – TV2: Auth/Core closeout nếu có thay đổi code hoặc contract

**Người phụ trách:** TV2  
**Branch đề xuất:** `feat/tv2-authz-core-closeout`  
**Độ ưu tiên:** P0 nếu có code/runtime change, P1 nếu chỉ docs/evidence  
**Lý do:** TV2 đã fix 10 bug. Mốc tiếp theo là chốt lại auth/core bằng evidence và sửa nốt điểm thiếu nếu có.

### Nội dung có thể làm

```text
docs/evidence/tv2/p0-01-keycloak-token-flow.txt
docs/evidence/tv2/p0-02-user-auth.txt
docs/evidence/tv2/p0-03-admin-rbac.txt
docs/evidence/tv2/p0-04-order-bola.txt
docs/evidence/tv2/p0-05-billing-auth.txt
docs/evidence/tv2/p0-06-jwt-issuer-jwks-config.txt
docs/evidence/tv2/p0-07-mfa-status.md
docs/evidence/tv2/tv2-authz-model-summary.md
docs/evidence/tv2/demo-users-and-roles.md
openapi.yaml nếu cần cập nhật contract
```

### Nếu TV2 chỉ thêm evidence/docs

Không cần merge ngay từng file. Có thể merge cuối ngày sau khi chạy smoke test.

### Nếu TV2 sửa code runtime

Ví dụ sửa:

```text
services/user/
services/order/
services/admin/
services/billing/
idp/
demo/auth/
openapi.yaml nếu đổi contract
```

thì phải merge sớm sau khi pass:

```bash
bash tests/smoke/main-smoke.sh
bash tests/security/authz-negative-tests.sh
```

### Điều kiện merge

```text
- Keycloak discovery 200.
- Alice/Bob/Admin token lấy được.
- /users/me Alice 200.
- Admin: Alice 403, Admin 200.
- BOLA: vulnerable 200 có chủ đích, fixed 403 khi Alice đọc Bob.
- Billing: Alice 202, fake/malformed token 401.
- Không ghi “hệ thống hết bug”; chỉ ghi “10 known issues fixed/triaged”.
```

---

## MERGE 4 – TV1: Webhook timestamp/mTLS hardening

**Người phụ trách:** TV1  
**Branch đề xuất:** `feat/tv1-webhook-hardening`  
**Độ ưu tiên:** P0 nếu có code/runtime change, P1 nếu chỉ limitation/evidence  
**Lý do:** TV1 dashboard đã merge. Phần còn lại của TV1 là chốt webhook secure channel.

### Nội dung cần làm

```text
- Kiểm tra webhook timestamp freshness.
- Nếu chưa có: bổ sung hoặc ghi limitation rõ.
- Kiểm tra mTLS.
- Nếu làm được: triển khai mTLS thật.
- Nếu chưa kịp: ghi limitation rõ, không gọi HMAC là mTLS.
- Lưu evidence valid/invalid/replay/timestamp/mTLS.
```

### Nếu sửa code/runtime

Ví dụ sửa:

```text
services/billing/
demo/webhook/
gateway/
infra/
```

thì phải merge sớm sau khi pass:

```bash
bash tests/smoke/main-smoke.sh
bash tests/security/webhook-tests.sh
bash tests/security/edge-hardening-tests.sh
```

### Nếu chỉ thêm evidence/limitation

Có thể merge cuối ngày.

### Điều kiện merge

```text
- Valid webhook pass.
- Invalid webhook fail.
- Replay fail ở lần gửi lại.
- Timestamp freshness có evidence hoặc limitation rõ.
- mTLS có evidence hoặc limitation rõ.
```

---

## MERGE 5 – TV3: Observability evidence

**Người phụ trách:** TV3  
**Branch đề xuất:** `qa/tv3-observability-evidence`  
**Độ ưu tiên:** P1  
**Lý do:** observability quan trọng cho báo cáo/demo, nhưng không nên block TV1/TV2 runtime nếu chỉ là evidence.

### Nội dung nên làm

```text
docs/evidence/tv3/structured-json-log-final-evidence.txt
docs/evidence/tv3/correlation-id-final-evidence.txt
docs/evidence/tv3/loki-grafana-observability.md
```

### Điều kiện merge

```text
- Log JSON parse được.
- correlation ID từ request xuất hiện trong service log.
- Nếu có Loki/Grafana evidence thì ghi rõ cách query.
```

Nếu sửa Promtail/Loki/Grafana config trong `infra/` hoặc `observability/`, phải chạy thêm smoke test.

---

## MERGE 6 – TV3: Security scan and fuzz/negative evidence

**Người phụ trách:** TV3  
**Branch đề xuất:** `qa/tv3-security-scan-fuzz-evidence`  
**Độ ưu tiên:** P1  
**Lý do:** cần cho đồ án nhưng không block người khác nếu chỉ thêm evidence.

### Nội dung nên làm

```text
docs/evidence/tv3/security-scan-final-sanitized.txt
docs/evidence/tv3/fuzz-negative-final-evidence.txt
tests/security/fuzz-negative-tests.sh
```

### Điều kiện merge

```text
- Bandit không có issue nghiêm trọng.
- Trivy không còn CVE dependency đã biết.
- Gitleaks nếu còn finding demo/history thì phải triage/sanitize.
- Không commit secret/token thật.
- Fuzz negative tests không làm service crash.
```

---

## MERGE 7 – Final daily evidence/docs

**Người phụ trách:** cả nhóm, TV3 hoặc người quản lý merge chốt  
**Branch đề xuất:** `docs/final-daily-evidence`  
**Độ ưu tiên:** P2 hoặc cuối ngày  
**Lý do:** gom lại trạng thái trong ngày.

### Nội dung nên làm

```text
docs/PROJECT_STATUS.md
docs/DAILY_MERGE_CHECKLIST.md
docs/evidence/final/main-regression-final.txt
docs/evidence/final/main-final-smoke.txt
README.md nếu cần cập nhật port frontend 3002
```

### Điều kiện merge

```text
- Không sửa code runtime.
- Không đưa secret thật.
- Ghi rõ main hiện có gì.
- Ghi rõ phần còn thiếu: MFA runtime, mTLS nếu chưa hoàn chỉnh, OPA nếu không dùng.
```

---

## 4. Ma trận trách nhiệm sau khi UI TV1 đã merge

| Thành viên | Trách nhiệm chính | Merge sớm khi | Merge cuối ngày khi |
|---|---|---|---|
| TV1 | Gateway, Edge, Webhook | Sửa gateway/webhook runtime, mTLS, timestamp | Chỉ thêm evidence/summary |
| TV2 | Identity, Auth, Authz, Core API | Sửa Keycloak/JWT/RBAC/BOLA/Billing auth | Chỉ thêm evidence/authz model |
| TV3 | Smoke test, Regression, DevSecOps, Observability | Tạo script test dùng chung, sửa CI/test | Security scan/evidence/docs |

---

## 5. Thứ tự merge ngắn gọn

```text
1. TV3 main smoke test.
2. TV3 regression scripts.
3. TV2 auth/core closeout nếu có code hoặc contract change.
4. TV1 webhook timestamp/mTLS hardening nếu có runtime change.
5. TV3 observability evidence.
6. TV3 security scan/fuzz evidence.
7. Final daily docs/evidence.
```

Nếu có bug blocker bất kỳ lúc nào:

```text
- Compose không lên.
- Health endpoint chết.
- Token không lấy được.
- /users/me 401 do issuer.
- Admin RBAC bị bypass.
- Gateway route/CORS gãy.
```

thì dừng thứ tự trên, tạo hotfix branch và fix blocker trước.

---

## 6. Quy trình trước mỗi lần merge vào `main`

Mỗi branch trước khi merge phải làm:

```bash
git checkout <branch>
git fetch origin
git merge origin/main
docker compose -f infra/docker-compose.yml up -d --build
bash tests/smoke/main-smoke.sh
```

Nếu branch lớn hoặc sửa runtime:

```bash
bash tests/final/main-regression.sh
```

Sau khi merge vào main:

```bash
git checkout main
git pull origin main
git merge --no-ff <branch> -m "merge <short-description> into main"

docker compose -f infra/docker-compose.yml up -d --build --force-recreate
bash tests/smoke/main-smoke.sh

git push origin main
```

---

## 7. Quy tắc dùng Codex trong các merge tiếp theo

Dùng Codex cho:

```text
- Tạo script test.
- Sửa code theo bug đã xác định.
- Cập nhật docs/evidence.
- Refactor nhỏ frontend/test.
```

Không để Codex tự quyết:

```text
- Có nên merge không.
- Expected behavior của BOLA /vulnerable.
- Có coi mTLS là đã hoàn thành không.
- Có sửa gateway/auth/runtime ngoài phạm vi không.
```

Mẫu prompt cho Codex:

```text
Bạn đang ở branch <branch>.

Yêu cầu:
- Chỉ sửa file <file list>.
- Không sửa <file list>.
- Expected behavior là <mô tả>.
- Sau sửa chạy <test command>.
- Không commit.
- In git diff cuối cùng.
```

---

## 8. Kết luận

Sau khi UI TV1 đã merge, việc cần ưu tiên nhất là **TV3 đưa smoke test và regression script vào main**. Đây là nền để mọi merge sau an toàn hơn.

Thứ tự đúng không phải “ai làm xong trước merge trước”, mà là:

```text
Cái gì làm nền cho người khác thì merge trước.
Cái gì chỉ là evidence/docs thì merge sau.
Cái gì sửa runtime thì phải test kỹ rồi merge sớm.
Cái gì chưa test thì không merge.
```
