# mTLS Demo Certificates

Run `bash demo/mtls/generate-mtls-certs.sh` to create the short-lived webhook
mTLS demo CA and client certificate under `infra/certs/`.

The generated private keys and certificate signing requests are ignored by
Git. The generated CA certificate is mounted by Kong, and the test suite uses
the generated CA private key to create ephemeral webhook client certificates.

Generated files are local-only runtime inputs. Do not commit `.key`, `.p12`,
CSR, serial, or generated certificate files.
