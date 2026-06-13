# Rate Limit Policy

Kong's OSS `rate-limiting` plugin uses the source IP as the client identity and
the local in-memory policy for this single-node prototype.

| Route class | Routes | Limit |
|---|---|---|
| Health and normal | health routes, billing, webhooks | 60 requests/minute/IP |
| Sensitive | users, orders, admin | 10 requests/minute/IP |

The lower limit reduces brute force, credential stuffing, BOLA enumeration,
and admin abuse. Health routes use a separate route so normal checks and the
k6 baseline are not constrained by the sensitive endpoint limit.

`policy: local` is appropriate only for this one-node demo. A multi-node
deployment must use Redis-backed limits or a managed gateway so all nodes
share counters. Authenticated production traffic should additionally limit by
consumer/user and tenant, not only by IP.

Run:

```bash
bash demo/curl/test-rate-limit.sh
```

Expected result: one or more requests return `HTTP 429`.

