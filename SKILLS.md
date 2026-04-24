---
name: rad-modules-implementation
description: Guide for implementing Terraform/OpenTofu modules in the rad-modules repository. The modules are standalone GKE-based Kubernetes and multi-cloud fleet deployments (Istio_GKE, Bank_GKE, MC_Bank_GKE, AKS_GKE, EKS_GKE).
---

# RAD Modules Implementation Skill

This skill explains how the Terraform/OpenTofu modules in this repository are structured and how to add a new one. The canonical reference throughout this document is **`modules/Istio_GKE`**: read its source alongside this guide.

## 1. Repository Overview

Each top-level entry under `modules/` is an **independent, self-contained module**. There is no shared foundation module, no symlink pattern, and no cross-module Terraform dependency. A module owns every resource it provisions and produces its own state.

The five modules in the repository today:

| Module | What it provisions | Target audience |
|---|---|---|
| `Istio_GKE` | GKE Standard cluster + open-source Istio (sidecar **or** ambient mode) + Prometheus/Jaeger/Grafana/Kiali + optional Bookinfo sample | Platform engineers learning upstream Istio |
| `Bank_GKE` | Single GKE cluster (Autopilot or Standard) + Cloud Service Mesh (managed Istio) + Bank of Anthos v0.6.7 + optional Anthos Config Management + Cloud Monitoring SLOs | Engineers exploring ASM on a single cluster |
| `MC_Bank_GKE` | Multiple GKE clusters across multiple regions + fleet-wide Cloud Service Mesh + Multi-Cluster Ingress (MCI) + Multi-Cluster Services (MCS) + Bank of Anthos across all clusters behind a global HTTPS load balancer | Engineers exploring multi-cluster mesh and traffic |
| `AKS_GKE` | Microsoft Azure AKS cluster registered with GCP as a **GKE Attached Cluster** via Fleet, with the GKE Connect agent installed via Helm | Engineers exploring multi-cloud fleet management |
| `EKS_GKE` | AWS EKS cluster registered with GCP as a **GKE Attached Cluster** via Fleet, with the GKE Connect agent installed via Helm | Engineers exploring multi-cloud fleet management |

Supporting directories:

- `rad-launcher/` — `radlab.py` is a Python CLI that wraps OpenTofu/Terraform for interactive module deployment from a workstation or Cloud Shell.
- `rad-ui/automation/` — Cloud Build YAML files (`cloudbuild_deployment_{create,destroy,purge,update}.yaml`) used by the RAD platform UI to run module deployments remotely.
- `scripts/` — standalone helper shell scripts grouped by topic (`gcp-istio-security/`, `gcp-istio-traffic/`, `gcp-cr-mesh/`, `gcp-m2c-vm/`). Each subdirectory contains a single `.sh` script and a `README.md`. These are not called by any Terraform module; they are hand-run by engineers for lab exercises or operational tasks.
- Top-level `README.md` and `CHANGELOG.md` are upstream OpenTofu documents, not project documentation.

## 2. Standard Module Layout

Modules follow a common file layout. The distinguishing `.tf` files differ by what the module deploys, but the scaffolding is shared. Using `modules/Istio_GKE` as the example:

```
modules/Istio_GKE/
├── main.tf              # Project bootstrap, API enablement, random_id, project data source
├── provider-auth.tf     # google provider + service-account impersonation
├── versions.tf          # required_providers + required_version
├── variables.tf         # UIMeta-annotated inputs
├── outputs.tf           # deployment_id, project_id, cluster_credentials_cmd, external_ip
├── network.tf           # VPC, subnet with secondary ranges, firewall rules, Cloud Router + NAT
├── gke.tf               # GKE cluster, node pool, cluster service account, IAM
├── istiosidecar.tf      # null_resource installing Istio in sidecar mode (conditional)
├── istioambient.tf      # null_resource installing Istio in ambient mode (conditional)
├── manifests/           # Raw Kubernetes manifests applied as-is
├── templates/           # Kubernetes manifest templates rendered by Terraform
├── README.md            # Short overview + usage + Requirements/Providers/Resources/Inputs/Outputs tables
└── Istio_GKE.md         # Long technical walkthrough (≈1,400 lines)
```

