# TV1 Edge Incident Runbook

## Mục đích
Tài liệu này hướng dẫn cách xử lý nhanh các sự cố liên quan đến API Gateway, Webhook Security và các cuộc tấn công SSRF.

## 1. Cách xác minh cấu hình an toàn (TLS/HSTS/CORS/Rate Limit)
Khi có nghi ngờ cấu hình Edge bị thay đổi:
- **TLS 1.3-only**: Chạy lệnh `echo | openssl s_client -connect localhost:8443 -tls1_2` (kỳ vọng `alert` hoặc `error`).
- **HSTS**: `curl -k -I https://localhost:8443/api/v1/users/health | grep Strict-Transport-Security`.
- **CORS**: `curl -si -X OPTIONS http://localhost:8000/api/v1/users/health -H "Origin: https://evil.example" -H "Access-Control-Request-Method: GET" | grep access-control-allow-origin` (không được phép có output).
- **Rate Limit**: Gửi 20 request liên tiếp và kiểm tra xem có nhận HTTP `429 Too Many Requests` hay không.

## 2. Xử lý Rate Limit Spike (Tấn công DoS/Brute Force)
**Triệu chứng**: Ghi nhận một lượng lớn log HTTP 429 từ Gateway, dịch vụ phản hồi chậm hoặc có dấu hiệu bị tấn công DDoS lớp ứng dụng.
**Cách xử lý**:
1. Lấy `client_ip` từ log của Kong (`docker compose logs kong`).
2. Xác định IP có phải hợp lệ hay không.
3. Chặn IP tấn công bằng WAF hoặc iptables. Tại Kong, có thể dùng plugin `ip-restriction` để reject ngay lập tức IP đó.

## 3. Xoay Webhook Secret (Khi nghi ngờ lộ Secret)
**Triệu chứng**: Webhook endpoint nhận nhiều request có signature hợp lệ nhưng không phải do bên thứ ba thực sự gửi.
**Cách xử lý**:
1. Tạo một secret mới (mạnh, dài hơn 32 ký tự ngẫu nhiên).
2. Cập nhật biến môi trường `WEBHOOK_SECRET` cho Billing Service trong `infra/docker-compose.yml`.
3. Restart Billing Service: `docker compose -f infra/docker-compose.yml up -d billing-service`.
4. Cập nhật webhook secret mới cho đối tác gửi webhook.
5. Kiểm tra log `missing_webhook_header` hoặc 401 trên Gateway để đảm bảo request từ đối tác đang được ký đúng với secret mới.

## 4. Phát hiện Webhook Replay / Invalid Signature
**Triệu chứng**: Kẻ tấn công cố gửi lại các webhook cũ.
**Phát hiện**:
- Các request cũ sẽ bị Billing Service trả về lỗi `403` với `timestamp_expired` hoặc `replayed_nonce`.
- Cấu hình alerting (nếu có Loki/Grafana) theo dõi số lượng HTTP 403 trên endpoint `/api/v1/webhooks/payment` tăng cao.

## 5. Xử lý SSRF Attempt tới Metadata IP
**Triệu chứng**: Admin Service log lỗi `ssrf_blocked` khi có user cố gắng fetch `http://169.254.169.254`.
**Cách xử lý**:
1. Trích xuất `correlation_id` và token của user thực hiện hành động.
2. Kiểm tra xem token này có bị lộ không.
3. Thu hồi (revoke) token của user và reset password nếu nghi ngờ tài khoản bị xâm phạm.
4. Đảm bảo Network Egress Policy (như AWS Security Groups / Kubernetes NetworkPolicies) không có bất kỳ ngoại lệ nào cho phép outbound tới `169.254.169.254`.

## 6. Xử lý sự cố liên quan đến TLS 1.3-only
**Triệu chứng**: Khách hàng/Client cũ phàn nàn không thể kết nối tới API (SSL handshake failed).
**Cách xử lý**:
- Thông báo về chính sách ngừng hỗ trợ TLS 1.2 vì lý do bảo mật.
- Yêu cầu khách hàng cập nhật thư viện / trình duyệt lên phiên bản hỗ trợ TLS 1.3.
- (Tuyệt đối không downgrade cấu hình `KONG_SSL_PROTOCOLS` xuống TLS 1.2 trừ khi có sự đồng ý của hội đồng bảo mật).

## 7. Xoay (Rotate) Webhook Client Certificate (mTLS)
**Triệu chứng**: Nghi ngờ private key của client certificate bị lộ, hoặc client cert đã hết hạn.
**Cách xử lý**:
1. Chạy lại script sinh cert để cấp phát một certificate mới: `bash infra/certs/generate-webhook-mtls-certs.sh`.
2. Gửi file `infra/certs/webhook-client.crt` và `webhook-client.key` (qua kênh an toàn) cho đối tác webhook sender.
3. Nếu CA certificate (`webhook-ca.crt`) cũng được sinh lại, cần mount file mới vào Kong Gateway và restart Kong (`docker compose restart kong`).
4. Theo dõi log của Billing Service: nếu thấy `webhook_mtls_rejected` (mã lỗi 401 `mtls_client_cert_required`), có thể đối tác vẫn đang dùng cert cũ không hợp lệ hoặc cert chưa được CA trust.
