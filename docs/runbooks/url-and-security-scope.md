# URL And Security Scope

This document is the canonical URL and security-scope reference for the Topic 10
SME Cloud API security lab. Use it when writing demo scripts, evidence summaries,
and report text.

## Public Application API

| Purpose | URL | Scope |
|---|---|---|
| Public API through Kong | `https://localhost:8443` | Only public application API endpoint for local lab users, tests, and demos |

The public API uses the local Kong TLS listener. The lab certificate is
self-signed, so local curl/k6 commands may use insecure local trust options such
as `curl -k` or k6 `insecureSkipTLSVerify`. Production must use a CA-trusted
certificate and normal certificate validation.

The legacy plaintext gateway URL `http://localhost:8000` is not the public API
and should not be used in current instructions.

## Lab-Local Control Plane And Observability

These HTTP endpoints are local lab control-plane or observability surfaces. They
are not public application API endpoints.

| Component | URL | Scope |
|---|---|---|
| Kong Admin API | `http://127.0.0.1:8001` | Lab-local gateway administration, loopback-bound |
| Keycloak | `http://localhost:8080` | Lab-local identity provider/admin and OIDC issuer |
| Vault | `http://localhost:8200` | Lab-local dev-mode secret-management workflow evidence |
| Grafana | `http://localhost:3001` | Lab-local dashboards and alerting UI |

Redis is internal-only in Docker Compose. It is used for webhook replay nonce TTL
storage and is not documented as a host-accessible endpoint.

## mTLS Scope

The project makes scoped mTLS claims only. The implemented
and evidenced mTLS/TLS scope is:

1. Client to Kong uses TLS 1.3 on `https://localhost:8443`.
2. Kong to backend services uses gateway-backend mTLS sidecars.
3. Billing to Order ownership verification uses verified mTLS through
   `https://order-mtls-proxy:8443`.
4. Webhook secure channel uses HMAC timestamp/nonce validation and mTLS client
   certificate validation.

Backend application containers may still receive traffic from their local Nginx
sidecar over the Docker-internal service path after the sidecar completes mTLS
verification. This lab runtime is sidecar-based, not a full service mesh.

## Secret-Management Scope

`infra/.env` is an ignored local Docker Compose bootstrap file. It must not be
committed and must not be copied into evidence.

Vault OSS runs in local dev mode to demonstrate centralized secret-management
workflows and rotation evidence. The lab does not claim that every runtime secret
is fetched from Vault. Production should use Vault HA, cloud KMS, Secrets
Manager, or an equivalent managed secret store with auditable access, rotation,
and backup policy.

Never commit or print JWTs, refresh tokens, client secrets, `WEBHOOK_SECRET`
values, private keys, `.p12` bundles, `infra/certs`, `.env`, generated tokens,
or generated secret material.

## Supply-Chain Scope

Local evidence includes SAST/SCA/secret scanning, SBOM generation, image scan
support, and Cosign readiness/dry-run paths.

Cosign dry-run/evidence mode does not create a signature. Only claim that an
artifact or image was signed when keyless CI signing or local lab signing was
actually run against a real image and the corresponding verification output is
preserved. Production signing should use immutable image digests and GitHub
Actions OIDC identity pinned during verification.

