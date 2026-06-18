# Attack Simulation Scripts

This directory contains scripts used to simulate attacks against the API Gateway and backend services.

## Scripts

| Script | Target | Description |
|--------|--------|-------------|
| `bola-object-access.sh` | Order Service | Tests BOLA vulnerable and fixed endpoints. |
| `rate-limit-trigger.sh` | Kong Gateway | Sends rapid requests to trigger HTTP 429. |
| `ssrf-attack.sh` | Admin Service | Tests SSRF vulnerable and fixed endpoints. |
| `token-replay.sh` | User / Billing | Tests expired JWTs and duplicate webhook nonces. |
| `webhook-forgery.sh` | Billing Service | Tests HMAC-SHA256 signature verification. |

## Running
Tokens must be obtained first. Example:
```bash
ACCESS_TOKEN=$(cat /tmp/user-token.txt) bash tests/attack/ssrf-attack.sh
```
