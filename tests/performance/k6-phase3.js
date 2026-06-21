import http from "k6/http";
import { check, group, sleep } from "k6";
import { Rate, Trend, Counter } from "k6/metrics";

export const options = {
  insecureSkipTLSVerify: true,
  vus: Number(__ENV.K6_VUS || "1"),
  duration: __ENV.K6_DURATION || "45s",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    phase3_failed_request_rate: ["rate<0.01"],
    phase3_health_duration: ["p(95)<750"],
    phase3_auth_duration: ["p(95)<1000"],
  },
};

const BASE_URL = __ENV.BASE_URL || "https://localhost:8443";
const ACCESS_TOKEN = __ENV.ACCESS_TOKEN || "";
const SLEEP_SECONDS = Number(__ENV.K6_SLEEP_SECONDS || "12");

const failedRate = new Rate("phase3_failed_request_rate");
const healthDuration = new Trend("phase3_health_duration", true);
const authDuration = new Trend("phase3_auth_duration", true);
const statusCount = new Counter("phase3_status_count");

function record(name, res, trend) {
  const ok = res.status >= 200 && res.status < 300;

  failedRate.add(!ok);
  statusCount.add(1, {
    endpoint: name,
    status: String(res.status),
  });

  if (ok && trend) {
    trend.add(res.timings.duration);
  }

  if (!ok || __ENV.K6_LOG_STATUS === "1") {
    const body = (res.body || "").slice(0, 160).replace(/\s+/g, " ");
    console.log(
      `${name} status=${res.status} error=${res.error || ""} duration_ms=${res.timings.duration} body=${body}`
    );
  }

  check(res, {
    [`${name} returned 2xx`]: (r) => r.status >= 200 && r.status < 300,
  });
}

export default function () {
  group("health endpoints", function () {
    const healthPaths = [
      ["/api/v1/users/health", "users-health"],
      ["/api/v1/orders/health", "orders-health"],
      ["/api/v1/billing/health", "billing-health"],
      ["/api/v1/admin/health", "admin-health"],
    ];

    for (const [path, name] of healthPaths) {
      const res = http.get(`${BASE_URL}${path}`, { timeout: "5s" });
      record(name, res, healthDuration);
    }
  });

  if (ACCESS_TOKEN) {
    group("authenticated users/me", function () {
      const res = http.get(`${BASE_URL}/api/v1/users/me`, {
        headers: { Authorization: `Bearer ${ACCESS_TOKEN}` },
        timeout: "5s",
      });
      record("users-me", res, authDuration);
    });
  }

  sleep(SLEEP_SECONDS);
}

function metricValue(data, metric, key) {
  return data.metrics?.[metric]?.values?.[key];
}

function fmtMs(value) {
  return typeof value === "number" ? `${value.toFixed(2)} ms` : "N/A";
}

function fmtRate(value) {
  return typeof value === "number" ? `${(value * 100).toFixed(2)}%` : "N/A";
}

export function handleSummary(data) {
  const lines = [
    "Phase 3 k6 Performance Summary",
    `Target: ${BASE_URL}`,
    `Authenticated /users/me: ${ACCESS_TOKEN ? "included" : "skipped; set ACCESS_TOKEN to include it"}`,
    `Health p50: ${fmtMs(metricValue(data, "phase3_health_duration", "med"))}`,
    `Health p95: ${fmtMs(metricValue(data, "phase3_health_duration", "p(95)"))}`,
    `Authenticated p50: ${fmtMs(metricValue(data, "phase3_auth_duration", "med"))}`,
    `Authenticated p95: ${fmtMs(metricValue(data, "phase3_auth_duration", "p(95)"))}`,
    `Failed request rate: ${fmtRate(metricValue(data, "phase3_failed_request_rate", "rate"))}`,
    `Total requests: ${metricValue(data, "http_reqs", "count") ?? "N/A"}`,
    "",
  ];

  return {
    stdout: `${lines.join("\n")}\n`,
  };
}
