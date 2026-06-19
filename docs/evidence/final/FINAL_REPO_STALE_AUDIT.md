# Final Repository Stale Reference Audit

Date: 2026-06-19

This audit reviews stale-looking documentation and evidence references after the
current baseline reached final regression with 11 suites passing. The project is
a production-oriented security prototype, not a fully production-ready
deployment.

## Source Of Truth Used For Review

- Default Docker Compose uses Gateway-to-Backend mTLS.
- MFA/TOTP required actions are present for human users in the current Keycloak
  realm.
- OPA/RBAC and Billing-to-Order ownership checks are implemented.
- Container runtime hardening and OpenAPI/excessive-data contract tests are
  integrated into final regression.
- Final regression currently has 11 suites and passes.

## Stale-Looking Matches Reviewed

Reviewed grep patterns:

```text
p0-07-mfa-status-grep
OTP is not enforced
MFA.*not implemented
not implemented at runtime
TODO
PLACEHOLDER / placeholder
future work
default Compose remains
optional sidecar
9/9
11/11
production-ready / fully production
```

## Fixed Or Reclassified

| Item | Action |
|------|--------|
| `docs/evidence/tv2/p0-07-mfa-status-grep.txt` | Moved to `docs/evidence/tv2/pre-merge/p0-07-mfa-status-grep.txt` and marked as historical/superseded. |
| `docs/evidence/tv2/p0-07-mfa-status.md` | Updated evidence link to the pre-merge historical grep location. |
| `docs/archive/planning/TV1_Edge_Network_Webhook_Security_WorkPlan.md` | Marked as historical planning material. |
| `docs/archive/planning/TV2_Identity_Core_Application_WorkPlan.md` | Marked as historical planning material. |
| `docs/archive/planning/TV3_DevSecOps_Observability_RedTeam_WorkPlan.md` | Marked as historical planning material. |
| `docs/archive/planning/VẠN_Detailed_Assignment_After_Main_Merge.md` | Marked as historical assignment material. |
| `docs/archive/planning/HUY_Detailed_Assignment_After_Main_Merge.md` | Marked as historical assignment material. |
| `docs/archive/planning/NHẤT_Detailed_Assignment_After_Main_Merge.md` | Marked as historical assignment material. |
| `docs/archive/planning/Merge_Order_After_TV1_UI_Merge.md` | Marked as historical merge-planning material. |

## Valid Lab Placeholders

These matches are intentionally retained:

| Match | Reason |
|-------|--------|
| `infra/.env` placeholder checks in README/TESTING_GUIDE and Vault bootstrap evidence | Valid lab bootstrap/preflight behavior; generated local secrets remain ignored and are not production source of truth. |
| `sha-placeholder` in Cosign dry-run examples | Valid non-secret placeholder for documenting CI signing readiness without requiring a real published image digest. |
| `secret/data/api/webhook` placeholder examples in chapter evidence | Valid Vault path examples, not secret material. |
| `webhook-secret-placeholder` in red-team webhook forgery docs | Deliberate fake HMAC demo value, not a real secret. |
| Historical `secret-reference-audit.txt` placeholder matches | Generated audit evidence; retained as historical review output. |

## Historical / Pre-Merge / Planning Records

Remaining TODO, limitation, or old path matches in the following files are
historical records, not current status claims:

- `docs/archive/planning/TV1_Edge_Network_Webhook_Security_WorkPlan.md`
- `docs/archive/planning/TV2_Identity_Core_Application_WorkPlan.md`
- `docs/archive/planning/TV3_DevSecOps_Observability_RedTeam_WorkPlan.md`
- `docs/archive/planning/VẠN_Detailed_Assignment_After_Main_Merge.md`
- `docs/archive/planning/HUY_Detailed_Assignment_After_Main_Merge.md`
- `docs/archive/planning/NHẤT_Detailed_Assignment_After_Main_Merge.md`
- `docs/archive/planning/Merge_Order_After_TV1_UI_Merge.md`
- `docs/evidence/tv2/pre-merge/**`
- `docs/evidence/final/final-file-tree-maxdepth4.txt`
- historical regression outputs that mention earlier 9/9 or 11/11 sub-suite
  counts

## Remaining Manual Review Items

- `docs/Framework Tailoring for Implementation and Theoretical Research.md`
  contains theoretical research/source material and uses "placeholders" in an
  academic context. It was left unchanged.
- Historical evidence files under `docs/evidence/final/` still contain earlier
  command output and generated file-tree snapshots. They are retained for audit
  traceability and should not be treated as current runtime status unless the
  authoritative index says so.
- If final evidence is regenerated for submission packaging, refresh generated
  tree/status artifacts in one deliberate evidence-update branch rather than
  editing them ad hoc.
