# Phase 3 k6 Performance Evidence

## Scope

Target: `https://localhost:8443`

This run measures low-load baseline latency for the Phase 2/Phase 3 hardened profile:

- Kong public HTTPS gateway on `https://localhost:8443`
- TLS 1.3 edge profile
- gateway-backend mTLS sidecars
- security headers / WAF / rate-limit enabled
- authenticated `/api/v1/users/me` included

This is not a maximum stress-test result. It is baseline p50/p95 evidence for the secured local lab profile.

## Run Configuration

- VUs: 1
- Duration: 45 seconds
- Sleep between iterations: 12 seconds
- Authenticated path: included
- Total requests: 20

## Result

| Metric | Value |
|---|---:|
| Health p50 | 5.03 ms |
| Health p95 | 73.96 ms |
| Authenticated `/users/me` p50 | 5.23 ms |
| Authenticated `/users/me` p95 | 8.14 ms |
| Failed request rate | 0.00% |
| Total requests | 20 |

## Conclusion

The secured local profile completed the k6 low-load baseline run with zero failed requests. The public API endpoint `https://localhost:8443` remained responsive with p95 latency below the Phase 3 threshold for both health endpoints and authenticated `/api/v1/users/me`.
