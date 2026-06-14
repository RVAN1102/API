# Capstone Project - Cloud API-Based Network Application Security

## Overview

This project is a prototype for **Cloud API-Based Network Application Security
for Small Company Services**. The goal is to design, implement, and evaluate a
practical API security architecture suitable for a small company with limited
operations budget.

The prototype focuses on:

- API Gateway routing and edge security.
- CORS policy.
- Rate limiting against brute force and abuse.
- Gateway-level filtering for abnormal requests.
- HTTPS/TLS termination and HSTS.
- mTLS design for gateway-to-backend traffic.
- Signed webhook protection using HMAC-SHA256, timestamp, and nonce.
- Correlation ID propagation for tracing.
- Gateway latency benchmark with k6.

## Current Prototype Architecture

```text
Client / Test Scripts
        |
        v
Kong API Gateway
  - Routes
  - CORS
  - Rate limiting
  - Request size limit
  - Basic edge filter
  - HTTPS + HSTS
  - Correlation ID
        |
        +--> Prism API mock from services/openapi.yaml
        |
        +--> Webhook receiver demo with HMAC/replay verification
```

The non-webhook APIs are mocked with Prism based on
`services/openapi.yaml`. This allows the gateway and security controls to be
tested before the real backend services are integrated.

## Main Folders

| Path | Purpose |
|---|---|
| `gateway/` | Kong configuration and gateway security documentation |
| `infra/` | Docker Compose runtime |
| `services/openapi.yaml` | Shared API contract |
| `demo/curl/` | Curl-based gateway test scripts |
| `demo/webhook/` | Webhook signing scripts and demo receiver |
| `demo/k6/` | Gateway latency benchmark |
| `demo/tls/` | Self-signed TLS certificate helper |
| `demo/mtls/` | mTLS certificate helper and notes |
| `docs/evidence/tv1/` | Recorded test evidence |
| `docs/chapter3/` | Report content for gateway edge design |

## Requirements

See `requirements.txt` for the required tools. Minimum practical setup:

- Docker Desktop
- Docker Compose
- Git Bash
- Python 3.13
- OpenSSL
- curl

k6 can be installed locally, but this project also supports running k6 through
Docker.

## Run The Prototype

From the project root:

```bash
docker compose -f infra/docker-compose.yml up -d --build
docker compose -f infra/docker-compose.yml ps
```

Expected services:

- `infra-kong-1`
- `infra-api-mock-1`
- `infra-webhook-demo-1`

Gateway endpoints:

- HTTP: `http://localhost:8000`
- HTTPS: `https://localhost:8443`
- Kong Admin API: `http://127.0.0.1:8001`

## Test Gateway Routes

```bash
bash demo/curl/test-gateway-routes.sh
```

Expected result: all health endpoints return `HTTP 200`.

## Test CORS

```bash
bash demo/curl/test-cors.sh
```

Expected result: response includes allowed CORS headers for
`http://localhost:5173`.

## Test Rate Limiting

```bash
bash demo/curl/test-rate-limit.sh
```

Expected result: repeated requests eventually return `HTTP 429`.

## Test Edge Filtering

```bash
bash demo/curl/test-waf-filter.sh
```

Expected results:

- valid request passes,
- SQLi/XSS sample is rejected,
- invalid method is rejected,
- oversized body is rejected by the gateway.

## Test Correlation ID

```bash
bash demo/curl/test-correlation-id.sh
```

Expected result: `X-Correlation-ID` is preserved and echoed in the response.

## Test HTTPS And HSTS

On Windows, native `curl` may fail against local self-signed certificates due
to Schannel behavior. Use Docker curl for reliable testing:

```bash
docker run --rm curlimages/curl:latest --insecure --include \
  https://host.docker.internal:8443/api/v1/users/health

docker run --rm curlimages/curl:latest --insecure --dump-header - \
  --output /dev/null https://host.docker.internal:8443/api/v1/users/health
```

Expected result: HTTPS request succeeds and the response includes:

```text
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

## Test Webhook Security

In Git Bash, set `PYTHON_BIN` if `python` points to the Windows Store alias:

```bash
export PYTHON_BIN=/c/Users/duynh/AppData/Local/Programs/Python/Python313/python.exe
```

Valid webhook:

```bash
bash demo/webhook/send-valid-webhook.sh
```

Expected result: `HTTP_STATUS:200`.

Invalid signature:

```bash
bash demo/webhook/send-invalid-signature.sh
```

Expected result: `HTTP_STATUS:401`.

Replay nonce:

```bash
bash demo/webhook/send-replay-webhook.sh
```

Expected result: first request returns `HTTP_STATUS:200`, second request
returns `HTTP_STATUS:403`.

## Run k6 Benchmark

```bash
docker run --rm -e BASE_URL=http://host.docker.internal:8000 \
  -v "$PWD/demo/k6:/scripts:ro" \
  grafana/k6 run /scripts/gateway-latency.js
```

The benchmark checks:

- p50 latency,
- p95 latency,
- request rate,
- failed request rate.

## Collect Evidence

```bash
export PYTHON_BIN=/c/Users/duynh/AppData/Local/Programs/Python/Python313/python.exe
bash demo/curl/collect-tv1-evidence.sh
```

Evidence is saved under:

```text
docs/evidence/tv1/
```

The k6 output should be saved as:

```text
docs/evidence/tv1/k6-gateway-summary.txt
```

## Stop The Stack

```bash
docker compose -f infra/docker-compose.yml down
```

## Notes

- Do not commit real secrets, private keys, `.env`, `.pem`, or `.key` files.
- Demo certificates are generated only for local testing.
- Kong OSS is used for gateway-level filtering, not as a full enterprise WAF.
- Runtime mTLS is documented and prepared, but not enabled by default because
  backend services do not yet expose TLS listeners.

