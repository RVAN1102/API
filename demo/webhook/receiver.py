#!/usr/bin/env python3
"""Stateful webhook verification PoC for the TV1 edge-security demo."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.environ.get("WEBHOOK_SECRET", "dev-webhook-secret-change-me").encode()
MAX_AGE = int(os.environ.get("WEBHOOK_MAX_AGE_SECONDS", "300"))
NONCES: dict[str, int] = {}
NONCE_LOCK = threading.Lock()


class WebhookHandler(BaseHTTPRequestHandler):
    server_version = "WebhookDemo/1.0"

    def log_message(self, fmt: str, *args: object) -> None:
        print(json.dumps({"event": "http_access", "message": fmt % args}))

    def respond(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        correlation_id = self.headers.get("X-Correlation-ID")
        if correlation_id:
            self.send_header("X-Correlation-ID", correlation_id)
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path != "/api/v1/webhooks/payment":
            self.respond(404, {"error": "not_found"})
            return

        timestamp_value = self.headers.get("X-Webhook-Timestamp")
        nonce = self.headers.get("X-Webhook-Nonce")
        supplied_signature = self.headers.get("X-Webhook-Signature")
        if not timestamp_value or not nonce or not supplied_signature:
            self.respond(401, {"error": "missing_webhook_header"})
            return

        try:
            timestamp = int(timestamp_value)
        except ValueError:
            self.respond(403, {"error": "invalid_timestamp"})
            return

        now = int(time.time())
        if abs(now - timestamp) > MAX_AGE:
            self.respond(403, {"error": "expired_timestamp"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)
        signed = timestamp_value.encode() + b"." + nonce.encode() + b"." + raw_body
        expected = "sha256=" + hmac.new(SECRET, signed, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, supplied_signature):
            self.respond(401, {"error": "invalid_signature"})
            return

        with NONCE_LOCK:
            expired = [value for value, expiry in NONCES.items() if expiry < now]
            for value in expired:
                del NONCES[value]
            if nonce in NONCES:
                self.respond(403, {"error": "replayed_nonce"})
                return
            NONCES[nonce] = now + MAX_AGE

        try:
            event = json.loads(raw_body)
            for required in ("event_id", "event_type", "checkout_id"):
                if not event.get(required):
                    raise ValueError(required)
        except (json.JSONDecodeError, ValueError):
            self.respond(400, {"error": "invalid_event_schema"})
            return

        self.respond(200, {"status": "accepted", "event_id": event["event_id"]})


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), WebhookHandler).serve_forever()

