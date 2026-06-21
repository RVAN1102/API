#!/usr/bin/env bash
# Repo-wide URL/security-scope consistency audit.

set -euo pipefail

OUT_DIR="/tmp/repo-consistency"
DETAILS="${OUT_DIR}/details.txt"
mkdir -p "${OUT_DIR}"
: > "${DETAILS}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

record_matches() {
  local title="$1"
  shift
  {
    printf '\n## %s\n' "${title}"
    "$@" || true
  } >> "${DETAILS}"
}

DOC_TARGETS=(
  README.md
  TESTING_GUIDE.md
  docs
  gateway
  services
  tests
  scripts
  .github
)

OLD_PUBLIC_API_A='http://localhost:'
OLD_PUBLIC_API_B='8000'
OLD_PUBLIC_API="${OLD_PUBLIC_API_A}${OLD_PUBLIC_API_B}"
OLD_LOOPBACK_API_A='http://127.0.0.1:'
OLD_LOOPBACK_API_B='8000'
OLD_LOOPBACK_API="${OLD_LOOPBACK_API_A}${OLD_LOOPBACK_API_B}"
OLD_PUBLIC_API_PATTERN="${OLD_PUBLIC_API}|${OLD_LOOPBACK_API}"

current_doc_matches() {
  rg -n \
    --glob '!docs/evidence/**/*.txt' \
    --glob '!docs/evidence/**/*.json' \
    --glob '!docs/evidence/**/main-regression-*.txt' \
    --glob '!docs/runbooks/url-and-security-scope.md' \
    --glob '!scripts/audit/repo-consistency-audit.sh' \
    "$@" "${DOC_TARGETS[@]}" 2>/dev/null || true
}

if current_doc_matches "${OLD_PUBLIC_API_PATTERN}" | grep -q .; then
  fail "Old plaintext public API references found"
  record_matches "old public API references" current_doc_matches "${OLD_PUBLIC_API_PATTERN}"
else
  pass "No current old public API references to ${OLD_PUBLIC_API}"
fi

if current_doc_matches 'users should call .*http://|direct backend service URLs|direct HTTP service URLs are used by users' | grep -q .; then
  fail "Plaintext/direct backend S2S wording found"
  record_matches "plaintext backend S2S references" current_doc_matches 'users should call .*http://|direct backend service URLs|direct HTTP service URLs are used by users'
else
  pass "No current wording says users call direct backend service URLs"
fi

if current_doc_matches 'docker-compose\.mtls\.yml' | grep -q .; then
  fail "Legacy docker-compose.mtls.yml references found"
  record_matches "legacy docker-compose.mtls.yml references" current_doc_matches 'docker-compose\.mtls\.yml'
else
  pass "No legacy docker-compose.mtls.yml references"
fi

MTLS_OVERCLAIM_PATTERN='all internal traffic is '
MTLS_OVERCLAIM_PATTERN+='mTLS|all east-west traffic is '
MTLS_OVERCLAIM_PATTERN+='mTLS|full service mesh'
if current_doc_matches "$MTLS_OVERCLAIM_PATTERN" \
  | grep -vE 'not a full service mesh|chưa phải full service mesh|Production should|Production nên' \
  | grep -q .; then
  fail "mTLS overclaim wording found"
  record_matches "mTLS overclaim wording" current_doc_matches "$MTLS_OVERCLAIM_PATTERN"
else
  pass "No current mTLS overclaim wording"
fi

if current_doc_matches 'Grafana.*localhost:3000|localhost:3000.*Grafana|Grafana accessible at localhost:3000' | grep -q .; then
  fail "Grafana localhost:3000 confusion found"
  record_matches "Grafana 3000 confusion" current_doc_matches 'Grafana.*localhost:3000|localhost:3000.*Grafana|Grafana accessible at localhost:3000'
else
  pass "Grafana is not documented as localhost:3000"
fi

if current_doc_matches 'server-version|server version leak|Server header leak|ZAP.*Server.*version|X-Powered-By.*leak' | grep -q .; then
  warn "Possible stale ZAP/server-version leak wording found"
  record_matches "old ZAP server-version leak wording" current_doc_matches 'server-version|server version leak|Server header leak|ZAP.*Server.*version|X-Powered-By.*leak'
else
  pass "No current stale ZAP server-version leak wording"
fi

SECRET_STATUS="$(
  git status --short -- .env infra/.env infra/certs .artifacts '*.p12' '*.key' '*token*' 2>/dev/null \
    | grep -vE '^[[:space:]]*D[[:space:]]+docs/' \
    || true
)"
if [ -n "${SECRET_STATUS}" ]; then
  warn "Generated or secret-like files appear in git status; review before staging"
  {
    printf '\n## generated/secret-like git status\n'
    printf '%s\n' "${SECRET_STATUS}"
  } >> "${DETAILS}"
else
  pass "No generated/secret-like files detected in git status scope"
fi

printf '\nDetails saved to %s\n' "${DETAILS}"
printf 'Summary: PASS=%s WARN=%s FAIL=%s\n' "${PASS_COUNT}" "${WARN_COUNT}" "${FAIL_COUNT}"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  exit 1
fi