Other modules introduce their own domain-specific files alongside this skeleton:

| Module | Additional/replacement files |
|---|---|
| `Bank_GKE` | `asm.tf` (Cloud Service Mesh via GKE Hub), `deploy.tf` (downloads Bank of Anthos tarball and applies manifests), `hub.tf` (fleet membership), `glb.tf` (global load balancer IP), `monitoring.tf` (SLOs), `templates/*.yaml.tpl` |
| `MC_Bank_GKE` | `asm.tf`, `deploy.tf`, `hub.tf`, `glb.tf`, `mcs.tf` (MCI/MCS features), `manifests.tf` (applies YAML from `manifests/`), `manifests/` |
| `AKS_GKE` | `provider.tf` (direct provider config, no impersonation wrapper), no `versions.tf`, no `network.tf` (Azure VNet is created inline in `main.tf`), nested `modules/attached-install-manifest/` and `modules/attached-install-mesh/` (Helm-based installers) |
| `EKS_GKE` | `provider.tf`, `vpc.tf` (AWS VPC), `iam.tf` (AWS IAM roles for EKS), same nested `modules/` as AKS_GKE |

### 2.1 Nested Submodules

`AKS_GKE/modules/` and `EKS_GKE/modules/` contain two inner Terraform modules:

- `attached-install-manifest` — Renders and applies the GKE Connect agent bootstrap manifest via Helm. Called automatically by the parent module after the cluster is registered as a GKE Attached Cluster.
- `attached-install-mesh` — Optional Anthos Service Mesh installer. **Not called automatically** by the parent; invoke it from your own root module if you want ASM on the attached cluster.

## 3. Standard File Contents

### 3.1 `main.tf`

Every module's `main.tf` does the same three things at the top:

1. Looks up the existing GCP project via `data "google_project" "existing_project"` keyed by `var.existing_project_id`.
2. Generates a deployment suffix: `random_id "default"` is created when `var.deployment_id` is `null`; `local.random_id` resolves to either the provided value or the generated hex.
3. Enables the project's required APIs via `google_project_service.enabled_services` with `disable_dependent_services = false` and `disable_on_destroy = false` (critical — prevents destroy from disabling APIs that other modules may be using).

Modules that install workloads via `kubectl` also include a `null_resource.wait_for_container_api` that polls `gcloud services list` until `container.googleapis.com` reports as enabled before any cluster resource is created.

### 3.2 `provider-auth.tf` vs `provider.tf`

Two patterns exist:

**Impersonation pattern (`provider-auth.tf`)** — used by `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`:

```hcl
provider "google" { alias = "impersonated" ... }

data "google_service_account_access_token" "default" {
  count                  = length(var.resource_creator_identity) != 0 ? 1 : 0
  provider               = google.impersonated
  target_service_account = var.resource_creator_identity
  lifetime               = "1800s"
}

provider "google"      { access_token = ... }
provider "google-beta" { access_token = ... }
```

When `resource_creator_identity` is set, the module provisions resources as that service account instead of the caller's ADC.

**Direct pattern (`provider.tf`)** — used by `AKS_GKE`, `EKS_GKE`. These modules configure `azurerm`/`aws`/`helm` providers directly and do not impersonate for GCP calls.

### 3.3 `versions.tf`

Pins required providers and `required_version`. The set of pinned providers differs per module:

