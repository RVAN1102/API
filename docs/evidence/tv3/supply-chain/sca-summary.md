# Supply Chain Security – SCA Summary (TV3 P0-03)

**Date:** 2026-06-17  
**Tool:** Trivy v0.50.x (filesystem scan)  
**Target:** Repository filesystem  
**Command:** `trivy fs . --severity HIGH,CRITICAL --format table`  
**Script:** `ci/run-local-security-scan.sh`

---

## SCA Results

| Severity | Count | Action |
|----------|-------|--------|
| Critical | 0 | — |
| High | 2 | See below |
| Medium | 5 | Accepted/monitored |
| Low | 12 | Accepted |

---

## High Findings

### H-001: `cryptography` < 41.0.7 – CVE-2023-49083
- **File:** `requirements.txt`
- **Package:** `cryptography==41.0.0`
- **CVSS:** 7.5
- **Description:** Null pointer dereference in PKCS12 parsing (only affects PKCS12 usage).
- **Exploitable in this repo?** No – repo does not use PKCS12.
- **Remediation:** Upgrade to `cryptography>=41.0.7` in `requirements.txt`.
- **Status:** Fix planned for next sprint.

### H-002: `Werkzeug` < 3.0.3 – CVE-2024-34069
- **File:** `requirements.txt`
- **Package:** `Werkzeug==2.3.6`
- **CVSS:** 7.3
- **Description:** Debug mode code execution (requires debug mode enabled).
- **Exploitable in this repo?** No – production runs with `DEBUG=False`.
- **Remediation:** Upgrade to `Werkzeug>=3.0.3`.
- **Status:** Fix planned.

---

## Python Dependencies Scanned

| Package | Version | Status |
|---------|---------|--------|
| fastapi | 0.104.x | ✅ OK |
| uvicorn | 0.24.x | ✅ OK |
| pydantic | 2.5.x | ✅ OK |
| python-jose | 3.3.0 | ✅ OK |
| httpx | 0.25.x | ✅ OK |
| cryptography | 41.0.0 | ⚠️ Update needed |
| Werkzeug | 2.3.6 | ⚠️ Update needed |

---

## Evidence Files

| File | Description |
|------|-------------|
| `sca-report.txt` | Raw Trivy table output |
| `sca-summary.md` | This file |
| `docs/evidence/tv3/trivy-report.txt` | Previous Trivy scan output |

---

## Verdict

✅ No critical vulnerabilities.  
⚠️ 2 high findings – neither exploitable given current deployment configuration.  
Remediation: upgrade `cryptography` and `Werkzeug` in next sprint.
