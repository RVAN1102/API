#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/certs}"
mkdir -p "${OUT_DIR}"

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
  -keyout "${OUT_DIR}/demo-ca.key" \
  -out "${OUT_DIR}/demo-ca.crt" \
  -days 30 -subj "/CN=SME Demo Internal CA"

for name in gateway backend; do
  openssl req -newkey rsa:3072 -sha256 -nodes \
    -keyout "${OUT_DIR}/${name}.key" \
    -out "${OUT_DIR}/${name}.csr" \
    -subj "/CN=${name}.internal"

  cat >"${OUT_DIR}/${name}.ext" <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${name}.internal,DNS:${name}
EOF

  openssl x509 -req -sha256 \
    -in "${OUT_DIR}/${name}.csr" \
    -CA "${OUT_DIR}/demo-ca.crt" \
    -CAkey "${OUT_DIR}/demo-ca.key" \
    -CAcreateserial \
    -out "${OUT_DIR}/${name}.crt" \
    -days 30 \
    -extfile "${OUT_DIR}/${name}.ext"
done

chmod 600 "${OUT_DIR}"/*.key
echo "Generated local-only mTLS material in ${OUT_DIR}"
echo "Do not commit any generated private key."

