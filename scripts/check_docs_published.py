#!/usr/bin/env python3
"""
Published-documentation checker for the rad-modules repository.

Every module under modules/ owns two documentation pages — docs/modules/<M>.md
(configuration guide) and docs/labs/<M>.md (lab guide) — which are published to
the RAD docs site (https://docs.radmodules.dev) out of the sibling
rad.github.io repository. Nothing in either repo previously enforced that they
actually reach the site, and the two can drift silently in both directions.

That is not hypothetical. rad.github.io commit 846fdf8 (2026-07-29) deleted all
sixteen pages as "phantom published pages" on the test that none "correspond to
any module that exists in partner-modules/modules/" — the wrong catalogue, since
these eight are rad-modules' own. The site kept building green (nothing links to
the pages by name; the sidebar and certification cross-links are generated from
sidebars.ts and src/data/certMap.ts, which the same commit also pruned), so no
check anywhere went red. The pages returned 404 for seven weeks and were noticed
only by hand.

Findings have two severities, matching scripts/check_conventions.py:
  FAIL — the page is missing locally, carries YAML front matter, or is absent
         from the live site (HTTP 404). These break the build.
  WARN — the published body has drifted from this repo's copy, or the live site
         could not be reached to prove anything. Reported but non-blocking
         unless --strict is passed.

Why front matter is a FAIL and not cosmetic: source pages are published by the
sync in rad.github.io's SKILL.md section 11.2, which keeps the SITE's front
matter and appends the source file after it. A source file that ships its own
`---` block therefore lands as a second front-matter block halfway down the
published page. The site's front matter is also the real SEO title and meta
description; the source blocks that used to be here carried placeholders like
"EKS_GKE Module Documentation" instead. Four pages shipped such a block until
they were stripped; keep them plain Markdown starting at the `# ` heading.

Usage:
    python3 scripts/check_docs_published.py [--offline] [--site-dir ../rad.github.io]
                                            [--strict] [--base-url URL]

Exit codes:
    0  No FAIL findings (WARN findings may be present unless --strict)
    1  One or more FAIL findings (or any finding under --strict)
    2  Bad invocation (missing modules/ or docs/ directory)
"""

import argparse
import os
import sys
import urllib.error
import urllib.request

BASE_URL = "https://docs.radmodules.dev"
SECTIONS = ("modules", "labs")
ATTEMPTS = 3
TIMEOUT = 20


def module_names(modules_dir):
    """Every module directory — the checker follows modules/, never a hardcoded list,
    so a ninth module is covered the day it is added."""
    return sorted(
        d for d in os.listdir(modules_dir)
        if os.path.isdir(os.path.join(modules_dir, d)) and not d.startswith(".")
    )


def body(path):
    """The publishable body: everything from the first `# ` heading onward.

    This is exactly what SKILL.md section 11.2 splices beneath the site's own front
    matter, so it is the only part that can meaningfully be compared across repos.
    """
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    for i, line in enumerate(lines):
        if line.startswith("# "):
            return "\n".join(lines[i:]).rstrip("\n")
    return None


def http_status(url):
    """Return (status, error). A 404 is a real answer, not an error — urllib raises
    on it, so it is caught and reported as a status. Transport failures are retried
    and then surfaced separately: unreachable is not the same as missing, and a
    flaky runner must not turn into a red build over a page that is fine."""
    last = None
    for _ in range(ATTEMPTS):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "rad-modules-docs-check"})
            with urllib.request.urlopen(req, timeout=TIMEOUT) as res:
                return res.status, None
        except urllib.error.HTTPError as exc:
            return exc.code, None
        except Exception as exc:  # timeout, DNS, TLS, connection reset
            last = exc
    return None, last


def run_checks(root, offline, site_dir, strict, base_url):
    findings = []

    def fail(msg):
        findings.append(("FAIL", msg))

    def warn(msg):
        findings.append(("WARN", msg))

    modules_dir = os.path.join(root, "modules")
    for name in module_names(modules_dir):
        for section in SECTIONS:
            rel = f"docs/{section}/{name}.md"
            path = os.path.join(root, rel)

            # Check 1 (FAIL): the page exists in this repo at all.
            if not os.path.isfile(path):
                fail(f"[{name}] {rel} is missing — every module owns a {section} page")
                continue

            # Check 2 (FAIL): plain Markdown, no YAML front matter (see module docstring).
            with open(path, encoding="utf-8") as fh:
                first = fh.readline().strip()
            if first == "---":
                fail(f"[{name}] {rel} starts with a YAML front-matter block — "
                     f"source pages must begin at the `# ` heading")

            if body(path) is None:
                fail(f"[{name}] {rel} has no `# ` heading — nothing to publish")
                continue

            # Check 3 (FAIL on 404 / WARN on unreachable): the page is live.
            if not offline:
                url = f"{base_url}/docs/{section}/{name}"
                status, err = http_status(url)
                if status is None:
                    warn(f"[{name}] could not reach {url} ({type(err).__name__}) — "
                         f"publication not verified")
                elif status == 404:
                    fail(f"[{name}] {url} returns 404 — the page is not published. "
                         f"Sync it into rad.github.io (SKILL.md section 11.2) and check "
                         f"sidebars.ts and src/data/certMap.ts still list it")
                elif status >= 400:
                    warn(f"[{name}] {url} returns HTTP {status}")

            # Check 4 (WARN): the published body matches this repo's copy.
            if site_dir:
                site_path = os.path.join(site_dir, rel)
                if not os.path.isfile(site_path):
                    fail(f"[{name}] {rel} absent from {site_dir} — present here but "
                         f"not in the docs site repo")
                else:
                    ours, theirs = body(path), body(site_path)
                    if theirs is None:
                        warn(f"[{name}] {site_dir}/{rel} has no `# ` heading")
                    elif ours != theirs:
                        warn(f"[{name}] {rel} body differs from the published copy "
                             f"({len(ours)}B here vs {len(theirs)}B on the site) — re-sync it")

    fails = [m for s, m in findings if s == "FAIL"]
    warns = [m for s, m in findings if s == "WARN"]

    if findings:
        print(f"\n{'=' * 60}\n{len(fails)} ERROR(S), {len(warns)} WARNING(S):\n{'=' * 60}")
        for msg in fails:
            print(f"  FAIL  {msg}")
        for msg in warns:
            print(f"  WARN  {msg}")
    else:
        print("All module documentation and lab guides are present and published.")

    # FAIL findings always break the build; WARN findings break only under --strict.
    return 1 if fails or (strict and warns) else 0


def main():
    parser = argparse.ArgumentParser(description="Check rad-modules published documentation")
    parser.add_argument("--root", default=".", help="Repository root (default: .)")
    parser.add_argument("--offline", action="store_true",
                        help="Skip the live-site checks (no network)")
    parser.add_argument("--site-dir", default=None,
                        help="Path to a rad.github.io checkout, to diff published bodies")
    parser.add_argument("--strict", action="store_true",
                        help="Treat WARN findings as failures too")
    parser.add_argument("--base-url", default=None, help=f"Override {BASE_URL}")
    args = parser.parse_args()

    base_url = (args.base_url or BASE_URL).rstrip("/")

    for required in ("modules", "docs"):
        if not os.path.isdir(os.path.join(args.root, required)):
            print(f"error: {os.path.join(args.root, required)} not found", file=sys.stderr)
            sys.exit(2)

    sys.exit(run_checks(args.root, args.offline, args.site_dir, args.strict, base_url))


if __name__ == "__main__":
    main()
