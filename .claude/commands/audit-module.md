Audit the rad-modules module: $ARGUMENTS

Resolve $ARGUMENTS to a directory under `modules/` (e.g. "Istio_GKE", "Bank_GKE",
"AKS_GKE"). If it doesn't match a directory, report the available modules and stop.

Run every check below and report findings. For each issue, state what is wrong and the
correct fix per `.agent/skills/module-conventions/SKILL.md`. End with:
  "Module $ARGUMENTS: N issue(s) found." or "Module $ARGUMENTS passes all checks."

You may run `python3 scripts/check_conventions.py --modules-dir modules/` first for the
mechanical checks, then add the judgement-based ones below.

---

**CHECK 1 — TEN STANDARD VARIABLES**

Read the module's variables.tf. Verify all ten standard variables are declared with the
correct names: module_description, module_dependency, module_services, credit_cost,
require_credit_purchases, enable_purge, public_access, deployment_id,
resource_creator_identity, trusted_users. Also verify enable_services is declared.

Note legitimate exceptions: attached-cluster modules (AKS_GKE, EKS_GKE) may omit
enable_services; migration modules without a cluster may omit trusted_users. Report
omissions, but classify these as informational for those module types.

---

**CHECK 2 — UIMETA TAGS**

Every variable description must contain a `{{UIMeta group=N order=M}}` tag inside the
description string (not a separate comment). Report any variable missing it. Confirm
`enable_services`, where present, uses `group=0 order=109`.

---

**CHECK 3 — SENSITIVE CREDENTIALS**

Any variable whose name contains client_secret, aws_secret_key, aws_access_key,
private_key, or service_account_key must set `sensitive = true` AND must have no
hardcoded default (no default, or `default = ""`). Report violations.

---

**CHECK 4 — PROVIDER AUTH PATTERN**

Determine which pattern the module uses and confirm it is internally consistent:
  - Pattern A (direct): a single `provider.tf`, no impersonation. Used by AKS_GKE, EKS_GKE.
  - Pattern B (impersonated): `versions.tf` (requirements) + `provider-auth.tf` with the
    `google_service_account_access_token` data source gated on
    `length(var.resource_creator_identity) != 0`, feeding both `google` and `google-beta`.

Flag: both provider.tf and provider-auth.tf present (should be one or the other); a module
using `google-beta` under Pattern A (must be Pattern B); a hardcoded `access_token`.

---

**CHECK 5 — API ENABLEMENT INVARIANT**

For every `google_project_service` resource (usually in main.tf), confirm BOTH:
  disable_dependent_services = false
  disable_on_destroy         = false
and that it does NOT use `lifecycle { prevent_destroy = true }`. These are critical:
multiple modules share a project, so disabling APIs on destroy breaks the others.

---

**CHECK 6 — LICENSE HEADERS**

Every .tf file should begin with the Apache 2.0 block-comment header (Google LLC).
Report any .tf file missing it.

---

**CHECK 7 — OUTPUTS**

outputs.tf should export at least `deployment_id` and `project_id`. For attached-cluster
modules that keep outputs in main.tf, confirm those two outputs exist somewhere. Report if
absent.

---

**CHECK 8 — DOCUMENTATION CONSISTENCY**

  a) README.md exists and its Inputs table lists every variable in variables.tf with
     matching defaults (minus the {{UIMeta}} tag).
  b) `module_documentation` default in variables.tf points to the GitHub URL of
     `docs/labs/<Module>.md` — NOT a LAB_GUIDE.md inside the module directory.
  c) The lab guide `docs/labs/<Module>.md` exists.
  d) No `LAB_GUIDE.md` file exists inside the module directory.
