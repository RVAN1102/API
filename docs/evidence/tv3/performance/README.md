# Phase 3 Performance Evidence

## Scope

This folder stores Phase 3 k6 baseline performance evidence for the secured local lab profile.

Target: `https://localhost:8443`

The measured path goes through the public Kong HTTPS gateway. The run includes the hardened local profile:

- TLS public gateway on `https://localhost:8443`
- gateway-backend mTLS sidecars
- WAF/security filtering enabled
- rate limiting enabled
- authenticated `/api/v1/users/me` included

This is a low-load baseline run, not a maximum stress test.

## k6 Run Configuration

| Item | Value |
|---|---:|
| Virtual users | 1 |
| Duration | 45 seconds |
| Sleep between iterations | 12 seconds |
| Completed iterations | 4 |
| Interrupted iterations | 0 |
| Total requests | 20 |
| Authenticated path | Included |

## Result

| Metric | Value |
|---|---:|
| Health p50 | 5.03 ms |
| Health p95 | 73.96 ms |
| Authenticated `/users/me` p50 | 5.23 ms |
| Authenticated `/users/me` p95 | 8.14 ms |
| Failed request rate | 0.00% |

## Evidence Files

- `k6-phase3-output.txt`
- `k6-phase3-summary.json`
- `k6-phase3-summary.md`

## Conclusion

The secured local lab profile completed the Phase 3 k6 low-load baseline run with zero failed requests. The public API endpoint remained responsive under the measured baseline workload.
