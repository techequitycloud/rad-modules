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
├── <MODULE_NAME>.md       # Long-form educational deep dive
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
- **Kubernetes templates** live under `manifests/` (raw YAML) or `templates/` (Go-template `.yaml.tpl` rendered by `templatefile(...)`). Pick one per module based on whether any values are substituted.
- **License header**: every `.tf` file begins with the Apache 2.0 block-comment header. Copy it from a neighbouring file when creating a new one.
- **Naming**: files are lowercase with hyphens (`provider-auth.tf`), module directory names are `PascalCase_WithUnderscores`, HCL resource names are `snake_case`.

## variables.tf Structure

Variables are organized into numbered sections using `// SECTION N:` or `# SECTION N:` comments. The ordering below is the established convention:

```
# SECTION 1: Deployment   → module_description, module_dependency, module_services,
#                           credit_cost, require_credit_purchases, enable_purge,
#                           public_access, deployment_id, resource_creator_identity,
#                           trusted_users
# SECTION 2: Project      → existing_project_id, enable_services
# SECTION 3: Network      → create_network, network_name, subnet_name, ip_cidr_ranges, ...
# SECTION 4: Cluster      → create_cluster, cluster_name_prefix, k8s_version, release_channel, ...
# SECTION 5: IAM / Creds  → client_id/tenant_id/subscription_id/client_secret (Azure),
#                           aws_access_key/aws_secret_key (AWS)
# SECTION 6+: Feature-specific (e.g. service mesh, config management, application)
```

Not every module needs every section — `AKS_GKE` has no dedicated network section because AKS manages its own VNet, and `Istio_GKE` merges IAM into cluster setup. The numbering should still follow this order wherever the section is present.

### Every Module Ships These Ten Standard Variables

The variables below exist in **every** module and must keep their exact names, types, and defaults. `rad-launcher` looks for them; the RAD UI renders them in a standard panel.

| Variable | Type | Default | Notes |
|---|---|---|---|
| `module_description` | `string` | module-specific text | Shown in catalog |
| `module_dependency` | `list(string)` | e.g. `["GCP Project"]` | Deploy order |
| `module_services` | `list(string)` | e.g. `["GCP","GKE",...]` | UI tags |
| `credit_cost` | `number` | `100` or `200` | Platform credits |
| `require_credit_purchases` | `bool` | `false` | |
| `enable_purge` | `bool` | `true` | |
| `public_access` | `bool` | `true` | Catalog visibility |
| `deployment_id` | `string` | `null` | 4-char suffix; `null` ⇒ auto |
| `resource_creator_identity` | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | Impersonated SA |
| `trusted_users` | `list(string)` | `[]` | Cluster-admin emails |

`trusted_users` should carry the duplicate-and-whitespace validations from `AKS_GKE/variables.tf`; copy them when adding to a new module.

### UIMeta Tags

Every variable description ends with a `{{UIMeta ...}}` tag (inside the description string, not a comment) that drives UI rendering:

```hcl
variable "gcp_region" {
  description = "GCP region where the GKE cluster ... Defaults to 'us-central1'. {{UIMeta group=2 order=302 updatesafe }}"
  type        = string
  default     = "us-central1"
}
```

Parameters:
- `group=N` — UI panel grouping, corresponding loosely to SECTION (0=Deployment, 1=Project, 2=Network, etc.).
- `order=NNN` — sort order within the group. Gaps are fine; leave room to insert new variables.
- `updatesafe` — **presence flag**, not a key=value. Include it for variables that can change in place without recreating the module (e.g. `trusted_users`, `resource_creator_identity`, region-pinned lookups). Omit it for variables that force replacement (e.g. cluster names, network CIDRs).

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
    azurerm = { source = "hashicorp/azurerm", version = ">=3.17.0" }
    helm    = { source = "hashicorp/helm",    version = "~> 2.0" }
    random  = { source = "hashicorp/random",  version = "3.6.2" }
  }
  required_version = ">= 0.13"
}

provider "google" { project = var.existing_project_id }
provider "azurerm" {
  features {}
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  subscription_id = var.subscription_id
}
```

### Pattern B — Impersonated provider (used by `Bank_GKE`, `MC_Bank_GKE`, `Istio_GKE`)

Split `versions.tf` (provider requirements only) + `provider-auth.tf` (runtime auth via service-account impersonation). This is required when the module provisions GCP resources that require a specific owner.

```hcl
# provider-auth.tf — impersonation pattern, copy verbatim
provider "google" {
  alias = "impersonated"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

data "google_service_account_access_token" "default" {
  count                  = length(var.resource_creator_identity) != 0 ? 1 : 0
  provider               = google.impersonated
  scopes                 = ["userinfo-email", "cloud-platform"]
  target_service_account = var.resource_creator_identity
  lifetime               = "3600s"  # Bank_GKE and MC_Bank_GKE; Istio_GKE uses "1800s"
}

provider "google" {
  access_token = length(var.resource_creator_identity) != 0 ? data.google_service_account_access_token.default[0].access_token : null
}

provider "google-beta" {
  access_token = length(var.resource_creator_identity) != 0 ? data.google_service_account_access_token.default[0].access_token : null
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
  project_id = trimspace(var.existing_project_id)
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

Each module needs two markdown files, both kept in sync with `variables.tf`:

### README.md (~90–110 lines)

Follow the exact table shape used by existing modules:

1. One-paragraph overview.
2. Link to the deep-dive `<MODULE>.md`.
3. `## Usage` — a minimal `module "name" { source = "..." ... }` block.
4. `## Requirements` — provider versions table.
5. `## Providers` — same table, lightly different.
6. `## Modules` (optional) — nested submodules.
7. `## Resources` — short table of `name | type`.
8. `## Inputs` — full `name | description | type | default | required` table for every variable in `variables.tf`.
9. `## Outputs` — matching table.

The README's Inputs table must reflect defaults and descriptions from `variables.tf` verbatim (minus the `{{UIMeta ...}}` tag). When updating a variable, update the README in the same change.

### `<MODULE_NAME>.md` (~1000–2600 lines)

Long-form educational document. Follows the section structure seen in `modules/AKS_GKE/AKS_GKE.md`: Overview & Learning Objectives → What This Module Deploys → feature-specific deep dives → Troubleshooting. New modules can start shorter but should cover the "why" behind each architectural choice.

## Checklist When Adding a New Module

1. Copy an existing module of similar shape (`AKS_GKE` for attached, `Istio_GKE` or `Bank_GKE` for native GKE).
2. Rename the directory to `PascalCase_WithUnderscores`.
3. Replace all Apache 2.0 copyright years where appropriate, but keep "Google LLC".
4. Update `module_description`, `module_dependency`, `module_services`, `credit_cost` defaults in `variables.tf` to match the new scope.
5. Keep the ten standard variables intact. Add module-specific variables in their own `SECTION N`, each with a `{{UIMeta group=N order=NNN }}` tag.
6. Update `default_apis` in `main.tf` to the APIs actually required.
7. Decide Pattern A vs Pattern B for provider auth; delete the unused file.
8. Rewrite `README.md` tables against the final `variables.tf`, and write the deep-dive `<MODULE_NAME>.md`.
9. Run `tofu fmt -recursive` and `tofu validate` in the module directory before committing.
10. Smoke test via `rad-launcher` with a minimal `--varfile` before declaring done.
