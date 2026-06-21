#!/usr/bin/env bash
# scripts/security/cosign-sign.sh
#
# Artifact / Container Image Signing with Cosign
#
# Signs container images using Cosign keyless signing (Fulcio/Rekor) or
# local demo key for lab environments.
#
# Usage (keyless – requires OIDC token, e.g., GitHub Actions):
#   bash scripts/security/cosign-sign.sh keyless <image>
#
# Usage (local key – lab demo):
#   bash scripts/security/cosign-sign.sh local <image>
#
# Usage (generate evidence only):
#   bash scripts/security/cosign-sign.sh evidence
#
# Usage (CI dry-run/readiness, no signing):
#   bash scripts/security/cosign-sign.sh dry-run <image>
#
# SECURITY NOTE:
#   - Private key is NEVER committed to repo.
#   - Only verify output is stored in evidence.
#   - Local key is for lab demo only.
#
# Output:
#   ${REPORT_DIR}/cosign-signing-summary.md
#   ${REPORT_DIR}/cosign-verify-output.txt

set -uo pipefail

MODE="${1:-evidence}"
IMAGE="${2:-}"
REPORT_DIR="${REPORT_DIR:-.artifacts/test-runs/tv3/supply-chain}"
KEY_DIR="${TMPDIR:-/tmp}/cosign-lab-keys"

mkdir -p "${REPORT_DIR}"
mkdir -p "${KEY_DIR}"

echo "=== Cosign Artifact Signing ==="
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Mode: ${MODE}"
echo ""

case "${MODE}" in
  # --------------------------------------------------
  # Keyless signing (production / GitHub Actions)
  # --------------------------------------------------
  keyless)
    if [ -z "${IMAGE}" ]; then
      echo "[ERROR] Image required: bash cosign-sign.sh keyless <image>"
      exit 1
    fi
    if [ -z "${COSIGN_CERT_IDENTITY_REGEXP:-}" ]; then
      echo "[ERROR] Set COSIGN_CERT_IDENTITY_REGEXP to the expected GitHub workflow identity before keyless verification."
      exit 1
    fi
    if ! command -v cosign > /dev/null 2>&1; then
      echo "[ERROR] cosign not installed. Install: https://docs.sigstore.dev/cosign/installation/"
      exit 1
    fi
    echo "--- Signing ${IMAGE} (keyless) ---"
    cosign sign --yes "${IMAGE}" 2>&1 | tee "${REPORT_DIR}/cosign-verify-output.txt"
    echo ""
    echo "--- Verifying signature ---"
    cosign verify \
      --certificate-identity-regexp="${COSIGN_CERT_IDENTITY_REGEXP}" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
      "${IMAGE}" 2>&1 | tee -a "${REPORT_DIR}/cosign-verify-output.txt"
    ;;

  # --------------------------------------------------
  # Local key signing (lab demo)
  # --------------------------------------------------
  local)
    if [ -z "${IMAGE}" ]; then
      echo "[ERROR] Image required: bash cosign-sign.sh local <image>"
      exit 1
    fi
    if ! command -v cosign > /dev/null 2>&1; then
      echo "[ERROR] cosign not installed."
      exit 1
    fi

    KEY_FILE="${KEY_DIR}/cosign-lab.key"
    PUB_FILE="${KEY_DIR}/cosign-lab.pub"

    echo "--- Generating local demo key (not committed to repo) ---"
    if [ ! -f "${KEY_FILE}" ]; then
      COSIGN_PASSWORD="" cosign generate-key-pair \
        --output-key-prefix "${KEY_DIR}/cosign-lab" 2>/dev/null
    fi

    echo "--- Signing ${IMAGE} with local key ---"
    COSIGN_PASSWORD="" cosign sign \
      --key "${KEY_FILE}" \
      "${IMAGE}" 2>&1 | tee "${REPORT_DIR}/cosign-verify-output.txt"

    echo ""
    echo "--- Verifying signature ---"
    COSIGN_PASSWORD="" cosign verify \
      --key "${PUB_FILE}" \
      "${IMAGE}" 2>&1 | tee -a "${REPORT_DIR}/cosign-verify-output.txt"

    # Cleanup private key immediately
    rm -f "${KEY_FILE}"
    echo "[SECURITY] Private key deleted after use."
    ;;

  # --------------------------------------------------
  # Dry-run / CI readiness check
  # --------------------------------------------------
  dry-run)
    if [ -z "${IMAGE}" ]; then
      IMAGE="ghcr.io/example/topic10-api:sha-placeholder"
    fi
    echo "--- Cosign dry-run for ${IMAGE} ---"
    if command -v cosign > /dev/null 2>&1; then
      cosign version 2>&1 | tee "${REPORT_DIR}/cosign-verify-output.txt"
    else
      echo "[WARN] cosign not installed; dry-run documents the expected CI command." \
        | tee "${REPORT_DIR}/cosign-verify-output.txt"
    fi
    {
      echo ""
      echo "Expected keyless signing command for a published CI image:"
      echo "  cosign sign --yes ${IMAGE}"
      echo ""
      echo "Expected keyless verification command:"
      echo "  cosign verify --certificate-identity-regexp=<expected-github-workflow-identity> --certificate-oidc-issuer=https://token.actions.githubusercontent.com ${IMAGE}"
      echo ""
      echo "No signature, key, or credential is generated in dry-run mode."
    } | tee -a "${REPORT_DIR}/cosign-verify-output.txt"
    ;;

  # --------------------------------------------------
  # Generate readiness evidence (no Docker image needed, no signing claim)
  # --------------------------------------------------
  evidence)
    echo "--- Generating Cosign readiness evidence (no image signed) ---"
    cat > "${REPORT_DIR}/cosign-verify-output.txt" <<'TXT'
