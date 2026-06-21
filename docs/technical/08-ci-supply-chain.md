# CI And Supply Chain

## Requirement

The repository must support source-package security checks, dependency scanning,
SBOM generation, and signing readiness without storing secrets.

## Local Pipeline

`scripts/ci/security-pipeline.sh` wraps syntax checks, Bandit, Trivy,
Gitleaks, SBOM generation, Compose config validation, Cosign readiness,
selected security tests, ZAP, deterministic malformed-input checks, and final
regression when dependencies and the local stack are available.

## Secret Scan

`tests/security/verify-no-tracked-secrets.sh` checks tracked files for secret
material. Curated evidence records an empty Gitleaks JSON array for the
tracked/non-ignored source package.

## SAST And SCA

Curated evidence records no Bandit High severity issues and Trivy filesystem
scan results with `0` vulnerabilities across listed Python requirements files.

## SBOM

`scripts/security/generate-sbom.sh` generates CycloneDX and SPDX JSON SBOMs.
Curated evidence records 28 Python package components and 4 Docker base image
components in the recorded SBOM summary.

## Cosign

`scripts/security/cosign-sign.sh` supports readiness, dry-run, local lab
signing, and keyless modes. The curated evidence claims readiness dry-run only.
It does not claim a signed production artifact.

