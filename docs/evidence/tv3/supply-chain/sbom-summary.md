# SBOM Summary (TV3 P0-03)

**Date:** 2026-06-17  
**Tool:** Trivy v0.50.x  
**Script:** `scripts/security/generate-sbom.sh`  
**Formats:** CycloneDX 1.4, SPDX 2.3

---

## SBOM Coverage

| Artifact | Format | File |
|---------|--------|------|
| Repository filesystem | CycloneDX 1.4 | `sbom-cyclonedx.json` |
| Repository filesystem | SPDX 2.3 | `sbom-spdx.json` |

---

## Component Summary

| Language | Package Manager | Components |
|----------|----------------|-----------|
| Python | pip / requirements.txt | 28 |
| N/A | Docker base images | 4 |

---

## Top Python Dependencies

| Package | Version | License |
|---------|---------|---------|
| fastapi | 0.104.1 | MIT |
| uvicorn | 0.24.0 | BSD |
| pydantic | 2.5.2 | MIT |
| python-jose | 3.3.0 | MIT |
| httpx | 0.25.2 | BSD |
| cryptography | 41.0.0 | Apache-2.0 |
| requests | 2.31.0 | Apache-2.0 |
| Werkzeug | 2.3.6 | BSD |
| prometheus-client | 0.19.0 | Apache-2.0 |
| opentelemetry-sdk | 1.21.0 | Apache-2.0 |

---

## Regeneration Commands

```bash
# CycloneDX SBOM
trivy fs --format cyclonedx --output docs/evidence/tv3/supply-chain/sbom-cyclonedx.json .

# SPDX SBOM
trivy fs --format spdx-json --output docs/evidence/tv3/supply-chain/sbom-spdx.json .

# Or use script:
bash scripts/security/generate-sbom.sh
```

---

## Verdict

✅ SBOM generated for all services.  
✅ CycloneDX format for toolchain integration.  
✅ SPDX format for compliance reporting.  
✅ No license violations detected.
