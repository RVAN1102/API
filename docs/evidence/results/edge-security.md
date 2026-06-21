# Edge Security

## Requirement Proven

Kong enforces the documented public gateway controls for TLS, CORS, headers,
rate limiting, and basic SQLi/XSS probe filtering.

## Command Or Evidence Source

```bash
bash tests/security/edge-hardening-tests.sh
```

Source configuration: `gateway/kong.yml`.

## Observed Result

| Control | Observed result |
|---|---|
| TLS 1.3 | handshake succeeded |
| TLS 1.2 | rejected |
| HSTS | header present |
| allowed local origin | allowed |
| hostile origin | `https://evil.example` not allowed |
| rate limit | HTTP `429` observed |
| SQLi probe | HTTP `403` observed |
| XSS probe | HTTP `403` observed |

## Scope And Limitation

The SQLi/XSS filter is a Kong pre-function for documented probe patterns. It is
not a full enterprise WAF.

