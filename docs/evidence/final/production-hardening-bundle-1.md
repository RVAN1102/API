# Production-Oriented Hardening Bundle 1

This note records prototype hardening evidence for the `fix/production-hardening-bundle-1`
branch. It does not claim full production readiness.

## Container Runtime Hardening

`infra/docker-compose.yml` applies `no-new-privileges`, `cap_drop: [ALL]`,
`read_only: true`, and `tmpfs: [/tmp]` to these low-state runtime containers:

- `user-service`
- `order-service`
- `billing-service`
- `admin-service`
- `webhook-demo`
- `opa`
- `otel-collector`

The Gateway-to-Backend mTLS Nginx sidecars use `no-new-privileges`, but are
intentionally not `cap_drop: [ALL]` or read-only because the official Nginx
entrypoint renders config and performs startup filesystem ownership changes
before serving TLS traffic.

Stateful or runtime-writable services are intentionally not read-only:
`kong`, `keycloak`, `vault`, `redis`, `loki`, `grafana`, `promtail`,
`alertmanager`, and `jaeger`.

Validation command:

```bash
bash tests/security/container-runtime-hardening-tests.sh
```

## Excessive Data Exposure Contract Tests

`tests/security/openapi-contract-tests.sh` obtains the existing `ci-alice`
automation token and checks selected Kong-routed API responses:

- `GET /api/v1/users/me`
- `GET /api/v1/orders/ord-alice-1001`

The test verifies exact expected response keys and recursively rejects
sensitive-looking token, secret, debug, config, private-key, and internal-owner
map fields.

Validation command:

```bash
bash tests/security/openapi-contract-tests.sh
```

## Image SBOM And Cosign CI Path

`.github/workflows/security-scan.yml` now includes an image supply-chain job
that builds each Python service image, scans it with Trivy, emits CycloneDX
image SBOM artifacts, installs Cosign, and runs a keyless-signing readiness
dry-run. It does not require production signing secrets in the repository.

Local scripts:

```bash
SBOM_IMAGES="topic10-user-service:local" bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-placeholder
```
