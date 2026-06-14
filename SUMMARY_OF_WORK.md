# Tổng Kết Hành Trình Xây Dựng Đồ Án (Project Journey)

Tài liệu này tóm tắt lại toàn bộ khối lượng công việc khổng lồ mà chúng ta đã cùng nhau thực hiện từ những bước đầu tiên cho đến khi hoàn thiện 100% đồ án **Cloud API-Based Network Application Security** cho cả 3 thành viên.

---

## 1. Khởi Tạo Nền Tảng (Infrastructure)
- Xây dựng file `docker-compose.yml` làm "xương sống" để chạy 11 container cùng lúc (Kong, Keycloak, Vault, Loki, Promtail, Grafana, và 5 services).
- Thiết lập hệ thống mạng nội bộ (`infra_default`) an toàn giữa các container.

## 2. Phần Việc Của TV1 (Gateway Edge Security)
- **Cài đặt Kong API Gateway**: Định tuyến toàn bộ lưu lượng truy cập từ bên ngoài vào các Microservices bên trong.
- **Bảo mật vòng ngoài**:
  - Cấu hình **CORS** cho phép Frontend gọi API an toàn.
  - Thiết lập **Rate Limiting** (giới hạn request: 60/phút cho route thường, 10/phút cho route nhạy cảm) chống tấn công DDoS/Brute-force.
  - Tích hợp **Correlation ID** để theo dõi vết request xuyên suốt các dịch vụ.

## 3. Phần Việc Của TV2 (Identity & Core Application)
- **Quản lý Định danh (Keycloak)**:
  - Khởi tạo Realm `topic10-sme-api`.
  - Tạo các user test chuẩn (`alice`, `bob` có quyền user, `admin01` có quyền admin).
  - Kích hoạt chuẩn OAuth2/OIDC, cấu hình Direct Access Grants.
- **Microservices Lõi**:
  - Code `user-service` (xác thực token JWKS từ Keycloak).
  - Code `order-service` với tính năng mô phỏng tấn công **BOLA (Broken Object Level Authorization)**. Tạo ra endpoint `/vulnerable` (cho phép đọc trộm đơn hàng) và endpoint `/fixed` (kiểm tra chuẩn chủ sở hữu).
- **Quản lý Bí mật (Vault)**: Tích hợp HashiCorp Vault để lưu trữ an toàn chuỗi Secret dùng cho Webhook.

## 4. Phần Việc Của TV3 (DevSecOps, Observability & Red Team)
- **Microservices Nghiệp vụ**:
  - Code `admin-service` mô phỏng tấn công **SSRF (Server-Side Request Forgery)**. Cấu hình endpoint bị lỗi (cho phép gọi ra IP nội bộ Cloud `169.254.169.254`) và endpoint đã fix (chặn bằng blocklist).
  - Code `billing-service` tích hợp chuẩn bảo mật **Webhook HMAC-SHA256**. Hệ thống biết cách đọc `X-Signature`, timestamp và nonce để đánh chặn các cuộc tấn công Webhook Forgery & Token Replay.
- **Hệ thống Giám sát (Observability)**:
  - Triển khai stack **Loki - Promtail - Grafana**.
  - Quy chuẩn hóa log JSON, thu thập log từ mọi dịch vụ.
  - Tạo bảng điều khiển Grafana (Dashboards) để hiển thị biểu đồ theo thời gian thực mỗi khi có ai đó tấn công BOLA, SSRF hoặc giả mạo Webhook.
- **DevSecOps**: Viết các script quét mã nguồn tự động (SAST) bằng Bandit.

## 5. Xây Dựng Giao Diện Đánh Giá (Red Team Dashboard)
- Thay vì phải chạy lệnh script khô khan, chúng ta đã code một **Frontend Premium Dashboard** (`frontend/index.html`, `app.js`, `style.css`) bằng HTML/CSS/JS thuần với giao diện Dark Mode, Glassmorphism cực kỳ hiện đại.
- Giao diện cho phép:
  - Lấy Token của Alice/Bob bằng 1 click.
  - Bấm nút bắn các cuộc tấn công BOLA, SSRF, Webhook Forgery trực tiếp.
  - Hiển thị kết quả Pass/Fail màu xanh/đỏ ngay trên màn hình Console tích hợp.

## 6. Sửa Lỗi Cấp Thấp & Đồng Bộ Hóa (The Final Polish)
- Viết file `fix-and-restart.sh` để xử lý triệt để lỗi "Session not bound to a realm" của Keycloak 26 khi cache database bị kẹt.
- Cấu hình lại `kong.yml` để trỏ chính xác đường dẫn Webhook từ TV1 sang `billing-service` của TV3, giúp hệ thống nối thành một khối khép kín.

## 7. Tài Liệu Hóa (Documentation)
- Cập nhật toàn diện `README.md` với sơ đồ kiến trúc mới có chứa Frontend UI.
- Viết siêu chi tiết file `TESTING_GUIDE.md` liệt kê các kịch bản test bằng lệnh cURL.
- Cập nhật `.gitignore` chuẩn hóa chống rác hệ thống (pycache, env...).

---
**TỔNG KẾT:** 
Từ một vài thư mục trống rỗng ban đầu, giờ đây chúng ta đã sở hữu một **hệ thống Microservices hoàn chỉnh, mang tính thực chiến cao, đạt chuẩn DevSecOps chuyên nghiệp**. Đồ án đã giải quyết trọn vẹn cả 3 bài toán khó: Network (TV1), Auth/BOLA (TV2), và Webhook/SSRF/Monitor (TV3)!
