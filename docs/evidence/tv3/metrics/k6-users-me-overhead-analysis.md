# k6 Users Me Edge Overhead Analysis

## Requirement Proven

Measures low-load controlled edge path overhead compared with direct backend path for the same authenticated `/api/v1/users/me` endpoint.

## Command Or Evidence Source

`bash tests/metrics/run-k6-overhead.sh`

## Methodology

Both direct and edge runs use the same constant-arrival-rate scenario: 6 requests per minute for 3 minutes, with 1 pre-allocated VU and 2 maximum VUs. The direct phase presents the generated Kong client certificate because the backend is mTLS-only; the edge phase enters through HTTPS Kong. This should produce about 18 requests per run, intentionally runs below the observed Kong rate-limit threshold, and is not a stress test.

## Observed Result

| Scenario | Requests | p50 ms | p95 ms |
|---|---:|---:|---:|
| Direct backend baseline | 18 | 5.23 | 8.57 |
| Edge protected via Kong | 19 | 16.68 | 24.35 |
| Added latency | n/a | 11.45 | 15.78 |

## Scope And Limitation

Latency source: direct `users_me_latency_ms`, edge `users_me_latency_ms`. This compares the Kong-protected edge path with the direct backend path for one authenticated endpoint. It does not isolate mTLS overhead from other gateway, TLS, policy, network, or container-runtime effects.
