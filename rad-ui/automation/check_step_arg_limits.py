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
import collections
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

        # A volume shares data BETWEEN steps, so Cloud Build rejects a build
        # that declares one in only a single step:
        #
        #   invalid build: Volume "x" is used only once, need twice or more
        #
        # Same class of failure as the arg limit — the build never starts, and
        # the deployment reports a generic error naming no cause. It happened
        # for real: staging a script into a volume and consuming it within the
        # SAME step invalidated the destroy pipeline and broke every destroy in
        # the platform until it was split into two steps.
        counts = collections.Counter(
            vol.get("name")
            for step in (doc.get("steps", []) or [])
            for vol in (step.get("volumes") or [])
        )
        for name, count in sorted(counts.items()):
            if count < 2:
                failed = True
                print(
                    f"VOLUME {os.path.basename(path)}: volume {name!r} is "
                    f"declared by {count} step; Cloud Build needs 2 or more"
                )

    if failed:
        print("\nBuilds with an over-limit step or a single-use volume are "
              "rejected before they start.")
        return 1
    print("All Cloud Build step args are within the 10,000-character limit."
          + (" Some are close — see TIGHT above." if warned else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
