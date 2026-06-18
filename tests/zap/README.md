# OWASP ZAP Baseline Scan

This directory contains configuration for running automated API security scans using OWASP ZAP against the Kong API Gateway.

## Files
- `run-zap-baseline.sh`: Docker-based runner script
- `zap-baseline.conf`: Rule configuration for the baseline scan

## Running
```bash
bash tests/zap/run-zap-baseline.sh
```

Reports are generated in `docs/evidence/tv3/`.
