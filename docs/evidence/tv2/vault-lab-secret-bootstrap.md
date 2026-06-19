# Vault Lab Secret Bootstrap Evidence

## Purpose

Fresh clones need a reproducible way to run the local Docker Compose stack and
final regression without committing real secrets. This repo uses
`scripts/bootstrap-lab-env.sh` to create `infra/.env` from
`infra/.env.example` and fill required lab values with `openssl rand -hex 24`.

## Lab Behavior

- `infra/.env` is a local generated file for Docker Compose compatibility and
  regression bootstrap.
- `infra/.env` is ignored by Git and must not be committed or staged.
- The bootstrap script only prints status messages such as `[OK] ... present`
  or `[INFO] generated ...`; it does not print secret values.
- Existing non-placeholder values are preserved, so rerunning the script is
  idempotent.
- The final regression preflight calls the bootstrap script when `infra/.env`
  is missing or still contains placeholders, then reloads the file.

## Vault/KMS Alignment

Vault OSS local is used in the prototype to demonstrate central secret
management concepts: dedicated secret paths, rotation runbooks, and separation
between application code and secret values.

Current limitation: local Docker Compose still receives the required service and
webhook lab values through `infra/.env`. This evidence does not claim that every
runtime secret is fetched directly from Vault by every service.

## Production Recommendation

For SME production deployments, `.env` should not be the source of truth for
secrets. Use one of:

- Vault HA with audit devices, backup/recovery, policy-based least privilege,
  and rotation procedures.
- Cloud KMS plus a managed secret store such as AWS Secrets Manager, GCP Secret
  Manager, Azure Key Vault, or an equivalent provider service.
- Platform secret injection for runtime workloads, with short-lived credentials
  and clear ownership of rotation.

Production evidence should cover audit logging, rotation, access policy review,
recovery testing, and proof that secret values are not written to logs or
tracked evidence.

## Commands

```bash
# Create or repair local lab env without printing secret values.
bash scripts/bootstrap-lab-env.sh

# Final regression auto-runs the same bootstrap if needed.
bash tests/final/main-regression.sh
```
