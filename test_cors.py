import urllib.request
import json

req = urllib.request.Request("http://localhost:8080/realms/topic10-sme-api/protocol/openid-connect/token", method="OPTIONS")
req.add_header("Origin", "http://localhost:3000")
req.add_header("Access-Control-Request-Method", "POST")

try:
    with urllib.request.urlopen(req) as response:
        print("Status:", response.status)
        print("Headers:", response.headers)
except Exception as e:
    print("Error:", e)
