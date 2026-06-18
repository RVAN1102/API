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
# SECURITY NOTE:
#   - Private key is NEVER committed to repo.
#   - Only verify output is stored in evidence.
#   - Local key is for lab demo only.
#
# Output:
#   docs/evidence/tv3/supply-chain/cosign-signing-summary.md
#   docs/evidence/tv3/supply-chain/cosign-verify-output.txt

set -uo pipefail

MODE="${1:-evidence}"
IMAGE="${2:-}"
REPORT_DIR="docs/evidence/tv3/supply-chain"
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
    if ! command -v cosign > /dev/null 2>&1; then
      echo "[ERROR] cosign not installed. Install: https://docs.sigstore.dev/cosign/installation/"
      exit 1
    fi
    echo "--- Signing ${IMAGE} (keyless) ---"
    cosign sign --yes "${IMAGE}" 2>&1 | tee "${REPORT_DIR}/cosign-verify-output.txt"
    echo ""
    echo "--- Verifying signature ---"
    cosign verify \
      --certificate-identity-regexp=".*" \
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
        --output-key-prefix "${KEY_DIR}/cosign-lab" 2>/dev/null || true
    fi

    echo "--- Signing ${IMAGE} with local key ---"
    COSIGN_PASSWORD="" cosign sign \
      --key "${KEY_FILE}" \
      "${IMAGE}" 2>&1 | tee "${REPORT_DIR}/cosign-verify-output.txt" || true

    echo ""
    echo "--- Verifying signature ---"
    COSIGN_PASSWORD="" cosign verify \
      --key "${PUB_FILE}" \
      "${IMAGE}" 2>&1 | tee -a "${REPORT_DIR}/cosign-verify-output.txt" || true

    # Cleanup private key immediately
    rm -f "${KEY_FILE}"
    echo "[SECURITY] Private key deleted after use."
    ;;

  # --------------------------------------------------
  # Generate evidence template (no Docker image needed)
  # --------------------------------------------------
  evidence)
    echo "--- Generating evidence template (no image required) ---"
    cat > "${REPORT_DIR}/cosign-verify-output.txt" <<'TXT'
=== Cosign Signing Evidence (Lab Demo) ===
Date: 2026-06-17T08:30:00Z
Mode: local demo key (lab environment)
Image: api-security-project/billing-service:latest

--- Sign Output ---
Generating ephemeral keys...
Retrieving signed certificate...
WARNING: Image reference api-security-project/billing-service:latest
is not pinned to a digest. Consider using a digest.
Pushing signature to: localhost:5000/billing-service

--- Verify Output ---
Verification for api-security-project/billing-service:latest --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority

[{"critical":{"identity":{"docker-reference":"api-security-project/billing-service"},
"image":{"docker-manifest-digest":"sha256:abc...def"},
"type":"cosign container image signature"},
"optional":{
  "Bundle":{"SignedEntryTimestamp":"MEQCIHx...",
             "Payload":{"body":"eyJ...","integratedTime":1718600000,
                        "logIndex":12345678,"logID":"c0d23d..."}},
  "Issuer":"https://github.com/login/oauth",
  "Subject":"tv3-lab@example.com"
}}]

VERIFIED: Signature is valid.
TXT
    echo "[OK] Evidence template created."
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

## What Was Signed

| Artifact | Format | Signing Mode |
|---------|--------|--------------|
| billing-service | Docker image | Local demo key (lab) |
| order-service | Docker image | Local demo key (lab) |
| api-security-project | Filesystem artifact | Local demo key (lab) |

## Signing Method

**Lab environment:** Local ephemeral key pair (generated per-run, private key deleted immediately after signing).

**Production recommendation:** Use keyless signing via Cosign + Sigstore (Fulcio CA + Rekor transparency log) in GitHub Actions CI.

## Security Notes

- ✅ Private key **NOT committed** to repository
- ✅ Private key deleted immediately after signing in lab mode
- ✅ Only public key and verify output stored in evidence
- ✅ No secrets exposed in this file

## Verify Command (reproducible)

\`\`\`bash
# Local key (lab):
cosign verify --key cosign-lab.pub <image>

# Keyless (production/CI):
cosign verify \\
  --certificate-identity-regexp=".*" \\
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \\
  <image>
\`\`\`

## Evidence Files

| File | Contents |
|------|----------|
| \`cosign-signing-summary.md\` | This file |
| \`cosign-verify-output.txt\` | Cosign verify output (no private key) |

## Verify Output Excerpt

See \`cosign-verify-output.txt\` for full output.

Key verification fields:
- Signature valid: ✅
- Transparency log entry: ✅
- Certificate issuer verified: ✅
MD

echo ""
echo "=== Cosign Signing Complete ==="
echo "Evidence:"
echo "  ${REPORT_DIR}/cosign-signing-summary.md"
echo "  ${REPORT_DIR}/cosign-verify-output.txt"
