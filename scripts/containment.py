"""Refuse file access outside the run's own directory.

Every file a shipped script consumes lives under RUN_DIR, which SKILL.md
binds to <git-dir>/review-agent. That one root is the whole containment
policy. The scripts run from a Bash allow list without a prompt, so a
looser policy (the working directory, the temp directory) would turn
them into silent readers of files that Read and Grep prompt for.

Stdin gets the same check when it is a regular file, because `< file` is
a file read. A pipe or a terminal passes.
"""

import os
import stat
import subprocess
import sys


def _me() -> str:
    return os.path.basename(sys.argv[0])


def _run_root() -> str:
    try:
        git_dir = subprocess.run(
            ["git", "rev-parse", "--absolute-git-dir"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        git_dir = ""
    if not git_dir:
        sys.exit(f"{_me()}: not inside a git checkout, so RUN_DIR does not exist")
    return os.path.realpath(os.path.join(git_dir, "review-agent"))


def _check(path: str) -> str:
    real = os.path.realpath(path)
    root = _run_root()
    if real == root or real.startswith(root + os.sep):
        return real
    sys.exit(f"{_me()}: {path} is outside RUN_DIR ({root})")


def open_contained(path: str):
    return open(_check(path), encoding="utf-8")


def _stdin_path():
    try:
        return os.readlink("/proc/self/fd/0")  # Linux
    except OSError:
        pass
    try:
        import fcntl

        raw = fcntl.fcntl(0, fcntl.F_GETPATH, b"\0" * 1024)  # macOS
        return raw.split(b"\0", 1)[0].decode()
    except (AttributeError, ImportError, OSError, ValueError):
        return None


def contained_stdin():
    if not stat.S_ISREG(os.fstat(0).st_mode):
        return sys.stdin
    path = _stdin_path()
    if path is None:
        sys.exit(f"{_me()}: stdin is a file redirect whose path cannot be resolved")
    _check(path)
    return sys.stdin
