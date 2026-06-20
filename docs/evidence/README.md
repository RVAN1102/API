# Evidence Directory

Tracked files in this directory are the official report evidence. New local test runs should write transient output to `.artifacts/test-runs/` unless a maintainer intentionally refreshes official evidence.

Start with `docs/evidence/final/AUTHORITATIVE_EVIDENCE_INDEX.md` for the current review set. The index summarizes the evidence for known P0 findings addressed and validated by regression.

Historical evidence that captured the old plaintext public gateway has been
archived under `docs/evidence/archive/pre-8443-http8000/`. Those files are kept
for audit history and are not current HTTPS evidence.

Topic 10 quantitative evidence is summarized in:

- `docs/evidence/tv3/secops-metrics/secops-mttd-mttr-summary.md`
- `docs/evidence/tv3/secops-metrics/latency-cost-tradeoff-summary.md`

Lab secret bootstrap and Vault/KMS alignment are summarized in:

- `docs/evidence/tv2/vault-lab-secret-bootstrap.md`
