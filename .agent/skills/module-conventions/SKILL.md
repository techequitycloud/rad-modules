---
name: module-conventions
description: Binding rules for every module in rad-modules — TF file layout, variables.tf structure with UIMeta, provider-auth impersonation, and common deployment-ID / project / trusted-users patterns.
---

# Module Conventions

Every module under `modules/` is an independent OpenTofu root module and shares the same structural conventions. Deviating from them breaks either `rad-launcher` variable validation or the RAD UI rendering. Treat these rules as load-bearing.

## Directory Layout

A module directory looks like this (`Bank_GKE` shown as the canonical multi-file example; `AKS_GKE` and `EKS_GKE` are simpler):

```
modules/<Module_Name>/
├── README.md              # Short summary + Usage + Requirements/Providers/Resources/Inputs/Outputs tables
├── tests/                 # Module test fixtures (the long-form deep dive lives at docs/modules/<Module_Name>.md, NOT inside the module)
├── main.tf                # Locals, random_id, data.google_project, google_project_service.enabled_services
├── variables.tf           # All inputs, annotated with UIMeta tags (see below)
├── versions.tf            # OR provider.tf — required_providers + required_version
├── provider-auth.tf       # OR provider.tf — google / azurerm / aws provider config
├── network.tf             # VPC / subnet / firewall / NAT
├── <feature>.tf           # e.g. gke.tf, asm.tf, hub.tf, deploy.tf, glb.tf, mcs.tf, istiosidecar.tf
├── outputs.tf             # deployment_id + project_id at minimum
├── manifests/             # or templates/ — static or templated Kubernetes YAML
└── modules/               # optional, nested module-local helpers (not cross-module)
    └── <helper>/
        ├── main.tf
        ├── variables.tf
        └── ...
```

Rules:

- **No symlinks.** Modules do not share TF files. If `Bank_GKE` and `MC_Bank_GKE` need similar `asm.tf`, each has its own copy.
- **Nested modules** (e.g. `modules/AKS_GKE/modules/attached-install-manifest/`) are scoped to one parent module only; they must not be referenced from other modules in the repo.
- **Kubernetes templates** live under `manifests/` (raw YAML) or `templates/` (Go-template `.yaml.tpl` rendered by `templatefile(...)`). Pick one per module based on whether any values are substituted. `MC_Bank_GKE` is the only module that actually renders templates (`manifests.tf` writes `templates/*.yaml.tpl` out to `manifests/` via `local_file`); the `templates/` and `manifests/` directories in `Istio_GKE` and the `templates/` directory in `Bank_GKE` are **unreferenced by any `.tf` file** and have been since those modules' initial commits. Don't copy a pattern out of them assuming it is live.
- **License header**: every `.tf` file should begin with the Apache 2.0 block-comment header. Copy it from a neighbouring file when creating a new one. Three existing `versions.tf` files (`Bank_GKE`, `Migration_Center`, `VMware_Engine`) currently lack it, which is why `scripts/check_conventions.py` reports a missing header as WARN rather than FAIL.
- **Naming**: files are lowercase with hyphens (`provider-auth.tf`), module directory names are `PascalCase_WithUnderscores`, HCL resource names are `snake_case`.

## variables.tf Structure

Variables are organized into numbered sections using `// SECTION N:` or `# SECTION N:` comments. The ordering below is the established convention:

```
# SECTION 1: Deployment   → module_description, module_dependency, module_services,
#                           credit_cost, require_credit_purchases, enable_purge,
#                           public_access, deployment_id, resource_creator_identity,
#                           trusted_users, enable_services
# SECTION 2: Project      → project_id
# SECTION 3: Network      → create_network, network_name, subnet_name, ip_cidr_ranges, ...
# SECTION 4: Cluster      → create_cluster, cluster_name_prefix, k8s_version, release_channel, ...
# SECTION 5: IAM / Creds  → client_id/tenant_id/subscription_id/client_secret (Azure),
#                           aws_access_key/aws_secret_key (AWS)
# SECTION 6+: Feature-specific (e.g. service mesh, config management, application)
```

> **`enable_services` belongs in group 0 (SECTION 1: Deployment).** Place it at the end of the Deployment section (order=109) so the API-enabling toggle is grouped with other platform-level deployment controls rather than with project-specific inputs. Use `{{UIMeta group=0 order=109 }}`.

