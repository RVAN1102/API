# Phase 3 MTTD/MTTR Evidence Status

## Scope

This file tracks Phase 3 SecOps MTTD/MTTR evidence status.

MTTD and MTTR must be reported only from measured timestamps:

- MTTD = detection timestamp minus attack start timestamp.
- MTTR = containment or remediation verification timestamp minus detection timestamp.
- HTTP response latency is not MTTD.
- k6 p50/p95 performance latency is not MTTD/MTTR.

## Current Status

Measured Phase 3 MTTD/MTTR values are not recorded in this file yet.

The repository keeps this file as an evidence-status document to avoid inventing detection or remediation times. A completed MTTD/MTTR entry must preserve:

- attack start timestamp
- detection source
- detection timestamp
- containment or remediation verification timestamp
- computed MTTD in seconds
- computed MTTR in seconds

## Candidate Scenarios

| Scenario | Detection source | Status |
|---|---|---|
| 401 authentication failure spike | Loki/Grafana or structured gateway/service logs | Awaiting measured Phase 3 run |
| 403/BOLA forbidden spike | Loki/Grafana or structured gateway/service logs | Awaiting measured Phase 3 run |
| 429 rate-limit event | Kong/gateway logs or Loki/Grafana alert evidence | Awaiting measured Phase 3 run |
| SSRF blocked access | SSRF block logs and HTTP 403 evidence | Awaiting measured Phase 3 run |
| WAF blocked request | Kong/gateway WAF/security-filter logs | Awaiting measured Phase 3 run |

## Evidence Rule

Do not commit tokens, raw secrets, private keys, or unreviewed generated logs. Only commit reviewed summaries and sanitized outputs.