| Module | Pinned providers | `required_version` |
|---|---|---|
| `Istio_GKE` | `google`, `kubernetes` | `>= 0.13` |
| `Bank_GKE` | `google` (>= 5.0), `kubernetes` (>= 2.23), `kubectl` (gavinbunney/kubectl >= 1.14), `time` (>= 0.9), `http` (>= 3.0) | `>= 1.3` |
| `MC_Bank_GKE` | `google`, `kubernetes` | `>= 0.13` |
| `AKS_GKE` | No top-level `versions.tf`; the nested submodules have their own | — |
| `EKS_GKE` | No top-level `versions.tf`; the nested submodules have their own | — |

Providers that are used but not explicitly pinned (e.g. `random`, `null`, `google-beta`) are downloaded at the version OpenTofu/Terraform selects automatically. All three GKE-based modules configure a `google-beta` provider in `provider-auth.tf` for completeness, but none currently assign resources to it explicitly.

### 3.4 `variables.tf` — UIMeta Annotations

All input variables carry a `{{UIMeta group=N order=M }}` annotation at the end of their `description`. The platform UI uses these to group and order inputs on the deployment form. The sectioning convention used in `Istio_GKE/variables.tf`:

| Group | Section | Variables |
|---|---|---|
| 0 | Provider / Metadata | `module_description`, `module_dependency`, `module_services`, `credit_cost`, `require_credit_purchases`, `enable_purge`, `public_access`, `resource_creator_identity`, `trusted_users` |
| 1 | Main | `existing_project_id`, `gcp_region` |
| 2 | Network | `create_network`, `network_name`, `subnet_name`, `ip_cidr_ranges` |
| 3 | GKE | `create_cluster`, `gke_cluster`, `release_channel`, `pod_ip_range`, `pod_cidr_block`, `service_ip_range`, `service_cidr_block` |
| 4 | Features | `enable_services`, `istio_version`, `install_ambient_mesh` |
| 6 | Application | `deploy_application` |

Example variable:

```hcl
variable "existing_project_id" {
  description = "GCP project ID of the destination project where the GKE cluster and Istio service mesh will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
}
```

The `updatesafe` tag marks variables whose value can change on an in-place `terraform apply` without forcing resource replacement.

### 3.5 `outputs.tf`

Standard outputs present in every GKE-based module (compare `modules/Istio_GKE/outputs.tf:17-38`):

- `deployment_id` — echoes the suffix (provided or generated) used in resource names.
- `project_id` — the GCP project where resources were deployed.
- `cluster_credentials_cmd` — a ready-to-paste `gcloud container clusters get-credentials ...` command for operators.
- `external_ip` — read from a file written by a post-provisioning `null_resource` (e.g. Istio Ingress Gateway IP); falls back to `"IP not available"` via `fileexists()`.

Attached-cluster modules (`AKS_GKE`, `EKS_GKE`) expose no Terraform outputs; they document the equivalent `gcloud container attached clusters get-credentials` command in their README.

### 3.6 Post-Provisioning with `null_resource`

Anything that cannot be expressed as a Terraform resource — installing Istio via `istioctl`, applying Bank of Anthos manifests, waiting for a LoadBalancer IP — is wrapped in `null_resource` with `local-exec` provisioners. Conventions observed in `istiosidecar.tf:17-293`:

1. **Triggers** capture every variable needed by the `destroy` provisioner (e.g. `cluster_name`, `region`, `project_id`, `resource_creator_identity`), because `self.triggers.*` is the only input available at destroy time.
2. **Create provisioner**: `set -eo pipefail`, install missing CLIs (`kubectl`, `istioctl`) into `$HOME/.local/bin`, run `gcloud container clusters get-credentials ... --impersonate-service-account=...`, then perform the actual install.
3. **Destroy provisioner**: `set +e` to make cleanup best-effort — failures during destroy should never block Terraform from removing infrastructure. Uses `--ignore-not-found` on kubectl calls and `|| echo "Warning: ..."` on each step.
4. **Explicit `depends_on`** against the cluster and node pool, so Terraform does not attempt the install until Kubernetes is actually ready.

## 4. Documentation Pattern

Each module ships two markdown files:

