#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"

if ! headers="$(curl --silent --show-error --insecure --dump-header - \
    "${BASE_URL}/api/v1/users/health" --output /dev/null)"; then
  docker_bin="${DOCKER_BIN:-docker}"
  if ! command -v "${docker_bin}" >/dev/null 2>&1 &&
      [[ -x "/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]]; then
    docker_bin="/c/Program Files/Docker/Docker/resources/bin/docker.exe"
  fi
  echo "Native curl failed; retrying through Linux curl container." >&2
  headers="$("${docker_bin}" run --rm curlimages/curl:latest \
    --silent --show-error --insecure --dump-header - --output /dev/null \
    "https://host.docker.internal:8443/api/v1/users/health")"
fi

printf '%s\n' "${headers}"
grep -qi '^Strict-Transport-Security:' <<<"${headers}"
