# mTLS And Webhook Security

## Requirement

The API must prove the implemented HTTPS/mTLS paths and webhook authentication
controls without expanding the claim beyond the runtime configuration.

## Direct HTTPS/mTLS Paths

- Client to Kong uses HTTPS on `https://localhost:8443`.
- Kong to backend services uses direct HTTPS/mTLS to backend port `8443`.
- Billing to Order ownership verification uses `https://order-service:8443`.
- Webhook traffic uses HMAC timestamp/nonce validation plus mTLS client
  certificate verification.

## Gateway-To-Backend mTLS

Kong presents the internal `kong-client` certificate to each backend service.
Each backend validates the client certificate against the internal CA and
presents its own backend server certificate.

Rerunnable command:

```bash
bash tests/security/gateway-backend-mtls-tests.sh
```

Curated evidence records successful health calls through all four direct
HTTPS/mTLS upstreams and rejection of missing or wrong client certificates.

## Billing-To-Order mTLS

Billing is configured with:

```text
ORDER_SERVICE_URL=https://order-service:8443
ORDER_SERVICE_TLS_CA_CERT=/etc/internal-tls/ca.crt
ORDER_SERVICE_TLS_CLIENT_CERT=/etc/internal-tls/billing-client.crt
ORDER_SERVICE_TLS_CLIENT_KEY=/etc/internal-tls/billing-client.key
```

Curated evidence records that Billing reaches Order through the approved direct
HTTPS/mTLS path and cannot use a plaintext Order application port.

## Webhook Controls

Webhook requests require:

```text
X-Webhook-Timestamp
X-Webhook-Nonce
X-Webhook-Signature
```

Billing validates HMAC-SHA256 over timestamp, nonce, and raw body. The nonce
store blocks replay for the configured TTL. Kong checks client certificate
verification state and passes the result to Billing.

Rerunnable commands:

```bash
bash tests/security/webhook-tests.sh
bash tests/security/webhook-nonce-persistence-tests.sh
```

Curated evidence records valid webhook acceptance and rejection of invalid
signature, old timestamp, replayed nonce, missing headers, and missing client
certificate.
