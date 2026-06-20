# Demo Video Script

**Duration:** ~15-20 minutes  
**File:** `docs/demo/demo-video-script.md`  
**Presenter:** Project team

---

## Setup Before Recording

```bash
# 1. Start the full stack
docker compose -f infra/docker-compose.yml up -d --build
sleep 30

# 2. Verify all services running
docker compose -f infra/docker-compose.yml ps

# 3. Open browser tabs:
#    - Grafana: http://localhost:3000
#    - Jaeger:  http://localhost:16686
#    - Keycloak: http://localhost:8080/admin (do NOT screen-share login credentials)

# 4. Clear terminal history before recording
history -c
```

---

## Scene 1: System Startup (0:00 – 1:30)

**Narration:** "Hệ thống API Security bao gồm Kong Gateway, Keycloak, Vault, và 4 microservices: User, Order, Billing, Admin."

```bash
# Show all services healthy
docker compose -f infra/docker-compose.yml ps
curl https://localhost:8443/api/v1/users/health | python3 -m json.tool
curl http://localhost:8001/api/v1/orders/health | python3 -m json.tool
curl http://localhost:8002/api/v1/billing/health | python3 -m json.tool
```

**Show:** All services `Up`, health endpoints return `{"status": "ok"}`

---

## Scene 2: Safe Auth Flow (1:30 – 3:00)

**Narration:** "Người dùng alice đăng nhập qua Keycloak bằng Authorization Code + PKCE, nhận JWT token (TTL=300s), và truy cập API."

```bash
# Generate the PKCE authorization URL, open it in a browser, then exchange the
# returned code. Do not show full tokens on screen during the demo.
bash demo/auth/pkce-token-request.sh url
bash demo/auth/pkce-token-request.sh exchange <code> <code_verifier>
export ALICE_TOKEN=<access_token_from_exchange_output>

# Use token
curl -s https://localhost:8443/api/v1/users/me \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Correlation-ID: demo-auth-001" \
  | python3 -m json.tool
```

**Show:** 200 OK, user data returned (no token in output)

---

## Scene 3: Client Credentials S2S (3:00 – 4:30)

**Narration:** "Billing service dùng Client Credentials flow để gọi Order service – machine-to-machine không cần user."

```bash
# Service-to-service token
S2S_TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "grant_type=client_credentials&client_id=billing-service&client_secret=REDACTED" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "S2S token length: ${#S2S_TOKEN}"

# Show token introspection result (not the token itself)
curl -s -X POST \
  http://localhost:8080/realms/myrealm/protocol/openid-connect/token/introspect \
  -d "client_id=billing-service&client_secret=REDACTED&token=$S2S_TOKEN" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print({'active': d['active'], 'scope': d['scope'], 'client_id': d['client_id']})"
```

---

## Scene 4: Billing → Order Access Check (4:30 – 6:00)

**Narration:** "Khi Alice checkout, Billing gọi Order để kiểm tra ownership trước khi xử lý thanh toán."

```bash
# Alice owns ord-alice-5001 – checkout succeeds
curl -v -X POST https://localhost:8443/api/v1/billing/checkout \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Correlation-ID: demo-ownership-001" \
  -H "Content-Type: application/json" \
  -d '{"order_id": "ord-alice-5001"}'
```

**Show:** 202 Accepted (Alice owns the order)

---

## Scene 5: BOLA Attack Blocked (6:00 – 7:30)

**Narration:** "Alice cố truy cập đơn hàng của Bob – hệ thống chặn với 403."

```bash
# BOLA attempt: Alice tries Bob's order
echo "--- BOLA Attack ---"
curl -v https://localhost:8443/api/v1/orders/ord-bob-2001/fixed \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Correlation-ID: demo-bola-001"
# Expected: 403 Forbidden

# Loki log shows bola_attempt event
echo "--- Loki Query (403 logs) ---"
# Show in Grafana: {job="docker"} |= "authz_forbidden"
```

**Show:** 403, Loki showing bola_attempt event with actor=alice, target=ord-bob-2001

---

## Scene 6: Webhook Forgery/Replay Blocked (7:30 – 9:00)

**Narration:** "Webhook với HMAC sai → 401. Webhook replay nonce → 401."

```bash
# Bad HMAC
curl -v -X POST https://localhost:8443/api/v1/auth/webhook \
  -H "X-Webhook-Timestamp: $(date +%s)" \
  -H "X-Webhook-Signature: sha256=deadbeefdeadbeef" \
  -H "X-Webhook-Nonce: demo-bad-001" \
  -d '{"event":"payment"}'
# Expected: 401

# Show replay blocked
# (Use tests/attack/webhook-forgery.sh for full demo)
bash tests/attack/webhook-forgery.sh 2>&1 | tail -20
```

**Show:** 401 on bad HMAC, 401 on replay

---

## Scene 7: SSRF Blocked (9:00 – 10:00)

