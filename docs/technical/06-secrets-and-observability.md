# Secrets And Observability

## Requirement

The repository must keep generated secret material out of source control and
provide local logs, correlation IDs, dashboards, and traces for security
analysis.

## Secret Handling

`scripts/bootstrap-lab-env.sh` prepares local ignored runtime values. Do not
commit `.env`, private keys, `.p12` files, generated certificates, token values,
`.artifacts`, raw secrets, `__pycache__`, or `.pyc`.

`infra/.env.example` is committed as an example file. Local runtime values are
not evidence.

## Vault Scope

Vault runs in dev mode at `http://localhost:8200` as a lab-local secret workflow
surface. The Compose runtime still uses ignored local environment values for
required local secrets. The docs do not claim every runtime secret is fetched
from Vault.

## Observability

| Component | Role |
|---|---|
| Promtail | reads Docker logs |
| Loki | stores and queries logs |
| Grafana | local dashboard and alert UI at `http://localhost:3001` |
| Jaeger | local trace UI |
| OpenTelemetry Collector | trace pipeline |

Services and gateway controls emit structured request and security events. Kong
uses `X-Correlation-ID` for request correlation.

## Evidence

Relevant commands:

```bash
bash tests/security/verify-no-tracked-secrets.sh
bash tests/metrics/measure-mttd-mttr.sh
```

Curated evidence records source-package secret checks and states that no current
MTTD or MTTR timing value is claimed.
