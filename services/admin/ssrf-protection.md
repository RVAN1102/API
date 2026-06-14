# SSRF Protection Design (TV3)

## Overview

Server-Side Request Forgery (SSRF) occurs when an attacker tricks the server
into making HTTP requests to unintended targets (internal metadata services,
local ports, private network resources).

OWASP API Security Top 10: **API7:2023 Server Side Request Forgery**.

---

## Vulnerable Endpoint

`POST /api/v1/admin/metadata-fetch/vulnerable`

**Flaw**: Accepts any URL and fetches it without validation.
An attacker can send `http://169.254.169.254/latest/meta-data/` to read
cloud instance metadata (AWS, GCP, Azure).

---

## Fixed Endpoint

`POST /api/v1/admin/metadata-fetch/fixed`

**Fix**: URL validation via `validate_ssrf_url()` in `main.py`.

### Blocklist

| Category           | Blocked Values                                  |
|--------------------|-------------------------------------------------|
| AWS metadata       | `169.254.169.254`                               |
| GCP metadata       | `metadata.google.internal`                      |
| Loopback           | `localhost`, `127.0.0.0/8`, `::1`               |
| Link-local         | `169.254.0.0/16`                                |
| Private IPv4       | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`|
| Null network       | `0.0.0.0/8`                                     |
| Dangerous schemes  | `file://`, `gopher://`, `ftp://`                |
| Non-http schemes   | Any scheme other than `http` or `https`         |

### DNS Rebinding Protection

After hostname validation, the service resolves the hostname via DNS and
checks the resolved IP against private ranges. This prevents attacks where
a public hostname resolves to a private IP.

---

## Demo Scenarios

| URL                                | Endpoint   | Expected |
|------------------------------------|------------|----------|
| `http://169.254.169.254/...`       | /vulnerable | 200 (flaw)|
| `http://169.254.169.254/...`       | /fixed      | 403 ssrf_blocked |
| `http://localhost:8200/v1/sys/...` | /fixed      | 403 ssrf_blocked |
| `file:///etc/passwd`               | /fixed      | 403 ssrf_blocked |

---

## Log Events

Security events emitted when SSRF is detected:

| Event Type     | Description                        |
|----------------|------------------------------------|
| `ssrf_attempt` | SSRF attempted via vulnerable endpoint |
| `ssrf_blocked` | SSRF blocked by fixed endpoint     |

---

## References

- OWASP: https://owasp.org/API-Security/editions/2023/en/0xa7-server-side-request-forgery/
- `tests/attack/ssrf-attack.sh`
- `observability/alerts/loki-alert-rules.yml`
