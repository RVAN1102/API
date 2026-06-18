# Monthly Cost Estimate – SME API Security Platform (TV3 P1-01)

**Date:** 2026-06-17  
**Context:** Cloud API-Based Network Application Security for Small Company Services  
**Target:** SME với ~1,000-10,000 API requests/day

---

## Tier 1: Lab – Self-Hosted OSS (Current)

| Component | Tool | Cost |
|-----------|------|------|
| API Gateway | Kong OSS | **$0** |
| Identity Provider | Keycloak | **$0** |
| Secrets Management | HashiCorp Vault OSS | **$0** |
| Observability | Grafana + Loki + Promtail | **$0** |
| Tracing | Jaeger (all-in-one) | **$0** |
| Container Orchestration | Docker Compose | **$0** |
| Compute (VPS) | ~2 vCPU, 4GB RAM | **~$20/month** |
| Storage | 50GB SSD | **~$5/month** |
| **Total Lab OSS** | | **~$25/month** |

---

## Tier 2: Production – SME Managed Services

### Cloud Platform: AWS (example)

| Component | Service | Est. Cost/Month |
|-----------|---------|----------------|
| API Gateway / WAF | AWS API Gateway + WAF | $15–30 (1M calls/month) |
| Identity Provider | AWS Cognito | $0–55 (free tier: 50K MAU) |
| Secrets Manager | AWS Secrets Manager | ~$0.40/secret + $0.05/10K calls ≈ $5 |
| KMS | AWS KMS | ~$1/CMK + $0.03/10K calls ≈ $3 |
| Logs | CloudWatch Logs | ~$0.50/GB ingested ≈ $5 |
| Monitoring | CloudWatch Metrics | ~$3 (custom metrics) |
| Compute (ECS Fargate) | 2 vCPU, 4GB (0.5 vCPU tasks) | ~$40 |
| Load Balancer | ALB | ~$16 |
| Storage (RDS) | db.t3.micro | ~$15 |
| **Total Production AWS** | | **~$100–150/month** |

---

### Cloud Platform: GCP (alternative)

| Component | Service | Est. Cost/Month |
|-----------|---------|----------------|
| API Gateway | Cloud Endpoints / Apigee | $0–200 (depends on tier) |
| Identity | Firebase Auth / Identity Platform | $0–46 (free up to 50K MAU) |
| Secrets | Secret Manager | ~$0.06/version + API calls ≈ $2 |
| KMS | Cloud KMS | ~$0.06/key/month + $0.03/10K ops ≈ $3 |
| Logs | Cloud Logging | Free tier: 50GB/month |
| Monitoring | Cloud Monitoring | Free tier covers most SME needs |
| Compute (Cloud Run) | 2 services, 0.5 vCPU each | ~$10–30 |
| **Total Production GCP** | | **~$60–130/month** |

---

## Expected Free Tier / Low-Cost Options

| Service | Free Tier | Notes |
|---------|----------|-------|
| AWS Cognito | 50,000 MAU free | Sufficient for most SMEs |
| GCP Firebase Auth | Unlimited | Free for basic auth |
| AWS API Gateway | 1M calls/month (12 months) | Year 1 startup |
| CloudWatch Logs | 5GB/month | Upgrade for production |
| GCP Logging | 50GB/month | Generous free tier |

---

## Total Cost Summary

| Environment | Monthly Cost | Notes |
|-------------|-------------|-------|
| **Lab (OSS)** | **~$25** | Self-hosted VPS only |
| **Production (AWS)** | **~$100–150** | Managed services, SME load |
| **Production (GCP)** | **~$60–130** | Alternative; slightly cheaper |

---

## Cost Optimization Recommendations

1. **Start with free tiers**: Cognito (50K MAU), Firebase Auth (unlimited)
2. **Use Vault OSS**: Avoid $1,000+/month Vault Enterprise
3. **Cloud Run vs. ECS**: Cloud Run has lower idle costs
4. **Request caching**: Reduce API Gateway call count
5. **Log retention**: Keep only 7 days in hot storage; archive to S3/GCS

---

> **Note:** Estimates based on 2024-2026 public pricing. Actual costs depend on traffic patterns.  
> All estimates use public cloud pricing calculators.
