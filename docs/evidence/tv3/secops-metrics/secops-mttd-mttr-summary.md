# SecOps MTTD/MTTR Summary

**Scope:** Topic 10 quantitative SecOps evidence for attack/defense scenarios.  
**Rule:** do not use HTTP response latency as MTTD. MTTD starts at the attack signal and ends when Loki/alert/query evidence detects it. MTTR starts at detection and ends when containment or remediation is verified.

## Measurement Method

| Metric | Definition | Source of truth |
|---|---|---|
| MTTD | `logql_detection_time - attack_start` or `alert_fired - attack_start` | Loki LogQL threshold polling, Grafana alert state, or structured log timestamp evidence |
| MTTR | `remediation_done - logql_detection_time` or `remediation_done - alert_fired` | Follow-up blocked request, runbook action completed, or regression evidence |
| Status | `measured`, `implemented`, or `simulated` | `measured` requires timestamped lab output; `implemented` means control/evidence exists; `simulated` means method is defined but not yet executed for that scenario |

## Scenario Matrix

| Attack/Signal | Detection Source | Expected Alert/Log Field | MTTD Measurement Method | MTTR/Remediation Action | Evidence File/Link | Status |
|---|---|---|---|---|---|---|
| 401 unauthorized spike | Loki LogQL threshold polling over user-service auth failures; Grafana rule `HighUnauthorizedRate` | `event_type=auth_failure`, `status_code=401`, `security_event=true`, `correlation_id=mttd-401-*` | Measured by `tests/metrics/measure-mttd-mttr.sh` as `logql_detection_time - attack_start`; rerun the script against the current HTTPS gateway for fresh timing evidence | Verify containment with a follow-up blocked unauthenticated/invalid-token request; investigate source IP/user, block source if needed, rotate impacted credentials | `docs/evidence/tv3/metrics/401_unauthorized_spike-diagnostics.md` | measured |
| 403 forbidden/BOLA attempt | Loki LogQL threshold polling over order-service 403 responses; Grafana rule `HighForbiddenRate`; BOLA regression evidence | `status_code=403`, `event_type=api_request` or `authz_forbidden`, `correlation_id=mttd-403-bola-*` | Measured by `tests/metrics/measure-mttd-mttr.sh` as `logql_detection_time - attack_start`; rerun the script against the current HTTPS gateway for fresh timing evidence | Verify fixed endpoint still returns 403 for cross-user object access; keep ownership check enabled; review actor/target pattern and source | `docs/evidence/tv3/metrics/403_forbidden_bola_spike-diagnostics.md`, `docs/evidence/tv2/gvhd-authz-negative-after-client-credentials.txt` | measured |
| 429 rate-limit abuse | Loki LogQL threshold polling over Kong access logs; Grafana rule `RateLimitTriggered` | HTTP access log with `429`, or structured `event_type=rate_limit_triggered`, `client_ip`, `correlation_id` | Measured by `tests/metrics/measure-mttd-mttr.sh` as `logql_detection_time - attack_start`; rerun the script against the current HTTPS gateway for fresh timing evidence | Verify continued 429 containment at Gateway; optionally tune Kong limits, block abusive IP, and review false positives | `docs/evidence/tv3/metrics/429_rate_limit_spike-diagnostics.md`, `docs/evidence/tv1/edge-final/rate-limit-429-final.txt` | measured |
| SSRF attempt | Loki alert/query over Admin service SSRF logs; alert `SSRFAttemptDetected`; red-team SSRF evidence | `reason=ssrf_blocked`, `blocked_url`, `status_code=403`, `correlation_id`, metadata host/IP pattern | Method defined; measured in lab evidence if the SSRF script and Loki query are executed together. Existing alert evidence documents an expected timeline of about one Loki evaluation interval, but this summary does not claim a fresh runtime MTTD number without timestamped measurement output | Fixed endpoint blocks metadata/private targets with 403; preserve network egress controls; triage requested URL and actor; keep vulnerable endpoint demo-only | `docs/evidence/tv3/observability/alert-ssrf-or-403.md`, `docs/evidence/tv1/ssrf-egress/network-egress-control-runtime-after-fix.txt` | implemented |
| Webhook invalid signature | Structured webhook security log and regression evidence; intended alert `WebhookInvalidSignature` | `event_type=webhook_invalid_signature`, `decision=blocked`, `nonce`, HTTP 401 | Method defined; measured in lab evidence if webhook-forgery script timestamps are correlated with Loki log timestamps. No runtime MTTD number is claimed here without executing that measurement | Reject bad HMAC with 401; notify sender owner; rotate webhook secret only if compromise is suspected; verify valid webhook still succeeds | `docs/evidence/tv1/webhook-final/webhook-invalid-signature.txt`, `docs/runbooks/incident-response.md` | implemented |
| Webhook replay nonce | Structured webhook replay log and regression evidence; intended alert `WebhookReplayDetected` | `event_type=webhook_replay_detected`, `decision=blocked`, `nonce`, HTTP 401/403 depending on route generation | Method defined; measured in lab evidence if replay timestamps are correlated with Loki log timestamps. No runtime MTTD number is claimed here without executing that measurement | Reject replayed nonce; keep nonce store TTL aligned with timestamp freshness window; use Redis-backed shared TTL storage for multi-replica/restart safety | `docs/evidence/tv1/webhook-final/webhook-replay-nonce.txt`, `docs/evidence/tv1/webhook-final/persistent-nonce-store.md`, `docs/runbooks/incident-response.md` | implemented |

## Regeneration Commands

```bash
# Timestamped MTTD/MTTR measurement for 401, 403/BOLA, and 429:
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/metrics/measure-mttd-mttr.sh

# SSRF and webhook detection method checks:
ACCESS_TOKEN="${ADMIN_TOKEN}" bash tests/attack/ssrf-attack.sh
bash tests/attack/webhook-forgery.sh
```

New measurement output should be reviewed before replacing official evidence. Do not commit access tokens, refresh tokens, client secrets, private keys, Vault tokens, or raw webhook secrets.
