# MTTD/MTTR Analysis

Generated: Wed Jun 17 10:53:07 AM UTC 2026

## Methodology

In this prototype, security events are detected **synchronously** – the backend service
validates the request and logs the event in the same HTTP call. Therefore:

- **MTTD** ≈ response time of the blocked request (detection happens during request processing)
- **MTTR** ≈ same as MTTD (the HTTP 4xx response IS the mitigation action)

## Results Summary

| Scenario | MTTD (ms) | MTTR (ms) | HTTP Status |
|---|---|---|---|
| ssrf_blocked | 1500 | 1500 | 403 |
| rate_limit_429 | 100 | 100 | 429 |
| webhook_invalid_signature | 12 | 12 | 401 |

## Limitations

- Async log-based detection (e.g., Grafana alert) would add latency not measured here.
- Rate limiting detection is measured from the 429 response timing.
- BOLA detection requires an authenticated user token.