Not every module needs every section — `AKS_GKE` has no dedicated network section because AKS manages its own VNet, and `Istio_GKE` merges IAM into cluster setup. The numbering should still follow this order wherever the section is present.

### Every Module Ships These Ten Standard Variables

The variables below exist in nearly every module and must keep their exact names, types, and defaults. `rad-launcher` looks for them; the RAD UI renders them in a standard panel. Two carry documented exceptions: `trusted_users` is Kubernetes-specific and is deliberately omitted by `Container_Migration`, `Migration_Center` and `VMware_Engine`, and `enable_services` is omitted by `AKS_GKE`, `EKS_GKE` and `Migration_Center`. Three further variables belong in the same group-0 panel: `module_documentation` (docs URL) and `shared_users` (platform-only visibility list), declared by all eight modules, and `enable_rad_gcpproject` (`bool`, default `false`, `{{UIMeta group=0 order=110 }}`), declared by seven — every module except `Istio_GKE`. Setting it `false` hides the "GCP Project on RAD" option so the module can only be deployed into a customer's own GCP project; each module's description names the specific APIs the RAD-managed tier policies deny that make it necessary (e.g. `vmwareengine`/`vmmigration` for `VMware_Engine`, fifteen Anthos/mesh/multi-cluster APIs for `MC_Bank_GKE`). Keep that list in step with the module's `default_apis`. `scripts/check_conventions.py` enforces this list at WARN level; run it before opening a PR.

| Variable | Type | Default | Notes |
|---|---|---|---|
| `module_description` | `string` | module-specific text | Shown in catalog |
| `module_dependency` | `list(string)` | e.g. `["GCP Project"]` | Deploy order |
| `module_services` | `list(string)` | e.g. `["GCP","GKE",...]` | UI tags |
| `credit_cost` | `number` | `0` | Platform credits; every module in this repo currently ships `0` |
| `require_credit_purchases` | `bool` | `false` | |
| `enable_purge` | `bool` | `true` | |
| `public_access` | `bool` | `true` | Catalog visibility |
| `deployment_id` | `string` | `null` | 4-char suffix; `null` ⇒ auto |
| `resource_creator_identity` | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | Impersonated SA |
| `trusted_users` | `list(string)` | `[]` | Cluster-admin emails |

`trusted_users` should carry the duplicate-and-whitespace validations from `AKS_GKE/variables.tf`; copy them when adding to a new module.

### UIMeta Tags

Every variable description ends with a `{{UIMeta ...}}` tag (inside the description string, not a comment) that drives UI rendering. **A variable with no tag at all has no group and renders VISIBLE** — group 0 is stripped and everything else is shown, so missing metadata fails open rather than closed. Platform-injected values need an explicit `group=0`.

```hcl
variable "region" {
  description = "GCP region where the GKE cluster ... Defaults to 'us-central1'. {{UIMeta group=1 order=103 }}"
  type        = string
  default     = "us-central1"
}
```

(The input is named `region`, never `gcp_region` — see the standard-variable list above. And it carries **no** `updatesafe`: changing the region relocates every regional resource.)

Parameters:
- `group=N` — UI panel grouping, corresponding loosely to SECTION (0=Deployment, 1=Project, 2=Network, etc.).
- `order=NNN` — sort order within the group. Gaps are fine; leave room to insert new variables.
- `updatesafe` — **presence flag**, not a key=value. Include it for variables that can change in place without recreating the module (e.g. `trusted_users`, `resource_creator_identity`, `tenant_id`, cloud credentials, node-pool sizing). Omit it for variables that force replacement (e.g. cluster names, name prefixes, network CIDRs, `project_id`, and every region variable — `region`, `gcp_location`, `azure_region`, `aws_region`).

  **Its ABSENCE is what the platform acts on, as of 2026-08-19.** An unflagged field raises a *"this update will destroy project resources"* confirmation when edited on an existing deployment, and is rendered read-only when the admin setting **Enforce Update Safe** is on. Until then the webapp's matcher looked for a token no module writes, so the flag had never been read by anything and wrong flags accumulated unchecked — `region` carried it in 422 modules across the catalogue.

  The asymmetry settles any doubtful case: an over-generous flag is a **silent data-loss path** (it tells the user an edit is safe when it will replace the resource), while omitting it costs a needless warning. **When in doubt, leave it off.** Two traps beyond "forces replacement": a variable that appears in a resource's `count`/`for_each` **condition** gates that resource's existence, so turning it off destroys it; and a comparison against a **literal** (`var.mode == "custom"`) is a mode switch that destroys on any change, whereas a comparison against **emptiness** (`!= ""`, `!= null`, `length(...) > 0`) only destroys when the value is cleared — the latter keeps the flag. Verify with `../rad-automation/scripts/check_updatesafe_flags.py` (sibling repo).

