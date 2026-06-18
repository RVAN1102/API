# Chapter 5: DevSecOps, Observability, and Red Team (TV3)

## 5.1 Overview

TV3 focuses on embedding security into the operational lifecycle (DevSecOps), providing deep visibility into security events (Observability), and validating the defenses through offensive techniques (Red Team).

## 5.2 DevSecOps & Security Scanning

We integrated security testing into the CI/CD pipeline using GitHub Actions and provided a local scanning script (`ci/run-local-security-scan.sh`).

### Tools Used
1. **Bandit:** Static Application Security Testing (SAST) for Python code. Identifies insecure use of functions, hardcoded passwords, etc.
2. **Gitleaks:** Scans git history and current workspace for exposed secrets and credentials.
3. **Trivy:** Scans the filesystem and container images for known CVEs (Common Vulnerabilities and Exposures) in dependencies.

## 5.3 Observability Stack

A robust observability stack is critical for detecting and responding to attacks.

### 5.3.1 Architecture
- **Format:** All FastAPI services emit logs as structured JSON to stdout.
- **Collector:** **Promtail** reads the Docker container logs, extracts specific labels (e.g., `event_type`, `correlation_id`), and forwards them.
- **Storage:** **Loki** aggregates the logs.
- **Visualization:** **Grafana** provides the "API Security Overview" dashboard, tracking BOLA attempts, SSRF blocks, and webhook anomalies in real-time.

### 5.3.2 Security Logging Schema
Security-relevant logs include:
```json
{
  "event_type": "ssrf_blocked",
  "security_event": true,
  "client_ip": "192.168.1.5",
  "correlation_id": "uuid-1234",
  "message": "SSRF blocked: 169.254.169.254"
}
```

## 5.4 Red Team Operations & Vulnerability Demos

### 5.4.1 SSRF (Server-Side Request Forgery)
The Admin service demonstrates SSRF.
- **Vulnerability:** `/vulnerable` endpoint blindly fetches user-provided URLs.
- **Fix:** `/fixed` endpoint uses a strict blocklist (`validate_ssrf_url`) blocking private IPs, localhost, and cloud metadata IPs (`169.254.169.254`).

### 5.4.2 Webhook Forgery & Replay
The Billing service implements HMAC-SHA256 signature verification.
- **Attack Script:** `webhook-forgery.sh` attempts to send webhooks with missing or invalid signatures.
- **Replay Defense:** The service enforces a max timestamp age (e.g., 5 minutes) and tracks nonces to prevent replay attacks.

### 5.4.3 API Fuzzing (RESTler) & OWASP ZAP Active Scan/API Scan
- **ZAP:** OWASP ZAP Active Scan/API Scan runs against the OpenAPI definition through Kong and is the final DAST evidence. The retired passive-only workflow is not final DAST evidence.
- **RESTler:** Stateful API fuzzing configuration targeting the OpenAPI spec to find logic flaws and crashes.

## 5.5 MTTD / MTTR Metrics

We implemented a measurement script (`tests/metrics/measure-mttd-mttr.sh`) to calculate Mean Time to Detect (MTTD) and Mean Time to Respond (MTTR) from monitoring evidence. MTTD is measured from `attack_start` to `alert_fired` using Loki/Grafana alert state or LogQL threshold polling. MTTR is measured from `alert_fired` to `remediation_done` or verified containment. HTTP response latency is not used as an MTTD proxy.
