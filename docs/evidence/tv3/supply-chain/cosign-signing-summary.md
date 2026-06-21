# Cosign Artifact Signing Summary (TV3 P0-03)

**Tool:** Cosign (sigstore)  
**Script:** `scripts/security/cosign-sign.sh`  
**Current CI mode:** keyless-readiness dry-run, no signature created

## Current Repository Evidence

The repository supports Cosign signing workflows without storing private keys or
production credentials. The default CI job builds service images, scans them,
emits image SBOM artifacts, installs Cosign, and runs:

```bash
bash scripts/security/cosign-sign.sh dry-run \
  ghcr.io/<owner>/<repo>/<service>-service:<sha>
```

Dry-run mode documents the expected keyless commands and verifies tool
availability when Cosign is present. It does not claim that a signature exists.

## Real Signing Path

Real production signing should use immutable image digests and GitHub Actions
OIDC:

```bash
export COSIGN_CERT_IDENTITY_REGEXP="https://github.com/<owner>/<repo>/.github/workflows/security-scan.yml@refs/heads/main"
cosign sign --yes <image-ref-by-digest>
cosign verify \
  --certificate-identity-regexp="${COSIGN_CERT_IDENTITY_REGEXP}" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  <image-ref-by-digest>
```

The expected trust model is keyless signing through Fulcio with transparency in
Rekor and verification pinned to the repository workflow identity and OIDC
issuer. Local lab signing remains available with `scripts/security/cosign-sign.sh
local <image>`, which uses a temporary key under `/tmp` and deletes the private
key after use.

## Evidence Files

| File | Contents |
|------|----------|
| `cosign-signing-summary.md` | This current summary |
| `.artifacts/test-runs/tv3/supply-chain/cosign-verify-output.txt` | Runtime dry-run or signing output when the script is executed |

Do not claim that images were signed unless `keyless` or `local` mode was run
against a real image and the corresponding verify output is preserved.
