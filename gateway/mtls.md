# Gateway-to-Backend HTTPS/mTLS

The final runtime does not use an HTTP sidecar hop. Kong connects directly to
backend services over HTTPS and presents the internal `kong-client` certificate.
Each backend service listens on port `8443`, presents its own server certificate,
and requires a client certificate signed by the internal demo CA.

Runtime identities:

- `kong-client.crt` / `kong-client.key`: Kong client identity.
- `billing-client.crt` / `billing-client.key`: Billing service client identity for Billing-to-Order calls.
- `user-service.crt` / `user-service.key`: User service server identity.
- `order-service.crt` / `order-service.key`: Order service server identity.
- `billing-service.crt` / `billing-service.key`: Billing service server identity.
- `admin-service.crt` / `admin-service.key`: Admin service server identity.
- `keycloak.crt` / `keycloak.key`: HTTPS identity for Keycloak.
- `opa.crt` / `opa.key`: HTTPS identity for OPA.
- `vault.crt` / `vault.key`: HTTPS identity for Vault.

Generate the ignored local certificate material with:

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
```

The generated files are lab-only runtime artifacts under
`infra/certs/gateway-backend/` and must not be committed.
