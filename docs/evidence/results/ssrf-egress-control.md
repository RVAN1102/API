# SSRF And Egress Control

## Requirement Proven

The fixed Admin metadata-fetch endpoint blocks metadata targets, and backend
network egress is constrained by internal Docker networks.

## Command Or Evidence Source

```bash
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/attack/ssrf-attack.sh
bash tests/security/network-egress-control-tests.sh
```

## Observed Result

| Check | Observed result |
|---|---|
| fixed metadata endpoint with metadata IP | HTTP `403` |
| backend service networks | internal |
| Billing and Order unapproved shared network | absent |
| Billing to Order path | `billing-order-mtls-internal` and `https://order-service:8443` |
| Admin to metadata target | unreachable in egress test |
| Admin to public Internet target used by test | unreachable in egress test |
| egress test summary | `28/28` assertions passed |

## Scope And Limitation

The vulnerable endpoint remains available as a controlled demonstration path.
The defense claim is based on the fixed endpoint and network egress test.
