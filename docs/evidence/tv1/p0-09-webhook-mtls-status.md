# TV1 P0.9 - Webhook mTLS Status

Status: PASS

The webhook channel is protected by mutual TLS (mTLS) at the Edge gateway (Kong), in addition to HMAC signature verification, replay nonce protection, and timestamp freshness validation.

- **Kong Gateway** is configured with `KONG_SSL_VERIFY_CLIENT=optional` and a trusted CA (`webhook-ca.crt`).
- Kong's `pre-function` Lua plugin checks `ngx.var.ssl_client_verify` and injects the `X-Mtls-Client-Verified: SUCCESS` header if the client certificate is valid.
- The **Billing Service** explicitly enforces this header when `WEBHOOK_MTLS_REQUIRED=true`, rejecting requests with HTTP 401 if the client certificate was not verified by the gateway.

This architecture ensures that only authorized clients possessing a valid client certificate issued by the internal CA can successfully send webhooks to the backend service.
