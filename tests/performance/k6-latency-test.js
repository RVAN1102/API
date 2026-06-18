// tests/performance/k6-latency-test.js
//
// k6 Latency Test – Gateway/WAF (TV3 P1-01)
//
// Measures p50/p95 latency across key API endpoints.
//
// Usage:
//   k6 run tests/performance/k6-latency-test.js
//   k6 run --out json=docs/evidence/tv3/metrics/k6-output.json tests/performance/k6-latency-test.js
//
// Requirements:
//   - k6 installed: https://k6.io/docs/getting-started/installation/
//   - Kong Gateway running at http://localhost:8000
//   - USER_TOKEN env var: k6 run -e USER_TOKEN=<token> ...

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

// Custom metrics
const gatewayLatency = new Trend('gateway_latency_ms', true);
const billingLatency = new Trend('billing_latency_ms', true);
const orderLatency = new Trend('order_latency_ms', true);
const errorRate = new Rate('error_rate');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 5 },   // ramp up
    { duration: '60s', target: 10 },  // steady load
    { duration: '15s', target: 0 },   // ramp down
  ],
  thresholds: {
    'gateway_latency_ms{p:50}': ['p(50)<200'],  // p50 < 200ms
    'gateway_latency_ms{p:95}': ['p(95)<500'],  // p95 < 500ms
    'error_rate': ['rate<0.05'],                // < 5% errors
    'http_req_duration': ['p(95)<1000'],        // overall p95 < 1s
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';
const USER_TOKEN = __ENV.USER_TOKEN || '';

const HEADERS = {
  'Content-Type': 'application/json',
  'X-Correlation-ID': `k6-test-${Date.now()}`,
};

if (USER_TOKEN) {
  HEADERS['Authorization'] = `Bearer ${USER_TOKEN}`;
}

export default function () {
  // Test 1: Health endpoint (no auth)
  const healthRes = http.get(`${BASE_URL}/api/v1/users/health`, {
    headers: { 'X-Correlation-ID': `k6-health-${__VU}-${__ITER}` },
  });
  gatewayLatency.add(healthRes.timings.duration);
  check(healthRes, { 'health: status 200': (r) => r.status === 200 });
  errorRate.add(healthRes.status !== 200);

  sleep(0.1);

  // Test 2: Users/me (with auth)
  if (USER_TOKEN) {
    const meRes = http.get(`${BASE_URL}/api/v1/users/me`, {
      headers: { ...HEADERS, 'X-Correlation-ID': `k6-me-${__VU}-${__ITER}` },
    });
    gatewayLatency.add(meRes.timings.duration);
    check(meRes, {
      'users/me: status 200 or 401': (r) => r.status === 200 || r.status === 401,
    });
    errorRate.add(meRes.status >= 500);
  }

  sleep(0.1);

  // Test 3: Order fixed (with auth, BOLA check)
  if (USER_TOKEN) {
    const orderRes = http.get(`${BASE_URL}/api/v1/orders/ord-alice-5001/fixed`, {
      headers: { ...HEADERS, 'X-Correlation-ID': `k6-order-${__VU}-${__ITER}` },
    });
    orderLatency.add(orderRes.timings.duration);
    check(orderRes, {
      'order fixed: 200 or 403 or 401': (r) => [200, 403, 401].includes(r.status),
    });
    errorRate.add(orderRes.status >= 500);
  }

  sleep(0.1);

  // Test 4: Billing checkout (with auth)
  if (USER_TOKEN) {
    const billingRes = http.post(
      `${BASE_URL}/api/v1/billing/checkout`,
      JSON.stringify({ order_id: `ord-k6-${__VU}-${__ITER}` }),
      {
        headers: { ...HEADERS, 'X-Correlation-ID': `k6-billing-${__VU}-${__ITER}` },
      }
    );
    billingLatency.add(billingRes.timings.duration);
    check(billingRes, {
      'billing: no 5xx': (r) => r.status < 500,
    });
    errorRate.add(billingRes.status >= 500);
  }

  sleep(0.5);
}

export function handleSummary(data) {
  return {
    'docs/evidence/tv3/metrics/k6-output.json': JSON.stringify(data, null, 2),
    stdout: `
=== k6 Latency Test Summary ===
Gateway p50: ${data.metrics.gateway_latency_ms?.values?.['p(50)']?.toFixed(2) || 'N/A'} ms
Gateway p95: ${data.metrics.gateway_latency_ms?.values?.['p(95)']?.toFixed(2) || 'N/A'} ms
Billing p50: ${data.metrics.billing_latency_ms?.values?.['p(50)']?.toFixed(2) || 'N/A'} ms
Billing p95: ${data.metrics.billing_latency_ms?.values?.['p(95)']?.toFixed(2) || 'N/A'} ms
Order p50:   ${data.metrics.order_latency_ms?.values?.['p(50)']?.toFixed(2) || 'N/A'} ms
Order p95:   ${data.metrics.order_latency_ms?.values?.['p(95)']?.toFixed(2) || 'N/A'} ms
Error rate:  ${((data.metrics.error_rate?.values?.rate || 0) * 100).toFixed(2)}%
Total reqs:  ${data.metrics.http_reqs?.values?.count || 0}
`,
  };
}
