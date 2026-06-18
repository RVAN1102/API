# Quyết định Hardening: TLS 1.3-Only tại Edge

## Rationale
Mặc dù yêu cầu tối thiểu của đề tài cho phép TLS 1.2+/1.3, nhóm đã chủ động cấu hình API Gateway (Edge) **chỉ chấp nhận kết nối TLS 1.3**.

**Lý do:**
1. **Giảm bề mặt tấn công:** TLS 1.2 có hàng tá Cipher Suites yếu và lỗi thời (ví dụ RSA key exchange, CBC mode ciphers) có khả năng bị tấn công (như POODLE, ROBOT). TLS 1.3 loại bỏ hoàn toàn các cấu trúc mã hóa yếu, chỉ giữ lại các bộ mã hóa AEAD cực mạnh.
2. **Hiệu năng:** TLS 1.3 giảm thiểu số lượng round-trip (1-RTT handshake) giúp giảm latency khi thiết lập kết nối mã hóa.
3. **Quyết định có chủ đích:** Việc thiết lập cấu hình từ chối kết nối TLS 1.2 không phải là do "cấu hình sai" mà là một quyết định **hardening có chủ đích** của nhóm nhằm tối đa hóa mức độ bảo mật ở vùng biên (Edge).

## Evidence
File evidence chứng minh TLS 1.3 được chấp nhận và TLS 1.2 bị từ chối được lưu tại:
`docs/evidence/tv1/edge-final/tls-13-only-and-hsts.txt`
