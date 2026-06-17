#!/usr/bin/env bash
# =============================================================================
# Generate Self-Signed mTLS Certificates for Webhook Channel
# TV1 – Edge/Gateway Hardening
#
# Output:
#   infra/certs/webhook-ca.crt       – Webhook CA certificate (public)
#   infra/certs/webhook-ca.key       – Webhook CA private key  (NEVER commit)
#   infra/certs/webhook-client.crt   – Client cert (for test sender)
#   infra/certs/webhook-client.key   – Client private key      (NEVER commit)
#
# Usage:
#   bash infra/certs/generate-webhook-mtls-certs.sh
# =============================================================================
set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_KEY="${CERT_DIR}/webhook-ca.key"
CA_CRT="${CERT_DIR}/webhook-ca.crt"
CLIENT_KEY="${CERT_DIR}/webhook-client.key"
CLIENT_CSR="${CERT_DIR}/webhook-client.csr"
CLIENT_CRT="${CERT_DIR}/webhook-client.crt"

echo "=== TV1 mTLS Cert Generator ==="
echo "Output dir: ${CERT_DIR}"
echo ""

# ---------------------------------------------------------------------------
# 1. Generate CA key + self-signed CA certificate
# ---------------------------------------------------------------------------
echo "[1/4] Generating Webhook CA private key (RSA 4096)..."
openssl genrsa -out "${CA_KEY}" 4096 2>/dev/null
echo "      -> ${CA_KEY}"

echo "[2/4] Generating self-signed Webhook CA certificate (10 years)..."
openssl req -new -x509 \
  -key "${CA_KEY}" \
  -out "${CA_CRT}" \
  -days 3650 \
  -subj "//C=VN/O=Topic10-SME-API/OU=TV1-Edge/CN=Webhook-CA" \
  -extensions v3_ca 2>/dev/null
echo "      -> ${CA_CRT}"

# ---------------------------------------------------------------------------
# 2. Generate Client key + CSR + sign with CA
# ---------------------------------------------------------------------------
echo "[3/4] Generating Webhook Client private key (RSA 2048)..."
openssl genrsa -out "${CLIENT_KEY}" 2048 2>/dev/null
echo "      -> ${CLIENT_KEY}"

echo "[4/4] Generating and signing Webhook Client certificate (1 year)..."
openssl req -new \
  -key "${CLIENT_KEY}" \
  -out "${CLIENT_CSR}" \
  -subj "//C=VN/O=Topic10-SME-API/OU=TV1-WebhookSender/CN=webhook-sender" 2>/dev/null

openssl x509 -req \
  -in "${CLIENT_CSR}" \
  -CA "${CA_CRT}" \
  -CAkey "${CA_KEY}" \
  -CAcreateserial \
  -out "${CLIENT_CRT}" \
  -days 365 \
  -sha256 2>/dev/null

rm -f "${CLIENT_CSR}" "${CERT_DIR}/webhook-ca.srl"
echo "      -> ${CLIENT_CRT}"

# ---------------------------------------------------------------------------
# 3. Generate PKCS12 (.p12) for Windows native curl (Schannel) compatibility
# ---------------------------------------------------------------------------
echo "[5/5] Generating PKCS12 format for Windows compatibility..."
openssl pkcs12 -export -out "${CERT_DIR}/webhook-client.p12" \
  -inkey "${CLIENT_KEY}" -in "${CLIENT_CRT}" -passout pass:webhook 2>/dev/null
echo "      -> ${CERT_DIR}/webhook-client.p12"

# ---------------------------------------------------------------------------
# 4. Verify
# ---------------------------------------------------------------------------
echo ""
echo "=== Verification ==="
echo "CA cert subject:"
openssl x509 -in "${CA_CRT}" -noout -subject -dates 2>/dev/null

echo ""
echo "Client cert subject:"
openssl x509 -in "${CLIENT_CRT}" -noout -subject -dates 2>/dev/null

echo ""
echo "Verifying client cert is signed by CA..."
openssl verify -CAfile "${CA_CRT}" "${CLIENT_CRT}" 2>/dev/null && echo "VERIFY OK"

# ---------------------------------------------------------------------------
# 4. Output inline CA PEM for kong.yml
# ---------------------------------------------------------------------------
echo ""
echo "=== CA Certificate (paste into kong.yml ca_certificates.cert) ==="
cat "${CA_CRT}"

echo ""
echo "=== Done ==="
echo "Files generated:"
echo "  ${CA_CRT}     (public  – safe to commit)"
echo "  ${CA_KEY}     (private – DO NOT commit, in .gitignore)"
echo "  ${CLIENT_CRT} (public  – safe to commit for demo)"
echo "  ${CLIENT_KEY} (private – DO NOT commit, in .gitignore)"
echo ""
echo "Next step: copy CA cert PEM into gateway/kong.yml under ca_certificates."
