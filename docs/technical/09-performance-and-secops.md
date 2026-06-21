# Performance And SecOps

## Requirement

The repository must record current performance evidence honestly and distinguish
implemented detection signals from measured detection timing.

## k6 Baseline

The current recorded k6 result is a low-load secured baseline, not a stress
test.

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

Rerunnable command:

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" k6 run tests/performance/k6-phase3.js
```

## SecOps Signals

The implementation logs or exposes:

- authentication failures;
- authorization failures and BOLA attempts;
- rate-limit responses;
- SSRF blocked events;
- webhook invalid signature, old timestamp, and replay nonce outcomes.

## MTTD And MTTR

`tests/metrics/measure-mttd-mttr.sh` measures detection timing from Loki query
or alert evidence. The curated docs do not claim current measured values.

