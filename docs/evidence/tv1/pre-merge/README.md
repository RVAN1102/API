# TV1 Pre-Merge Historical Evidence

This directory contains historical evidence captured before the final hardening
work was merged into `main`. Files in this directory may mention earlier gaps
such as Gateway-to-Backend mTLS not being implemented. Those statements are not
the current project status.

Current authoritative status:
- Gateway-to-Backend mTLS is enabled in the default Compose runtime.
- Webhook ingress mTLS is implemented separately from HMAC/timestamp/nonce.
- Current evidence is indexed from `docs/evidence/final/AUTHORITATIVE_EVIDENCE_INDEX.md`.
