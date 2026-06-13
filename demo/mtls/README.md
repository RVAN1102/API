# mTLS Demo Certificates

Run `bash demo/mtls/generate-mtls-certs.sh` to create a short-lived demo CA,
gateway identity, and backend identity under `demo/mtls/certs/`.

The generated private keys and certificate signing requests are ignored by
Git. This script demonstrates the certificate roles only; follow
`gateway/mtls.md` before enabling runtime mTLS.

