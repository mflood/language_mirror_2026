#!/usr/bin/env python3
"""Email notifications for the daily news pipeline, via AWS SES.

Sender:    news@sixwandsstudios.com  (domain DKIM-verified in SES us-east-1)
Recipient: flood.today@gmail.com     (override with NEWS_NOTIFY_EMAIL)

Never raises: a notification failure must not break a publish. send() returns
True/False and prints a warning on failure.

CLI (used by scheduled_run.sh for failure alerts):
    notify_email.py --subject "..." [--body "..."] [--body-file path] [--tail N]
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

REGION = "us-east-1"
SENDER = "Six Wands News <news@sixwandsstudios.com>"
DEFAULT_RECIPIENT = "flood.today@gmail.com"


def send(subject: str, body: str) -> bool:
    recipient = os.environ.get("NEWS_NOTIFY_EMAIL", DEFAULT_RECIPIENT)
    try:
        import boto3
        ses = boto3.client("ses", region_name=REGION)
        ses.send_email(
            Source=SENDER,
            Destination={"ToAddresses": [recipient]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {"Text": {"Data": body, "Charset": "UTF-8"}},
            },
        )
        print(f"  ✉ notified {recipient}: {subject}")
        return True
    except Exception as e:  # noqa: BLE001 — notification must never break the caller
        print(f"  ⚠ email notification failed ({type(e).__name__}): {e}", file=sys.stderr)
        return False


def main() -> int:
    p = argparse.ArgumentParser(description="Send a pipeline notification email via SES")
    p.add_argument("--subject", required=True)
    p.add_argument("--body", default="")
    p.add_argument("--body-file", type=Path, help="Append this file's content to the body")
    p.add_argument("--tail", type=int, default=0,
                   help="With --body-file: include only the last N lines")
    args = p.parse_args()

    body = args.body
    if args.body_file and args.body_file.exists():
        text = args.body_file.read_text(encoding="utf-8", errors="replace")
        if args.tail:
            text = "\n".join(text.splitlines()[-args.tail:])
        body = f"{body}\n\n{text}" if body else text

    return 0 if send(args.subject, body) else 1


if __name__ == "__main__":
    raise SystemExit(main())
