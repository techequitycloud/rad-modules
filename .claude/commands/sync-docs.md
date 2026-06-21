Find and fix all documentation drift between the rad-modules codebase and its docs
(CLAUDE.md, README.md, SKILLS.md, AGENTS.md, per-module README.md/`<Module>.md`, and
`docs/labs/<Module>.md`).

Run every check below and apply fixes directly.

---

**CHECK 1 — MODULE LIST**

List every directory under `modules/` that is a real module (has main.tf or variables.tf;
PascalCase_WithUnderscores name). Compare against:
  a) The "Module Families" table in CLAUDE.md.
  b) The module list/table in README.md.
  c) Any module enumeration in SKILLS.md and AGENTS.md.
Add missing modules; remove entries whose directory no longer exists. Keep the
"what it deploys" one-liners accurate.

---

**CHECK 2 — README INPUTS/OUTPUTS TABLES**

For each module, compare its README.md `## Inputs` table against variables.tf and its
`## Outputs` table against outputs.tf (and any outputs in main.tf):
  a) Every variable appears as a row with matching default and a description that matches
     variables.tf verbatim minus the `{{UIMeta ...}}` tag.
  b) Every output appears in the Outputs table.
Add missing rows, fix stale defaults/descriptions. Do the same for the `## Requirements`
and `## Providers` tables against versions.tf / provider.tf.

---

**CHECK 3 — LAB GUIDE LINKS**

For each module:
  a) `module_documentation` default in variables.tf must be the GitHub URL of
     `docs/labs/<Module>.md`. Fix if it points elsewhere (especially a LAB_GUIDE.md).
  b) README.md links the lab guide as `../../docs/labs/<Module>.md`. Fix broken links.
  c) Confirm `docs/labs/<Module>.md` exists; if a module has none, report it.
  d) Report (do not auto-delete) any `LAB_GUIDE.md` found inside a module directory — that
     file should not exist; the lab guide always lives under docs/labs/.

---

**CHECK 4 — SKILL FILE ACCURACY**

For each `.agent/skills/*/SKILL.md`, verify any file lists, module names, variable names,
or counts it states still match the codebase. Update stale references. Pay attention to
module-conventions/SKILL.md (the ten standard variables, provider patterns) and
repository-context/SKILL.md.

---

**CHECK 5 — SCRIPT & PATH REFERENCES**

Scan CLAUDE.md, AGENTS.md, README.md, and SKILLS.md for references to `scripts/<name>`,
`rad-launcher/<name>`, and workflow files. Verify each path exists; fix broken references.

---

After applying all fixes, run `tofu fmt -recursive modules/` if any .tf changed, then
report a summary of what was updated. Do not commit unless asked.
