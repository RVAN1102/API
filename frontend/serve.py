#!/usr/bin/env python3
"""
Simple HTTP Server for the Security Test Dashboard.
Run this script to serve the frontend on http://localhost:3002
"""

import http.server
import socketserver
import os

PORT = 3002

# Change directory to the frontend folder
web_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(web_dir)

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    """Serve files with no-cache headers to prevent stale JS/CSS being served."""
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def log_message(self, format, *args):
        # Suppress per-request logs to keep terminal clean
        pass

with socketserver.TCPServer(("", PORT), NoCacheHandler) as httpd:
    print(f"==================================================")
    print(f"🚀 API Security Dashboard is running!")
    print(f"👉 Open your browser at: http://localhost:{PORT}")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