**Narration:** "SSRF attack trên metadata IP bị chặn bởi URL validation."

```bash
# SSRF attempt – fixed endpoint
curl -v "https://localhost:8443/api/v1/admin/metadata-fixed?url=http://169.254.169.254/latest/meta-data/" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "X-Correlation-ID: demo-ssrf-001"
# Expected: 403

# vs vulnerable endpoint (demo)
curl -v "https://localhost:8443/api/v1/admin/metadata-vulnerable?url=http://169.254.169.254/" \
  -H "Authorization: Bearer $ALICE_TOKEN"
# Shows attack risk on vulnerable endpoint
```

---

## Scene 8: ZAP Active Scan Result (10:00 – 11:00)

**Narration:** "ZAP Active Scan tìm thấy 0 HIGH, 2 MEDIUM (đã phân tích false positive)."

```bash
# For current HTTPS evidence, rerun the scan before the defense demo.
bash tests/security/zap-active-scan.sh
cat docs/evidence/final/AUTHORITATIVE_EVIDENCE_INDEX.md
```

**Show:** ZAP command and authoritative evidence index. Archived pre-HTTPS ZAP
reports are retained only for audit history.

---

## Scene 9: API Fuzzing Result (11:00 – 11:45)

**Narration:** "47 fuzz requests – 0 crashes. 2 minor findings đã có kế hoạch sửa."

```bash
bash tests/security/run-fuzzing.sh
cat docs/evidence/final/AUTHORITATIVE_EVIDENCE_INDEX.md
```

---

## Scene 10: Grafana/Loki Alert 401/403/429 (11:45 – 13:00)

**Narration:** "3 alert rules: 401, 403, 429. Grafana/Loki shows real alert data."

**Show in browser:**
1. Open Grafana: `http://localhost:3000`
2. Navigate to Alerting → Alert rules
3. Show `HighUnauthorizedRate`, `HighForbiddenRate`, `RateLimitTriggered`
4. Show Loki Explorer with query: `{job="docker"} |= "401" | json`

```bash
# Trigger alerts live (optional)
for i in $(seq 1 12); do
  curl -s -o /dev/null https://localhost:8443/api/v1/users/me \
    -H "Authorization: Bearer fake.token.$i"
done
echo "Triggered 12x 401 – check Grafana for alert"
```

---

## Scene 11: Distributed Trace Billing → Order (13:00 – 14:00)

**Narration:** "Jaeger trace cho thấy toàn bộ flow: Gateway → Billing → Order."

**Show in browser:**
1. Open Jaeger: `http://localhost:16686`
2. Search: Service = `billing-service`
3. Show trace with 4 spans: gateway/request → billing/checkout → billing/request-order-ownership → order/verify-ownership
4. Show TraceID and durations

```bash
cat docs/evidence/tv3/observability/tracing-jaeger-billing-order.md
```

---

## Scene 12: SBOM / Artifact Signing Proof (14:00 – 15:00)

**Narration:** "SBOM CycloneDX cho 28 components Python. Cosign verify xác nhận image đã được ký."

```bash
# SBOM
cat docs/evidence/tv3/supply-chain/sbom-summary.md
python3 -c "
import json
d=json.load(open('docs/evidence/tv3/supply-chain/sbom-cyclonedx.json'))
print(f'Components: {len(d.get(\"components\", []))}')
print(f'Format: {d.get(\"bomFormat\")}')
"

# Cosign verify
cat docs/evidence/tv3/supply-chain/cosign-verify-output.txt | head -20
```

---

## Scene 13: Key Rotation / Token Revocation Drill (15:00 – 16:30)

**Narration:** "Xoay vòng HMAC secret – old secret bị reject, new secret hoạt động. MTTD=2min, MTTR=3min."

```bash
cat .artifacts/test-runs/tv3/key-rotation-output.txt
cat docs/evidence/tv3/secops-metrics/secops-mttd-mttr-summary.md
```

---

## Scene 14: Final Regression (16:30 – 17:30)

**Narration:** "Final regression: tất cả test suites pass sau merge."

```bash
bash tests/final/main-regression.sh 2>&1 | tail -20
cat docs/evidence/final/final-security-regression-after-all-hardening.txt | tail -30
```

---

## Closing

**Narration:** "Nhóm đã hoàn thành: ZAP Active Scan, API Fuzzing, SAST/SCA/SBOM/Cosign, Observability với 3 alert rules, Distributed Tracing, 4 Red Team scenarios, Resilience Drills, p50/p95 metrics, MTTD/MTTR, 3 Runbooks, và Final Regression. Tất cả evidence đều có thể chạy lại."

---

## Checklist Before Recording

- [ ] Stack fully running (`docker ps` shows all healthy)
- [ ] Grafana accessible at localhost:3000
- [ ] Jaeger accessible at localhost:16686
- [ ] Terminal history cleared
- [ ] Tokens will be masked from screen (only length shown)
- [ ] Evidence files already generated for quick `cat` demos
