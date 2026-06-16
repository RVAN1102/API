# Daily Merge Checklist

Use this checklist **before every merge** into `main`.

---

## Pre-Merge Checklist

- [ ] `git checkout main && git pull origin main`
- [ ] `git checkout <your-branch>`
- [ ] `git merge origin/main` (resolve any conflicts)
- [ ] `docker compose -f infra/docker-compose.yml up -d --build`
- [ ] Wait for all containers to be healthy
- [ ] `bash tests/smoke/main-smoke.sh` → all PASS
- [ ] Run your branch-specific tests
- [ ] No real secrets in evidence files
- [ ] No unresolved merge conflicts

## For Large / Runtime Changes (additional)

- [ ] `bash tests/final/main-regression.sh` → all suites PASS
- [ ] `bash ci/run-local-security-scan.sh` → no new critical issues

## Merge into `main`

```bash
git checkout main
git pull origin main
git merge --no-ff <your-branch> -m "merge <short-description> into main"
```

## Post-Merge Verification

- [ ] `docker compose -f infra/docker-compose.yml up -d --build --force-recreate`
- [ ] `bash tests/smoke/main-smoke.sh` → all PASS
- [ ] `git push origin main`

## If Post-Merge Tests Fail

1. **Do NOT push** the broken main
2. Revert: `git revert HEAD`
3. Push the revert: `git push origin main`
4. Fix on branch and re-merge
