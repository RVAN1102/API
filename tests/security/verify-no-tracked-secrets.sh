#!/usr/bin/env bash
# Verify that tracked source does not contain local secrets or generated key
# material. The script reports file paths only; it does not print secret values.

set -euo pipefail

FAILED=0
PACKAGE_SCAN_DIR=""

cleanup() {
  if [ -n "${PACKAGE_SCAN_DIR}" ] && [ -d "${PACKAGE_SCAN_DIR}" ]; then
    rm -rf "${PACKAGE_SCAN_DIR}"
  fi
}
trap cleanup EXIT

fail() {
  FAILED=1
  echo "[FAIL] $*"
}

pass() {
  echo "[PASS] $*"
}

tracked_matches() {
  git ls-files "$@" 2>/dev/null
}

grep_paths() {
  local pattern="$1"
  shift
  git grep -Il -E "${pattern}" -- "$@" 2>/dev/null || true
}

check_no_paths() {
  local label="$1"
  shift
  local matches
  matches="$(tracked_matches "$@")"
  if [ -n "${matches}" ]; then
    fail "${label}"
    printf '%s\n' "${matches}" | sed 's/^/  /'
  else
    pass "${label}"
  fi
}

check_no_grep_paths() {
  local label="$1"
  local pattern="$2"
  shift 2
  local matches
  matches="$(grep_paths "${pattern}" "$@")"
  if [ -n "${matches}" ]; then
    fail "${label}"
    printf '%s\n' "${matches}" | sort -u | sed 's/^/  /'
  else
    pass "${label}"
  fi
}

prepare_package_scan_dir() {
  PACKAGE_SCAN_DIR="$(mktemp -d /tmp/topic10-secret-hygiene.XXXXXX)"
  while IFS= read -r -d '' path; do
    [ -f "${path}" ] || continue
    mkdir -p "${PACKAGE_SCAN_DIR}/$(dirname "${path}")"
    cp "${path}" "${PACKAGE_SCAN_DIR}/${path}"
  done < <(git ls-files --cached --modified --others --exclude-standard -z)
  printf '%s\n' "${PACKAGE_SCAN_DIR}"
}

echo "=== Tracked Secret Hygiene Verification ==="

check_no_paths "infra/.env is not tracked" "infra/.env"
check_no_paths "infra/certs private keys are not tracked" "infra/certs/*.key"
check_no_paths "infra/certs PKCS#12 bundles are not tracked" "infra/certs/*.p12"

check_no_grep_paths \
  "tracked files contain no private key PEM blocks" \
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|-----BEGIN PRIVATE KEY-----' \
  .

check_no_grep_paths \
  "tracked files contain no obvious JWT access-token values" \
  'eyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}' \
  .

if command -v gitleaks >/dev/null 2>&1; then
  SCAN_DIR="$(prepare_package_scan_dir)"
  if gitleaks dir "${SCAN_DIR}" --no-banner --redact --exit-code 1 >/tmp/gitleaks-secret-hygiene.txt 2>&1; then
    pass "Gitleaks detects no current tracked/non-ignored source package secrets"
  else
    fail "Gitleaks detected secret-like values; run the post-purge scan for redacted report details"
  fi
else
  fail "gitleaks is required for client secret/password verification"
fi

if [ "${FAILED}" -ne 0 ]; then
  echo "=== Verification failed ==="
  exit 1
fi

echo "=== Verification passed ==="
