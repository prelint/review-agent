#!/usr/bin/env bash
# Tests for the python scripts in scripts/. Runs offline; needs python3.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0
check() {
  if [ "$2" = "$3" ]; then
    echo "ok: $1"
  else
    echo "FAIL: $1: expected [$2], got [$3]"
    fail=1
  fi
}

# --- hash-bodies.py ---

hashes() {
  printf '{"body": %s}\n' "$1" \
    | python3 "${SCRIPTS}/hash-bodies.py" \
    | python3 -c 'import json,sys; o=json.load(sys.stdin); print(o["body_hash"], o["substance_hash"])'
}

read -r B1 S1 <<<"$(hashes '"Confidence Score: 3/5"')"
read -r B2 S2 <<<"$(hashes '"**Confidence Score: 3/5**"')"
read -r B3 S3 <<<"$(hashes '"Confidence Score: 5/5"')"
check "emphasis edit moves body_hash" "moved" "$([ "$B1" != "$B2" ] && echo moved)"
check "emphasis edit keeps substance_hash" "same" "$([ "$S1" = "$S2" ] && echo same)"
check "verdict digit moves substance_hash" "moved" "$([ "$S1" != "$S3" ] && echo moved)"

read -r _ S4 <<<"$(hashes '"<img align=\"right\" src=\"https://x/a.svg\" alt=\"Agree\"> point"')"
read -r _ S5 <<<"$(hashes '"<img align=\"right\" src=\"https://x/a.svg\" alt=\"Disagree\"> point"')"
check "img alt text survives" "moved" "$([ "$S4" != "$S5" ] && echo moved)"

read -r _ S6 <<<"$(hashes '"see [the fix](https://github.com/x/y/pull/1) here"')"
read -r _ S7 <<<"$(hashes '"see the fix here"')"
check "link keeps text, drops url" "same" "$([ "$S6" = "$S7" ] && echo same)"

read -r _ S8 <<<"$(hashes '"claim text <!-- hidden marker -->"')"
read -r _ S9 <<<"$(hashes '"claim text."')"
check "html comment and trailing punctuation strip" "same" "$([ "$S8" = "$S9" ] && echo same)"

read -r B10 S10 <<<"$(hashes 'null')"
read -r B11 S11 <<<"$(printf '{"surface": "review"}\n' | python3 "${SCRIPTS}/hash-bodies.py" \
  | python3 -c 'import json,sys; o=json.load(sys.stdin); print(o["body_hash"], o["substance_hash"])')"
check "null body hashes like missing body" "same" "$([ "$B10 $S10" = "$B11 $S11" ] && echo same)"

# --- join-threads.py ---

cat > "${TMP}/comments.jsonl" <<'EOF'
{"id": 1, "in_reply_to": null}
{"id": 2, "in_reply_to": 1}
{"id": 3, "in_reply_to": 99}
EOF
cat > "${TMP}/threads.jsonl" <<'EOF'
{"id": "T1", "comments": {"nodes": [{"databaseId": 1}]}}
{"id": "T2", "comments": {"nodes": []}}
EOF

out="$(python3 "${SCRIPTS}/join-threads.py" "${TMP}/comments.jsonl" "${TMP}/threads.jsonl" 2>"${TMP}/err")"
rc=$?
check "reply joins through its root" "T1" \
  "$(printf '%s\n' "$out" | python3 -c 'import json,sys; print([json.loads(l)["thread_id"] for l in sys.stdin][1])')"
check "missing parent yields null" "None" \
  "$(printf '%s\n' "$out" | python3 -c 'import json,sys; print([json.loads(l)["thread_id"] for l in sys.stdin][2])')"
check "count mismatch exits 3" "3" "$rc"

cat > "${TMP}/threads-ok.jsonl" <<'EOF'
{"id": "T1", "comments": {"nodes": [{"databaseId": 1}]}}
EOF
printf '{"id": 1, "in_reply_to": null}\n' > "${TMP}/comments-ok.jsonl"
python3 "${SCRIPTS}/join-threads.py" "${TMP}/comments-ok.jsonl" "${TMP}/threads-ok.jsonl" >/dev/null 2>&1
check "matching counts exit 0" "0" "$?"

# --- ledger-counts.py ---

cat > "${TMP}/ledger.json" <<'EOF'
{
  "items": [
    {"claims": [
      {"severity": "BLOCKER", "status": "open"},
      {"severity": "REQUIRED", "status": "fixed"},
      {"severity": "BLOCKER", "status": "unresolvable"}
    ]}
  ],
  "findings": [
    {"severity": "BLOCKER", "status": "open"},
    {"severity": "BLOCKER", "status": "posted"},
    {"severity": "NIT", "status": "dropped"}
  ]
}
EOF
check "open counts claims and findings" "2" "$(python3 "${SCRIPTS}/ledger-counts.py" open "${TMP}/ledger.json")"
check "blockers split closed sets per kind" "3" "$(python3 "${SCRIPTS}/ledger-counts.py" blockers "${TMP}/ledger.json")"
python3 "${SCRIPTS}/ledger-counts.py" open "${TMP}/absent.json" >/dev/null 2>&1
check "missing ledger exits non-zero" "1" "$?"
python3 "${SCRIPTS}/ledger-counts.py" nonsense "${TMP}/ledger.json" >/dev/null 2>&1
check "unknown mode exits 2" "2" "$?"

# --- json-body.py ---

body='reply with `backticks` and "quotes" and $(pwd)'
roundtrip="$(printf '%s' "$body" | python3 "${SCRIPTS}/json-body.py" \
  | python3 -c 'import json,sys; sys.stdout.write(json.load(sys.stdin)["body"])')"
check "json-body round-trips shell metacharacters" "$body" "$roundtrip"

# --- jsonl-to-json.py ---

printf '{"a": 1}\n\n{"b": 2}\n' > "${TMP}/rows.jsonl"
check "jsonl-to-json skips blank lines" '[{"a": 1}, {"b": 2}]' \
  "$(python3 "${SCRIPTS}/jsonl-to-json.py" "${TMP}/rows.jsonl")"
check "jsonl-to-json reads stdin" '[{"a": 1}]' \
  "$(printf '{"a": 1}\n' | python3 "${SCRIPTS}/jsonl-to-json.py")"

exit "$fail"
