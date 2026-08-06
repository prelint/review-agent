#!/usr/bin/env bash
# Guard tests for self-update.sh. Every case exits before the network step, so
# the suite runs offline. Run it from anywhere; needs git >= 2.28.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/self-update.sh"
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

# canonical_url, extracted from the script, so the test runs the shipped code.
canon() {
  bash -c "$(sed -n '/^canonical_url()/,/^}/p' "${SCRIPT}"); canonical_url \"\$1\"" _ "$1"
}
TARGET="https://github.com/prelint/review-agent"
check "https form" "${TARGET}" "$(canon 'https://github.com/prelint/review-agent.git')"
check "scp ssh form" "${TARGET}" "$(canon 'git@github.com:prelint/review-agent.git')"
check "long ssh form" "${TARGET}" "$(canon 'ssh://git@github.com/prelint/review-agent.git')"
check "trailing slash" "${TARGET}" "$(canon 'https://github.com/prelint/review-agent/')"

run() {
  "$1/self-update.sh" 2>&1 >/dev/null
}

mkdir -p "${TMP}/nogit" && cp "${SCRIPT}" "${TMP}/nogit/"
check "non-git dir" "review-agent: update skipped: not a git checkout" "$(run "${TMP}/nogit")"

# Fixture clone. The origin URL is never contacted: every case below exits
# before the fetch. The copied script is untracked and must not trip -uno.
git init --quiet --initial-branch=main "${TMP}/clone"
git -C "${TMP}/clone" -c user.email=t@t -c user.name=t commit --allow-empty --quiet -m init
git -C "${TMP}/clone" remote add origin https://github.com/prelint/review-agent.git
cp "${SCRIPT}" "${TMP}/clone/"

git -C "${TMP}/clone" remote set-url origin https://github.com/example/other.git
check "wrong origin" \
  "review-agent: update skipped: origin is https://github.com/example/other.git, not https://github.com/prelint/review-agent.git" \
  "$(run "${TMP}/clone")"
git -C "${TMP}/clone" remote set-url origin https://github.com/prelint/review-agent.git

git -C "${TMP}/clone" checkout --quiet -b other
check "wrong branch" "review-agent: update skipped: checkout is on 'other', not 'main'" "$(run "${TMP}/clone")"
git -C "${TMP}/clone" checkout --quiet main

echo tracked >"${TMP}/clone/file"
git -C "${TMP}/clone" add file
git -C "${TMP}/clone" -c user.email=t@t -c user.name=t commit --quiet -m file
echo edit >>"${TMP}/clone/file"
check "local edits" "review-agent: update skipped: checkout has local edits" "$(run "${TMP}/clone")"
git -C "${TMP}/clone" checkout --quiet -- file

date +%s >"${TMP}/clone/.git/self-update-stamp"
check "throttled" "" "$(run "${TMP}/clone")"

exit "${fail}"
