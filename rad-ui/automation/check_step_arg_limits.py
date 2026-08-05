#!/usr/bin/env python3
"""Fail if any Cloud Build step's inline script exceeds Google's arg limit.

Cloud Build rejects a build outright when a single step arg exceeds 10,000
characters:

    invalid build: invalid .steps field: build step 0 arg 1 too long (max: 10000)

This is not a warning and not a runtime error — the build never starts, so every
deployment or destroy using that pipeline fails immediately with a message that
says nothing about what changed. It happened for real: adding an explanatory
comment block to the destroy pipeline's first step pushed it to 10,164 and broke
every destroy in the platform until it was trimmed back.

The scripts here are large and edited by hand, so the limit is easy to cross
without noticing. Run this after touching any cloudbuild_*.yaml.
"""
import glob
import os
import sys

import yaml

LIMIT = 10_000
# Flag anything this close, so a small future edit doesn't silently cross it.
WARN_AT = 9_000


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    files = sorted(glob.glob(os.path.join(here, "cloudbuild*.yaml")))
    if not files:
        print("no cloudbuild*.yaml found", file=sys.stderr)
        return 1

    failed = False
    warned = False
    for path in files:
        with open(path, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
        for index, step in enumerate(doc.get("steps", []) or []):
            for arg_index, arg in enumerate(step.get("args", []) or []):
                size = len(arg)
                if size > LIMIT:
                    failed = True
                    print(
                        f"OVER  {os.path.basename(path)} step {index} "
                        f"({step.get('id')}) arg {arg_index}: {size} > {LIMIT}"
                    )
                elif size > WARN_AT:
                    warned = True
                    print(
                        f"TIGHT {os.path.basename(path)} step {index} "
                        f"({step.get('id')}) arg {arg_index}: {size} "
                        f"({LIMIT - size} left)"
                    )

    if failed:
        print("\nBuilds with an over-limit step are rejected before they start.")
        return 1
    print("All Cloud Build step args are within the 10,000-character limit."
          + (" Some are close — see TIGHT above." if warned else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
