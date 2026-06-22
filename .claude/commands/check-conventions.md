Check every module under `modules/` for convention drift against the binding rules in
`.agent/skills/module-conventions/SKILL.md` and CLAUDE.md.

rad-modules has NO shared foundation module — each module is independent. "Drift" here
means a module diverging from the repo-wide conventions, not from a parent module.

Start by running the mechanical checker, then add the judgement-based checks it can't do:

```bash
python3 scripts/check_conventions.py            # FAIL findings break, WARN findings inform
python3 scripts/check_conventions.py --strict   # treat warnings as failures too
```

Summarise its output, then verify the following across all modules.

---

**Step 1 — STANDARD VARIABLE CONSISTENCY**

Collect every module's variables.tf. For the ten standard variables
(module_description, module_dependency, module_services, credit_cost,
require_credit_purchases, enable_purge, public_access, deployment_id,
resource_creator_identity, trusted_users) verify:
  a) The variable is present (note the legitimate exceptions: AKS_GKE/EKS_GKE may omit
     enable_services; migration modules without a cluster may omit trusted_users).
  b) Its TYPE matches across modules (e.g. trusted_users is always `list(string)`).
  c) `resource_creator_identity` default is the standard SA
     ("rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com").
  d) `trusted_users` carries the duplicate-and-whitespace validation blocks from
     AKS_GKE/variables.tf.

Report per module: "<Module>: <variable> — <discrepancy>".

---

**Step 2 — UIMETA COMPLETENESS**

Every variable in every module must have a `{{UIMeta group=N order=M}}` tag in its
description. List any variable missing it, grouped by module.

---

**Step 3 — API ENABLEMENT INVARIANT**

For every `google_project_service` across all modules, confirm
`disable_dependent_services = false` and `disable_on_destroy = false`, and that none use
`lifecycle { prevent_destroy = true }`. Report any violation — this is a hard rule.

---

**Step 4 — LICENSE HEADERS & SYMLINKS**

  a) Report any .tf file missing the Apache 2.0 header.
  b) Report any symlink found inside a module directory (modules must never share files).

---

**Output**

Group findings by module; skip modules with none. If everything is consistent, say:
"All modules are consistent with the repo conventions."

If asked to FIX drift: for a missing standard variable, copy the complete variable block
(description with its {{UIMeta}} tag, type, default, validations) from a module that has it
correct (prefer AKS_GKE for the standard ten), inserting it in the right SECTION/order.
Never invent a hardcoded credential default. After fixing, run
`tofu fmt -recursive modules/` and re-run the checker.
