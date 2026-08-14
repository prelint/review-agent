#!/usr/bin/env python3
"""Add body_hash and substance_hash to each JSONL object.

Reads JSONL from the file argument or stdin. Writes JSONL to stdout.
Hashes the "body" field. A missing or null body hashes as "".

The normalisation steps are the contract in reference/intake.md under
"Content hash". This script is their one implementation. Change the list
there and this file in the same commit.
"""

import hashlib
import json
import re
import sys
import unicodedata

from containment import contained_stdin, open_contained


def _img_alt(match: re.Match) -> str:
    # Verdict badges live in alt and nowhere else. An img with no alt
    # becomes one space, like any other tag.
    alt = re.search(r'\balt=("([^"]*)"|\'([^\']*)\'|([^\s>]+))', match.group(0), re.I)
    if not alt:
        return " "
    return alt.group(2) or alt.group(3) or alt.group(4) or " "


def normalise(body: str) -> str:
    s = body
    # 1. Strip HTML comments, script and style blocks entirely.
    s = re.sub(r"<!--.*?-->", "", s, flags=re.S)
    s = re.sub(r"<(script|style)\b.*?</\1\s*>", "", s, flags=re.S | re.I)
    # 2. Replace an img tag with its alt text.
    s = re.sub(r"<img\b[^>]*>", _img_alt, s, flags=re.I)
    # 3. Replace every other tag with one space, keeping the text between tags.
    s = re.sub(r"<[^>]+>", " ", s)
    # 4. Replace [text](url) with text; drop bare URLs.
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = re.sub(r"https?://\S+", "", s)
    # 5. Strip code-fence language tags, heading marks, blockquote marks,
    #    list bullets, then emphasis. Fence lines go first: they need their
    #    backticks still present to be found.
    s = re.sub(r"^[ \t]*```[ \t]*\S+[ \t]*$", " ", s, flags=re.M)
    s = re.sub(r"^[ \t]*#{1,6}[ \t]+", " ", s, flags=re.M)
    s = re.sub(r"^[ \t]*>[ \t]?", " ", s, flags=re.M)
    s = re.sub(r"^[ \t]*(?:[-+*]|\d+[.)])[ \t]+", " ", s, flags=re.M)
    s = re.sub(r"[*_`]", "", s)
    # 6. Collapse whitespace runs to one space; strip the ends.
    s = re.sub(r"\s+", " ", s).strip()
    # 7. Strip trailing punctuation from the whole string: Unicode category P
    #    plus whitespace, so an appended ellipsis or fullwidth stop cannot
    #    re-open an unchanged item. Not category S: a trailing currency or
    #    math symbol ("5€") is part of the claim, and erasing it would let an
    #    altered claim keep its hash.
    while s and (unicodedata.category(s[-1]).startswith("P") or s[-1].isspace()):
        s = s[:-1]
    # 8. Casefold.
    return s.casefold()


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def main() -> int:
    source = open_contained(sys.argv[1]) if len(sys.argv) > 1 else contained_stdin()
    for line in source:
        if not line.strip():
            continue
        item = json.loads(line)
        body = item.get("body") or ""
        item["body_hash"] = sha256(body)
        item["substance_hash"] = sha256(normalise(body))
        print(json.dumps(item))
    return 0


if __name__ == "__main__":
    sys.exit(main())