- **`README.md`** (≈90–100 lines): short prose intro, a copy-pastable `module "..." { source = ... }` usage block, and standard tables for Requirements, Providers, Modules (if any), Resources, Inputs, Outputs.
- **`<Module_Name>.md`** (≈1,100–2,600 lines): long-form technical walkthrough covering the architecture diagram, every resource the module creates, the networking layout, security model, and operational guidance. These are meant as learning material — `Istio_GKE.md` explains VPC-native networking, secondary IP ranges, iptables-based traffic interception, and the sidecar-vs-ambient trade-off in enough depth to teach the technology, not just operate it.

When writing these files for a new module, match the tone and depth of `modules/Istio_GKE/README.md` and `modules/Istio_GKE/Istio_GKE.md`.

## 5. Creating a New Module

There is no scaffolding script. Create a new module by copying the layout from the closest existing module:

1. **Pick a template** based on what you are deploying:
   - Single GKE cluster with workload → copy `Istio_GKE` or `Bank_GKE`.
   - Multi-cluster GKE → copy `MC_Bank_GKE`.
   - Attached cluster on AWS/Azure → copy `EKS_GKE` / `AKS_GKE`.
2. `cp -a modules/Istio_GKE modules/MyNewModule` and rename any module-specific `.tf` files (e.g. `istiosidecar.tf` → `mynewmodule.tf`).
3. Edit `variables.tf` — update `module_description`, `module_services`, `module_dependency`, any feature flags, and default values. Keep the UIMeta annotations; renumber `order` values if you add new variables in an existing group.
4. Replace the provisioning logic in the domain-specific `.tf` files. If you need post-provisioning steps, follow the `null_resource` pattern in `istiosidecar.tf`.
5. Update `outputs.tf` — always expose `deployment_id`, `project_id`, and (for GKE modules) `cluster_credentials_cmd`.
6. Write `README.md` and `<Module_Name>.md` using the existing modules as a template for structure and depth.
7. Validate:

   ```bash
   cd modules/MyNewModule
   tofu init      # or: terraform init
   tofu validate
   tofu fmt -check
   tofu plan -var="existing_project_id=my-test-project"
   ```

## 6. Conventions and Invariants

- **File naming**: `snake_case` for `.tf` files. Module directories use `PascalCase` / `SCREAMING_SNAKE_CASE` (e.g. `Istio_GKE`, `MC_Bank_GKE`).
- **Copyright headers**: Every `.tf` file begins with the Apache 2.0 license header.
- **API enablement**: Always set `disable_dependent_services = false` and `disable_on_destroy = false` on `google_project_service` to avoid disabling APIs that may be in use by other modules or deployments.
- **Destroy safety**: Any `null_resource` with a meaningful create-time effect **must** have a matching `when = destroy` provisioner that cleans up, and that provisioner must tolerate missing resources (`--ignore-not-found`, `|| true`, etc.).
- **Impersonation**: Only fetch an impersonation access token when `length(var.resource_creator_identity) != 0`; otherwise let the provider use ADC.
- **No secrets in variables**: Credentials like `client_secret`, `aws_secret_key` are module inputs but must never be given default values. The caller is responsible for sourcing them from a secret store.

## 7. Running a Module

### Local (OpenTofu/Terraform)

```bash
cd modules/Istio_GKE
tofu init
tofu plan  -var="existing_project_id=my-gcp-project"
tofu apply -var="existing_project_id=my-gcp-project"
tofu destroy -var="existing_project_id=my-gcp-project"
```

### Via the RAD Lab launcher

```bash
cd rad-launcher
python3 installer_prereq.py
python3 radlab.py
```

`radlab.py` interactively prompts for a module, project, and variables, then drives `tofu init/apply` under the hood.

### Via the RAD UI platform

The platform invokes Cloud Build with the YAML files in `rad-ui/automation/`:

