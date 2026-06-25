# CI And Supply Chain

## Requirement Proven

The repository uses Gitleaks for secret scanning, Bandit for Python SAST, and
Trivy for filesystem/container SCA and SBOM generation. No Snyk result is
claimed. Cosign readiness is preserved without claiming an unsigned image is
signed.

## Command Or Evidence Source

```bash
bash tests/security/verify-no-tracked-secrets.sh
bash scripts/security/generate-sbom.sh
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-example
# Optional after SBOM generation, when cosign is installed:
bash scripts/security/cosign-sign.sh sign-blob docs/evidence/tv3/supply-chain/sbom-cyclonedx.json
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
| SBOM component count | current filesystem CycloneDX run records 25 Python components; image SBOM generation was not requested in this run |
| Cosign image signing | readiness dry-run only |
| Cosign local artifact signing | optional `sign-blob` mode signs and verifies a local SBOM; no successful blob-signing result is claimed unless its ignored verification output exists |

## Scope And Limitation

The result covers the tracked/non-ignored source package. Historical Git history
cleanliness and production image signing are not claimed. The optional blob
demo uses generated material only under ignored `.artifacts` and deletes its
private key after verification. Cosign was not installed in the validated local
environment, so only dry-run readiness evidence was produced.
