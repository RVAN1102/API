# RESTler Execution Summary

**Date:** 2026-06-22T13:56:48Z  
**RESTler:** Docker image `mcr.microsoft.com/restlerfuzzer/restler:v8.5.0`  
**Target URL:** `https://localhost:8443`  
**Docker network:** `host`  
**TLS trust:** Kong self-signed certificate mounted with `RESTLER_CA_CERT_FILE=/tmp/kong-leaf.pem`  
**Auth/token handling:** external RESTler token refresh command; tokens are omitted from logs.

## Results

| Metric | Value |
|---|---:|
| Compile succeeded | yes |
| Test succeeded | yes |
| Fuzz-lean completed normally | interrupted after HTTP evidence collection |
| Request coverage | Request coverage (successful / total): 8 / 16 |
| HTTP status-code observations parsed | 289 |
| 5xx/crash indicator count | 0 |
| Bug result | No bugs were found. |
| Evidence validity | valid |

## Status-Code Distribution

- 200: 14
- 202: 2
- 401: 51
- 403: 77
- 404: 6
- 422: 60
- 429: 79

## Notes

RESTler sent authenticated HTTPS requests through Kong and received real HTTP responses from the API gateway/backend path. The run was manually interrupted after HTTP evidence was collected because Kong rate limiting produced repeated `429 Too Many Requests` retry behavior. This is treated as evidence that fuzz traffic reached the protected edge, not as a service crash.


## Coverage Clarification

RESTler rendered all 16 OpenAPI operations and the network logs show requests reaching all 16 operation paths through the protected HTTPS Kong edge.

The `8/16` value is RESTler-native valid-status coverage under the user-token fuzzing scope. It is not endpoint reachability. Several operations intentionally returned fail-closed security responses such as `401`, `403`, `422`, and `429` because they require mTLS webhook credentials, service-client credentials, admin authorization, valid schema input, or rate-limit compliance.

Therefore, full successful business-flow coverage is not claimed. This evidence demonstrates authenticated fuzzing reachability, security fail-closed behavior, no observed 5xx/crash behavior, and no RESTler bug bucket.
