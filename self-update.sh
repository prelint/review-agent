#!/usr/bin/env bash
# Fast-forwards the installed clone from main. SKILL.md runs this before Stage 0.
# Checks the remote at most once every six hours. Refuses any checkout that is not
# the pinned clone install.sh creates. Exits 0 on every path: a stale skill still
# reviews, and this script must never stop a run.
set -uo pipefail

REPO="https://github.com/prelint/review-agent.git"
BRANCH="main"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="${SKILL_DIR}/.git/self-update-stamp"
THROTTLE_SECONDS=$((6 * 60 * 60))

say() { echo "review-agent: $*" >&2; }

[ -d "${SKILL_DIR}/.git" ] || { say "update skipped: not a git checkout"; exit 0; }

# Compare remotes as https://host/owner/repo, so ssh and .git forms match.
canonical_url() {
  printf '%s' "$1" | sed -e 's#^ssh://git@github\.com/#https://github.com/#' -e 's#^git@github\.com:#https://github.com/#' -e 's#\.git$##' -e 's#/$##'
}

origin="$(git -C "${SKILL_DIR}" remote get-url origin 2>/dev/null || true)"
if [ "$(canonical_url "${origin}")" != "$(canonical_url "${REPO}")" ]; then
  say "update skipped: origin is ${origin:-missing}, not ${REPO}"
  exit 0
fi

branch="$(git -C "${SKILL_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ "${branch}" != "${BRANCH}" ]; then
  say "update skipped: checkout is on '${branch}', not '${BRANCH}'"
  exit 0
fi

if [ -n "$(git -C "${SKILL_DIR}" status --porcelain -uno)" ]; then
  say "update skipped: checkout has local edits"
  exit 0
fi

now=$(date +%s)
if [ -f "${STAMP}" ]; then
  last=$(cat "${STAMP}" 2>/dev/null || echo 0)
  case "${last}" in '' | *[!0-9]*) last=0 ;; esac
  # A future stamp (clock skew, a restored VM) would throttle forever: expire it.
  [ "${last}" -gt "${now}" ] && last=0
  [ $((now - last)) -lt "${THROTTLE_SECONDS}" ] && exit 0
fi
# Stamp before the network step, so a failed attempt also waits out the throttle.
echo "${now}" >"${STAMP}"

# A failed fetch is offline, which is normal and transient: stay silent. A clone
# that fetched fine and still cannot fast-forward never heals on its own, so that
# message names the cause and the way out.
# The watchdog bounds the whole fetch. The lowSpeed settings only abort a transfer
# that has started, so a blackholed connect would otherwise stall for the OS
# timeout, and macOS has no timeout(1) to wrap it with.
GIT_TERMINAL_PROMPT=0 git -C "${SKILL_DIR}" \
  -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 \
  fetch --quiet origin "${BRANCH}" >/dev/null 2>&1 &
fetch_pid=$!
(sleep 20 && kill -9 "${fetch_pid}") >/dev/null 2>&1 &
watchdog_pid=$!
fetch_ok=yes
wait "${fetch_pid}" >/dev/null 2>&1 || fetch_ok=no
kill -9 "${watchdog_pid}" >/dev/null 2>&1 || true
wait "${watchdog_pid}" >/dev/null 2>&1 || true
[ "${fetch_ok}" = yes ] || exit 0

if ! git -C "${SKILL_DIR}" merge-base --is-ancestor HEAD "origin/${BRANCH}" 2>/dev/null; then
  say "update blocked: this checkout has commits that are not on origin/${BRANCH}. Re-run install.sh to reinstall."
  exit 0
fi

before=$(git -C "${SKILL_DIR}" rev-parse HEAD)
after=$(git -C "${SKILL_DIR}" rev-parse "origin/${BRANCH}")
[ "${before}" = "${after}" ] && exit 0

if ! ff_err=$(git -C "${SKILL_DIR}" merge --ff-only --quiet "origin/${BRANCH}" 2>&1 >/dev/null); then
  say "update failed: ${ff_err}"
  exit 0
fi
say "updated ${before:0:7}..${after:0:7} in ${SKILL_DIR}. If that is the copy you are running, read its SKILL.md again before you continue."
exit 0
