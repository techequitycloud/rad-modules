---
name: rad-modules-implementation
description: Guide for implementing Terraform/OpenTofu modules in the rad-modules repository. The modules are standalone GKE-based Kubernetes and multi-cloud fleet deployments (Istio_GKE, Bank_GKE, MC_Bank_GKE, AKS_GKE, EKS_GKE), VMware infrastructure (VMware_Engine), and migration labs (Container_Migration, Migration_Center).
---

# RAD Modules Implementation Skill

This skill explains how the Terraform/OpenTofu modules in this repository are structured and how to add a new one. The canonical reference throughout this document is **`modules/Istio_GKE`**: read its source alongside this guide.

## 1. Repository Overview

Each top-level entry under `modules/` is an **independent, self-contained module**. There is no shared foundation module, no symlink pattern, and no cross-module Terraform dependency. A module owns every resource it provisions and produces its own state.

The eight modules in the repository today:

| Module | What it provisions | Target audience |
|---|---|---|
| `Istio_GKE` | GKE Standard cluster + open-source Istio (sidecar **or** ambient mode) + Prometheus/Jaeger/Grafana/Kiali + optional Bookinfo sample | Platform engineers learning upstream Istio |
| `Bank_GKE` | Single GKE cluster (Autopilot or Standard) + Cloud Service Mesh (managed Istio) + Bank of Anthos v0.6.7 + optional Anthos Config Management + Cloud Monitoring SLOs | Engineers exploring ASM on a single cluster |
| `MC_Bank_GKE` | Multiple GKE clusters across multiple regions + fleet-wide Cloud Service Mesh + Multi-Cluster Ingress (MCI) + Multi-Cluster Services (MCS) + Bank of Anthos across all clusters behind a global HTTPS load balancer | Engineers exploring multi-cluster mesh and traffic |
| `AKS_GKE` | Microsoft Azure AKS cluster registered with GCP as a **GKE Attached Cluster** via Fleet, with the GKE Connect agent installed via Helm | Engineers exploring multi-cloud fleet management |
| `EKS_GKE` | AWS EKS cluster registered with GCP as a **GKE Attached Cluster** via Fleet, with the GKE Connect agent installed via Helm | Engineers exploring multi-cloud fleet management |
| `VMware_Engine` | Google Cloud VMware Engine (GCVE) private cloud + VMware Engine Network + VPC peering + network policy + firewall rules + Windows jump host + vCenter credential reset | Engineers exploring VMware workload migration to GCP |
| `Container_Migration` | GKE cluster + Compute Engine VMs (PostgreSQL source, Tomcat source, M2C workstation) provisioned as a hands-on Migrate to Containers (M2C) lab environment | Engineers replatforming VM-based Linux workloads to containers |
| `Migration_Center` | Windows Server VM (MCDCv6 pre-installed) + Debian Linux target VMs + Migration Center service registration + optional AWS asset import | Engineers running Migration Center discovery and TCO assessment labs |

Supporting directories:

