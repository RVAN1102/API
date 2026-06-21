# mTLS And Webhook Security

## Requirement

The API must prove the implemented mTLS paths and webhook authentication
controls without expanding the claim beyond the runtime configuration.

## Scoped mTLS Paths

- Client to Kong uses HTTPS/TLS on `https://localhost:8443`.
- Kong to backend services uses gateway-backend mTLS sidecars.
- Billing to Order ownership verification uses `https://order-mtls-proxy:8443`.
- Webhook uses HMAC timestamp/nonce validation plus mTLS client certificate.

mTLS coverage is limited to these paths.

## Gateway-To-Backend mTLS

Kong routes the four primary services to Nginx mTLS sidecars. Kong presents an
internal client certificate. Each sidecar verifies the client certificate before
forwarding to the service container.

Rerunnable command:

```bash
bash tests/security/gateway-backend-mtls-tests.sh
```

Curated evidence records successful health calls through all sidecars and
rejection of missing or wrong client certificates.

## Billing-To-Order mTLS

Billing is configured with:

```text
ORDER_SERVICE_URL=https://order-mtls-proxy:8443
ORDER_SERVICE_TLS_CA_CERT=/etc/s2s-mtls/ca.crt
ORDER_SERVICE_TLS_CLIENT_CERT=/etc/s2s-mtls/billing-client.crt
ORDER_SERVICE_TLS_CLIENT_KEY=/etc/s2s-mtls/billing-client.key
```

Curated evidence records that Billing reaches Order through the mTLS sidecar and
cannot use the plaintext Order application port directly.

## Webhook Controls

Webhook requests require:

```text
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

Billing validates HMAC-SHA256 over timestamp, nonce, and raw body. Redis stores
accepted nonce values with TTL to block replay. Kong checks client certificate
verification state and passes the result to Billing.

Rerunnable commands:

```bash
bash tests/security/webhook-tests.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

Curated evidence records valid webhook acceptance and rejection of invalid
signature, old timestamp, replayed nonce, missing headers, and missing client
certificate.

