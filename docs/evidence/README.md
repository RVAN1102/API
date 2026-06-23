# Evidence

This directory contains curated evidence summaries only. Each result file states
the requirement, source command or evidence source, observed result, and scope.
Raw logs, generated secrets, token values, private keys, and bulky tool outputs
are not included.

| Requirement | Result file |
|---|---|
| Compose and documentation consistency | `results/compose-and-repo-consistency.md` |
| Edge security | `results/edge-security.md` |
| Identity, authorization, and S2S | `results/identity-authorization-s2s.md` |
| mTLS and webhook security | `results/mtls-and-webhook-security.md` |
| SSRF and egress control | `results/ssrf-egress-control.md` |
| Testing and fuzzing | `results/testing-and-fuzzing.md` |
| ZAP active scan | `results/zap-active-scan.md` |
| CI and supply chain | `results/ci-supply-chain.md` |
| Performance and SecOps | `results/performance-and-secops.md` |

All public API evidence targets `https://localhost:8443`. Final runtime
evidence describes direct HTTPS/mTLS to backend port `8443`, HTTPS Keycloak,
HTTPS OPA, HTTPS Vault, and constrained Docker networks.
