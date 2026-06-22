# Vault/KMS-style Secret Retrieval Overhead

## Requirement Proven

Measures HashiCorp Vault dev-mode KV secret-read latency as a lab proxy for KMS-style secret retrieval overhead.

## Command Or Evidence Source

`bash tests/metrics/measure-kms-overhead.sh`

## Observed Result

| Metric | Value |
|---|---:|
| endpoint | `http://localhost:8200/v1/secret/data/api/webhook` |
| attempted samples | 30 |
| successful HTTP 200 samples | 0 |
| p50 latency ms | n/a |
| p95 latency ms | n/a |
| average latency ms | n/a |

## Scope And Limitation

This is not an AWS KMS measurement. It uses local HashiCorp Vault dev-mode secret reads as a lab proxy for secret-retrieval overhead. The script writes only HTTP status and timing data; no secret value or response body is written to evidence.
