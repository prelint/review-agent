#!/usr/bin/env python3
"""Convert JSONL (file argument or stdin) to one JSON array on stdout."""

import json
import sys

from containment import contained_stdin, open_contained

source = open_contained(sys.argv[1]) if len(sys.argv) > 1 else contained_stdin()
print(json.dumps([json.loads(line) for line in source if line.strip()]))
