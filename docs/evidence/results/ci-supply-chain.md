# CI And Supply Chain

## Requirement Proven

The repository has current source-package checks for secret hygiene, SAST/SCA,
SBOM generation, and Cosign readiness without claiming an unsigned artifact is
signed.

## Command Or Evidence Source

```bash
bash tests/security/verify-no-tracked-secrets.sh
bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-example
```

Recorded local scan source: curated summary in this file; rerun the listed commands for fresh local evidence
package evidence.

## Observed Result

| Area | Observed result |
|---|---|
| Bandit | no High severity issue recorded |
| Gitleaks | empty JSON array recorded |
| Trivy filesystem | `0` vulnerabilities across listed Python requirements targets |
| SBOM | CycloneDX and SPDX repository filesystem SBOMs recorded |
| SBOM component count | 28 Python packages and 4 Docker base images recorded |
| Cosign | readiness dry-run only |

## Scope And Limitation

The result covers the tracked/non-ignored source package. Historical Git history
cleanliness and production artifact signing are not claimed.

