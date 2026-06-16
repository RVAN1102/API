# TV1 P0.9 - Webhook mTLS Status

Status: LIMITATION

The current prototype implements webhook HMAC signature verification, replay nonce protection, and timestamp freshness validation.

Full mutual TLS client-certificate verification for the webhook channel is not implemented in this checkpoint.

This checkpoint must not be described as "mTLS completed". mTLS will be implemented later in a separate hardening branch, for example:

feat/tv1-mtls-service-channel
