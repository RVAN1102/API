# Correlation ID Policy

Kong's `correlation-id` plugin uses the `X-Correlation-ID` header.

- A caller-provided value is preserved.
- If absent, Kong generates a UUID.
- Kong echoes the final value in the downstream response.
- CORS permits and exposes the header.

Backends must include this value in structured logs and propagate it on
outbound calls. A correlation ID is observability metadata, not an
authentication credential; do not authorize requests based on it.

```bash
bash demo/curl/test-correlation-id.sh
```

