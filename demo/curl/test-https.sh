#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"

# -k is allowed only for the local Kong self-signed development certificate.
if curl --silent --show-error --insecure --include \
  "${BASE_URL}/api/v1/users/health"; then
  exit 0
fi

docker_bin="${DOCKER_BIN:-docker}"
if ! command -v "${docker_bin}" >/dev/null 2>&1 &&
    [[ -x "/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]]; then
  docker_bin="/c/Program Files/Docker/Docker/resources/bin/docker.exe"
fi

echo "Native curl failed; retrying through Linux curl container." >&2
"${docker_bin}" run --rm curlimages/curl:latest --silent --show-error \
  --insecure --include \
  "https://host.docker.internal:8443/api/v1/users/health"
