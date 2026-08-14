#!/usr/bin/env python3
"""Convert JSONL (file argument or stdin) to one JSON array on stdout."""

import json
import sys

source = open(sys.argv[1], encoding="utf-8") if len(sys.argv) > 1 else sys.stdin
print(json.dumps([json.loads(line) for line in source if line.strip()]))
