# Alert-Based MTTD/MTTR Analysis

**Generated:** 2026-06-22T15:40:02Z
**Source of truth:** Loki LogQL threshold polling at `http://localhost:3100`
**Target:** `https://localhost:8443`

## Methodology

- **MTTD** is measured as `logql_detection_time - attack_start`.
- **MTTR** is measured as `remediation_done - logql_detection_time`.
- Detection is Loki LogQL threshold-based evidence, not Grafana alert firing evidence.
- The script discovers Loki labels and probes multiple selectors/patterns before selecting a query.
- `logql_detection_time` is recorded only when the selected LogQL count meets or exceeds the scenario threshold.
- `remediation_done` is recorded after containment is verified with a follow-up blocked request.
- HTTP response latency is not used as MTTD.

## Results

| Scenario | MTTD (s) | MTTR (s) | Selector | Pattern | Count | Containment Status | Note |
|---|---:|---:|---|---|---:|---:|---|
| 401_unauthorized_spike | 7 | 0 | `{service="user-service"}` | `401` | 31.0 | 429 | logql_threshold_observed_value_31.0; containment_verified |
| 403_forbidden_bola_spike | 5 | 0 | `{service="order-service"}` | `"status_code": 403` | 10.0 | 403 | logql_threshold_observed_value_10.0; containment_verified |
| 429_rate_limit_spike | 1 | 0 | `{job="docker"}` | ` 429 ` | 13.0 | 429 | logql_threshold_observed_value_13.0; containment_verified |

## Evidence Files

- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-results.csv`
- `docs/evidence/tv3/metrics/mttd-mttr-alert-based-analysis.md`
- `docs/evidence/tv3/metrics/loki-labels.json`
- `docs/evidence/tv3/metrics/loki-label-values.json`
- `docs/evidence/tv3/metrics/*-diagnostics.md`
- `docs/evidence/tv3/metrics/*-selected-query-response.json`
- `docs/evidence/tv3/metrics/loki-sample-recent-logs.md` when no candidate query matches logs
