#!/usr/bin/env python3
"""Wrap stdin in {"body": ...} for gh api --input -.

Never build this JSON by shell interpolation: bodies quote code, and the
backticks they carry feed command substitution.
"""

import json
import sys

print(json.dumps({"body": sys.stdin.read()}))
