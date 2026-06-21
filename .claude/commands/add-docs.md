Generate or refresh documentation for one or more rad-modules modules: $ARGUMENTS

$ARGUMENTS is a comma/space-separated list of module names (e.g. "Istio_GKE", "Bank_GKE
EKS_GKE"). If empty, process every module under `modules/`.

For each module, produce/update three artifacts to match `variables.tf`/`outputs.tf` and the
shapes defined in `.agent/skills/module-conventions/SKILL.md` → "Documentation". Read an
existing well-formed module (Bank_GKE or Container_Migration) first to match table style.

---

**ARTIFACT 1 — README.md (~90–110 lines)**

Sections, in order:
  1. One-paragraph overview, including the `mig-{deployment_id}-*` (or module-appropriate)
     resource-naming convention.
  2. A link to the lab guide: `[<Module>.md](../../docs/labs/<Module>.md)`. NEVER link to a
     LAB_GUIDE.md inside the module directory.
  3. `## Usage` — a minimal `module "<name>" { source = "..." ... }` block with the required
     inputs.
  4. `## Requirements` — provider/version table from versions.tf or provider.tf.
  5. `## Providers` — the same providers.
  6. `## Modules` — only if the module has nested helpers under `modules/`.
  7. `## Resources` — `name | type` table of the resources the module creates.
  8. `## Inputs` — a row for EVERY variable in variables.tf: name, description (verbatim minus
     the `{{UIMeta ...}}` tag), type, default, required. Required = "yes" when there is no
     default.
  9. `## Outputs` — a row for every output in outputs.tf (and outputs in main.tf, if any).

The Inputs/Outputs tables must be exhaustive and exact — they are the module's contract.

---

**ARTIFACT 2 — `<Module>.md` (long-form deep dive, in the module directory)**

An educational deep dive into how the module works: the architecture it provisions, the
provider-auth pattern it uses and why, the post-provisioning `null_resource` flow, key design
decisions (e.g. Istio's IstioOperator HPA block, MC_Bank's static provider aliases), and
gotchas. This is narrative prose with code excerpts, not a table dump.

---

**ARTIFACT 3 — `docs/labs/<Module>.md` (shared lab guide)**

A hands-on lab guide. Structure: Overview & Architecture → Lab Setup (prereqs, project,
bucket, varfile) → numbered Exercises (deploy via rad-launcher, explore, modify) → Cleanup
(`radlab.py -m <Module> -a destroy ...`) → Reference. If this file already exists, update it
rather than overwriting hand-written exercises.

---

**AFTER GENERATING**

  - Set/verify `module_documentation` default in variables.tf points to the GitHub URL of
    `docs/labs/<Module>.md`.
  - Add the module to the "Module Families" table in CLAUDE.md and the README module list if
    missing.
  - Report what was written/updated per module. Do not commit unless asked.