=== Cosign Readiness Evidence ===
Mode: evidence

No image is signed in evidence mode.
Use this mode to document the expected CI/keyless commands without creating
keys, credentials, signatures, or transparency-log entries.

Expected keyless signing command for a published digest image:
  cosign sign --yes <image-ref-by-digest>

Expected keyless verification command:
  cosign verify --certificate-identity-regexp=<github-workflow-identity> --certificate-oidc-issuer=https://token.actions.githubusercontent.com <image-ref-by-digest>
TXT
    echo "[OK] Readiness evidence created; no image was signed."
    ;;
esac

# --------------------------------------------------
# Write signing summary
# --------------------------------------------------
cat > "${REPORT_DIR}/cosign-signing-summary.md" <<MD
# Cosign Artifact Signing Summary

**Date:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')  
**Tool:** Cosign (sigstore)  
**Mode:** ${MODE}  
**Script:** \`scripts/security/cosign-sign.sh\`

## Signing Status

| Mode | What Happens |
|------|--------------|
| \`keyless <image>\` | Runs real Cosign keyless sign and verify against a published image reference. Intended for CI with GitHub OIDC identity. |
| \`local <image>\` | Runs a local lab signing demo with a temporary key under \`/tmp\`, then deletes the private key. |
| \`dry-run <image>\` | Checks/document expected commands only; no image is signed. |
| \`evidence\` | Writes readiness evidence only; no image is signed. |

## Signing Method

**Current CI path:** \`.github/workflows/security-scan.yml\` builds service images,
runs Trivy image scans, emits CycloneDX image SBOM artifacts, installs Cosign,
and runs \`dry-run\` readiness commands without storing secrets.

**Production recommendation:** Publish immutable image digests and run Cosign
keyless signing via GitHub Actions OIDC, Fulcio, and Rekor. Verification should
pin the expected workflow identity and OIDC issuer.

## Security Notes

- ✅ Private key **NOT committed** to repository
- ✅ Local demo private key deleted immediately after signing in \`local\` mode
- ✅ Dry-run/evidence modes do not create signatures or credentials
- ✅ No secrets exposed in this file

## Reproducible Commands

\`\`\`bash
# Readiness only, no signing:
bash scripts/security/cosign-sign.sh dry-run ghcr.io/example/topic10-api:sha-placeholder

# Local lab signing demo:
cosign verify --key cosign-lab.pub <image>

# Keyless (production/CI):
cosign verify \\
  --certificate-identity-regexp="<expected GitHub workflow identity>" \\
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \\
  <image>
\`\`\`

## Evidence Files

| File | Contents |
|------|----------|
| \`cosign-signing-summary.md\` | This file |
| \`cosign-verify-output.txt\` | Cosign output for the selected mode; dry-run/evidence output is readiness-only |

## Output Note

Do not claim that an image was signed unless this script was run in \`keyless\`
or \`local\` mode against a real image and the resulting verify output is
preserved.
MD

echo ""
echo "=== Cosign Signing Complete ==="
echo "Evidence:"
echo "  ${REPORT_DIR}/cosign-signing-summary.md"
echo "  ${REPORT_DIR}/cosign-verify-output.txt"
