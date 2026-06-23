# mTLS And Webhook Security

## Requirement Proven

The direct HTTPS/mTLS paths and webhook HMAC/timestamp/nonce controls reject
missing, wrong, stale, or replayed credentials on covered paths.

## Command Or Evidence Source

```bash
bash tests/security/gateway-backend-mtls-tests.sh
bash tests/security/s2s-ownership-tests.sh
bash tests/security/webhook-tests.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

## Observed Result

| Check | Observed result |
|---|---|
| Kong to User direct HTTPS/mTLS | HTTP `200` |
| Kong to Order direct HTTPS/mTLS | HTTP `200` |
| Kong to Billing direct HTTPS/mTLS | HTTP `200` |
| Kong to Admin direct HTTPS/mTLS | HTTP `200` |
| missing client certificate to backend | rejected |
| wrong client certificate to backend | rejected |
| Kong client certificate to backend | accepted |
| Billing to Order direct HTTPS/mTLS | HTTP `200` in S2S evidence |
| valid webhook | HTTP `200` |
| invalid webhook signature | HTTP `401` |
| old webhook timestamp | HTTP `403` |
| replayed webhook nonce | first send HTTP `200`, second send HTTP `403` |
| missing webhook headers | rejected |
| missing webhook client certificate | HTTP `401` |
| webhook suite summary | `7/7` passed |

## Scope And Limitation

mTLS coverage is limited to client-to-Kong HTTPS, Kong-to-backend direct
HTTPS/mTLS, Billing-to-Order ownership verification, and webhook client
certificate validation. Other internal traffic is not claimed beyond its
documented HTTPS endpoints.
