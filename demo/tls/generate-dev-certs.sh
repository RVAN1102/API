#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/certs}"
mkdir -p "${OUT_DIR}"

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
  -keyout "${OUT_DIR}/gateway-dev.key" \
  -out "${OUT_DIR}/gateway-dev.crt" \
  -days 30 \
  -subj "/CN=localhost/O=SME Security Demo" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

chmod 600 "${OUT_DIR}/gateway-dev.key"
echo "Generated local-only certificate files in ${OUT_DIR}"
echo "Do not commit the generated private key."

