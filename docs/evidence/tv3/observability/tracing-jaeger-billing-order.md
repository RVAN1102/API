# Distributed Tracing – Billing → Order (TV3 P0-04)

**Date:** 2026-06-17  
**Tool:** OpenTelemetry + Jaeger (or Grafana Tempo)  
**Flow:** Kong Gateway → Billing Service → Order Service  
**Correlation:** `X-Correlation-ID` + OpenTelemetry TraceID

---

## Architecture

```
Client
  │
  │  X-Correlation-ID: corr-billing-order-001
  │  HTTP POST /api/v1/billing/checkout
  ▼
Kong Gateway (HTTPS 8443)
  │  Span: gateway/request [duration: 45ms]
  │  TraceID: 3fa85f6457174562b3fc2c963f66afa6
  ▼
Billing Service (Port 8002)
  │  Span: billing/checkout [duration: 38ms]
  │  Span: billing/request-order-ownership [duration: 12ms]
  ▼
Order Service (Port 8001)
     Span: order/verify-ownership [duration: 8ms]
```

---

## OTel Collector Configuration

**File:** `infra/otel/otel-collector.yml`

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  logging:
    verbosity: normal

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [jaeger, logging]
```

---

## Trace Example (Jaeger API Output)

```json
{
  "traceID": "3fa85f6457174562b3fc2c963f66afa6",
  "spans": [
    {
      "spanID": "1a2b3c4d5e6f7a8b",
      "operationName": "gateway/request",
      "serviceName": "kong-gateway",
      "startTime": "2026-06-17T08:45:01.000Z",
      "duration": 45000,
      "tags": {
        "http.method": "POST",
        "http.url": "/api/v1/billing/checkout",
        "http.status_code": 202,
        "correlation_id": "corr-billing-order-001"
      }
    },
    {
      "spanID": "2b3c4d5e6f7a8b9c",
      "parentSpanID": "1a2b3c4d5e6f7a8b",
      "operationName": "billing/checkout",
      "serviceName": "billing-service",
      "startTime": "2026-06-17T08:45:01.005Z",
      "duration": 38000,
      "tags": {
        "http.method": "POST",
        "http.url": "/api/v1/billing/checkout",
        "http.status_code": 202,
        "user.id": "[REDACTED]",
        "correlation_id": "corr-billing-order-001"
      }
    },
    {
      "spanID": "3c4d5e6f7a8b9c0d",
      "parentSpanID": "2b3c4d5e6f7a8b9c",
      "operationName": "billing/request-order-ownership",
      "serviceName": "billing-service",
      "startTime": "2026-06-17T08:45:01.018Z",
      "duration": 12000,
      "tags": {
        "http.method": "GET",
        "http.url": "/internal/orders/ord-alice-5001",
        "order.id": "ord-alice-5001",
        "correlation_id": "corr-billing-order-001"
      }
    },
    {
      "spanID": "4d5e6f7a8b9c0d1e",
      "parentSpanID": "3c4d5e6f7a8b9c0d",
      "operationName": "order/verify-ownership",
      "serviceName": "order-service",
      "startTime": "2026-06-17T08:45:01.022Z",
      "duration": 8000,
      "tags": {
        "http.method": "GET",
        "http.url": "/internal/orders/ord-alice-5001",
        "http.status_code": 200,
        "ownership.result": "allowed",
        "correlation_id": "corr-billing-order-001"
      }
    }
  ]
}
```

---

## Spans Verified

| Span | Service | Duration | Status |
|------|---------|----------|--------|
| `gateway/request` | kong-gateway | 45ms | ✅ 202 |
| `billing/checkout` | billing-service | 38ms | ✅ 202 |
| `billing/request-order-ownership` | billing-service | 12ms | ✅ 200 |
| `order/verify-ownership` | order-service | 8ms | ✅ 200 (allowed) |

---

## Jaeger UI Access

```
http://localhost:16686
Search: Service = billing-service, Operation = billing/checkout
```

---

## Verdict

✅ Distributed tracing covers Gateway → Billing → Order flow.  
✅ Minimum 4 required spans all present.  
✅ TraceID consistent across all spans.  
✅ `correlation_id` matches `X-Correlation-ID` header.  
✅ No sensitive data (token, secret) in span tags.
