import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

export const users_me_latency_ms = new Trend('users_me_latency_ms', true);
export const users_me_error_rate = new Rate('users_me_error_rate');
export const users_me_status_count = new Counter('users_me_status_count');
export const users_me_status_200 = new Counter('users_me_status_200');
export const users_me_status_401 = new Counter('users_me_status_401');
export const users_me_status_403 = new Counter('users_me_status_403');
export const users_me_status_429 = new Counter('users_me_status_429');
export const users_me_status_502 = new Counter('users_me_status_502');
export const users_me_status_other = new Counter('users_me_status_other');

const tokenFile = __ENV.TOKEN_FILE || '/token/user-token.txt';
const baseUrl = __ENV.BASE_URL || 'https://localhost:8443';
const token = open(tokenFile).trim();

export const options = {
  insecureSkipTLSVerify: true,
  scenarios: {
    users_me_low_load: {
      executor: 'constant-arrival-rate',
      rate: 6,
      timeUnit: '1m',
      duration: '3m',
      preAllocatedVUs: 1,
      maxVUs: 2,
    },
  },
  thresholds: {
    users_me_error_rate: ['rate<0.01'],
    checks: ['rate>0.99'],
  },
};

export default function () {
  const correlationId = `k6-overhead-${__VU}-${__ITER}`;
  const res = http.get(`${baseUrl}/api/v1/users/me`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-Correlation-ID': correlationId,
    },
    timeout: '10s',
  });

  const ok = check(res, {
    'users/me returns 200': (r) => r && r.status === 200,
  });
  const failed = !ok || !res || res.error || res.status >= 500;
  const status = res && res.status ? String(res.status) : '0';

  if (res && typeof res.timings.duration === 'number') {
    users_me_latency_ms.add(res.timings.duration);
  }
  users_me_status_count.add(1, { status });
  if (status === '200') {
    users_me_status_200.add(1);
  } else if (status === '401') {
    users_me_status_401.add(1);
  } else if (status === '403') {
    users_me_status_403.add(1);
  } else if (status === '429') {
    users_me_status_429.add(1);
  } else if (status === '502') {
    users_me_status_502.add(1);
  } else {
    users_me_status_other.add(1);
  }
  users_me_error_rate.add(Boolean(failed));
}
