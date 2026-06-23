# Identity, Authorization, And S2S

## Requirement Proven

User roles, service-client roles, ownership checks, and least-privilege
service-to-service access are enforced on covered paths.

## Command Or Evidence Source

```bash
bash tests/security/s2s-ownership-tests.sh
bash tests/security/opa-authz-tests.sh
```

Configuration sources:

- `idp/realm-export/topic10-realm.json`
- `services/openapi.yaml`
- service implementations under `services/`

## Observed Result

| Check | Observed result |
|---|---|
| Billing uses `https://order-service:8443` and client certificate material | pass |
| Billing cannot use plaintext Order application port directly | pass |
| Billing reaches Order over verified HTTPS/mTLS | HTTP `200` |
| Alice checkout for Alice order | HTTP `202` |
| Alice checkout for Bob order | HTTP `403` |
| wrong amount checkout | HTTP `409` |
| unknown order checkout | fail closed with HTTP `403` |
| service token calling human checkout | HTTP `403` |
| Billing service client on Order ownership endpoint | HTTP `200` |
| Admin service client on Order ownership endpoint | HTTP `403` |
| Admin service client on Admin maintenance endpoint | HTTP `200` |
| Billing service client on Admin maintenance endpoint | HTTP `403` |
| S2S suite summary | `25/25` passed |
| OPA authorization suite summary | `22/22` passed |

## Scope And Limitation

The result covers the local realm, service clients, and API paths exercised by
the S2S and OPA suites. It does not claim behavior for untested paths.
