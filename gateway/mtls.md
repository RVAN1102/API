# Gateway-to-Backend mTLS Design And Runtime Profile

The default Compose stack remains the stable final-regression baseline. It uses
HTTP backends plus short-lived Keycloak Client Credentials for backend S2S
authorization. To provide runtime evidence for the stricter Gateway-to-Backend
mTLS requirement without breaking the default path, the repo includes an
optional sidecar profile:

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml -f infra/docker-compose.mtls.yml up -d --build
bash tests/security/gateway-backend-mtls-tests.sh
```

## Runtime profile architecture

```text
Kong --HTTPS + Kong client cert--> Nginx mTLS sidecar --> HTTP loopback-style app path
```

For each backend service, the mTLS profile adds an Nginx sidecar:

- `user-mtls-proxy` fronts `user-service`
- `order-mtls-proxy` fronts `order-service`
- `billing-mtls-proxy` fronts `billing-service`
- `admin-mtls-proxy` fronts `admin-service`

Kong routes use `gateway/kong-mtls.yml`, which points upstreams at the HTTPS
sidecars instead of direct HTTP service URLs.

## Trust model

- `ca.crt` / `ca.key`: local internal demo CA generated on demand.
- `kong-client.crt` / `kong-client.key`: client identity presented by Kong
  when it connects to backend sidecars.
- `<service>-mtls-proxy.crt` / `<service>-mtls-proxy.key`: server identity
  presented by each backend sidecar.
- Kong verifies backend sidecar server certificates using the internal CA.
- Each sidecar verifies Kong's client certificate and rejects clients without a
  valid certificate issued by the internal CA.

Generated files are written under `infra/certs/gateway-backend/`, which is
ignored by Git. Do not commit private keys or generated certificate material.

## Evidence

Runtime evidence is produced by:

```bash
bash tests/security/gateway-backend-mtls-tests.sh
```

The test verifies:

1. Kong routes to User/Order/Billing/Admin health endpoints return HTTP 200 via
   the mTLS sidecars.
2. Direct TLS probes without a client certificate are rejected.
3. A self-signed rogue client certificate is rejected.
4. Kong's valid client certificate is accepted by the sidecars.

Evidence output is written to:

```text
docs/evidence/tv1/gateway-backend-mtls/gateway-backend-mtls-runtime.txt
```

## Production note

This is a lab/runtime demonstration, not a full service mesh. Production should
prefer a managed internal PKI or a service mesh such as Istio/Envoy with
short-lived certificate issuance, automatic rotation, workload identity
(SPIFFE/SPIRE-style identity), and revocation/renewal monitoring.
