# Gateway-to-Backend mTLS Design And Default Runtime

The default Compose stack enforces Gateway-to-Backend mTLS for the four primary
backend services. Kong no longer routes directly to the raw HTTP backends; it
routes to Nginx mTLS sidecars that verify Kong's internal client certificate
before forwarding requests to the local service container path.

Canonical URL/security scope is maintained in
`docs/runbooks/url-and-security-scope.md`. This document covers the
gateway-to-backend sidecar scope only; it does not claim all internal traffic is
mTLS.

Default runtime command:

```bash
bash demo/mtls/ensure-gateway-backend-certs.sh
docker compose -f infra/docker-compose.yml up -d --build
bash tests/security/gateway-backend-mtls-tests.sh
```

## Runtime architecture

```text
Kong --HTTPS + Kong client cert--> Nginx mTLS sidecar --> HTTP loopback-style app path
```

For each backend service, the default runtime includes an Nginx sidecar:

- `user-mtls-proxy` fronts `user-service`
- `order-mtls-proxy` fronts `order-service`
- `billing-mtls-proxy` fronts `billing-service`
- `admin-mtls-proxy` fronts `admin-service`

Kong routes in `gateway/kong.yml` point upstreams at the HTTPS sidecars instead
of direct HTTP service URLs.

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

Evidence output is written to ignored transient artifacts by default:

```text
.artifacts/test-runs/gateway-backend-mtls-runtime-<timestamp>.txt
```

To intentionally refresh the official evidence file, run:

```bash
UPDATE_OFFICIAL_EVIDENCE=1 bash tests/security/gateway-backend-mtls-tests.sh
```

Official evidence file:

```text
docs/evidence/tv1/gateway-backend-mtls/gateway-backend-mtls-runtime.txt
```

## Production note

This is a lab/runtime demonstration, not a full service mesh. Production should
prefer a managed internal PKI or a service mesh such as Istio/Envoy with
short-lived certificate issuance, automatic rotation, workload identity
(SPIFFE/SPIRE-style identity), and revocation/renewal monitoring.
