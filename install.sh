#!/usr/bin/env bash
# Installs review-agent into ~/.claude/skills/ and allows Claude Code to read the
# skill's own files without prompting on each one. Re-run to update.
set -euo pipefail

REPO="https://github.com/prelint/review-agent.git"
SKILL_DIR="${HOME}/.claude/skills/review-agent"
SETTINGS="${HOME}/.claude/settings.json"
RULE='Read(~/.claude/skills/review-agent/**)'

for dep in git python3; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "review-agent: needs $dep on PATH" >&2
    exit 1
  }
done

if [ -d "${SKILL_DIR}/.git" ]; then
  echo "review-agent: updating ${SKILL_DIR}"
  git -C "${SKILL_DIR}" pull --ff-only
elif [ -e "${SKILL_DIR}" ]; then
  echo "review-agent: ${SKILL_DIR} exists and is not a git checkout." >&2
  echo "review-agent: move it aside and re-run." >&2
  exit 1
else
  echo "review-agent: cloning into ${SKILL_DIR}"
  mkdir -p "$(dirname "${SKILL_DIR}")"
  git clone --quiet "${REPO}" "${SKILL_DIR}"
fi

python3 - "${SETTINGS}" "${RULE}" <<'PY'
import json
import os
import shutil
import stat
import sys
import time

settings_path, rule = sys.argv[1], sys.argv[2]
existing = os.path.exists(settings_path)

if existing:
    with open(settings_path) as fh:
        raw = fh.read()
    try:
        settings = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError as exc:
        sys.exit(
            f"review-agent: {settings_path} is not valid JSON ({exc}).\n"
            f"review-agent: add {rule} to permissions.allow by hand."
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

if rule in allow:
    print("review-agent: permission rule already present")
    sys.exit(0)
allow.append(rule)

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
print(f"review-agent: added {rule} to permissions.allow")
PY

echo
echo "review-agent: installed. Restart Claude Code, then run /review-agent"
