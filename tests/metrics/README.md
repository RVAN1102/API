# Security Metrics

This directory contains scripts to measure security operational metrics:
- **MTTD**: `alert_fired - attack_start`
- **MTTR**: `remediation_done - alert_fired`

Detection must come from Loki/Grafana alert state or LogQL threshold polling,
not HTTP response latency.

## Running
```bash
bash tests/metrics/measure-mttd-mttr.sh
```

Generates:

- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-results.csv`
- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-analysis.md`
