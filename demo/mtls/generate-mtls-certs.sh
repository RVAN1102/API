#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/infra/certs}"
mkdir -p "${OUT_DIR}"

CA_KEY="${OUT_DIR}/webhook-ca.key"
CA_CRT="${OUT_DIR}/webhook-ca.crt"
CLIENT_KEY="${OUT_DIR}/webhook-client.key"
CLIENT_CSR="${OUT_DIR}/webhook-client.csr"
CLIENT_CRT="${OUT_DIR}/webhook-client.crt"
CLIENT_EXT="${OUT_DIR}/webhook-client.ext"
CLIENT_P12="${OUT_DIR}/webhook-client.p12"

cat >"${CLIENT_EXT}" <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
subjectAltName=DNS:webhook-sender,DNS:webhook-sender.local
EOF

echo "Generating local-only webhook mTLS material in ${OUT_DIR}"
echo "No private key values will be printed."

openssl genrsa -out "${CA_KEY}" 4096 2>/dev/null
openssl req -new -x509 \
  -key "${CA_KEY}" \
  -out "${CA_CRT}" \
  -days 30 \
  -sha256 \
  -subj "/C=VN/O=Topic10-SME-API/OU=LocalDemo/CN=Webhook-Local-Demo-CA" 2>/dev/null

openssl genrsa -out "${CLIENT_KEY}" 2048 2>/dev/null
openssl req -new \
  -key "${CLIENT_KEY}" \
  -out "${CLIENT_CSR}" \
  -subj "/C=VN/O=Topic10-SME-API/OU=WebhookSender/CN=webhook-sender" 2>/dev/null

openssl x509 -req \
  -in "${CLIENT_CSR}" \
  -CA "${CA_CRT}" \
  -CAkey "${CA_KEY}" \
  -CAcreateserial \
  -out "${CLIENT_CRT}" \
  -days 30 \
  -sha256 \
  -extfile "${CLIENT_EXT}" 2>/dev/null

openssl pkcs12 -export \
  -out "${CLIENT_P12}" \
  -inkey "${CLIENT_KEY}" \
  -in "${CLIENT_CRT}" \
  -certfile "${CA_CRT}" \
  -passout pass:webhook 2>/dev/null

rm -f "${CLIENT_CSR}" "${CLIENT_EXT}" "${OUT_DIR}/webhook-ca.srl"
chmod 600 "${CA_KEY}" "${CLIENT_KEY}" "${CLIENT_P12}"
chmod 644 "${CA_CRT}" "${CLIENT_CRT}"

openssl verify -CAfile "${CA_CRT}" "${CLIENT_CRT}" >/dev/null

echo "Generated:"
echo "  ${CA_CRT}"
echo "  ${CA_KEY} (ignored private key)"
echo "  ${CLIENT_CRT}"
echo "  ${CLIENT_KEY} (ignored private key)"
echo "  ${CLIENT_P12} (ignored PKCS#12 bundle)"
echo ""
echo "Do not commit generated certificate material."
