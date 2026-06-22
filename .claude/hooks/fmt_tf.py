#!/usr/bin/env python3
"""
PostToolUse hook: auto-format .tf files after Claude edits or writes them, then
(advisory) validate the module when it is already initialized.

Receives the Claude Code hook payload as JSON on stdin.

1. Runs an in-place format on the file if it is a Terraform file. rad-modules CI
   uses `terraform` (~1.9) but `tofu` is interchangeable; this hook prefers `tofu`
   and falls back to `terraform`. Fails silently if neither is installed — it must
   never block the edit workflow.

2. If the file's module directory already contains a `.terraform/` directory (i.e.
   it has been initialized with `<binary> init -backend=false`), runs
   `<binary> validate` and feeds any failure back to Claude as additionalContext.
   The `.terraform/` gate keeps this cheap: it never forces an `init` and only
   validates modules being actively worked on. This is advisory — the edit has
   already happened, so it never blocks.
"""
import json
import subprocess
import sys
from pathlib import Path


def available_binary() -> str:
    """Return the first installed Terraform binary, or '' if none."""
    for binary in ("tofu", "terraform"):
        try:
            subprocess.run([binary, "version"], capture_output=True, check=False)
            return binary
        except FileNotFoundError:
            continue
    return ""


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    path = data.get("tool_input", {}).get("file_path", "")
    if not path.endswith(".tf"):
        sys.exit(0)

    binary = available_binary()
    if not binary:
        sys.exit(0)  # neither tofu nor terraform installed — skip silently

    # 1. Format the edited file in place.
    subprocess.run([binary, "fmt", path], capture_output=True, check=False)

    # 2. Advisory validate, only when the module is already initialized.
    module_dir = Path(path).parent
    if not (module_dir / ".terraform").exists():
        sys.exit(0)

    proc = subprocess.run(
        [binary, "validate", "-no-color"],
        cwd=str(module_dir),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode == 0:
        sys.exit(0)

    message = (proc.stderr or proc.stdout).strip()
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": (
                        f"`{binary} validate` failed in {module_dir} after this edit:\n\n"
                        f"{message}"
                    ),
                }
            }
        )
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
