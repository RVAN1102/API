# Performance And SecOps

## Requirement Proven

The repository records a low-load secured k6 baseline and identifies SecOps
detection signals without inventing detection timing. It also provides
automation for Loki LogQL MTTD/MTTR and Vault secret-read overhead evidence.

## Command Or Evidence Source

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" k6 run tests/performance/k6-phase3.js
bash tests/metrics/execute-mttd-scenario.sh
bash tests/metrics/measure-kms-overhead.sh
bash tests/metrics/measure-mttd-mttr.sh
bash tests/metrics/run-k6-overhead.sh
```

## Observed Result

Recorded secured gateway k6 result:

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
failures, authorization failures, rate-limit responses, SSRF blocks, and
webhook security failures.

Additional quantitative automation:

| Area | Methodology | Current curated result |
|---|---|---|
| Direct-vs-edge k6 overhead | `tests/metrics/run-k6-overhead.sh` runs the same authenticated `/api/v1/users/me` low-load scenario directly and through HTTPS Kong, then computes p50/p95 deltas | generated values are published only in `docs/evidence/tv3/metrics/k6-users-me-overhead-analysis.md` after both runs pass |
| MTTD/MTTR | `tests/metrics/execute-mttd-scenario.sh` runs Loki LogQL threshold polling and captures one correlation-ID log sample | no timing value is claimed unless generated metrics evidence exists |
| Vault/KMS-style overhead | `tests/metrics/measure-kms-overhead.sh` measures HTTPS Vault KV reads for `/v1/secret/data/api/webhook` without writing secret values | no value is claimed unless the summary records successful HTTP `200` samples and numeric p50/p95/average latency |

## Scope And Limitation

The recorded gateway result and the direct-vs-edge comparison are low-load
measurements, not stress tests. The comparison does not isolate mTLS from
gateway, TLS, policy, network, or container-runtime overhead. No current MTTD
or MTTR timing value is claimed in this curated summary.