- `notradmanaged` — presence flag. **Removes the variable from the deploy form** when the deployment lands in a RAD-managed project (RAD's own organisation, tier folders, RAD's billing account), and reverts it server-side on update; a customer's own project keeps it. Tag anything that lets the tenant reach past their own project into RAD's organisation — writing an org-scoped resource (`google_access_context_manager_*` has one access policy per ORG; `google_scc_notification_config`), or federating an external identity inward (Workload Identity Federation is project-scoped yet grants an arbitrary external CI system a standing foothold). **The module default must be benign**, because the server reverts a tagged variable to it: a `true` default switches the feature on for every RAD-managed deployment.

Sensitive credentials (`client_secret`, `aws_secret_key`, etc.) must also set `sensitive = true` on the variable itself — the UIMeta tag alone does not mark them secret.

### Description Copy Style

Variable descriptions are one flowing paragraph and follow this shape:

> `[What it is / effect] [Format or example] [Default] [Consequences of change]. {{UIMeta ... }}`

Example: `"Kubernetes version to deploy on the AKS cluster, specified as major.minor (e.g. '1.34'). Must be a version currently supported by AKS in the selected azure_region. The patch version is managed automatically by AKS. Defaults to '1.34'. {{UIMeta group=4 order=403 updatesafe }}"`

Keep this style when editing — the RAD UI shows the description verbatim in tooltips.

## Provider Authentication

Two patterns exist; pick based on whether the module touches Google APIs that must run as the impersonated service account.

### Pattern A — Direct provider (used by `AKS_GKE`, `EKS_GKE`)

Single `provider.tf` with all required providers and a direct `provider "google"` block. No impersonation — authentication comes from the caller's Application Default Credentials / Cloud Build service account.

```hcl
# provider.tf
terraform {
  required_providers {
    google  = { source = "hashicorp/google",  version = ">=5.0.0" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    helm    = { source = "hashicorp/helm",    version = "~> 2.0" }
    random  = { source = "hashicorp/random",  version = "3.6.2" }
  }
  required_version = ">= 0.13"
}

provider "google" { project = var.project_id }
provider "azurerm" {
  features {}
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  subscription_id = var.subscription_id
}
```

### Pattern B — Impersonated provider (used by `Bank_GKE`, `MC_Bank_GKE`, `Istio_GKE`, `Container_Migration`, `Migration_Center`, `VMware_Engine`)

Split `versions.tf` (provider requirements only) + `provider-auth.tf` (runtime auth via service-account impersonation). This is required when the module provisions GCP resources that require a specific owner.

```hcl
# provider-auth.tf — impersonation pattern, copy verbatim
provider "google" {
  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : null
}

provider "google-beta" {
  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : null
}
```

If a new module needs `google-beta`, it must use Pattern B so the beta provider also gets the impersonated token.

## main.tf Boilerplate

Every module's `main.tf` starts with this scaffold. The exact shape varies (`AKS_GKE` uses an unconditional `random_id`, `Bank_GKE` makes it conditional), but the ingredients are identical:

```hcl
locals {
  random_id      = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex
  project        = try(data.google_project.existing_project, null)
  project_number = try(local.project.number, null)

  default_apis     = [ /* module-specific list */ ]
  project_services = var.enable_services ? local.default_apis : []
}

resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0
  byte_length = 2
}

data "google_project" "existing_project" {
  project_id = trimspace(var.project_id)
}

resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.project_services)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false   # do NOT flip to true — breaks other modules
  disable_on_destroy         = false   # do NOT flip to true — breaks other modules
}
```

`disable_dependent_services = false` and `disable_on_destroy = false` are critical. Multiple RAD Lab modules may be deployed into the same project; disabling APIs on destroy would break the others.

## outputs.tf Minimum

