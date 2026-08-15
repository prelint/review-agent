#!/usr/bin/env python3
"""Count open or blocking work in a ledger.

Usage: ledger-counts.py open|blockers LEDGER

Prints one integer. Exits non-zero when the ledger is missing or invalid,
which the caller treats as ledger-unreadable. Status vocabularies match
reference/output.md, section 5.
"""

import json
import sys

from containment import open_contained

CLOSED_CLAIM = {"fixed", "rebutted", "deferred", "informational", "unresolvable"}
CLOSED_FINDING = {"fixed", "posted", "deferred", "rebutted", "dropped"}
BLOCKER_CLOSED_CLAIM = {"fixed", "rebutted", "unresolvable"}
BLOCKER_CLOSED_FINDING = {"fixed", "rebutted"}


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in ("open", "blockers"):
        print("usage: ledger-counts.py open|blockers LEDGER", file=sys.stderr)
        return 2
    try:
        with open_contained(sys.argv[2]) as f:
            led = json.load(f)
        claims = [c for i in led["items"] for c in i["claims"]]
        findings = led.get("findings", [])
        if sys.argv[1] == "open":
            n = sum(1 for c in claims if c["status"] not in CLOSED_CLAIM) + sum(
                1 for f in findings if f.get("status") not in CLOSED_FINDING
            )
        else:
            n = sum(
                1
                for c in claims
                if c.get("severity") == "BLOCKER"
                and c.get("status") not in BLOCKER_CLOSED_CLAIM
            ) + sum(
                1
                for f in findings
                if f.get("severity") == "BLOCKER"
                and f.get("status") not in BLOCKER_CLOSED_FINDING
            )
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"ledger-counts: {exc}", file=sys.stderr)
        return 1
    print(n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
