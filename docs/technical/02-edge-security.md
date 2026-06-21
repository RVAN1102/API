# Edge Security

## Requirement

The public gateway must enforce HTTPS, safe browser access policy, baseline
security headers, request-size control, rate limiting, and documented probe
filtering.

## Implementation

Source: `gateway/kong.yml`.

| Control | Implementation |
|---|---|
| TLS | Kong listens on `0.0.0.0:8443 ssl` with TLS protocol set to `TLSv1.3` |
| CORS | Kong CORS plugin allows configured local/demo origins |
| Correlation ID | Kong correlation ID plugin uses `X-Correlation-ID` |
| Request size | Kong request-size-limiting plugin allows `1` megabyte |
| Rate limit | normal routes `60/min`, sensitive routes `10/min` |
| Basic SQLi/XSS filter | Kong pre-function rejects documented obvious probe strings |
| Security headers | Kong post-function sets HSTS on HTTPS plus common browser hardening headers |

Kong OSS is not a full enterprise WAF. The gateway filter covers the explicit
probe patterns implemented in `gateway/kong.yml`.

## Evidence

Rerunnable command:

```bash
bash tests/security/edge-hardening-tests.sh
```

Curated evidence records TLS 1.3 success, TLS 1.2 rejection, HSTS present,
hostile origin rejection, rate limiting with HTTP `429`, and SQLi/XSS probes
blocked with HTTP `403`.

