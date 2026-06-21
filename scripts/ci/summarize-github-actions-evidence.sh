#!/usr/bin/env bash
# Summarize downloaded GitHub Actions security evidence without making signing
# claims that are not present in the artifacts.
#
# Usage:
#   bash scripts/ci/summarize-github-actions-evidence.sh <artifact-dir> [summary-file]
#
# The artifact directory should contain files downloaded from the
# `.github/workflows/security-scan.yml` run.

set -euo pipefail

ARTIFACT_DIR="${1:-}"
SUMMARY_FILE="${2:-docs/evidence/tv3/pipeline/github-actions-evidence-summary.md}"

if [ -z "${ARTIFACT_DIR}" ] || [ ! -d "${ARTIFACT_DIR}" ]; then
  echo "Usage: bash scripts/ci/summarize-github-actions-evidence.sh <artifact-dir> [summary-file]" >&2
  exit 2
fi

mkdir -p "$(dirname "${SUMMARY_FILE}")"

count_matches() {
  local pattern="$1"
  find "${ARTIFACT_DIR}" -type f -name "${pattern}" 2>/dev/null | wc -l | tr -d ' '
}

has_text() {
  local pattern="$1"
  if grep -R -I -q -- "${pattern}" "${ARTIFACT_DIR}" 2>/dev/null; then
    printf 'yes'
  else
    printf 'no'
  fi
}

BANDIT_COUNT="$(count_matches 'bandit-report.txt')"
TRIVY_COUNT="$(count_matches 'trivy-report.txt')"
IMAGE_TRIVY_COUNT="$(count_matches 'trivy-image-*.txt')"
IMAGE_SBOM_COUNT="$(count_matches 'image-sbom-*.cdx.json')"
COSIGN_DRY_RUN="$(has_text 'No signature, key, or credential is generated in dry-run mode')"
COSIGN_SIGNED="$(has_text 'Verified OK')"

SIGNING_STATUS="readiness-only"
if [ "${COSIGN_SIGNED}" = "yes" ]; then
  SIGNING_STATUS="verify-output-present-review-before-claiming"
elif [ "${COSIGN_DRY_RUN}" = "yes" ]; then
  SIGNING_STATUS="dry-run-no-signature"
fi

cat > "${SUMMARY_FILE}" <<MD
# GitHub Actions Security Evidence Summary

**Generated:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')  
**Artifact source directory:** \`${ARTIFACT_DIR}\`  
**Workflow:** \`.github/workflows/security-scan.yml\`

## Artifact Inventory

| Evidence | Count |
|---|---:|
| Bandit reports | ${BANDIT_COUNT} |
| Trivy filesystem reports | ${TRIVY_COUNT} |
| Trivy image reports | ${IMAGE_TRIVY_COUNT} |
| Image CycloneDX SBOMs | ${IMAGE_SBOM_COUNT} |

## Signing Scope

| Field | Value |
|---|---|
| Cosign dry-run marker found | ${COSIGN_DRY_RUN} |
| Cosign verify success text found | ${COSIGN_SIGNED} |
| Summary signing status | ${SIGNING_STATUS} |

Do not claim CI artifact signing succeeded unless the workflow run includes
reviewed keyless signing and verification evidence for a real image digest.
The default workflow currently documents Cosign keyless readiness by dry-run.

## Review Notes

- Keep downloaded raw artifacts out of Git unless they are curated and safe.
- Do not include secrets, tokens, private keys, `.p12` files, or generated cert
  material in evidence.
- Link this summary from the authoritative evidence index only after reviewing
  the source workflow run and artifact contents.
MD

echo "Wrote ${SUMMARY_FILE}"

