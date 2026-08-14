#!/usr/bin/env python3
"""Wrap a reply body in {"body": ...} for gh api --input -.

Pass the reply path (under RUN_DIR) as the argument, or pipe the body in.
Never build this JSON by shell interpolation: bodies quote code, and the
backticks they carry feed command substitution.
"""

import json
import sys

from containment import contained_stdin, open_contained

source = open_contained(sys.argv[1]) if len(sys.argv) > 1 else contained_stdin()
print(json.dumps({"body": source.read()}))
