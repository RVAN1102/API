# ZAP Active Scan

## Requirement Proven

The repository has ZAP active scan support for the HTTPS gateway. The counts
below are copied from the currently generated local ZAP summary.

## Command Or Evidence Source

```bash
bash tests/security/zap-active-scan.sh
```

Recorded target:

```text
https://localhost:8443
```

Generated source:

`.artifacts/test-runs/tv3/zap/zap-active-summary.md`

## Observed Result

| Risk level | Count |
|---|---:|
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 8 |

## Scope And Limitation

The generated report supports `0 High / 0 Medium / 0 Low` and 8 informational
alert types. It includes protected-path `401`/`403` responses, showing the scan
reached HTTPS Kong, but those responses do not prove successful authorized
business flows. Re-run the command and update this file from the generated
summary before making a newer scan claim.
