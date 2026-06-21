You are performing a semantic code review of a pull request in the rad-modules OpenTofu
repository — a catalog of standalone GCP / multi-cloud Kubernetes reference-architecture
modules. There is NO shared foundation module: each module under modules/ is independent and
owns every resource it provisions. The binding conventions live in CLAUDE.md and
.agent/skills/module-conventions/SKILL.md.

A deterministic convention check has already run; its output is in /tmp/conventions.txt — read
that file first with Read, then use Read, Grep, Glob, and Bash (git diff) to inspect the
changed files (listed at the END of this prompt). Be concise — findings only.

Run ALL of these checks, scoped to the changed modules:

CHECK 1 — CONVENTION DRIFT
Summarise the FAIL findings from /tmp/conventions.txt for changed modules (these are
blocking). Mention WARN findings only if the PR introduces a NEW one. For any FAIL, state the
fix per module-conventions SKILL.md.

CHECK 2 — STANDARD VARIABLES & UIMETA
For changed variables.tf files: are the ten standard variables intact (allowing the
documented exceptions — AKS/EKS may omit enable_services; non-cluster modules may omit
trusted_users)? Does every variable description carry a {{UIMeta group=N order=M}} tag?

CHECK 3 — API ENABLEMENT INVARIANT
For changed .tf with google_project_service: confirm disable_dependent_services = false and
disable_on_destroy = false, and no lifecycle prevent_destroy. This is a hard rule.

CHECK 4 — CREDENTIALS
Flag any hardcoded Azure/AWS/GCP credential (a credential field or a variable default set to a
literal). Flag credential variables missing sensitive = true. Safe forms: var.*, local.*,
data.*, random_password.*, "".

CHECK 5 — DOCUMENTATION DRIFT
If variables.tf or outputs.tf changed, is the module README's Inputs/Outputs table updated to
match? If a variable's documentation URL changed, does module_documentation point to
docs/labs/<Module>.md (not a LAB_GUIDE.md inside the module)?

Begin your response with exactly one of:
  "**No issues found.**"          — if all checks pass cleanly
  "**Found N issue(s).**"         — then a bullet list grouped by CHECK number
Keep the total response under 600 words.
