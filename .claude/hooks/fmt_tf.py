#!/usr/bin/env python3
"""
PostToolUse hook: auto-format .tf files after Claude edits or writes them.

Receives the Claude Code hook payload as JSON on stdin. Runs an in-place format
on the file if it is a Terraform file. rad-modules CI uses `terraform` (~1.9) but
`tofu` is interchangeable for fmt; this hook prefers `tofu` and falls back to
`terraform`. Fails silently if neither is installed — it must never block the
edit workflow.
"""
import json
import subprocess
import sys


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    path = data.get("tool_input", {}).get("file_path", "")
    if not path.endswith(".tf"):
        sys.exit(0)

    for binary in ("tofu", "terraform"):
        try:
            subprocess.run(
                [binary, "fmt", path],
                capture_output=True,
                check=False,
            )
            return  # formatted with the first available binary
        except FileNotFoundError:
            continue  # try the next binary
    # Neither tofu nor terraform installed — skip silently.


if __name__ == "__main__":
    main()
