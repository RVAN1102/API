# RESTler API Fuzzing

This directory contains configuration for Microsoft RESTler, a stateful REST API fuzzing tool.

## Files
- `run-restler-check.sh`: Runner script (requires RESTler Docker image)
- `restler-settings.json`: Configuration pointing to the OpenAPI spec

## Target
The fuzzing targets the OpenAPI spec defined in `services/openapi.yaml`.

## Running
```bash
bash tests/restler/run-restler-check.sh
```

Reports are generated in `docs/evidence/tv3/`.
