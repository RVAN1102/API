# ZAP Active Scan

## Requirement Proven

The repository has ZAP active scan support for the HTTPS gateway and a curated
recorded alert summary.

## Command Or Evidence Source

```bash
bash tests/security/zap-active-scan.sh
```

Recorded target:

```text
https://localhost:8443
```

## Observed Result

| Risk level | Count |
|---|---:|
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 8 |

## Scope And Limitation

The recorded alerts are informational, including expected client-error
responses from invalid or unauthorized paths. Re-run ZAP before making a new
scan result claim.

