# Edge Filtering Rules

## Scope

This prototype uses Kong OSS gateway controls. It is **not** a full enterprise
WAF and does not claim complete OWASP rule coverage.

Implemented controls:

- Maximum request payload: 1 MiB, rejected by Kong before proxying.
- Route method allowlists; unsupported methods do not match a route.
- Required `X-Webhook-*` header presence on webhook paths.
- A small pre-function filter for obvious query/body probes:
  `<script`, `javascript:`, `union select`, and `' or 1=1`.
- Per-route rate limiting.

The basic pattern filter is intentionally narrow. It demonstrates rejection at
the edge but must not replace schema validation, parameterized database
queries, contextual output encoding, or a managed WAF/ModSecurity deployment.

## Test

```bash
bash demo/curl/test-waf-filter.sh
```

Expected outcomes:

- Valid health request: `HTTP 200`.
- SQLi sample: `HTTP 403`.
- Unsupported `TRACE`: no matching route (`HTTP 404`).
- Oversized request: rejected by the request-size-limiting plugin. Kong OSS
  3.9 returns `HTTP 417` for this plugin response.

False positives and bypasses are possible with pattern matching. Production
deployment should run a maintained OWASP Core Rule Set in detection mode,
tune it against representative traffic, then progressively enable blocking.
