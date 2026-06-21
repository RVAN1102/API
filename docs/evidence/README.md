# Evidence Directory

Tracked files in this directory are the official report evidence. New local test runs should write transient output to `.artifacts/test-runs/` unless a maintainer intentionally refreshes official evidence.

Start with `docs/evidence/final/AUTHORITATIVE_EVIDENCE_INDEX.md` for the current review set. The index summarizes the evidence for known P0 findings addressed and validated by regression.

Canonical URL/security scope is defined in
`docs/runbooks/url-and-security-scope.md`. The public application API endpoint
is `https://localhost:8443`; HTTP Kong Admin, Keycloak, Vault, and Grafana URLs
are lab-local control-plane or observability endpoints.

Historical evidence that captured superseded gateway behavior is kept under
`docs/evidence/archive/` for audit history only and is not current HTTPS
evidence.

Topic 10 quantitative evidence is summarized in:

- `docs/evidence/tv3/secops-metrics/secops-mttd-mttr-summary.md`
- `docs/evidence/tv3/secops-metrics/latency-cost-tradeoff-summary.md`
- `docs/evidence/tv3/secops-metrics/phase3/mttd-mttr-phase3-summary.md`
- `docs/evidence/tv3/performance/README.md`
- `docs/evidence/tv3/fuzzing/phase3-openapi-fuzzing-summary.md`

Lab secret bootstrap and Vault/KMS alignment are summarized in:

- `docs/evidence/tv2/vault-lab-secret-bootstrap.md`
