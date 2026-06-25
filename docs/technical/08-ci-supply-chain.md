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
This repository uses Trivy for SCA/container/filesystem scanning; it does not
claim Snyk evidence.

## SBOM

`scripts/security/generate-sbom.sh` generates CycloneDX and SPDX JSON SBOMs.
The current filesystem run records 25 Python components. Image SBOM generation
is optional and was not requested in that run.

## Cosign

`scripts/security/cosign-sign.sh` supports readiness, dry-run, local image,
local `sign-blob`, and keyless modes. `sign-blob` can sign and verify a local
SBOM while keeping generated material under ignored `.artifacts` and deleting
the private key afterward. The curated evidence claims readiness dry-run only
unless generated verification output proves a successful blob run. It does not
claim a signed production image.
