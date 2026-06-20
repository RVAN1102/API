import http from "k6/http";
import { check } from "k6";
import { sleep } from "k6";

export const options = {
  vus: 1,
  duration: "30s",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<500"],
  },
};

const baseUrl = __ENV.BASE_URL || "https://localhost:8443";
const paths = [
  "/api/v1/users/health",
  "/api/v1/orders/health",
  "/api/v1/billing/health",
  "/api/v1/admin/health",
];

export default function () {
  for (const path of paths) {
    const response = http.get(`${baseUrl}${path}`);
    check(response, { [`${path} returns 200`]: (r) => r.status === 200 });
  }
  sleep(1);
}
