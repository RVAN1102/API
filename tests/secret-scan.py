#!/usr/bin/env python3
"""Secret scan for TV1 evidence directory."""
import re
import sys
from pathlib import Path

roots = [Path("docs/evidence/tv1")]
patterns = {
    "jwt":          re.compile(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'),
    "private_key":  re.compile(r'-----BEGIN.{0,20}PRIVATE KEY-----'),
    "client_secret":re.compile(r'client_secret\s*=\s*\S', re.I),
    "password_eq":  re.compile(r'password\s*=\s*\S', re.I),
}

bad = False
for root in roots:
    if not root.exists():
        print(f"[SKIP] {root} does not exist")
        continue
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except Exception as e:
            print(f"[WARN] Could not read {p}: {e}")
            continue
        for name, pat in patterns.items():
            if pat.search(text):
                print(f"[SECRET_LEAK] {name} found in: {p}")
                bad = True

if bad:
    print("\nSECRET_SCAN_FAIL: evidence files contain secrets. Fix before committing.")
    sys.exit(1)

print("SECRET_SCAN_PASS=true")
print("All TV1 evidence files are clean.")
