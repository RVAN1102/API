# Documentation

This directory contains the final technical documentation set. It is organized
by requirement and evidence, not by team, task history, or delivery chronology.

| Path | Purpose |
|---|---|
| `technical/01-architecture.md` | service layout, gateway, networks, and trust boundaries |
| `technical/02-edge-security.md` | TLS, CORS, headers, rate limiting, request size, and gateway filter |
| `technical/03-identity-authorization.md` | Keycloak, PKCE, MFA required action, RBAC, service clients, ownership checks |
| `technical/04-mtls-and-webhook-security.md` | scoped mTLS paths and webhook HMAC/nonce controls |
| `technical/05-ssrf-egress-control.md` | SSRF endpoint behavior and network egress controls |
| `technical/06-secrets-and-observability.md` | local secret handling, Vault scope, logs, correlation IDs, dashboards |
| `technical/07-testing-and-fuzzing.md` | regression, negative testing, deterministic malformed-input testing, ZAP |
| `technical/08-ci-supply-chain.md` | secret scan, SAST/SCA, SBOM, Cosign readiness |
| `technical/09-performance-and-secops.md` | k6 baseline and SecOps measurement status |
| `evidence/README.md` | curated evidence index |

The public application API endpoint throughout the docs is
`https://localhost:8443`.

