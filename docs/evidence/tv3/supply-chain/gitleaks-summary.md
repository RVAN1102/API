# Supply Chain Security - Gitleaks Summary (TV3 P0-03)

**Date:** 2026-06-18  
**Tool:** Gitleaks v8.30.1  
**Command:** `bash ci/run-local-security-scan.sh`  
**Script:** `ci/run-local-security-scan.sh`

---

## Current Status

The previous "0 active secrets" claim has been superseded because the tracked
source still contained generated certificate artifacts and the older raw
Gitleaks report itself produced secret-like findings.

Post-purge evidence is generated at:

- `docs/evidence/tv3/supply-chain/gitleaks-report-after-secret-purge.json`
- `docs/evidence/tv3/supply-chain/gitleaks-secret-purge-summary.md`

The scan covers the current tracked/non-ignored source package, not historical
Git commits.

Historical leak remediation requires separate history scanning, secret
rotation, and, if required, history rewrite coordination.

---

## Verdict

The authoritative post-purge result is the new report and summary listed above.
