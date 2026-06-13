# Gateway-to-Backend mTLS Design

mTLS is prepared as an integration design and certificate-generation demo. It
is not enabled in the default Compose stack because the team-owned backend
services do not yet expose TLS listeners.

## Trust model

- `demo-ca.crt`: demo internal CA trusted by Kong and backend services.
- `gateway.crt`/`gateway.key`: client identity presented by Kong upstream.
- `backend.crt`/`backend.key`: server identity presented by the backend.
- Kong verifies the backend certificate chain and expected service DNS name.
- The backend verifies Kong's client certificate chain and rejects clients
  without a certificate issued by the demo CA.

## Generate local-only material

```bash
bash demo/mtls/generate-mtls-certs.sh
```

All private keys are generated under an ignored `certs/` directory.

## Runtime integration

1. Add HTTPS listeners and client-certificate verification to each backend.
2. Mount CA/certificate/key files as secrets, never in images or Git.
3. Change Kong upstream URLs to `https://<service>:<tls-port>`.
4. Configure Kong's upstream client certificate and trusted CA.
5. Verify certificate rotation and rejection of untrusted/expired clients.

For production, use a dedicated internal PKI or service mesh with automated
short-lived certificate issuance and rotation.

