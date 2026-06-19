#!/usr/bin/env bash
# Generate short-lived internal CA and demo certificates for the optional
# Gateway-to-Backend mTLS runtime profile.
#
# Output is intentionally written under infra/certs/gateway-backend/, which is
# ignored by Git. Do not commit generated private keys or certificates.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/infra/certs/gateway-backend"
DAYS="${GATEWAY_BACKEND_MTLS_DAYS:-7}"
KEY_BITS="${GATEWAY_BACKEND_MTLS_KEY_BITS:-2048}"

mkdir -p "${OUT_DIR}"
chmod 755 "${OUT_DIR}"

need_openssl() {
  if ! command -v openssl >/dev/null 2>&1; then
    echo "ERROR: openssl is required to generate mTLS demo certificates" >&2
    exit 1
  fi
}

write_ext() {
  local name="$1"
  local type="$2"
  local ext_file="${OUT_DIR}/${name}.ext"

  if [ "${type}" = "server" ]; then
    cat > "${ext_file}" <<EXT
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${name}
EXT
  else
    cat > "${ext_file}" <<EXT
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
subjectAltName=DNS:${name}
EXT
  fi
}

generate_ca() {
  if [ -s "${OUT_DIR}/ca.crt" ] && [ -s "${OUT_DIR}/ca.key" ]; then
    return
  fi

  echo "[INFO] Generating internal demo CA for gateway-backend mTLS"
  openssl req -x509 -newkey "rsa:${KEY_BITS}" -nodes \
    -keyout "${OUT_DIR}/ca.key" \
    -out "${OUT_DIR}/ca.crt" \
    -days "${DAYS}" \
    -sha256 \
    -subj "/CN=topic10-gateway-backend-demo-ca" >/dev/null 2>&1
  chmod 600 "${OUT_DIR}/ca.key"
  chmod 644 "${OUT_DIR}/ca.crt"
}

generate_leaf() {
  local name="$1"
  local type="$2"

  if [ -s "${OUT_DIR}/${name}.crt" ] && [ -s "${OUT_DIR}/${name}.key" ]; then
    return
  fi

  echo "[INFO] Generating ${type} certificate: ${name}"
  write_ext "${name}" "${type}"
  openssl req -newkey "rsa:${KEY_BITS}" -nodes \
    -keyout "${OUT_DIR}/${name}.key" \
    -out "${OUT_DIR}/${name}.csr" \
    -subj "/CN=${name}" >/dev/null 2>&1

  openssl x509 -req \
    -in "${OUT_DIR}/${name}.csr" \
    -CA "${OUT_DIR}/ca.crt" \
    -CAkey "${OUT_DIR}/ca.key" \
    -CAcreateserial \
    -out "${OUT_DIR}/${name}.crt" \
    -days "${DAYS}" \
    -sha256 \
    -extfile "${OUT_DIR}/${name}.ext" >/dev/null 2>&1

  rm -f "${OUT_DIR}/${name}.csr" "${OUT_DIR}/${name}.ext"
  chmod 600 "${OUT_DIR}/${name}.key"
  chmod 644 "${OUT_DIR}/${name}.crt"
}

need_openssl
generate_ca
generate_leaf "kong-client" "client"
generate_leaf "user-mtls-proxy" "server"
generate_leaf "order-mtls-proxy" "server"
generate_leaf "billing-mtls-proxy" "server"
generate_leaf "admin-mtls-proxy" "server"

cat > "${OUT_DIR}/README.generated.txt" <<README
Generated demo certificate material for Topic 10 gateway-backend mTLS.
Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Validity days: ${DAYS}

These files are local runtime artifacts and are ignored by Git.
Do not commit private keys, PKCS#12 bundles, or long-lived certificates.
README
chmod 600 "${OUT_DIR}/README.generated.txt"


# Lab permission fix:
# Generated certs are bind-mounted into Kong/Nginx containers.
# Kong runs as a non-root user, so demo client/server certs and keys must be
# readable inside containers. Generated material remains ignored and mounted read-only.
find "${OUT_DIR}" -type d -exec chmod 0755 {} \;
find "${OUT_DIR}" -type f -name "*.crt" -exec chmod 0644 {} \;
find "${OUT_DIR}" -type f -name "*.key" -exec chmod 0644 {} \;
chmod 0600 "${OUT_DIR}/ca.key"

echo "[OK] Gateway-backend mTLS demo certificates are ready under infra/certs/gateway-backend"

