# Chapter 3 - Edge Gateway Security Design

## 3.1 API Gateway

The prototype places Kong OSS in DB-less mode at the only public API entry
point. Stable `/api/v1/*` paths are routed to upstream services, while the
Admin API is bound only to loopback. The current baseline uses real User,
Order, Billing, and Admin backend services behind Gateway-to-Backend mTLS
sidecars. Earlier API mock notes are historical and are not the default runtime
path.

## 3.2 TLS Termination and HSTS

Kong terminates HTTPS on port `8443`. This centralizes certificate handling
and provides a consistent transport-security boundary. HSTS is added only to
HTTPS responses with a one-year max age and subdomain coverage. Development
uses a self-signed certificate; production requires a trusted CA, automated
renewal, TLS 1.2+, and HTTP-to-HTTPS redirection.

## 3.3 CORS

The gateway allowlists three known frontend origins and only the methods and
headers required by the contract. Wildcard origins and credentialed CORS are
not enabled. This reduces unintended browser-based cross-origin access, while
authorization remains enforced by the application.

## 3.4 Rate Limiting

Health, billing, and webhook routes allow 60 requests per minute per IP.
Sensitive users, orders, and admin routes allow 10. This slows brute force,
credential stuffing, object enumeration, and administrative abuse. The local
counter is suitable for one Kong node; distributed deployment requires shared
Redis-backed or managed-gateway counters and per-user/per-tenant quotas.

## 3.5 WAF and Edge Filtering

Kong OSS is not described as a full WAF. The prototype rejects payloads over
1 MiB, unsupported methods, missing webhook headers, and a deliberately small
set of obvious SQLi/XSS probes. These controls demonstrate early rejection,
but production still requires schema validation, safe queries/output
encoding, and a maintained managed WAF or OWASP Core Rule Set deployment.

## 3.6 Gateway-to-Service mTLS

The mTLS design uses an internal CA, a client certificate for Kong, and server
certificates for backends. Both parties validate the peer certificate and
service identity. The default Docker Compose runtime enforces this through
Nginx sidecars in front of the backend services. Certificate-generation scripts
create local ignored lab certificates for reproducible testing.

## 3.7 Webhook HMAC and Replay Defense

Webhook senders sign
`timestamp + "." + nonce + "." + raw_body` using HMAC-SHA256. Receivers must
enforce a five-minute timestamp window, constant-time signature comparison,
atomic nonce storage with TTL, schema validation, and event idempotency.
Kong validates required header presence. A separate local receiver PoC proves
HMAC, timestamp, schema, and replay rejection without modifying team-owned
services. In production, these stateful checks belong to the receiving
Billing/Admin service with shared nonce storage.

## 3.8 Correlation ID

Kong preserves a caller's `X-Correlation-ID` or generates a UUID when absent,
then echoes it in the response. Services must propagate it and include it in
structured logs. This supports tracing and incident investigation without
treating the identifier as a security credential.

## 3.9 Evaluation

Reproducible curl scripts test routes, CORS, rate limits, edge filtering,
HTTPS, HSTS, and correlation IDs. A k6 workload records p50, p95, request rate,
and failed request rate across all health routes. Evidence files must record
actual command output; unexecuted checks must be marked as such rather than
reported as successful.
