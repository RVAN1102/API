# RESTler Observed Operation Coverage

RESTler rendered all 16 OpenAPI operations and network logs show requests reaching all 16 operation paths through the protected HTTPS Kong edge.

## Coverage Interpretation

| Metric | Value |
|---|---:|
| OpenAPI operations | 16 |
| RESTler rendered requests | 16/16 |
| Network-observed operation reachability | 16/16 |
| RESTler-native valid-status coverage | 8/16 |
| Parsed HTTP responses | 290 |
| 5xx/crash indicators | 0 |
| RESTler bug buckets | 0 |

The `8/16` value is RESTler-native valid-status coverage under the user-token fuzzing scope. It is not endpoint reachability. The network logs show that all 16 OpenAPI operations were exercised. Several operations intentionally returned fail-closed security responses such as `401`, `403`, `422`, and `429` because they require mTLS webhook credentials, service-client credentials, admin authorization, valid schema input, or rate-limit compliance.

Full successful business-flow coverage is not claimed. The evidence demonstrates authenticated fuzzing reachability, security fail-closed behavior, no observed 5xx/crash behavior, and no RESTler bug bucket.
