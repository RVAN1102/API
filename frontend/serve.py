#!/usr/bin/env python3
"""
Simple HTTP Server for the Security Test Dashboard.
Run this script to serve the frontend on http://localhost:3000
"""

import http.server
import socketserver
import os

PORT = 3000

# Change directory to the frontend folder
web_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(web_dir)

Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"==================================================")
    print(f"🚀 API Security Dashboard is running!")
    print(f"👉 Open your browser at: http://localhost:{PORT}")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
