# Vault/KMS-style Secret Retrieval Overhead

## Requirement Proven

Measures local HashiCorp Vault KV secret-read latency as a lab proxy for KMS-style secret retrieval overhead.

## Command Or Evidence Source

`bash tests/metrics/measure-kms-overhead.sh`

## Observed Result

| Metric | Value |
|---|---:|
| endpoint | `https://localhost:8200/v1/secret/data/api/webhook` |
| attempted samples | 30 |
| successful HTTP 200 samples | 30 |
| p50 latency ms | 13.237 |
| p95 latency ms | 17.676 |
| average latency ms | 13.143 |

## Scope And Limitation

This is not an AWS KMS measurement. It uses local HashiCorp Vault secret reads as a lab proxy for secret-retrieval overhead. The script writes only HTTP status and timing data; no secret value or response body is written to evidence.
