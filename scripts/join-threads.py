#!/usr/bin/env python3
"""Join inline comments to review threads on each thread's first comment.

Usage: join-threads.py COMMENTS_JSONL THREADS_JSONL

Writes every comment back out as JSONL with thread_id set. A null
thread_id on an inline comment marks a fetch or pagination failure, and
Stage 5 treats that item as unresolvable. See reference/intake.md.

Prints the thread-count check to stderr. Exits 3 on a count mismatch,
after writing the joined output.
"""

import json
import sys


def read_jsonl(path: str) -> list:
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: join-threads.py COMMENTS_JSONL THREADS_JSONL", file=sys.stderr)
        return 2
    comments = read_jsonl(sys.argv[1])
    threads = read_jsonl(sys.argv[2])

    comment_by_id = {c["id"]: c for c in comments}
    # comments.nodes[0].databaseId is the REST id of the comment that
    # started the thread. nodes can be empty when that comment was deleted.
    root_to_thread = {
        t["comments"]["nodes"][0]["databaseId"]: t["id"]
        for t in threads
        if t["comments"]["nodes"]
    }

    for c in comments:
        root, seen = c["id"], set()
        while True:  # walk up to the thread starter
            parent = (comment_by_id.get(root) or {}).get("in_reply_to")
            if not parent or parent in seen:  # a parent may be missing or cyclic
                break
            seen.add(root)
            root = parent
        c["thread_id"] = root_to_thread.get(root)
        print(json.dumps(c))

    # Only comments whose in_reply_to is null start threads. Counting all
    # inline comments would fire on every thread that has a reply.
    roots = sum(1 for c in comments if not c.get("in_reply_to"))
    check = f"join-threads: {len(threads)} threads, {roots} thread roots"
    if len(threads) != roots:
        print(check + " - MISMATCH, pagination may have failed", file=sys.stderr)
        return 3
    print(check, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
