# Admin Service (TV3)

## Overview

FastAPI-based Admin Service with maintenance and SSRF demo endpoints.

## Endpoints

| Method | Path                                    | Auth Required | Description                 |
|--------|-----------------------------------------|---------------|-----------------------------|
| GET    | /api/v1/admin/health                    | No            | Health check                |
| POST   | /api/v1/admin/maintenance               | Yes (Bearer)  | Run maintenance action      |
| POST   | /api/v1/admin/metadata-fetch/vulnerable | Yes (Bearer)  | SSRF vulnerable (no validation) |
| POST   | /api/v1/admin/metadata-fetch/fixed      | Yes (Bearer)  | SSRF fixed (URL blocklist)  |

## SSRF Demo

```bash
# SSRF Vulnerable: fetches any URL
curl -X POST https://localhost:8443/api/v1/admin/metadata-fetch/vulnerable \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "Content-Type: application/json" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}'

# SSRF Fixed: blocked by URL validation
curl -X POST https://localhost:8443/api/v1/admin/metadata-fetch/fixed \
  -H "Authorization: Bearer $(cat /tmp/user-token.txt)" \
  -H "Content-Type: application/json" \
  -d '{"fetch_url":"http://169.254.169.254/latest/meta-data/"}'
# → 403 ssrf_blocked
```

## See Also

- `services/admin/ssrf-protection.md` – SSRF protection design
- `tests/attack/ssrf-attack.sh` – attack simulation
