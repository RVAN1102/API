#!/usr/bin/env python3
"""Create or verify the canonical HMAC-SHA256 webhook signature."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import sys


def signature(secret: str, timestamp: str, nonce: str, raw_body: bytes) -> str:
    message = timestamp.encode() + b"." + nonce.encode() + b"." + raw_body
    digest = hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()
    return f"sha256={digest}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret", required=True)
    parser.add_argument("--timestamp", required=True)
    parser.add_argument("--nonce", required=True)
    parser.add_argument("--body", required=True, help="Exact raw request body")
    parser.add_argument("--verify", help="Compare against this signature")
    args = parser.parse_args()

    expected = signature(
        args.secret, args.timestamp, args.nonce, args.body.encode("utf-8")
    )
    if args.verify is None:
        print(expected)
        return 0

    valid = hmac.compare_digest(expected, args.verify)
    print("valid" if valid else "invalid")
    return 0 if valid else 1


if __name__ == "__main__":
    sys.exit(main())