- `cloudbuild_deployment_create.yaml` — `tofu apply`
- `cloudbuild_deployment_update.yaml` — re-apply with changed variables
- `cloudbuild_deployment_destroy.yaml` — `tofu destroy`
- `cloudbuild_deployment_purge.yaml` — destroy plus post-cleanup for any resources Terraform could not remove

These are invoked by the platform, not by module developers directly.

## 8. Troubleshooting

### Cluster credentials fail in a `null_resource`

The `local-exec` runs on the machine executing `tofu apply`, not in GCP. Check that `gcloud` and `kubectl` are installed and that either ADC or `--impersonate-service-account=${var.resource_creator_identity}` can reach the cluster. The installer blocks in `istiosidecar.tf:42-58` show how to install `kubectl` on demand when missing.

### `istioctl install` fails with HPA naming conflicts

The sidecar-mode installer (`istiosidecar.tf:109-148`) pipes a custom `IstioOperator` YAML into `istioctl install -y -f -` specifically to set an explicit `hpaSpec.scaleTargetRef.name = istio-ingressgateway`. If you see HPA errors, confirm this block is still present and unmodified.

### Destroy hangs or loops

A `null_resource` destroy provisioner is failing hard. Every destroy provisioner must be idempotent and best-effort — re-check that it uses `set +e` (not `set -e`), `--ignore-not-found` on kubectl calls, and redirects errors rather than aborting.

### API disabled after destroy

Ensure `google_project_service.enabled_services` has `disable_on_destroy = false`. If you inherited a module where it was `true`, change it before the first destroy — once an API is disabled, dependent resources in other deployments will start failing.

### Attached cluster never appears in the GCP Console

The GKE Connect agent must be installed on the attached cluster. In `AKS_GKE` and `EKS_GKE` this is the job of `modules/attached-install-manifest` — verify the submodule is being invoked and its Helm release succeeded.

### Bank of Anthos pods stuck pending

The `deploy.tf` `null_resource` downloads the release tarball into `.terraform/bank-of-anthos` on the machine running `apply`. If the download or extract fails, the manifests are never applied. Check the `local-exec` output; the download is forced fresh on every apply via `always_run = timestamp()` (see `modules/Bank_GKE/deploy.tf:40`).

## 9. Quick Reference

### Standard variable set (GKE-based modules)

```hcl
existing_project_id        # GCP project ID (required)
gcp_region                 # e.g. "us-central1"
resource_creator_identity  # SA email for impersonation; default points to the platform SA
trusted_users              # Emails granted cluster-admin via RBAC/Connect Gateway
deployment_id              # Optional suffix; auto-generated if null
enable_services            # Toggle project_service API enablement
create_network             # true = create VPC; false = use existing
create_cluster             # true = create GKE; false = install onto existing
```

### Standard output set (GKE-based modules)

```hcl
output "deployment_id"          { value = var.deployment_id }
output "project_id"             { value = local.project.project_id }
output "cluster_credentials_cmd" {
  value = "gcloud container clusters get-credentials ${var.gke_cluster} --region ${var.gcp_region} --project ${local.project.project_id}"
}
output "external_ip" {
  value = fileexists("${path.module}/scripts/app/external_ip.txt") ? file("${path.module}/scripts/app/external_ip.txt") : "IP not available"
}
```

### Common providers

The table shows which providers each module actively uses. All three GKE-based modules also configure a `google-beta` provider block in `provider-auth.tf` as a convenience (for future use), but no resources are currently assigned to it.

| Module | google | kubernetes | kubectl | helm | azurerm | aws | random | null | time / http |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Istio_GKE | ✓ | ✓ | | | | | ✓ | ✓ | |
| Bank_GKE | ✓ | ✓ | ✓ | | | | ✓ | ✓ | ✓ |
| MC_Bank_GKE | ✓ | ✓ (×N aliases) | | | | | ✓ | ✓ | |
| AKS_GKE | ✓ | | | ✓ | ✓ | | ✓ | | |
| EKS_GKE | ✓ | | | ✓ | | ✓ | ✓ | | |
