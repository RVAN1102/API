# mTLS And Webhook Security

## Requirement Proven

The scoped mTLS paths and webhook HMAC/timestamp/nonce controls reject missing,
wrong, stale, or replayed credentials on covered paths.

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
| Kong to User sidecar | HTTP `200` |
| Kong to Order sidecar | HTTP `200` |
| Kong to Billing sidecar | HTTP `200` |
| Kong to Admin sidecar | HTTP `200` |
| missing client certificate to backend sidecar | rejected |
| wrong client certificate to backend sidecar | rejected |
| Kong client certificate to backend sidecar | accepted |
| Billing to Order sidecar mTLS | HTTP `200` in S2S evidence |
| valid webhook | HTTP `200` |
| invalid webhook signature | HTTP `401` |
| old webhook timestamp | HTTP `403` |
| replayed webhook nonce | first send HTTP `200`, second send HTTP `403` |
| missing webhook headers | rejected |
| missing webhook client certificate | HTTP `401` |

## Scope And Limitation

mTLS coverage is limited to client-to-Kong TLS, Kong-to-backend sidecars,
Billing-to-Order ownership verification, and webhook client certificate
validation. Other internal traffic is not claimed as mTLS.

