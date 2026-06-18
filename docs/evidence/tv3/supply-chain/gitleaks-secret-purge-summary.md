# Gitleaks Secret Purge Summary

**Date:** 2026-06-18

## Scope

This evidence covers the current tracked/non-ignored source package produced
from the working tree. It does not claim that historical Git commits are clean.

## Controls

- `infra/.env` is ignored and replaced by `infra/.env.example`.
- Generated mTLS private keys and PKCS#12 bundles under `infra/certs/` are ignored.
- `infra/certs/` keeps only safe tracked documentation and `.gitkeep`.
- Local demo webhook mTLS material is generated on demand by `demo/mtls/generate-mtls-certs.sh`.
- Gitleaks is run without `|| true` for the post-purge secret claim.

## Evidence

- Raw redacted report: `docs/evidence/tv3/supply-chain/gitleaks-report-after-secret-purge.json`
- Tracked-file verifier: `tests/security/verify-no-tracked-secrets.sh`

## Result

The current working tree/HEAD source package is clean for this post-purge
scope. The raw Gitleaks report is an empty JSON array:

```text
[]
```

The following commands completed successfully on 2026-06-18:

```bash
bash tests/security/verify-no-tracked-secrets.sh
bash ci/run-local-security-scan.sh
```

This proves the current tracked/non-ignored source package no longer contains
the purged local `.env`, generated private keys, PKCS#12 bundles, private key
blocks, obvious JWT values, or Gitleaks-detected secrets.

Historical leaks, if found by a separate `gitleaks git`/history scan, require
secret rotation and a separate history-remediation decision.
