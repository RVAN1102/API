#!/usr/bin/env bash
set -euo pipefail

EXPECTED_BRANCH="fix/gvhd-p0-security-evidence"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FAIL: not inside a Git repository"
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"

if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "FAIL: wrong branch."
  echo "Expected: $EXPECTED_BRANCH"
  echo "Current : $CURRENT_BRANCH"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "FAIL: working tree is not clean before Codex starts."
  git status -sb
  exit 1
fi

echo "PASS: branch guard ok."
echo "Branch: $CURRENT_BRANCH"
echo "Commit: $(git rev-parse HEAD)"
