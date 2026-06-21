# Final Repository Stale Evidence Audit

**Scope:** Phase 2 security-completion synchronization for the current final
baseline.

## Reviewed

- Public gateway references and stale plaintext gateway URLs.
- ZAP, fuzzing, and supply-chain evidence paths.
- Cosign signing claims versus the current CI dry-run/readiness workflow.
- Final evidence index links.
- Dev/test token-helper wording.

## Fixed

- Current ZAP and fuzzing commands now write transient runtime output under
  `.artifacts/test-runs/` instead of committed evidence paths.
- The evidence index points to rerunnable current commands instead of stale
  ZAP/fuzzing outputs.
- Cosign evidence now describes readiness/dry-run behavior unless a real
  `keyless` or `local` signing mode is executed.
- Stale generated final-regression/file-tree evidence snapshots were removed
  from the current authoritative baseline.

## Valid Lab Placeholders

- `sha-placeholder` in Cosign dry-run examples.
- Placeholder detection in `scripts/bootstrap-lab-env.sh`.
- Local demo/dev user-password defaults in `demo/auth/get-user-token.sh`.
- Internal backend healthchecks using service-local port `8000`.

## Historical Records

Older point-in-time regression outputs under `docs/evidence/final/` are retained
only when they do not contradict the current authoritative index. Archived
evidence is audit history, not current HTTPS evidence.

## Remaining Manual Review

- Rerun `bash tests/security/zap-active-scan.sh` before making fresh ZAP result
  claims.
- Rerun `bash tests/security/run-fuzzing.sh` before making fresh fuzzing result
  claims.
- Use `scripts/security/cosign-sign.sh keyless <image-digest>` with a pinned
  GitHub Actions identity before claiming a production image signature.