- `rad-launcher/` — `radlab.py` is a Python CLI that wraps OpenTofu/Terraform for interactive module deployment from a workstation or Cloud Shell.
- `rad-ui/automation/` — Cloud Build YAML files (`cloudbuild_deployment_{create,destroy,purge,update}.yaml`) used by the RAD platform UI to run module deployments remotely.
- `scripts/` — standalone helper shell scripts grouped by topic (`gcp-istio-security/`, `gcp-istio-traffic/`, `gcp-cr-mesh/`, `gcp-m2c-vm/`, `gcp-gemini-cymbalpools/`). Each subdirectory contains a single `.sh` script and a `README.md`. These are not called by any Terraform module; they are hand-run by engineers for lab exercises or operational tasks.
- `docs/labs/` — centralized lab guides for all modules (e.g. `docs/labs/Istio_GKE.md`). This is the canonical location for all step-by-step lab guides; there are no `LAB_GUIDE.md` files inside module directories.
- `docs/modules/` — reference documentation for GKE-based modules.
- `docs/capabilities/`, `docs/practices/` — cross-cutting capability and practice guides.
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
├── tests/               # *.tftest.hcl — mock-provider plan tests (no GCP credentials needed)
├── README.md            # Short overview + usage + Requirements/Providers/Resources/Inputs/Outputs tables
└── Istio_GKE.md         # Long technical walkthrough (≈1,400 lines)
# Lab guide lives at: docs/labs/Istio_GKE.md
```

Other modules introduce their own domain-specific files alongside this skeleton:

| Module | Additional/replacement files |
|---|---|
| `Bank_GKE` | `asm.tf` (Cloud Service Mesh via GKE Hub), `deploy.tf` (downloads Bank of Anthos tarball and applies manifests), `hub.tf` (fleet membership), `glb.tf` (global load balancer IP), `monitoring.tf` (SLOs), `templates/*.yaml.tpl` |
| `MC_Bank_GKE` | `asm.tf`, `deploy.tf`, `hub.tf`, `glb.tf`, `mcs.tf` (MCI/MCS destroy cleanup), `manifests.tf` (renders templates → `manifests/`), `manifests/`; `deploy.tf` uses `for_each` over all clusters — ConfigMaps and Services are applied to every cluster, while DB StatefulSets (`accounts-db.yaml`, `ledger-db.yaml`) are applied to `cluster1` (primary) only; non-primary clusters connect to the databases via MCS |
| `AKS_GKE` | `provider.tf` (direct provider config, no impersonation wrapper), no `versions.tf`, no `network.tf` (Azure VNet is created inline in `main.tf`), nested `modules/attached-install-manifest/` and `modules/attached-install-mesh/` (Helm-based installers) |
| `EKS_GKE` | `provider.tf`, `vpc.tf` (AWS VPC), `iam.tf` (AWS IAM roles for EKS), same nested `modules/` as AKS_GKE |
| `VMware_Engine` | `private_cloud.tf` (GCVE private cloud), `network_peering.tf` (VPC ↔ VMware Engine Network peering), `network_policy.tf` (internet/external IP access), `firewall.tf` (VPC firewall rules), `jump_host.tf` (Windows Server 2022 VM), `vcenter_credentials.tf` (reset and retrieve vCenter solution user credentials via `null_resource`), `vmware_network.tf` (VMware Engine Network), `vpc.tf` (peer VPC), `cleanup.tf` (best-effort destroy cleanup) |

### 2.1 Nested Submodules

`AKS_GKE/modules/` and `EKS_GKE/modules/` contain two inner Terraform modules:

- `attached-install-manifest` — Renders and applies the GKE Connect agent bootstrap manifest via Helm. Called automatically by the parent module after the cluster is registered as a GKE Attached Cluster.
- `attached-install-mesh` — Optional Anthos Service Mesh installer. **Not called automatically** by the parent; invoke it from your own root module if you want ASM on the attached cluster.

## 3. Standard File Contents

### 3.1 `main.tf`

Every module's `main.tf` does the same three things at the top:

1. Looks up the existing GCP project via `data "google_project" "existing_project"` keyed by `var.project_id`.
2. Generates a deployment suffix: `random_id "default"` is created when `var.deployment_id` is `null`; `local.random_id` resolves to either the provided value or the generated hex.
3. Enables the project's required APIs via `google_project_service.enabled_services`. Two protections are required — this is critical because multiple independent modules may be deployed into the same GCP project, and a destroy of one module must not pull APIs out from under another:

```hcl
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.default_apis)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
```

`disable_on_destroy = false` prevents Terraform from issuing a `serviceusage.services.disable` call when the resource record is destroyed. Without this, a `tofu destroy` on one module can silently disable an API (e.g. `container.googleapis.com`) that another module — or a manually deployed workload — still depends on. The resource record is removed from Terraform state but the API remains enabled in GCP — this is the correct behaviour.

`disable_dependent_services = false` prevents Terraform from cascade-disabling transitive API dependencies (e.g. disabling `container.googleapis.com` could otherwise automatically disable `containerregistry.googleapis.com`).

**Do not add `lifecycle { prevent_destroy = true }` to `google_project_service` resources.** Although it prevents the resource record from being deleted, it also causes the platform destroy pipeline to fail with "Instance cannot be destroyed" when a full `tofu destroy` is run. `disable_on_destroy = false` is sufficient — it keeps the API enabled without blocking destroy. The `enable_services` toggle variable must be declared in **group 0, order 109** (Provider / Metadata) so it appears alongside other platform-level controls on the deployment form.

Modules that install workloads via `kubectl` also include a `null_resource.wait_for_container_api` that polls `gcloud services list` until `container.googleapis.com` reports as enabled before any cluster resource is created.

### 3.2 `provider-auth.tf` vs `provider.tf`

Two patterns exist:

**Impersonation pattern (`provider-auth.tf`)** — used by `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`, `VMware_Engine`, `Container_Migration`, `Migration_Center`:

```hcl
provider "google" { alias = "impersonated" ... }

data "google_service_account_access_token" "default" {
  count                  = length(var.resource_creator_identity) != 0 ? 1 : 0
  provider               = google.impersonated
  target_service_account = var.resource_creator_identity
  lifetime               = "3600s"
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
| `Istio_GKE` | `google` (>= 5.0), `google-beta` (>= 5.0), `kubernetes` (>= 2.23) | `>= 1.3` |
| `Bank_GKE` | `google` (>= 5.0), `kubernetes` (>= 2.23), `kubectl` (gavinbunney/kubectl >= 1.14), `time` (>= 0.9), `http` (>= 3.0) | `>= 1.3` |
| `MC_Bank_GKE` | `google` (>= 5.0), `google-beta` (>= 5.0), `kubernetes` (>= 2.23) | `>= 1.3` |
| `VMware_Engine` | `google` (>= 5.0), `random` (>= 3.0), `null` (>= 3.0), `external` (>= 2.0) | `>= 1.3` |
| `Container_Migration` | `google` (>= 5.0, < 6.0), `random` (>= 3.0), `null` (>= 3.0) | `>= 1.3` |
| `Migration_Center` | `google` (>= 5.0, < 6.0), `aws` (>= 5.0, < 6.0), `random` (>= 3.0), `null` (>= 3.0), `tls` (>= 4.0) | `>= 1.3` |
| `AKS_GKE` | No top-level `versions.tf`; the nested submodules have their own | — |
| `EKS_GKE` | No top-level `versions.tf`; the nested submodules have their own | — |

Providers that are used but not explicitly pinned (e.g. `random`, `null`) are downloaded at the version OpenTofu/Terraform selects automatically. `Istio_GKE`, `MC_Bank_GKE`, `Bank_GKE`, `VMware_Engine`, `Container_Migration`, and `Migration_Center` configure a `google-beta` provider block in `provider-auth.tf`, but none currently assign resources to it explicitly. `Istio_GKE` and `MC_Bank_GKE` explicitly pin `google-beta` in `versions.tf` (alongside `google`) even though no resources use it.

### 3.4 `variables.tf` — UIMeta Annotations

All input variables carry a `{{UIMeta group=N order=M }}` annotation at the end of their `description`. The platform UI uses these to group and order inputs on the deployment form. The sectioning convention used across GKE-based modules:

| Group | Section | Variables |
|---|---|---|
| 0 | Provider / Metadata | `module_description`, `module_documentation`, `module_dependency`, `module_services`, `credit_cost`, `require_credit_purchases`, `enable_purge`, `public_access`, `resource_creator_identity`, `trusted_users`, `deployment_id`, `enable_services` |
| 1 | Main | `project_id`, `region` |
| 2 | Network | `create_network`, `network_name`, `subnet_name`, `ip_cidr_ranges` |
| 3 | GKE | `create_cluster`, `gke_cluster`, `release_channel`, `pod_ip_range`, `pod_cidr_block`, `service_ip_range`, `service_cidr_block` |
| 4 | Features | `istio_version`, `install_ambient_mesh` |
| 6 | Application | `deploy_application` |

`VMware_Engine` uses a different group structure reflecting its domain:

| Group | Section | Variables |
|---|---|---|
| 0 | Provider / Metadata | (same as above, including `enable_services`) |
| 1 | Main | `project_id`, `region`, `zone` |
| 4 | Private Cloud | `management_cidr`, `private_cloud_type`, `node_type_id`, `node_count` |
| 5 | Network Peering | `create_vpc` |
| 6 | Network Policy | `edge_services_cidr`, `enable_internet_access`, `enable_external_ip` |
| 7 | Firewall Rules | `create_default_firewall_rules`, `internal_traffic_cidr` |
| 8 | Jump Host | `create_jump_host`, `jump_host_machine_type`, `jump_host_boot_disk_size_gb`, `jump_host_subnetwork` |
| 9 | vCenter Credentials | `reset_vcenter_credentials`, `vcenter_solution_user` |

`AKS_GKE` and `EKS_GKE` consolidate their main configuration (project, cloud credentials, region/location) into group 1, and cluster-specific settings into group 4. There is no group 2 or 3 for these modules.

Example variable:

```hcl
variable "project_id" {
  description = "GCP project ID of the destination project where the GKE cluster and Istio service mesh will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
}
```

The `updatesafe` tag marks variables whose value can change on an in-place `terraform apply` without forcing resource replacement.

The `module_documentation` variable (group 0, order 1) holds a URL to the module's external documentation and is displayed in the platform UI as a help reference. Every module must include it.

### 3.5 `outputs.tf`

Standard outputs present in every GKE-based module (compare `modules/Istio_GKE/outputs.tf:17-38`):

- `deployment_id` — echoes the suffix (provided or generated) used in resource names.
- `project_id` — the GCP project where resources were deployed.
- `cluster_credentials_cmd` — a ready-to-paste `gcloud container clusters get-credentials ...` command for operators.
- `external_ip` — read from a file written by a post-provisioning `null_resource` (e.g. Istio Ingress Gateway IP); falls back to `"IP not available"` via `fileexists()`.

`VMware_Engine` exposes VMware-specific outputs instead of cluster credentials:

- `deployment_id`, `project_id` — same as GKE modules.
- `vmware_engine_network_id` — full resource ID of the VMware Engine Network.
- `private_cloud_id` — full resource ID of the GCVE private cloud.
- `vcenter_fqdn`, `nsx_fqdn`, `hcx_fqdn` — management console FQDNs accessible from the jump host.
- `network_peering_state` — current state of the VPC ↔ VMware Engine Network peering.
- `network_policy_id` — full resource ID of the network policy.

Attached-cluster modules (`AKS_GKE`, `EKS_GKE`) expose no Terraform outputs; they document the equivalent `gcloud container attached clusters get-credentials` command in their README.

### 3.6 Post-Provisioning with `null_resource`

Anything that cannot be expressed as a Terraform resource — installing Istio via `istioctl`, applying Bank of Anthos manifests, waiting for a LoadBalancer IP — is wrapped in `null_resource` with `local-exec` provisioners. Conventions observed in `istiosidecar.tf:17-293`:

1. **Triggers** capture every variable needed by the `destroy` provisioner (e.g. `cluster_name`, `region`, `project_id`, `resource_creator_identity`), because `self.triggers.*` is the only input available at destroy time.
2. **Create provisioner**: `set -eo pipefail`, install missing CLIs (`kubectl`, `istioctl`) into `$HOME/.local/bin`, run `gcloud container clusters get-credentials ... --impersonate-service-account=...`, then perform the actual install.
3. **Destroy provisioner**: `set +e` to make cleanup best-effort — failures during destroy should never block Terraform from removing infrastructure. Uses `--ignore-not-found` on kubectl calls and `|| echo "Warning: ..."` on each step.
4. **Explicit `depends_on`** against the cluster and node pool, so Terraform does not attempt the install until Kubernetes is actually ready.

## 4. Documentation Pattern

Each module ships two markdown files inside the module directory, plus one in `docs/labs/`:

- **`README.md`** (≈90–100 lines): short prose intro, a copy-pastable `module "..." { source = ... }` usage block, and standard tables for Requirements, Providers, Modules (if any), Resources, Inputs, Outputs.
- **`<Module_Name>.md`** (≈1,100–2,600 lines): long-form technical walkthrough covering the architecture diagram, every resource the module creates, the networking layout, security model, and operational guidance. These are meant as learning material — `Istio_GKE.md` explains VPC-native networking, secondary IP ranges, iptables-based traffic interception, and the sidecar-vs-ambient trade-off in enough depth to teach the technology, not just operate it.
- **`docs/labs/<Module_Name>.md`**: step-by-step hands-on lab guide for engineers walking through the module's use cases. Covers prerequisites, deployment steps, lab exercises, and cleanup. This file is referenced from `README.md` and is the target of the `module_documentation` URL in `variables.tf`. **Do not create a `LAB_GUIDE.md` inside the module directory.**

When writing these files for a new module, match the tone and depth of `modules/Istio_GKE/README.md`, `modules/Istio_GKE/Istio_GKE.md`, and `docs/labs/Istio_GKE.md`.

## 5. Creating a New Module

There is no scaffolding script. Create a new module by copying the layout from the closest existing module:

1. **Pick a template** based on what you are deploying:
   - Single GKE cluster with workload → copy `Istio_GKE` or `Bank_GKE`.
   - Multi-cluster GKE → copy `MC_Bank_GKE`.
   - Attached cluster on AWS/Azure → copy `EKS_GKE` / `AKS_GKE`.
   - VMware / non-Kubernetes GCP infrastructure → copy `VMware_Engine`.
2. `cp -a modules/Istio_GKE modules/MyNewModule` and rename any module-specific `.tf` files (e.g. `istiosidecar.tf` → `mynewmodule.tf`).
3. Edit `variables.tf` — update `module_description`, `module_documentation`, `module_services`, `module_dependency`, any feature flags, and default values. Keep the UIMeta annotations; renumber `order` values if you add new variables in an existing group.
4. Replace the provisioning logic in the domain-specific `.tf` files. If you need post-provisioning steps, follow the `null_resource` pattern in `istiosidecar.tf`.
5. Update `outputs.tf` — always expose `deployment_id`, `project_id`, and (for GKE modules) `cluster_credentials_cmd`.
6. Write `README.md` and `<Module_Name>.md` inside the module directory. Write the step-by-step lab guide as `docs/labs/<Module_Name>.md`. Set the `module_documentation` variable default in `variables.tf` to the GitHub URL of the `docs/labs/<Module_Name>.md` file.
7. Validate:

   ```bash
   cd modules/MyNewModule
   tofu init      # or: terraform init
   tofu validate
   tofu fmt -check
   tofu plan -var="project_id=my-test-project"
   ```

## 6. Conventions and Invariants

- **File naming**: `snake_case` for `.tf` files. Module directories use `PascalCase` / `SCREAMING_SNAKE_CASE` (e.g. `Istio_GKE`, `MC_Bank_GKE`).
- **Copyright headers**: Every `.tf` file begins with the Apache 2.0 license header.
- **API enablement — never disable on destroy**: Always set `disable_dependent_services = false` and `disable_on_destroy = false` on every `google_project_service` resource (see canonical pattern in §3.1). This is a hard invariant: the platform deploys multiple independent modules into a single GCP project, so destroying one module must not disable APIs that other modules, workloads, or platform components depend on. `disable_on_destroy = false` makes `tofu destroy` remove the Terraform resource record while leaving the API enabled in GCP — this is the correct and sufficient protection. Do **not** add `lifecycle { prevent_destroy = true }` to these resources: it blocks the platform's destroy pipeline with a fatal "Instance cannot be destroyed" error. The `enable_services` toggle variable belongs in **group 0, order 109** (see §3.4) — it is a platform-level control and must not be placed in any other group. When auditing inherited code, search for `disable_on_destroy = true` or any `google_project_service` block missing the flags and correct it before the first destroy is run.
- **Destroy safety**: Any `null_resource` with a meaningful create-time effect **must** have a matching `when = destroy` provisioner that cleans up, and that provisioner must tolerate missing resources (`--ignore-not-found`, `|| true`, etc.).
- **Impersonation**: Only fetch an impersonation access token when `length(var.resource_creator_identity) != 0`; otherwise let the provider use ADC.
- **No secrets in variables**: Credentials like `client_secret`, `aws_secret_key` are module inputs but must never be given default values. The caller is responsible for sourcing them from a secret store.
- **`prevent_destroy` on critical IAM bindings**: IAM bindings that must outlive a `tofu destroy` (e.g. `VMware_Engine`'s `google_project_iam_member.vmmigration_sa_user`) use `lifecycle { prevent_destroy = true }`. This protects service agent permissions that are expensive or impossible to re-grant automatically.
- **`project_id` variable name**: All modules use `project_id` (not `existing_project_id` or any other alias) for the GCP project input.
- **Region variable name**: All modules use `region` (not `gcp_region`) for the GCP region input. The `AKS_GKE` module additionally exposes `gcp_location` (the GKE Hub registration region) and `azure_region`; `EKS_GKE` exposes `gcp_location` and `aws_region`.
- **MC_Bank_GKE ConfigMaps**: ConfigMaps and Services are applied to every cluster in the fleet. Only database StatefulSets are restricted to the primary cluster. Applying ConfigMaps to all clusters ensures non-primary application pods can resolve backend service addresses via MCS.

## 7. Running a Module

### Local (OpenTofu/Terraform)

```bash
cd modules/Istio_GKE
tofu init
tofu plan  -var="project_id=my-gcp-project"
tofu apply -var="project_id=my-gcp-project"
tofu destroy -var="project_id=my-gcp-project"
```

### Via the RAD Modules Launcher

```bash
cd rad-launcher
python3 installer_prereq.py
python3 radlab.py
```

`radlab.py` interactively prompts for a module, project, and variables, then drives `tofu init/apply` under the hood.

### Via the RAD UI platform

The platform invokes Cloud Build with the YAML files in `rad-ui/automation/`:

- `cloudbuild_deployment_create.yaml` — `tofu apply`; **timeout: 10800s**
- `cloudbuild_deployment_update.yaml` — re-apply with changed variables; **timeout: 10800s**
- `cloudbuild_deployment_destroy.yaml` — `tofu destroy`; **timeout: 10800s**
- `cloudbuild_deployment_purge.yaml` — destroy plus post-cleanup for any resources Terraform could not remove; **timeout: 600s**

**Provider caching**: The create, update, and destroy pipelines cache the downloaded Terraform provider binaries in GCS between builds. Before each `tofu init` the pipeline restores the cache from `gs://${_DEPLOYMENT_BUCKET_ID}/terraform-provider-cache/${_MODULE_NAME}/providers.tar.gz` into `/workspace/.terraform-plugin-cache/` (via `TF_PLUGIN_CACHE_DIR`) and saves it back after a successful init. A missing cache is non-fatal; providers are downloaded fresh on the first run for a given module.

**Kubernetes rollout timeout handling**: When `tofu apply` exits non-zero because a `kubectl rollout status` wait timed out (matched by patterns like `timed out waiting for the condition`, `Deployment.*timed out`, `StatefulSet.*timed out`), both the create and update pipelines treat this as a **partial success** rather than a failure. The infrastructure and Kubernetes objects are fully provisioned; pods continue their own health checks independently. This prevents spurious deployment failures caused by slow image pulls or node scheduling delays.

These pipelines are invoked by the platform, not by module developers directly.

## 8. Troubleshooting

### Cluster credentials fail in a `null_resource`

The `local-exec` runs on the machine executing `tofu apply`, not in GCP. Check that `gcloud` and `kubectl` are installed and that either ADC or `--impersonate-service-account=${var.resource_creator_identity}` can reach the cluster. The installer blocks in `istiosidecar.tf:42-58` show how to install `kubectl` on demand when missing.

### `istioctl install` fails with HPA naming conflicts

The sidecar-mode installer (`istiosidecar.tf:109-148`) pipes a custom `IstioOperator` YAML into `istioctl install -y -f -` specifically to set an explicit `hpaSpec.scaleTargetRef.name = istio-ingressgateway`. If you see HPA errors, confirm this block is still present and unmodified.

### Destroy hangs or loops

A `null_resource` destroy provisioner is failing hard. Every destroy provisioner must be idempotent and best-effort — re-check that it uses `set +e` (not `set -e`), `--ignore-not-found` on kubectl calls, and redirects errors rather than aborting.

### API disabled after destroy

**Symptom**: After a `tofu destroy`, other deployments in the same project start failing with errors like `API [container.googleapis.com] not enabled on project`, `googleapi: Error 403: ... is disabled`, or similar.

**Root cause**: A `google_project_service` resource had `disable_on_destroy = true` (or the flag was omitted, which defaults to `true` in older provider versions), and/or was missing `lifecycle { prevent_destroy = true }`. When the resource was destroyed, Terraform issued an API disable call that affected the whole project.

**Fix on the destroyed module**: Open `main.tf` and confirm the resource matches the canonical pattern from §3.1 — all three protections must be present:

```hcl
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.default_apis)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false

  lifecycle {
    prevent_destroy = true
  }
}
```

Correct the flags **before** running another destroy. Changing the flags does not re-enable already-disabled APIs.

**Re-enabling a disabled API**: Run `gcloud services enable <api> --project=<project_id>` for each affected API. For GKE modules the most commonly disabled API is `container.googleapis.com`; re-enable it and then re-run `tofu apply` on any module that was impacted.

**Auditing for this mistake**: Run the following to find `google_project_service` blocks missing the safe flags:

```bash
grep -n "disable_on_destroy\|disable_dependent_services\|prevent_destroy" modules/*/main.tf
```

Every block must show all three settings. Absence of any line is a defect — add them explicitly rather than relying on defaults.

### API `prevent_destroy` blocks `tofu destroy`

This is expected and intentional. `google_project_service` resources with `lifecycle { prevent_destroy = true }` cause `tofu destroy` to exit with an error rather than disable project APIs. To fully decommission a module and remove its API records from state, first remove the `lifecycle` block (or run `terraform state rm 'google_project_service.enabled_services["<api>"]'`) then re-run `tofu destroy`. Do not skip this — APIs disabled mid-destroy can break other running modules in the same project.

### Attached cluster never appears in the GCP Console

The GKE Connect agent must be installed on the attached cluster. In `AKS_GKE` and `EKS_GKE` this is the job of `modules/attached-install-manifest` — verify the submodule is being invoked and its Helm release succeeded.

### Bank of Anthos pods stuck pending

The `deploy.tf` `null_resource` downloads the release tarball into `.terraform/bank-of-anthos` on the machine running `apply`. If the download or extract fails, the manifests are never applied. Check the `local-exec` output; the download is forced fresh on every apply via `always_run = timestamp()` (see `modules/Bank_GKE/deploy.tf:40`).

### VMware Engine `prevent_destroy` blocks `tofu destroy`

The `google_project_iam_member.vmmigration_sa_user` resource has `lifecycle { prevent_destroy = true }`. This is intentional — the VM Migration service agent binding must not be removed during a partial destroy. To fully decommission the module, remove the `prevent_destroy` block from `main.tf` before running `tofu destroy`.

## 9. Quick Reference

### Standard variable set (GKE-based modules)

```hcl
project_id                 # GCP project ID (required)
region                     # e.g. "us-central1"
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
  value = "gcloud container clusters get-credentials ${var.gke_cluster} --region ${var.region} --project ${local.project.project_id}"
}
output "external_ip" {
  value = fileexists("${path.module}/scripts/app/external_ip.txt") ? file("${path.module}/scripts/app/external_ip.txt") : "IP not available"
}
```

### Common providers

The table shows which providers each module actively uses. GKE-based modules, `VMware_Engine`, `Container_Migration`, and `Migration_Center` also configure a `google-beta` provider block in `provider-auth.tf` as a convenience (for future use), but no resources are currently assigned to it.

| Module | google | kubernetes | kubectl | helm | azurerm | aws | tls | random | null | external | time / http |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Istio_GKE | ✓ | ✓ | | | | | | ✓ | ✓ | | |
| Bank_GKE | ✓ | ✓ | ✓ | | | | | ✓ | ✓ | | ✓ |
| MC_Bank_GKE | ✓ | ✓ (×N aliases) | | | | | | ✓ | ✓ | | |
| AKS_GKE | ✓ | | | ✓ | ✓ | | | ✓ | | | |
| EKS_GKE | ✓ | | | ✓ | | ✓ | | ✓ | | | |
| VMware_Engine | ✓ | | | | | | | ✓ | ✓ | ✓ | |
| Container_Migration | ✓ | | | | | | | ✓ | ✓ | | |
| Migration_Center | ✓ | | | | | ✓ | ✓ | ✓ | ✓ | | |
