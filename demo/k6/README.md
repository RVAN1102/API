# Gateway Latency Benchmark

Start the stack, then run:

```bash
docker run --rm --network host \
  -v "$PWD/demo/k6:/scripts:ro" \
  grafana/k6 run /scripts/gateway-latency.js
```

On Docker Desktop where host networking is unavailable:

```bash
docker run --rm -e BASE_URL=https://host.docker.internal:8443 \
  -v "$PWD/demo/k6:/scripts:ro" \
  grafana/k6 run /scripts/gateway-latency.js
```

The summary reports request rate, failed request rate, median latency
(`med`, used as p50), and p95 latency. The conservative thresholds require
less than 1% failed requests and p95 below 500 ms in the local baseline.

