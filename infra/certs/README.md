# Local mTLS Certificate Output

This directory is intentionally kept free of committed certificate material.

Generate local demo webhook mTLS files on demand:

```bash
bash demo/mtls/generate-mtls-certs.sh
```

The script writes short-lived demo files such as `webhook-ca.crt`,
`webhook-ca.key`, `webhook-client.crt`, `webhook-client.key`, and
`webhook-client.p12` into this directory. Generated private keys and PKCS#12
bundles are ignored by Git and must not be committed.

