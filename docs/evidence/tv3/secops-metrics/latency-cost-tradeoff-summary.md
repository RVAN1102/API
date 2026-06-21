# Latency And SME Cost Trade-Off Summary

**Scope:** p50/p95 latency measurement method for Gateway/WAF/security controls and SME-focused cost/complexity trade-offs.  
**Rule:** only claim numeric p50/p95 values when a script or evidence file was actually run. Commands below are safe smoke/regression commands; they do not change runtime security logic.

## Latency Measurement Matrix

| Control | Expected Overhead Source | Metric: p50/p95 Latency | How To Measure | Evidence Command | SME Trade-Off |
|---|---|---|---|---|---|
| Kong Gateway routing over default HTTPS lab path | TLS termination, route lookup, upstream proxying, headers | p50/p95 from health requests; current smoke output is to be filled by running script | Run a small curl-based smoke against health endpoints through `BASE_URL` | `BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh` | Low operational cost in lab; adds a central enforcement point and modest latency; acceptable for SME APIs when p95 stays within SLA |
| Kong HTTPS path, TLS, HSTS, and edge controls | TLS handshake/session reuse plus Gateway route/plugins | p50/p95 from HTTPS health requests; to be filled by running script against `HTTPS_BASE_URL` | Provide HTTPS URL if Kong TLS is exposed locally | `HTTPS_BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh` | Better transport security; operational cost is certificate lifecycle and troubleshooting; upgrade automation when manual cert handling becomes frequent |
| Gateway/WAF/security plugin path | Token validation, rate-limit plugin, request size/WAF filters, logging | Current smoke script records a low-request sanity check; older pre-HTTPS k6 reports are archived and should not be treated as current HTTPS evidence | Use k6 benchmark for fuller load, smoke script for quick lab check | `k6 run -e BASE_URL=https://localhost:8443 tests/performance/k6-latency-test.js`; `bash scripts/metrics/latency-overhead-smoke.sh` | Security controls add latency but reduce incident impact; for SME, keep simple defaults first and tune when p95 or false positives hurt users |
| Direct service baseline versus Gateway path | Difference between internal service and Gateway route | Overhead is `gateway p50/p95 - direct p50/p95`; to be filled only when `DIRECT_BASE_URL` is provided | Compare the same health path through Gateway and direct service where safe in a lab | `BASE_URL=https://localhost:8443 DIRECT_BASE_URL=http://localhost:<service-port> REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh` | Direct exposure should remain lab-only; production should prefer Gateway even if direct service is faster |
| Vault/KMS secret retrieval | Production startup secret fetch or KMS decrypt call | Existing evidence documents manual Vault read latency as a startup/rotation budget; current lab runtime secrets are injected by Docker Compose env, not fetched directly by every service from Vault | Keep secret reads out of hot request path; measure startup and rotation separately | See `docs/evidence/tv3/metrics/kms-vault-call-overhead.md` | Low per-request impact if cached at startup; operational cost is secret rotation and availability planning |
| Loki/Grafana logging and alerting | Structured log serialization, log shipping, alert evaluation interval | Request latency impact is indirect; SecOps detection latency is measured as MTTD, not HTTP p95 | Use MTTD script for detection; use latency smoke/k6 for request path | `ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/metrics/measure-mttd-mttr.sh` | Improves visibility at medium operational cost; managed logging is attractive once self-hosted operations consume too much time |

## Current Evidence Pointers

| Evidence | Claim Type | Notes |
|---|---|---|
| `BASE_URL=https://localhost:8443 REQUESTS=5 bash scripts/metrics/latency-overhead-smoke.sh` | current lightweight latency smoke command | Writes transient p50/p95 output under `.artifacts/test-runs/metrics/`; use a fresh run before making current latency claims |
| `demo/k6/gateway-latency.js` | reproducible smoke workload | Health endpoint k6 script; useful when k6 is installed or Docker k6 is available |
| `scripts/metrics/latency-overhead-smoke.sh` | reproducible curl-based smoke method | Writes transient CSV/Markdown summaries to `.artifacts/test-runs/metrics/` |
| `docs/evidence/tv3/metrics/kms-vault-call-overhead.md` | measured manual Vault read latency | Treats Vault/KMS as production startup/rotation budget, not proof that every lab service fetches runtime secrets from Vault |

## SME Cost And Trade-Off Analysis

| Area | Option Used In Lab | Production Recommendation For SME | Security Benefit | Operational Cost/Complexity | When To Upgrade |
|---|---|---|---|---|---|
| Identity Provider | Keycloak self-hosted in Docker lab | Start with managed IdP when the team is small; keep Keycloak only if customization or data residency requires it | MFA, OIDC/OAuth2, centralized user lifecycle, token revocation | Self-hosted: Medium/High; managed: Low/Medium but vendor-dependent | Upgrade when uptime, patching, MFA policy, or audit requirements exceed team capacity |
| Secrets/KMS | Vault OSS local/dev mode | Use cloud KMS/Secrets Manager or managed Vault for production; keep local Vault for learning and demos | Centralized secret storage, rotation workflow, reduced hardcoded-secret risk | OSS local: Medium; managed KMS: Low/Medium; managed Vault: Medium/High | Upgrade when production secrets, rotation evidence, HA, audit logs, or compliance are required |
| API Gateway/WAF | Kong OSS local Gateway | Managed API Gateway/WAF for SME production unless Kong expertise already exists | Rate limiting, TLS edge, request filtering, centralized routing and auth policy | Kong OSS: Medium; managed Gateway/WAF: Low/Medium with provider lock-in | Upgrade when 24/7 availability, WAF rules, DDoS protection, and automated cert lifecycle matter more than plugin flexibility |
| Logging/SIEM | Loki/Grafana self-hosted | Managed logging/SIEM for production alerts and retention; keep Loki/Grafana for lab observability | Alerting, incident timelines, correlation IDs, MTTD evidence | Self-hosted: Medium; managed: Low/Medium; SIEM tuning can become High | Upgrade when retention, on-call alerts, compliance search, or cross-service incident response becomes hard to operate locally |
| Webhook replay nonce store | In-process/lab nonce protection evidence | Use Redis or another shared TTL store for multi-replica production webhook replay protection | Prevents replay across replicas and restarts; supports timestamp freshness controls | Low/Medium for managed Redis; Medium for self-hosted Redis | Upgrade before horizontal scaling webhook handlers or accepting high-value payment events |
| DAST/Fuzzing | ZAP/RESTler automation in repo evidence | Keep automated ZAP/RESTler in CI and schedule periodic manual pentest for release gates | Repeatable regression detection plus expert review for business logic flaws | Automation: Low/Medium after setup; manual pentest: Medium/High | Upgrade to external/manual testing before launch, major auth changes, or compliance/security review |

## Reporting Guidance

- Report p50/p95 from `k6` or the smoke script output only after running the command in the target lab.
- Report overhead only when both a Gateway path and a comparable direct baseline are measured in the same run.
- Use Low/Medium/High operational cost categories unless internal pricing data is available.
- Keep raw credentials and tokens out of evidence; record token length, redacted values, or command method only.