Every module exports at least `deployment_id` and `project_id`:

```hcl
output "deployment_id" {
  description = "Module Deployment ID"
  value       = var.deployment_id
}

output "project_id" {
  description = "Project ID"
  value       = local.project.project_id
}
```

Modules that expose user-facing endpoints (e.g. `Istio_GKE` with the Ingress Gateway IP) add more outputs with short `description` strings.

## Documentation

Each module has one markdown file kept in sync with `variables.tf`, plus a shared lab guide under `docs/labs/`:

### README.md (~90–110 lines)

Follow the exact table shape used by existing modules:

1. One-paragraph overview, including the `mig-{deployment_id}-*` resource naming convention.
2. Link out to the module's documentation with a two-level relative path — the deep dive at `docs/modules/<Module_Name>.md` (e.g. `[Bank_GKE.md](../../docs/modules/Bank_GKE.md)`) and/or the lab guide at `docs/labs/<Module_Name>.md` (e.g. `[Container_Migration.md](../../docs/labs/Container_Migration.md)`). **Never** link to a `LAB_GUIDE.md` inside the module directory — that file does not exist.
3. `## Usage` — a minimal `module "name" { source = "..." ... }` block.
4. `## Requirements` — provider versions table.
5. `## Providers` — same table, lightly different.
6. `## Modules` (optional) — nested submodules.
7. `## Resources` — short table of `name | type`.
8. `## Inputs` — full `name | description | type | default | required` table for every variable in `variables.tf`.
9. `## Outputs` — matching table.

The README's Inputs table must reflect defaults and descriptions from `variables.tf` verbatim (minus the `{{UIMeta ...}}` tag). When updating a variable, update the README in the same change.

### Lab guide — `docs/labs/<Module_Name>.md`

Long-form hands-on lab guide shared across the repo. Lives at `docs/labs/<Module_Name>.md` (e.g. `docs/labs/Container_Migration.md`). Covers: Overview & Architecture → Lab Setup → numbered Exercises → Cleanup → Reference. The `module_documentation` variable default in `variables.tf` must point at published documentation for the module, **not** at a `LAB_GUIDE.md` inside the module. Two forms are in use today: the docs site (`https://docs.radmodules.dev/docs/modules/<Module_Name>` — `AKS_GKE`, `Bank_GKE`, `EKS_GKE`, `Istio_GKE`, `MC_Bank_GKE`) and the raw GitHub lab-guide URL (`https://github.com/techequitycloud/rad-modules/blob/main/docs/labs/<Module_Name>.md` — `Container_Migration`, `Migration_Center`, `VMware_Engine`). Match whichever form the module you copied from uses.

> **Do not create `LAB_GUIDE.md` inside a module directory.** The lab guide is always at `docs/labs/<Module_Name>.md`.

## Checklist When Adding a New Module

1. Copy an existing module of similar shape (`AKS_GKE` for attached, `Istio_GKE` or `Bank_GKE` for native GKE).
2. Rename the directory to `PascalCase_WithUnderscores`.
3. Replace all Apache 2.0 copyright years where appropriate, but keep "Google LLC".
4. Update `module_description`, `module_dependency`, `module_services`, `credit_cost` defaults in `variables.tf` to match the new scope.
5. Keep the ten standard variables intact. Add module-specific variables in their own `SECTION N`, each with a `{{UIMeta group=N order=NNN }}` tag.
6. Update `default_apis` in `main.tf` to the APIs actually required.
7. Decide Pattern A vs Pattern B for provider auth; delete the unused file.
8. Rewrite `README.md` tables against the final `variables.tf`, and write the lab guide at `docs/labs/<Module_Name>.md`. Update `module_documentation` default in `variables.tf` to point to its GitHub URL.
9. Run `tofu fmt -recursive` and `tofu validate` in the module directory before committing.
10. Smoke test via `rad-launcher` with a minimal `--varfile` before declaring done.
11. Give every `required_providers` entry an upper bound (`~> N.0`, not a bare `>= N.0.0`). `.terraform.lock.hcl` is gitignored repo-wide, so an unbounded constraint lets a fresh `tofu init` silently resolve a new major version and break the module before it reaches the cloud provider — confirmed live when `AKS_GKE`'s unbounded `azurerm` constraint resolved 5.0.1 and failed on a newly-required `node_provisioning_profile` block.
