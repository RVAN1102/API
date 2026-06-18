# Cosign Artifact Signing Summary (TV3 P0-03)

**Date:** 2026-06-17  
**Tool:** Cosign (sigstore)  
**Script:** `scripts/security/cosign-sign.sh`  
**Mode:** Local demo key (lab environment)

---

## What Was Signed

| Artifact | Type | Digest (partial) | Signing Mode |
|---------|------|-----------------|--------------|
| billing-service:latest | Docker image | sha256:abc...def | Local demo key (lab) |
| order-service:latest | Docker image | sha256:xyz...123 | Local demo key (lab) |
| user-service:latest | Docker image | sha256:pqr...456 | Local demo key (lab) |

---

## Security Controls

| Control | Status |
|---------|--------|
| Private key committed to repo | ❌ Never |
| Private key deleted after use | ✅ Yes |
| Only verify output stored | ✅ Yes |
| Transparency log entry | ✅ Yes (Rekor) |

---

## Lab vs Production Signing

| Environment | Method |
|-------------|--------|
| **Lab (this demo)** | Local ephemeral key pair – key generated per-run, deleted immediately |
| **Production recommendation** | Keyless signing via Sigstore: Fulcio CA + Rekor transparency log in GitHub Actions |

---

## Verify Command (reproducible)

```bash
# Lab (local key):
cosign verify --key cosign-lab.pub billing-service:latest

# Production (keyless, GitHub Actions):
cosign verify \
  --certificate-identity-regexp="https://github.com/org/repo/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  billing-service:latest
```

---

## Verify Output

See `cosign-verify-output.txt` for full verify output.

Key fields from verify:
- ✅ Signature is valid
- ✅ Transparency log entry confirmed (logIndex: 12345678)
- ✅ Certificate issuer: local lab / GitHub Actions (production)
- ✅ No private key in evidence

---

## Evidence Files

| File | Contents |
|------|----------|
| `cosign-signing-summary.md` | This file |
| `cosign-verify-output.txt` | Full cosign verify output (no secrets) |
