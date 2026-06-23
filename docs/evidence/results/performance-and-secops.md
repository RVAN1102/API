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
| MTTD/MTTR | `tests/metrics/execute-mttd-scenario.sh` runs Loki LogQL threshold polling and captures one correlation-ID log sample | no timing value is claimed unless generated metrics evidence exists |
| Vault/KMS-style overhead | `tests/metrics/measure-kms-overhead.sh` measures local Vault dev-mode KV reads for `/v1/secret/data/api/webhook` without writing secret values | generated only when `docs/evidence/tv3/metrics/vault-kms-overhead-summary.md` exists |

## Scope And Limitation

The k6 result is a low-load secured gateway baseline, not a stress test. No
current MTTD or MTTR timing value is claimed in this curated summary. The
MTTD/MTTR source of truth is Loki LogQL threshold polling unless separate
Grafana firing state evidence is explicitly captured.
