# Loki Sample Recent Logs

**Generated:** 2026-06-18T10:20:26Z
**Purpose:** Diagnostic samples used only when status-code detection cannot match Kong/service logs.

## Selector `{job="docker"}`

accepted_by_loki=true

```json
[
  "172.20.0.1 - - [18/Jun/2026:10:20:22 +0000] \"GET /api/v1/users/me HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"fcea3170dce83b1e5c812c227e9c1816\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:20:22 +0000] \"GET /api/v1/users/me HTTP/1.1\" 429 92 \"-\" \"curl/8.5.0\" kong_request_id: \"1511db6a2ac295146ef7e77b3203ef3e\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:20:22 +0000] \"GET /api/v1/users/me HTTP/1.1\" 401 78 \"-\" \"curl/8.5.0\" kong_request_id: \"f0416766887c8275eccb273d8947f265\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:20:22 +0000] \"GET /api/v1/users/me HTTP/1.1\" 401 78 \"-\" \"curl/8.5.0\" kong_request_id: \"b9c30019e603b87edea7682c5a21226c\"\n",
  "172.20.0.1 - - [18/Jun/2026:10:20:22 +0000] \"GET /api/v1/users/me HTTP/1.1\" 401 78 \"-\" \"curl/8.5.0\" kong_request_id: \"b8ffca3a7fc7e6788a91085ed31c5c29\"\n",
  "{\"timestamp\": \"2026-06-18T10:20:22Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.30.0.3\", \"correlation_id\": \"mttd-401-10\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}\n",
  "{\"timestamp\": \"2026-06-18T10:20:22Z\", \"level\": \"WARNING\", \"service\": \"user-service\", \"method\": \"GET\", \"path\": \"/api/v1/users/me\", \"status_code\": 401, \"client_ip\": \"172.30.0.3\", \"correlation_id\": \"mttd-401-9\", \"event_type\": \"auth_failure\", \"reason\": \"invalid_token\", \"category\": \"invalid_token\", \"security_event\": true}\n",
  "INFO:     172.30.0.3:41962 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized\n",
  "INFO:     172.30.0.3:41962 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized\n",
  "INFO:     172.30.0.3:41962 - \"GET /api/v1/users/me HTTP/1.1\" 401 Unauthorized\n"
]
```

## Selector `{container=~".*kong.*"}`

accepted_by_loki=true

```json
[]
```

## Selector `{container_name=~".*kong.*"}`

accepted_by_loki=true

```json
[]
```

## Selector `{compose_service="kong"}`

accepted_by_loki=true

```json
[]
```

## Selector `{service_name="kong"}`

accepted_by_loki=true

```json
[]
```

## Selector `{filename=~".*kong.*"}`

accepted_by_loki=true

```json
[]
```

## Selector `{}`

accepted_by_loki=false

```json
{
  "raw": "parse error : queries require at least one regexp or equality matcher that does not have an empty-compatible value. For instance, app=~\".*\" does not meet this requirement, but app=~\".+\" will\n"
}
```

