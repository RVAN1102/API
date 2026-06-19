# Gateway-to-Backend mTLS Runtime Profile

This evidence directory is for the optional `infra/docker-compose.mtls.yml`
profile. The default Compose stack remains stable for the existing final
regression; the mTLS profile demonstrates runtime Gateway-to-Backend mutual TLS
without rewriting backend application code.

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
docker compose -f infra/docker-compose.yml -f infra/docker-compose.mtls.yml up -d --build
bash tests/security/gateway-backend-mtls-tests.sh
```

Generated certificate material is written under `infra/certs/gateway-backend/`
and is ignored by Git. Do not commit generated private keys or long-lived
certificates.
