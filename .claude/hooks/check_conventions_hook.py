#!/usr/bin/env python3
"""
Stop hook: run the repository convention checker against modules that have
uncommitted .tf changes, and surface any FAIL-level violations back to Claude
before the turn ends.

scripts/check_conventions.py validates rad-modules' conventions with two
severities — FAIL (hard invariants: UIMeta tags, no symlinks, project_id naming,
sensitive credentials, the API disable_* invariant) and WARN (completeness rules
that legitimately vary by module type, e.g. attached-cluster modules omitting
outputs.tf/enable_services). This hook blocks ONLY on FAIL lines; WARN lines are
ignored so legitimate per-module variation never nags.

It also scopes findings to modules the user actually edited this session
(uncommitted in the working tree), so pre-existing FAILs elsewhere stay quiet.

Behaviour:
  - No uncommitted modules/*.tf changes      -> exit 0 silently.
  - Only WARNs, or FAILs in untouched modules -> exit 0 silently.
  - FAIL in a touched module                  -> emit {"decision": "block", ...}.
  - Respects stop_hook_active to avoid Stop->block->Stop loops.
  - Fails open (exit 0) on any unexpected error — never wedges the workflow.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
# Matches the checker's summary lines: "  FAIL  [ModuleName] ...". WARN lines
# (same shape, different severity) are intentionally NOT matched.
FAIL_RE = re.compile(r"^\s*FAIL\s+\[([^\]]+)\]")


def changed_modules() -> set:
    """Module dir names with uncommitted (staged/unstaged/untracked) .tf edits."""
    try:
        out = subprocess.run(
            ["git", "status", "--porcelain", "--", "modules/"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        ).stdout
    except FileNotFoundError:
        return set()

    mods = set()
    for line in out.splitlines():
        # Porcelain format: "XY path" (path may be "old -> new" for renames).
        path = line[3:].split(" -> ")[-1].strip().strip('"')
        if not path.endswith(".tf"):
            continue
        parts = Path(path).parts
        if len(parts) >= 2 and parts[0] == "modules":
            mods.add(parts[1])
    return mods


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    # Avoid infinite Stop -> block -> Stop loops.
    if data.get("stop_hook_active"):
        sys.exit(0)

    touched = changed_modules()
    if not touched:
        sys.exit(0)

    proc = subprocess.run(
        [sys.executable, "scripts/check_conventions.py"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode == 0:
        sys.exit(0)  # no FAILs (WARNs alone keep the exit code at 0)

    relevant = [
        line.strip()
        for line in proc.stdout.splitlines()
        if (m := FAIL_RE.search(line)) and m.group(1) in touched
    ]
    if not relevant:
        sys.exit(0)

    reason = (
        "Convention FAILs in modules you edited this session "
        "(scripts/check_conventions.py):\n\n"
        + "\n".join(relevant)
        + "\n\nFix these before finishing — see "
        ".agent/skills/module-conventions/SKILL.md. WARN-level findings and "
        "pre-existing FAILs in untouched modules are intentionally ignored."
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)


if __name__ == "__main__":
    main()
