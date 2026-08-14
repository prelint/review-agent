#!/usr/bin/env bash
# Tests for the python scripts in scripts/. Runs offline; needs git and python3.
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

# Fixture repo. File arguments must live under RUN_DIR
# (<git-dir>/review-agent), so every fixture goes there.
git init --quiet "${TMP}/repo"
RA="${TMP}/repo/.git/review-agent"
mkdir -p "${RA}"
in_repo() { (cd "${TMP}/repo" && "$@"); }

# --- hash-bodies.py ---

hashes() {
  printf '{"body": %s}\n' "$1" \
    | in_repo python3 "${SCRIPTS}/hash-bodies.py" \
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

read -r _ S12 <<<"$(hashes '"claim text…"')"
read -r _ S13 <<<"$(hashes '"claim text"')"
check "unicode trailing punctuation strips" "same" "$([ "$S12" = "$S13" ] && echo same)"

read -r B10 S10 <<<"$(hashes 'null')"
read -r B11 S11 <<<"$(printf '{"surface": "review"}\n' | in_repo python3 "${SCRIPTS}/hash-bodies.py" \
  | python3 -c 'import json,sys; o=json.load(sys.stdin); print(o["body_hash"], o["substance_hash"])')"
check "null body hashes like missing body" "same" "$([ "$B10 $S10" = "$B11 $S11" ] && echo same)"

printf '{"id": 7, "body": "x"}\n' > "${RA}/items.jsonl"
check "file argument under RUN_DIR works" "7" \
  "$(in_repo python3 "${SCRIPTS}/hash-bodies.py" "${RA}/items.jsonl" \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"

# --- join-threads.py ---

cat > "${RA}/comments.jsonl" <<'EOF'
{"id": 1, "in_reply_to": null}
{"id": 2, "in_reply_to": 1}
{"id": 3, "in_reply_to": 99}
EOF
cat > "${RA}/threads.jsonl" <<'EOF'
{"id": "T1", "comments": {"nodes": [{"databaseId": 1}]}}
{"id": "T3", "comments": {"nodes": [{"databaseId": 42}]}}
EOF

out="$(in_repo python3 "${SCRIPTS}/join-threads.py" "${RA}/comments.jsonl" "${RA}/threads.jsonl" 2>/dev/null)"
rc=$?
check "reply joins through its root" "T1" \
  "$(printf '%s\n' "$out" | python3 -c 'import json,sys; print([json.loads(l)["thread_id"] for l in sys.stdin][1])')"
check "missing parent yields null" "None" \
  "$(printf '%s\n' "$out" | python3 -c 'import json,sys; print([json.loads(l)["thread_id"] for l in sys.stdin][2])')"
check "paginated-out root exits 3" "3" "$rc"

cat > "${RA}/threads-ok.jsonl" <<'EOF'
{"id": "T1", "comments": {"nodes": [{"databaseId": 1}]}}
{"id": "T2", "comments": {"nodes": []}}
EOF
printf '{"id": 1, "in_reply_to": null}\n' > "${RA}/comments-ok.jsonl"
in_repo python3 "${SCRIPTS}/join-threads.py" "${RA}/comments-ok.jsonl" "${RA}/threads-ok.jsonl" >/dev/null 2>&1
check "deleted-root thread is not a mismatch" "0" "$?"

# --- ledger-counts.py ---

cat > "${RA}/ledger.json" <<'EOF'
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
check "open counts claims and findings" "2" \
  "$(in_repo python3 "${SCRIPTS}/ledger-counts.py" open "${RA}/ledger.json")"
check "blockers split closed sets per kind" "3" \
  "$(in_repo python3 "${SCRIPTS}/ledger-counts.py" blockers "${RA}/ledger.json")"
in_repo python3 "${SCRIPTS}/ledger-counts.py" open "${RA}/absent.json" >/dev/null 2>&1
check "missing ledger exits non-zero" "1" "$?"
in_repo python3 "${SCRIPTS}/ledger-counts.py" nonsense "${RA}/ledger.json" >/dev/null 2>&1
check "unknown mode exits 2" "2" "$?"

# --- json-body.py ---

body='reply with `backticks` and "quotes" and $(pwd)'
roundtrip="$(printf '%s' "$body" | in_repo python3 "${SCRIPTS}/json-body.py" \
  | python3 -c 'import json,sys; sys.stdout.write(json.load(sys.stdin)["body"])')"
check "json-body round-trips a piped body" "$body" "$roundtrip"

printf 'reply text' > "${RA}/reply.md"
check "json-body reads a RUN_DIR file argument" '{"body": "reply text"}' \
  "$(in_repo python3 "${SCRIPTS}/json-body.py" "${RA}/reply.md")"

# --- jsonl-to-json.py ---

printf '{"a": 1}\n\n{"b": 2}\n' > "${RA}/rows.jsonl"
check "jsonl-to-json skips blank lines" '[{"a": 1}, {"b": 2}]' \
  "$(in_repo python3 "${SCRIPTS}/jsonl-to-json.py" "${RA}/rows.jsonl")"
check "jsonl-to-json reads piped stdin" '[{"a": 1}]' \
  "$(printf '{"a": 1}\n' | in_repo python3 "${SCRIPTS}/jsonl-to-json.py")"

# --- containment: RUN_DIR is the only root ---

printf '{"token": "sensitive"}\n' > "${TMP}/tmp-secret.json"
printf '{"token": "sensitive"}\n' > "${TMP}/repo/wt-secret.json"

out="$(in_repo python3 "${SCRIPTS}/jsonl-to-json.py" "${TMP}/tmp-secret.json" 2>"${TMP}/err")"
check "temp-directory path is refused" "1" "$?"
check "temp-directory content is not printed" "" "$out"
check "refusal names RUN_DIR" "RUN_DIR" "$(grep -o RUN_DIR "${TMP}/err" | head -1)"

out="$(in_repo python3 "${SCRIPTS}/jsonl-to-json.py" "${TMP}/repo/wt-secret.json" 2>/dev/null)"
check "working-tree path is refused" "1" "$?"
check "working-tree content is not printed" "" "$out"

out="$(in_repo python3 "${SCRIPTS}/ledger-counts.py" open "${TMP}/tmp-secret.json" 2>/dev/null)"
check "ledger-counts refuses an outside path" "" "$out"

out="$(cd "${TMP}/repo" && python3 "${SCRIPTS}/json-body.py" < "${TMP}/tmp-secret.json" 2>/dev/null)"
check "stdin file redirect from outside is refused" "1" "$?"
check "redirected content is not printed" "" "$out"

out="$(cd "${TMP}/repo" && python3 "${SCRIPTS}/json-body.py" < "${RA}/reply.md" 2>/dev/null)"
check "stdin file redirect from RUN_DIR passes" '{"body": "reply text"}' "$out"

(cd "${TMP}" && python3 "${SCRIPTS}/jsonl-to-json.py" "${TMP}/tmp-secret.json") >/dev/null 2>"${TMP}/err2"
check "outside a git checkout everything is refused" "1" "$?"
check "no-checkout refusal says why" "git" "$(grep -o git "${TMP}/err2" | head -1)"

exit "$fail"
