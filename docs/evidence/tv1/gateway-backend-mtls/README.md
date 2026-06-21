# Gateway-to-Backend mTLS Default Runtime

This evidence directory is for the default `infra/docker-compose.yml` runtime.
Kong now calls User, Order, Billing, and Admin through Nginx sidecars that
enforce Gateway-to-Backend mutual TLS without rewriting backend application
code. Billing-to-Order ownership verification uses
`https://order-mtls-proxy:8443` with lab CA verification and a Billing client
certificate by default.

## Security model

- Kong acts as the TLS client when calling backend services.
- Each backend service is fronted by an Nginx sidecar that acts as the TLS
  server and requires a client certificate signed by the internal demo CA.
- Kong presents `kong-client.crt` and verifies each backend sidecar certificate
  against `ca.crt`.
- Calls without a client certificate or with a self-signed rogue certificate are
  rejected during TLS handshake.

## Reproduce

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
bash tests/security/gateway-backend-mtls-tests.sh
```

Generated certificate material is written under `infra/certs/gateway-backend/`
and is ignored by Git. Do not commit generated private keys or long-lived
certificates.
