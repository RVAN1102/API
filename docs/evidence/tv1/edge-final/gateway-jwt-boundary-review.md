# Gateway and JWT Validation Boundary Review

## 1. Kiến trúc hiện tại
- **API Gateway (Kong)** đảm nhiệm các tính năng Edge Security cơ bản:
  - TLS 1.3 termination & HSTS.
  - Rate limiting (theo IP, theo route).
  - CORS strict.
  - Request size limit (giảm thiểu rủi ro DoS từ payload lớn).
  - WAF/Edge filter (chặn các mẫu SQLi/XSS cơ bản, check bắt buộc các webhook header).
- **Backend Services (FastAPI)** đảm nhiệm việc JWT Validation:
  - Các service backend xác thực token qua việc lấy Public Key (JWKS) từ Keycloak.
  - Các role (ví dụ: `admin`) được trích xuất và verify trực tiếp tại backend.

## 2. Làm rõ phạm vi "Gateway JWT Validation"
Theo yêu cầu bảo mật, Gateway **không** trực tiếp validate chữ ký JWT hay kiểm tra tính hết hạn của JWT bằng plugin `kong-oidc` hay `kong-jwt`. Việc validation được nhường hoàn toàn cho Backend Services (Decentralized Auth). 

Gateway chỉ đóng vai trò route traffic và filter ở layer L4/L7.

**Kiến trúc này được chọn vì:**
- Phù hợp với tính chất Microservices: Mỗi service tự kiểm soát và verify quyền (AuthZ) riêng biệt, tránh cổ chai (bottleneck) ở Gateway.
- Mọi logic liên quan đến AuthZ/RBAC được quản lý bởi Service Policy, Gateway chỉ là điểm chặn các request độc hại rõ ràng.

## 3. Khẳng định
*Không claim sai lệch*: Hệ thống này **Backend services đảm nhiệm JWT verification**, còn Gateway chỉ làm nhiệm vụ **Edge controls**.
