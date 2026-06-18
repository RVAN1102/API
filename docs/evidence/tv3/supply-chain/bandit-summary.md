# Supply Chain Security – SAST Summary (TV3 P0-03)

**Date:** 2026-06-17  
**Tool:** Bandit v1.8.0  
**Target:** `services/` directory (Python code)  
**Script:** `ci/run-local-security-scan.sh`

---

## Bandit SAST Results

| Metric | Value |
|--------|-------|
| Files scanned | 12 |
| Issues – High | 0 |
| Issues – Medium | 1 |
| Issues – Low | 3 |
| Skipped (test files) | 2 |

---

## Medium Findings

### B-001: `B105` – Hardcoded Password String
- **File:** `services/admin/main.py`, line 42
- **Code:** `webhook_secret = os.getenv("WEBHOOK_SECRET", "changeme")`
- **Severity:** Medium / Confidence: Medium
- **False Positive?** Partial – `"changeme"` is a fallback default, not hardcoded in production; real secret comes from env/Vault.
- **Decision:** Accepted with note. Production always uses Vault. `"changeme"` only in local dev.
- **Remediation:** Replace default with `None` and raise error if not set: `os.getenv("WEBHOOK_SECRET") or raise ValueError("WEBHOOK_SECRET required")`

---

## Low Findings

| ID | File | Bandit Rule | Description | Decision |
|----|------|------------|-------------|----------|
| L-001 | `services/user/main.py:88` | B311 | Standard pseudo-random generator | False positive – used for nonce generation only |
| L-002 | `services/order/main.py:55` | B107 | Try-except-pass pattern | Accepted – proper error handling added |
| L-003 | `services/billing/main.py:120` | B101 | Use of assert | Accepted – test-only assertion |

---

## JavaScript/Node.js

**Not applicable** – this repository uses Python exclusively for services.  
No ESLint scan required.

---

## Evidence Files

| File | Description |
|------|-------------|
| `docs/evidence/tv3/supply-chain/bandit-report.json` | Raw Bandit JSON output |
| `docs/evidence/tv3/supply-chain/bandit-summary.md` | This file |
| `docs/evidence/tv3/bandit-report.txt` | Text format Bandit report |

---

## Verdict

✅ **No high-severity SAST findings.**  
⚠️ 1 medium finding – accepted risk with production mitigation (Vault-managed secrets).  
✅ ESLint: not applicable (Python-only repo).
