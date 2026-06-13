# TV1 Evidence

Evidence files in this directory must contain actual command output. Do not
manually mark a control as passing.

Start the stack and collect the curl/webhook evidence:

```bash
docker compose -f infra/docker-compose.yml up -d --build
bash demo/curl/collect-tv1-evidence.sh
```

Collect the k6 summary separately using `demo/k6/README.md` and save its
terminal summary as `docs/evidence/tv1/k6-gateway-summary.txt`.

The local webhook receiver PoC provides passing valid, invalid-signature, and
replay-protection evidence without modifying team-owned Billing/Admin code.
