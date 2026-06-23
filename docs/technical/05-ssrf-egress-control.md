# SSRF And Egress Control

## Requirement

The Admin service must demonstrate SSRF risk safely and provide a protected
metadata-fetch path. Backend containers must not have broad network egress.

## Admin Endpoints

| Endpoint | Behavior |
|---|---|
| `/api/v1/admin/metadata-fetch/vulnerable` | controlled vulnerable demonstration endpoint |
| `/api/v1/admin/metadata-fetch/fixed` | validates URL scheme, hostname, and resolved IP before fetch |

The fixed endpoint blocks metadata hosts, loopback, link-local ranges, private
addresses, null network, dangerous schemes, and non-HTTP schemes.

## Network Controls

Compose attaches application services to internal networks. Redis is
Docker-internal. Billing reaches Order through `billing-order-mtls-internal` and
the Order direct HTTPS/mTLS path.

## Evidence

Rerunnable commands:

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/attack/ssrf-attack.sh
bash tests/security/network-egress-control-tests.sh
```

Curated evidence records the fixed metadata endpoint blocking metadata access
with HTTP `403` and network egress checks passing `27/27` assertions.

## Scope

The vulnerable endpoint exists only as a controlled risk demonstration. The
current defense claim is based on the fixed endpoint and network egress test.

