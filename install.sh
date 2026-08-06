#!/usr/bin/env bash
# Installs review-agent into ~/.claude/skills/ and allows Claude Code to read the
# skill's own files and run its self-update without prompting. Re-run to update.
set -euo pipefail

REPO="https://github.com/prelint/review-agent.git"
BRANCH="main"
SKILL_DIR="${HOME}/.claude/skills/review-agent"
SETTINGS="${HOME}/.claude/settings.json"
RULES=(
  'Read(~/.claude/skills/review-agent/**)'
  'Bash(~/.claude/skills/review-agent/self-update.sh)'
)

for dep in git python3; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "review-agent: needs $dep on PATH" >&2
    exit 1
  }
done

# Compare remotes as https://host/owner/repo, so ssh and .git forms match.
canonical_url() {
  printf '%s' "$1" | sed -e 's#^ssh://git@github\.com/#https://github.com/#' -e 's#^git@github\.com:#https://github.com/#' -e 's#\.git$##' -e 's#/$##'
}

if [ -d "${SKILL_DIR}/.git" ]; then
  origin="$(git -C "${SKILL_DIR}" remote get-url origin 2>/dev/null || true)"
  if [ "$(canonical_url "${origin}")" != "$(canonical_url "${REPO}")" ]; then
    echo "review-agent: ${SKILL_DIR} tracks ${origin:-no origin remote}, not ${REPO}." >&2
    echo "review-agent: refusing to update someone else's checkout. Update it yourself," >&2
    echo "review-agent: or move it aside and re-run." >&2
    exit 1
  fi
  branch="$(git -C "${SKILL_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ "${branch}" != "${BRANCH}" ]; then
    echo "review-agent: ${SKILL_DIR} is on '${branch}', not '${BRANCH}'." >&2
    echo "review-agent: refusing to update a branch you are working on." >&2
    exit 1
  fi
  echo "review-agent: updating ${SKILL_DIR}"
  git -C "${SKILL_DIR}" pull --ff-only origin "${BRANCH}"
elif [ -e "${SKILL_DIR}" ]; then
  echo "review-agent: ${SKILL_DIR} exists and is not a git checkout." >&2
  echo "review-agent: move it aside and re-run." >&2
  exit 1
else
  echo "review-agent: cloning into ${SKILL_DIR}"
  mkdir -p "$(dirname "${SKILL_DIR}")"
  git clone --quiet "${REPO}" "${SKILL_DIR}"
fi

python3 - "${SETTINGS}" "${RULES[@]}" <<'PY'
import json
import os
import shutil
import stat
import sys
import time

link_path, rules = sys.argv[1], sys.argv[2:]

# Write through a symlink to whatever it points at. Dotfile managers symlink
# settings.json, and replacing the link with a regular file detaches it.
settings_path = os.path.realpath(link_path)
if settings_path != link_path:
    print(f"review-agent: {link_path} points at {settings_path}, writing there")

existing = os.path.exists(settings_path)

if existing:
    with open(settings_path) as fh:
        raw = fh.read()
    try:
        settings = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError as exc:
        sys.exit(
            f"review-agent: {settings_path} is not valid JSON ({exc}).\n"
            f"review-agent: add these to permissions.allow by hand: {', '.join(rules)}"
        )
    if not isinstance(settings, dict):
        sys.exit(f"review-agent: {settings_path} is not a JSON object. Leaving it alone.")
    mode = stat.S_IMODE(os.stat(settings_path).st_mode)
else:
    settings, mode = {}, 0o600

permissions = settings.setdefault("permissions", {})
if not isinstance(permissions, dict):
    sys.exit(f"review-agent: permissions in {settings_path} is not an object. Leaving it alone.")
allow = permissions.setdefault("allow", [])
if not isinstance(allow, list):
    sys.exit(f"review-agent: permissions.allow in {settings_path} is not a list. Leaving it alone.")

missing = [rule for rule in rules if rule not in allow]
if not missing:
    print("review-agent: permission rules already present")
    sys.exit(0)
allow.extend(missing)

if existing:
    backup = f"{settings_path}.bak.{time.strftime('%Y%m%d-%H%M%S')}"
    shutil.copy2(settings_path, backup)
    print(f"review-agent: backed up settings to {backup}")

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
tmp = f"{settings_path}.tmp"
with open(tmp, "w") as fh:
    json.dump(settings, fh, indent=2)
    fh.write("\n")
os.chmod(tmp, mode)
os.replace(tmp, settings_path)
print(f"review-agent: added to permissions.allow: {', '.join(missing)}")
PY

echo
echo "review-agent: installed. Restart Claude Code, then run /review-agent"
