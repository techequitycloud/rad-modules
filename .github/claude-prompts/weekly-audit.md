You are performing a weekly convention and documentation audit of the rad-modules OpenTofu
repository — a catalog of independent GCP / multi-cloud Kubernetes reference-architecture
modules (no shared foundation module). Conventions live in CLAUDE.md and
.agent/skills/module-conventions/SKILL.md.

A deterministic convention check already ran; its output is in /tmp/conventions.txt. Read it
first with Read, then use Read, Grep, Glob, and Bash to run ALL checks below.

CHECK 1 — CONVENTION DRIFT
Summarise the FAIL findings in /tmp/conventions.txt (blocking) and the WARN findings
(informational, grouped by module). Note any module whose deviations look unintended versus a
documented module-type exception (AKS/EKS omit enable_services; non-cluster modules omit
trusted_users).

CHECK 2 — MODULE LIST
List every directory under modules/ that is a real module. Compare against the "Module
Families" table in CLAUDE.md and the module list in README.md. Report modules missing from
either doc, or doc entries with no directory.

CHECK 3 — README TABLE ACCURACY
For each module, compare its README.md Inputs table against variables.tf (every variable a
row, matching defaults) and its Outputs table against outputs.tf. Report missing/incorrect
rows.

CHECK 4 — LAB GUIDE LINKS
For each module, confirm module_documentation in variables.tf points to the GitHub URL of
docs/labs/<Module>.md, that docs/labs/<Module>.md exists, and that NO LAB_GUIDE.md exists
inside the module directory.

CHECK 5 — REFERENCES
Verify every scripts/<name>, rad-launcher/<name>, and workflow path referenced in CLAUDE.md,
AGENTS.md, README.md, and SKILLS.md actually exists.

If all checks pass with no discrepancies, respond with exactly:
  CLEAN
Otherwise respond with a markdown report beginning with:
  ## Issues Found
Group findings by CHECK number. Be specific: exact filenames, counts, expected vs actual.
