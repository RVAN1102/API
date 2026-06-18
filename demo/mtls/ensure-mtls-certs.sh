#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CA_CERT="$ROOT_DIR/infra/certs/webhook-ca.crt"
CA_KEY="$ROOT_DIR/infra/certs/webhook-ca.key"
CLIENT_CERT="$ROOT_DIR/infra/certs/webhook-client.crt"
CLIENT_KEY="$ROOT_DIR/infra/certs/webhook-client.key"
GEN_SCRIPT="$ROOT_DIR/demo/mtls/generate-mtls-certs.sh"

hash_cert_pubkey() {
  openssl x509 -in "$1" -pubkey -noout \
    | openssl pkey -pubin -outform DER \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A
}

hash_key_pubkey() {
  openssl pkey -in "$1" -pubout \
    | openssl pkey -pubin -outform DER \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A
}

needs_regen=false

for f in "$CA_CERT" "$CA_KEY" "$CLIENT_CERT" "$CLIENT_KEY"; do
  if [ ! -s "$f" ]; then
    echo "[INFO] Missing webhook mTLS file: $f"
    needs_regen=true
  fi
done

if [ "$needs_regen" = false ]; then
  ca_cert_hash="$(hash_cert_pubkey "$CA_CERT" || true)"
  ca_key_hash="$(hash_key_pubkey "$CA_KEY" || true)"
  client_cert_hash="$(hash_cert_pubkey "$CLIENT_CERT" || true)"
  client_key_hash="$(hash_key_pubkey "$CLIENT_KEY" || true)"

  if [ "$ca_cert_hash" != "$ca_key_hash" ]; then
    echo "[INFO] Webhook CA certificate/private key mismatch; regenerating local mTLS certs"
    needs_regen=true
  fi

  if [ "$client_cert_hash" != "$client_key_hash" ]; then
    echo "[INFO] Webhook client certificate/private key mismatch; regenerating local mTLS certs"
    needs_regen=true
  fi
fi

if [ "$needs_regen" = true ]; then
  bash "$GEN_SCRIPT"
fi

ca_cert_hash="$(hash_cert_pubkey "$CA_CERT")"
ca_key_hash="$(hash_key_pubkey "$CA_KEY")"
client_cert_hash="$(hash_cert_pubkey "$CLIENT_CERT")"
client_key_hash="$(hash_key_pubkey "$CLIENT_KEY")"

if [ "$ca_cert_hash" != "$ca_key_hash" ]; then
  echo "[ERROR] Webhook CA certificate and private key still do not match after regeneration" >&2
  exit 1
fi

if [ "$client_cert_hash" != "$client_key_hash" ]; then
  echo "[ERROR] Webhook client certificate and private key still do not match after regeneration" >&2
  exit 1
fi

echo "[PASS] Webhook mTLS cert/key material is present and consistent"
