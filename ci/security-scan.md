# CI Security Scanning

This directory contains scripts and configurations for local and CI-based security scanning.

## Tools
- **Bandit:** Python SAST (Static Analysis)
- **Gitleaks:** Secret detection
- **Trivy:** Filesystem and dependency vulnerability scanning

## Usage
Run the local scanner before committing code:
```bash
bash ci/run-local-security-scan.sh
```

Reports are generated in `docs/evidence/tv3/`.
