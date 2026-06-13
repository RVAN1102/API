# TLS Termination and HSTS

Kong listens on `8443` with TLS and terminates the external HTTPS connection.
The local Compose baseline uses Kong's generated development certificate, so
`curl -k` is acceptable only for the isolated demo.

```bash
bash demo/curl/test-https.sh
bash demo/curl/test-hsts.sh
```

The post-function plugin emits:

```text
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

only when the client-facing request uses HTTPS. HTTP responses intentionally
do not receive HSTS from this configuration.

## Generate a local certificate

```bash
bash demo/tls/generate-dev-certs.sh
```

Generated keys are ignored by Git. For an explicit certificate, mount the
generated files as read-only secrets and configure `KONG_SSL_CERT` and
`KONG_SSL_CERT_KEY`. Never commit the private key. Production should use a
trusted CA or managed certificate service, TLS 1.2+, automated renewal, and an
HTTP-to-HTTPS redirect at the load balancer or ingress.

