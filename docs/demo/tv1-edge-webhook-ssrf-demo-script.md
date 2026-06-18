# Demo Script: Edge, Webhook & SSRF Security

Kịch bản demo này dùng để trình bày trực tiếp cho Giảng viên hướng dẫn (GVHD).

## 1. Demo Edge Hardening (TLS 1.3 & Rate Limit)

**Mục tiêu**: Chứng minh hệ thống chặn chuẩn TLS cũ và chặn kẻ tấn công brute-force.

**Thao tác**:
1. Mở terminal, chạy lệnh `openssl s_client -connect localhost:8443 -tls1_2`.
   - Kết quả: Handshake failed (mã lỗi `SSL alert number 70: wrong version`). Giải thích: Nhóm chủ động loại bỏ TLS 1.2.
2. Chạy lệnh với `-tls1_3`.
   - Kết quả: Kết nối thành công, hiển thị chi tiết Cipher suite (ví dụ: `TLS_AES_256_GCM_SHA384`).
3. Mở giao diện Frontend (http://localhost:3002). Đăng nhập bằng `Admin`.
4. Bấm liên tục 20 lần vào nút "Run Maintenance".
5. Chỉ ra trên console log rằng từ request thứ 16 trở đi, server trả về `HTTP 429 Too Many Requests`.

## 2. Demo SSRF Vulnerable vs Fixed

**Mục tiêu**: So sánh sự nguy hiểm của điểm yếu SSRF và hiệu quả của lớp bảo vệ.

**Thao tác**:
1. (Frontend) Lấy token `Admin`.
2. Bấm nút **Run Vulnerable Endpoint** ở phần SSRF Testing.
   - Kịch bản truyền vào URL: `http://169.254.169.254/latest/meta-data/`.
   - Kết quả: Server trả về HTTP 200, nội dung trả về là cloud metadata, chứng tỏ SSRF thành công.
3. Bấm nút **Run Fixed Endpoint**.
   - Kịch bản truyền vào URL: `http://169.254.169.254/latest/meta-data/`.
   - Kết quả: Server trả về HTTP 403 `ssrf_blocked`. Giải thích: Lớp bảo vệ URL Validation đã block các IP thuộc dải private/link-local.

## 3. Demo Webhook Security

**Mục tiêu**: Chứng minh Webhook giả mạo và Replay bị chặn.

**Thao tác**:
1. Mở giao diện Frontend (không cần login).
2. Bấm nút **Send Invalid Signature** ở phần Webhook Forgery.
   - Kết quả: Gateway/Backend trả về HTTP 401 Unauthorized do signature không đúng.
3. Bấm nút **Send Valid Signature** hai lần liên tiếp.
   - Lần 1: Thành công (HTTP 200).
   - Lần 2: Bị từ chối (HTTP 403) vì lý do Replay Attack (Nonce đã được sử dụng).
4. (Tùy chọn) Chạy file bash `bash tests/security/webhook-tests.sh` để chứng minh toàn bộ các case (kể cả missing header và old timestamp) đều bị reject.
