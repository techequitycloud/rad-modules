Guided walkthrough for adding a new rad-modules module: $ARGUMENTS

$ARGUMENTS may name the new module and/or its shape (e.g. "Anthos_GKE based on Bank_GKE",
"a new attached-cluster module for OKE"). If anything essential is unclear (module name,
which existing module to copy, target cloud), ask before scaffolding.

Follow the "Checklist When Adding a New Module" in
`.agent/skills/module-conventions/SKILL.md`. Work through the phases below, pausing where a
human decision is genuinely needed.

---

**PHASE 1 — CHOOSE THE TEMPLATE**

Pick the closest existing module to copy (no symlinks — every file is a standalone copy):
  - Attached cluster (registers a non-GKE cluster in a Fleet via Helm) → copy AKS_GKE or EKS_GKE (Pattern A, direct provider).
  - Native GKE + add-ons (mesh, app deploy) → copy Istio_GKE or Bank_GKE (Pattern B, impersonated provider).
  - Multi-cluster → copy MC_Bank_GKE (static kubernetes provider aliases cluster1–cluster4).
  - Migration / non-cluster → copy Container_Migration or Migration_Center.

State which template you chose and why. Copy it to `modules/<New_Name>/` with a
PascalCase_WithUnderscores name.

---

**PHASE 2 — PROVIDER AUTH**

Decide Pattern A vs Pattern B (see module-conventions SKILL.md) and DELETE the unused file:
  - Pattern A: keep a single `provider.tf`; remove `provider-auth.tf` + `versions.tf` split.
  - Pattern B: keep `versions.tf` + `provider-auth.tf`; remove `provider.tf`.
If the module uses `google-beta`, it MUST be Pattern B.

---

**PHASE 3 — VARIABLES**

In `variables.tf`:
  a) Keep the ten standard variables intact with their exact names/types/defaults:
     module_description, module_dependency, module_services, credit_cost,
     require_credit_purchases, enable_purge, public_access, deployment_id,
     resource_creator_identity, trusted_users. Copy trusted_users' validation blocks verbatim.
  b) Keep `enable_services` at group 0, order 109.
  c) Update module_description / module_dependency / module_services / credit_cost defaults
     to match the new module's scope.
  d) Add module-specific variables in their own `# SECTION N:` block. Every variable
     description MUST end with a `{{UIMeta group=N order=NNN }}` tag. Add `updatesafe` to
     variables that can change in place; omit it for replace-forcing ones (cluster names,
     CIDRs). Set `sensitive = true` on any credential variable and give it NO hardcoded default.

This is the part where your design judgement matters most — the variable surface defines the
module's UI and contract. Propose the SECTION layout and the module-specific variables, and
confirm with the user before writing the full file if the scope is non-trivial.

---

**PHASE 4 — main.tf SCAFFOLD**

Ensure main.tf has: the `locals` (random_id, project, project_services), `random_id.default`,
`data.google_project.existing_project`, and `google_project_service.enabled_services` with
`for_each = toset(local.project_services)` and BOTH `disable_dependent_services = false` and
`disable_on_destroy = false`. Update `default_apis` to exactly the APIs this module needs.

---

**PHASE 5 — RESOURCES & POST-PROVISIONING**

Implement the feature `.tf` files (network.tf, gke.tf, <feature>.tf). For anything not
expressible as a resource (CLI installs, manifest applies, waiting for an IP), use
`null_resource` + `local-exec` following the SKILL rules: triggers capture every destroy-time
variable; create provisioner uses `set -eo pipefail`; destroy provisioner uses `set +e` and
`--ignore-not-found`. Put Kubernetes YAML under `manifests/` (raw) or `templates/` (templated).

Ensure every new .tf begins with the Apache 2.0 license header (copy from a neighbour).

---

**PHASE 6 — OUTPUTS**

`outputs.tf` exports at least `deployment_id` and `project_id`, plus any user-facing endpoint
(e.g. ingress gateway IP) with a short description.

---

**PHASE 7 — DOCS**

  a) Write `README.md` with the standard tables (Overview, Usage, Requirements, Providers,
     Resources, Inputs, Outputs) reflecting the final variables.tf/outputs.tf.
  b) Write the lab guide at `docs/labs/<New_Name>.md` (Overview & Architecture → Lab Setup →
     Exercises → Cleanup → Reference). Do NOT create a LAB_GUIDE.md inside the module.
  c) Set `module_documentation` default in variables.tf to that lab guide's GitHub URL.
  d) Add the module to the "Module Families" table in CLAUDE.md and the README module list.

---

**PHASE 8 — VALIDATE**

From the module directory: `tofu fmt -recursive`, `tofu init -backend=false`, `tofu validate`.
Then from the repo root run `python3 scripts/check_conventions.py` and resolve any FAIL
findings for the new module. Suggest a `rad-launcher` smoke test:
`python3 rad-launcher/radlab.py -m <New_Name> -a create -p <proj> -b <bucket> -f <varfile>`.

Report what was created and any decisions left for the user.
