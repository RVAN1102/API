# Observability Stack (TV3)

## Overview

The observability stack collects, stores, and visualizes structured JSON logs
from all API services.

## Components

| Component | Purpose               | Port  |
|-----------|-----------------------|-------|
| Loki      | Log aggregation       | 3100  |
| Promtail  | Log collector         | 9080  |
| Grafana   | Dashboard/alerting    | 3001  |

## Architecture

```
Services (billing, admin, user, order)
  │ stdout JSON logs
  ▼
Docker container log files (/var/lib/docker/containers/)
  │
  ▼ (Promtail reads)
Loki (stores and indexes logs)
  │
  ▼
Grafana (queries Loki via LogQL)
```

## Start Observability Stack

```bash
docker compose -f infra/docker-compose.yml up -d loki promtail grafana
```

## Access Grafana

```
URL:      http://localhost:3001
Username: admin
Password: admin
```

Pre-configured dashboard: **API Security Overview**

## Key LogQL Queries

```logql
# All security events
{job="docker"} |= "security_event"

# BOLA attempts
{event_type="bola_attempt"}

# SSRF blocked
{event_type="ssrf_blocked"}

# Invalid webhook signatures
{event_type="webhook_invalid_signature"}

# HTTP 401/403 responses
{job="docker"} |= "\"status_code\":401"
{job="docker"} |= "\"status_code\":403"
```

## Log Schema

See `observability/log-schema.md`.

## Alert Rules

See `observability/alerts/api-security-alerts.md` and `observability/alerts/loki-alert-rules.yml`.
