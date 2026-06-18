# RESTler Execution Summary

**Date:** 2026-06-18T10:36:06Z
**RESTler:** Docker image: mcr.microsoft.com/restlerfuzzer/restler:v8.5.0
**OpenAPI path:** `/home/rvan1102/API-gvhd-p0-integrity/services/openapi.yaml`
**Target URL:** `http://localhost:8000`
**Auth/token handling:** No token is printed. Set `RESTLER_TOKEN` only if a local RESTler dictionary/settings flow consumes it; this runner does not synthesize auth evidence.

## Results

| Metric | Value |
|---|---:|
| OpenAPI operations covered by spec | 14 |
| Rendered/sent requests | {"gc": 0, "main_driver": 40, "LeakageRuleChecker": 0, "ResourceHierarchyChecker": 0, "UseAfterFreeChecker": 0, "InvalidDynamicObjectChecker": 0, "PayloadBodyChecker": 67, "ExamplesChecker": 0} |
| Bugs found | unknown |

## Status Codes

see RESTler logs

## Evidence Files

- `restler-compile.log`
- `restler-test.log`
- `restler-fuzz-lean.log`
- `testing_summary.json`
- `runSummary.json`
- `errorBuckets.json`

RESTler evidence is valid only when compile, test, and fuzz-lean all complete successfully.
