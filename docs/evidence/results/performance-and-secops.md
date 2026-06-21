# Performance And SecOps

## Requirement Proven

The repository records a low-load secured k6 baseline and identifies SecOps
detection signals without inventing detection timing.

## Command Or Evidence Source

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" k6 run tests/performance/k6-phase3.js
bash tests/metrics/measure-mttd-mttr.sh
```

## Observed Result

Recorded k6 result:

| Metric | Value |
|---|---:|
| target | `https://localhost:8443` |
| authenticated `/users/me` | included |
| health p50 | `5.03 ms` |
| health p95 | `73.96 ms` |
| authenticated p50 | `5.23 ms` |
| authenticated p95 | `8.14 ms` |
| failed request rate | `0.00%` |
| total requests | `20` |

Security signals available to the metrics script include authentication
failures, authorization failures, rate-limit responses, SSRF blocks, and webhook
security failures.

## Scope And Limitation

The k6 result is a low-load secured baseline, not a stress test. No current
MTTD or MTTR timing value is claimed.
