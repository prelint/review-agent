"""Refuse file paths outside the run's own ground.

The shipped scripts are on a Bash allow list, so they run without a
prompt. Without this check any of them would read an arbitrary JSON file
silently, and the allow rule would become a file-read bypass. A run owns
three places: the repository under review (the working directory), its
git directory (RUN_DIR lives inside it, and a worktree's git directory
sits outside the checkout), and the temp directory.
"""

import os
import subprocess
import sys
import tempfile


def _roots() -> list:
    roots = [os.getcwd(), tempfile.gettempdir()]
    try:
        git_dir = subprocess.run(
            ["git", "rev-parse", "--absolute-git-dir"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        if git_dir:
            roots.append(git_dir)
    except (OSError, subprocess.CalledProcessError):
        pass
    return [os.path.realpath(r) for r in roots]


def open_contained(path: str):
    real = os.path.realpath(path)
    for root in _roots():
        if real == root or real.startswith(root + os.sep):
            return open(real, encoding="utf-8")
    sys.exit(
        f"{os.path.basename(sys.argv[0])}: {path} is outside the repository, "
        "its git directory, and tmp"
    )
