# MTTD/MTTR Analysis

This legacy response-time based evidence is superseded.

Authoritative methodology and outputs now live at:

- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-results.csv`
- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-analysis.md`
- `tests/metrics/measure-mttd-mttr.sh`

## Correct Methodology

- **MTTD** is `alert_fired - attack_start`.
- **MTTR** is `remediation_done - alert_fired`.
- `alert_fired` must come from Grafana/Loki alert state or LogQL threshold detection.
- HTTP response milliseconds are not a valid MTTD measurement.
