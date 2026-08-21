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
| `Istio_GKE` | GKE Standard cluster + open-source Istio (sidecar **or** ambient mode) + Prometheus/Jaeger/Grafana/Kiali (no demo app — `deploy_application` is dead code; see §8) | Platform engineers learning upstream Istio |
| `Bank_GKE` | Single GKE cluster (Autopilot or Standard) + Cloud Service Mesh (managed Istio) + Bank of Anthos v0.6.10 + optional Anthos Config Management + Cloud Monitoring SLOs | Engineers exploring ASM on a single cluster |
| `MC_Bank_GKE` | Multiple GKE clusters across multiple regions + fleet-wide Cloud Service Mesh + Multi-Cluster Ingress (MCI) + Multi-Cluster Services (MCS) + Bank of Anthos across all clusters behind a global HTTPS load balancer | Engineers exploring multi-cluster mesh and traffic |
| `AKS_GKE` | Microsoft Azure AKS cluster registered with GCP as a **GKE Attached Cluster** via Fleet, with the GKE Connect agent installed via Helm | Engineers exploring multi-cloud fleet management |
| `EKS_GKE` | AWS EKS cluster registered with GCP as a **GKE Attached Cluster** via Fleet, with the GKE Connect agent installed via Helm | Engineers exploring multi-cloud fleet management |
| `VMware_Engine` | Google Cloud VMware Engine (GCVE) private cloud + VMware Engine Network + VPC peering + network policy + firewall rules + Windows jump host + vCenter credential reset | Engineers exploring VMware workload migration to GCP |
| `Container_Migration` | GKE cluster + Compute Engine VMs (PostgreSQL source, Tomcat source, M2C workstation) provisioned as a hands-on Migrate to Containers (M2C) lab environment | Engineers replatforming VM-based Linux workloads to containers |
| `Migration_Center` | Windows Server VM (MCDCv6 pre-installed) + Debian Linux target VMs + Migration Center service registration + optional AWS asset import | Engineers running Migration Center discovery and TCO assessment labs |

Supporting directories:

- `rad-launcher/` — `radlab.py` is a Python CLI that wraps OpenTofu/Terraform for interactive module deployment from a workstation or Cloud Shell.
- `rad-ui/automation/` — Cloud Build YAML files (`cloudbuild_deployment_{create,destroy,purge,update}.yaml`) used by the RAD platform UI to run module deployments remotely.
- `scripts/` — standalone helper shell scripts grouped by topic (`gcp-istio-security/`, `gcp-istio-traffic/`, `gcp-cr-mesh/`, `gcp-m2c-vm/`, `gcp-ge-cymbal/`). Each subdirectory contains a single `.sh` script and a `README.md`. These are not called by any Terraform module; they are hand-run by engineers for lab exercises or operational tasks.
- `docs/labs/` — centralized lab guides for all modules (e.g. `docs/labs/Istio_GKE.md`). This is the canonical location for all step-by-step lab guides; there are no `LAB_GUIDE.md` files inside module directories.
- `docs/modules/` — reference documentation for GKE-based modules.
- `docs/` contains only `labs/` and `modules/` — there are no `docs/capabilities/` or `docs/practices/` directories.
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
# Technical walkthrough lives at: docs/modules/Istio_GKE.md (≈245 lines)
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
| `VMware_Engine` | `google` (>= 5.0, < 6.0), `random` (>= 3.0), `null` (>= 3.0), `external` (>= 2.0) | `>= 1.3` |
| `Container_Migration` | `google` (>= 5.0, < 6.0), `random` (>= 3.0), `null` (>= 3.0) | `>= 1.3` |
| `Migration_Center` | `google` (>= 5.0, < 6.0), `aws` (>= 5.0, < 6.0), `random` (>= 3.0), `null` (>= 3.0), `tls` (>= 4.0) | `>= 1.3` |
| `AKS_GKE` | No top-level `versions.tf` — pinned instead in `provider.tf`: `azurerm` (~> 4.0), `google` (>= 5.0.0), `helm` (~> 2.0), `random` (3.6.2) | `>= 0.13` |
| `EKS_GKE` | No top-level `versions.tf` — pinned instead in `provider.tf`: `aws` (>= 4.5.0), `google` (>= 5.0.0), `helm` (~> 2.0), `time` (~> 0.9) | `>= 1.3` |

Providers that are used but not explicitly pinned (e.g. `random`, `null`) are downloaded at the version OpenTofu/Terraform selects automatically. `Istio_GKE`, `MC_Bank_GKE`, `Bank_GKE`, `VMware_Engine`, `Container_Migration`, and `Migration_Center` configure a `google-beta` provider block in `provider-auth.tf`, but none currently assign resources to it explicitly. `Istio_GKE` and `MC_Bank_GKE` explicitly pin `google-beta` in `versions.tf` (alongside `google`) even though no resources use it.

**An unbounded lower-bound constraint (`>= X.Y.Z` with no upper bound) is not equivalent to "pinned" — it's a live risk, not a hypothetical one.** `.terraform.lock.hcl` is gitignored repo-wide (`*.lock.hcl` in the root `.gitignore`), so every `tofu init` — CI, the Cloud Build pipelines, and any manual run — re-resolves providers fresh from the constraint string alone. `AKS_GKE`'s `azurerm` was `">=3.17.0"` until this was found to have resolved 5.0.1 on a routine re-init: azurerm 5.0 made `node_provisioning_profile` a required block on `azurerm_kubernetes_cluster`, so `tofu validate`/`plan` failed before ever reaching Azure. Fixed by pinning `"~> 4.0"` (now shown in the table above). The identical unbounded shape is still live in `EKS_GKE`'s `aws = ">=4.5.0"` and in `google = ">=5.0.0"` across every module in this table — currently resolving 7.43.0, two majors past when most of these modules were written. When adding or reviewing a `required_providers` block, use `~>` (or an explicit `< N.0.0`) rather than a bare `>=`, and match it to the major version the module's resource blocks were actually written against — not to "whatever's current" at pin time.

### 3.4 `variables.tf` — UIMeta Annotations

All input variables carry a `{{UIMeta group=N order=M }}` annotation at the end of their `description`. The platform UI uses these to group and order inputs on the deployment form. The sectioning convention used across GKE-based modules:

| Group | Section | Variables |
|---|---|---|
| 0 | Provider / Metadata | `module_description`, `module_documentation`, `module_dependency`, `module_services`, `credit_cost`, `require_credit_purchases`, `enable_purge`, `public_access`, `resource_creator_identity`, `trusted_users`, `deployment_id`, `enable_services` |
| 1 | Main | `project_id`, `region` |
| 2 | Network | `create_network`, `network_name`, `subnet_name`, `ip_cidr_ranges` |
| 3 | GKE | `create_cluster`, `gke_cluster`, `release_channel`, `pod_ip_range`, `pod_cidr_block`, `service_ip_range`, `service_cidr_block` |
| 4 | Features | `istio_version`, `install_ambient_mesh` |
| 0 | Application (source comment says `// SECTION 6`, but the UIMeta tag is group 0) | `deploy_application` (`{{UIMeta group=0 order=601 }}`) |

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

`AKS_GKE` consolidates its main configuration (project, Azure credentials, region/location) into group 1 and cluster-specific settings into group 4; it has no group 2 or 3. `EKS_GKE` does not follow that shape — it uses groups 0, 1, 2 and 3, with no group 4.

Example variable:

```hcl
variable "project_id" {
  description = "GCP project ID of the destination project where the GKE cluster and Istio service mesh will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
}
```

The `updatesafe` tag marks variables whose value can change on an in-place `terraform apply` without forcing resource replacement.

**Its absence is what the platform acts on (2026-08-19).** An unflagged field raises a *"this update will destroy project resources"* confirmation when edited on an existing deployment, and is read-only when the admin setting **Enforce Update Safe** is on. The webapp's matcher previously looked for a token no module writes, so the flag had never been read and wrong ones accumulated — `region` carried it in 422 modules catalogue-wide.

An over-generous flag is a **silent data-loss path**; a missing one merely warns. **When in doubt, leave it off**, and check with `rad-automation/scripts/check_updatesafe_flags.py`. Beyond "forces replacement", two traps: a variable in a resource's `count`/`for_each` **condition** gates that resource's existence (turning it off destroys it), and a comparison against a **literal** is a mode switch that destroys on any change, while a comparison against **emptiness** only destroys when the value is cleared.

The sibling `notradmanaged` tag **removes** the variable from the form in a RAD-managed project and reverts it server-side — for settings that reach past the tenant's own project into RAD's organisation (VPC Service Controls, Security Command Center, Workload Identity Federation). Its module default must be benign, because that is what the server reverts to.

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

Attached-cluster modules (`AKS_GKE`, `EKS_GKE`) expose only `deployment_id` and `project_id` (`modules/AKS_GKE/outputs.tf:19,25`); there is no credentials output — they document the equivalent `gcloud container attached clusters get-credentials` command in their README.

### 3.6 Post-Provisioning with `null_resource`

Anything that cannot be expressed as a Terraform resource — installing Istio via `istioctl`, applying Bank of Anthos manifests, waiting for a LoadBalancer IP — is wrapped in `null_resource` with `local-exec` provisioners. Conventions observed in `istiosidecar.tf:17-293`:

1. **Triggers** capture every variable needed by the `destroy` provisioner (e.g. `cluster_name`, `region`, `project_id`, `resource_creator_identity`), because `self.triggers.*` is the only input available at destroy time.
2. **Create provisioner**: `set -eo pipefail`, install missing CLIs (`kubectl`, `istioctl`) into `$HOME/.local/bin`, run `gcloud container clusters get-credentials ... --impersonate-service-account=...`, then perform the actual install.
3. **Destroy provisioner**: `set +e` to make cleanup best-effort — failures during destroy should never block Terraform from removing infrastructure. Uses `--ignore-not-found` on kubectl calls and `|| echo "Warning: ..."` on each step.
4. **Explicit `depends_on`** against the cluster and node pool, so Terraform does not attempt the install until Kubernetes is actually ready.
5. **Waiting on a GCP-managed async feature must poll the actual status field, not object existence.** GKE Hub/Fleet features (Cloud Service Mesh, MCI, ACM) create their `membershipStates` entry in `PROVISIONING` state within seconds of a spec update — long before the managed control plane is actually live. A wait loop that treats entry existence as "ready" (e.g. `grep -c` on the raw `membershipStates` describe output) returns success prematurely, and a downstream `null_resource` that deploys workloads immediately after will create pods with no sidecar injected, since the injector webhook isn't there yet and Deployments don't retroactively pick one up. Poll `membershipStates['<membership-path>'].servicemesh.controlPlaneManagement.state` until it equals `ACTIVE` instead — see `Bank_GKE/asm.tf`'s `wait_for_service_mesh` for the canonical pattern, and size the timeout well above the ~20-25 minutes first-time control-plane provisioning can take in a fresh project.

## 4. Documentation Pattern

Each module ships one markdown file inside the module directory, plus two under `docs/`:

- **`README.md`** (≈130–195 lines, inside the module directory): short prose intro, a copy-pastable `module "..." { source = ... }` usage block, and standard tables for Requirements, Providers, Modules (if any), Resources, Inputs, Outputs.
- **`docs/modules/<Module_Name>.md`** (≈200–270 lines): technical walkthrough covering the architecture, the resources the module creates, the networking layout, security model, and operational guidance. `docs/modules/Istio_GKE.md` is the reference example. Most modules point `module_documentation` at the published form of this file (`https://docs.radmodules.dev/docs/modules/<Module_Name>`); `Container_Migration`, `Migration_Center` and `VMware_Engine` instead point at the GitHub URL of their `docs/labs/` guide.
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
6. Write `README.md` inside the module directory, the technical walkthrough as `docs/modules/<Module_Name>.md`, and the step-by-step lab guide as `docs/labs/<Module_Name>.md`. Set the `module_documentation` variable default in `variables.tf` to the published docs URL `https://docs.radmodules.dev/docs/modules/<Module_Name>` (the convention in 5 of 8 modules; `Container_Migration`, `Migration_Center` and `VMware_Engine` instead link the GitHub URL of their `docs/labs/` guide).
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
- **No `prevent_destroy` in the modules today**: the only `lifecycle { prevent_destroy = … }` block anywhere under `modules/` is on `VMware_Engine`'s `google_project_iam_member.vmmigration_sa_user`, and it is set to `false` (`modules/VMware_Engine/main.tf:68`) so a full `tofu destroy` is never blocked. If you ever need an IAM binding to outlive a destroy, flipping that flag is the mechanism — but confirm the platform destroy pipeline can still complete first.
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

Before running any of the above against an unfamiliar/managed project (e.g. a Qwiklabs
lab): (1) if using an isolated `CLOUDSDK_CONFIG=<dir>` for this identity, also export
`GOOGLE_APPLICATION_CREDENTIALS="<dir>/application_default_credentials.json"` — `tofu`
does not honor `CLOUDSDK_CONFIG` itself (§8, "`PERMISSION_DENIED` on a project you can
definitely access"); (2) check `gcloud org-policies describe
constraints/gcp.resourceLocations --project=<id> --effective` before assuming the
module's default `region` is deployable there (§8, "Regional resource creation fails
with `violates constraint constraints/gcp.resourceLocations`").

### Via the RAD Modules Launcher

```bash
cd rad-launcher
python3 installer_prereq.py
python3 radlab.py
```

`radlab.py` interactively prompts for a module, project, and variables, then drives `tofu init/apply` under the hood.

### Via the RAD UI platform

The platform invokes Cloud Build with the YAML files in `rad-ui/automation/`:

- `cloudbuild_deployment_create.yaml` — `tofu apply`; **timeout: 3600s**
- `cloudbuild_deployment_update.yaml` — re-apply with changed variables; **timeout: 3600s**
- `cloudbuild_deployment_destroy.yaml` — `tofu destroy`; **timeout: 3600s**
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

**Fix on the destroyed module**: Open `main.tf` and confirm the resource matches the canonical pattern from §3.1 — both protections must be present, and there must be **no** `lifecycle` block (see §3.1: `prevent_destroy = true` here breaks the platform destroy pipeline):

```hcl
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.default_apis)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
```

Correct the flags **before** running another destroy. Changing the flags does not re-enable already-disabled APIs.

**Re-enabling a disabled API**: Run `gcloud services enable <api> --project=<project_id>` for each affected API. For GKE modules the most commonly disabled API is `container.googleapis.com`; re-enable it and then re-run `tofu apply` on any module that was impacted.

**Auditing for this mistake**: Run the following to find `google_project_service` blocks missing the safe flags:

```bash
grep -n "disable_on_destroy\|disable_dependent_services\|prevent_destroy" modules/*/main.tf
```

Every block must show both `disable_dependent_services = false` and `disable_on_destroy = false`. A missing line is a defect — add it explicitly rather than relying on defaults. A `prevent_destroy` line inside a `google_project_service` block is itself the defect (§3.1): remove it.

### API `prevent_destroy` blocks `tofu destroy`

This is expected and intentional. `google_project_service` resources with `lifecycle { prevent_destroy = true }` cause `tofu destroy` to exit with an error rather than disable project APIs. To fully decommission a module and remove its API records from state, first remove the `lifecycle` block (or run `terraform state rm 'google_project_service.enabled_services["<api>"]'`) then re-run `tofu destroy`. Do not skip this — APIs disabled mid-destroy can break other running modules in the same project.

### Attached cluster never appears in the GCP Console

The GKE Connect agent must be installed on the attached cluster. In `AKS_GKE` and `EKS_GKE` this is the job of `modules/attached-install-manifest` — verify the submodule is being invoked and its Helm release succeeded.

### Bank of Anthos pods stuck pending

The `deploy.tf` `null_resource` downloads the release tarball into `.terraform/bank-of-anthos` on the machine running `apply`. If the download or extract fails, the manifests are never applied. Check the `local-exec` output; the download is forced fresh on every apply via `always_run = timestamp()` (see `modules/Bank_GKE/deploy.tf:40`).

### Bank_GKE's mesh API guard times out after exactly 300s

`asm.tf`'s `verify_mesh_api_activation` polls for both `mesh.googleapis.com` and `meshconfig.googleapis.com` and `exit 1`s if either is missing after 300s. Enabling only `mesh.googleapis.com` in `default_apis` (`main.tf`) reproduces this every time — `meshconfig.googleapis.com` must be listed alongside it.

### CSM sidecar injection silently no-ops even though the control plane is `ACTIVE`

The namespace label `istio.io/rev` selects the CSM revision (`asm-managed`=REGULAR, `asm-managed-rapid`=RAPID, `asm-managed-stable`=STABLE), and it must match the cluster's `release_channel`. A mismatch does not error — injection is skipped for that namespace, silently. `Bank_GKE`/`MC_Bank_GKE` compute the correct label once as `local.asm_revision` (`main.tf`) and reference it everywhere the label is set; don't hardcode `asm-managed` if extending this pattern to another module. Diagnose with `gcloud container hub features describe servicemesh --project=<p> --format="value(membershipStates)"` compared against `kubectl get namespace <ns> -o jsonpath='{.metadata.labels.istio\.io/rev}'`.

### MC_Bank_GKE: Bank of Anthos pods have zero sidecars, and `gcloud container fleet mesh describe` shows `PROVISIONING` not `ACTIVE`

Distinct from the label-mismatch case above — here the label is correct, but `deploy.tf` ran before the managed control plane finished rolling out, so no injector webhook was present when the pods were created. This is the §3.6.5 pattern: `hub.tf`'s `wait_for_service_mesh` must poll `controlPlaneManagement.state` rather than merely checking that a `membershipStates` entry exists. For a deployment already in this state, waiting for `state` to reach `ACTIVE` and then running `kubectl rollout restart deployment,statefulset -n bank-of-anthos` forces pod recreation so the injector can act — the control plane finishing later does not retroactively touch existing pods.

### Regional resource creation fails with `violates constraint constraints/gcp.resourceLocations`

Not a quota or permission error, despite looking like one — the destination project enforces an org policy allowlisting specific regions/locations (common on ephemeral training/lab projects). Check `gcloud org-policies describe constraints/gcp.resourceLocations --project=<id> --effective` (enable `orgpolicy.googleapis.com` first if that itself 403s) before assuming a module's default region works. `MC_Bank_GKE` assigns clusters to regions round-robin via `i % length(var.available_regions)`, so a single allowed region still deploys the full `cluster_size` count of clusters, just co-located rather than spread across regions — the multi-cluster fleet/mesh/MCI demo still works, only geo-redundancy is lost. Single-region modules just need `region` changed to an allowed value.

### `PERMISSION_DENIED` on a project you can definitely access

Application Default Credentials (`~/.config/gcloud/application_default_credentials.json`) are one file, shared by every process on the machine — a `gcloud auth application-default login` run for a *different* task overwrites it for a `tofu apply` already in flight. `gcloud config configurations` does not isolate this; those config files live in the same shared, globally-overwritable directory. Confirm the identity actually behind ADC with `curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$(gcloud auth application-default print-access-token)"` before assuming an IAM or code problem. To run two identities/projects on one machine concurrently without this clash, each session needs its own `CLOUDSDK_CONFIG=<dir>`; `CLOUDSDK_CORE_ACCOUNT`/`CLOUDSDK_CORE_PROJECT` only scope a script's own `gcloud` calls, not ADC. **`CLOUDSDK_CONFIG` alone does not redirect `tofu`/`terraform` itself** — the Go-based `google` provider hardcodes `~/.config/gcloud/application_default_credentials.json` (or `GOOGLE_APPLICATION_CREDENTIALS` if set) and has no knowledge of `CLOUDSDK_CONFIG`, unlike `gcloud`'s own Python code. After isolating a session, also export `GOOGLE_APPLICATION_CREDENTIALS="$CLOUDSDK_CONFIG/application_default_credentials.json"` before running any `tofu` command, or it silently reads whichever ADC file happens to be at the shared default path.

### GKE cluster or node pool creation fails with `GCE_STOCKOUT`

`Error waiting for creating GKE cluster: ... does not have enough resources available to fulfill the request` is a transient capacity error, not a config or quota problem — but it can recur in a *different* zone on the next retry within the same region, which looks like bad luck but may be a genuine sustained shortage. GKE always provisions a transient "default" node pool as part of `google_container_cluster` creation itself, even with `remove_default_node_pool = true`; a stockout there fails the whole cluster resource before Terraform reaches any node pool you defined. `Istio_GKE`'s `google_container_node_pool.preemptible_nodes` compounds the exposure: `node_locations` is set to *every* zone in the region (`data.google_compute_zones.available_zones.names` in `gke.tf`), and for a regional pool `node_count` applies per zone — `node_count = 2` across 4 zones provisions 8 nodes, and a stockout in any single zone fails the whole pool. Killing/interrupting `tofu apply` does not cancel the GCP-side operation; check `gcloud container clusters describe <cluster> --region=<region> --format="value(status,statusMessage)"` directly after an interrupt rather than trusting local state. If the cluster lands in `ERROR`, it is very likely not yet in `tofu state list` (`Create()` doesn't call `SetId()` until its ready-wait succeeds), so `tofu destroy` won't find it — delete it directly with `gcloud container clusters delete` before re-`apply`ing. If the project is also org-policy-restricted to one region (previous entry), there is no fallback region — only retry or wait.

### `deploy_application` (Istio_GKE) does nothing

`variables.tf` declares `deploy_application` (default `true`) and describes it as deploying the Istio Bookinfo sample, but no `.tf` file, script, or manifest in the module reads `var.deploy_application` — toggling it has no effect in either direction. `docs/modules/Istio_GKE.md` and `docs/labs/Istio_GKE.md` already document the real behavior (no demo app is provisioned; deploy Bookinfo yourself into the pre-labelled `default` namespace). If you wire this variable up for real or remove it, update `variables.tf`'s `module_description` too — it previously implied Bookinfo came free with the module — and check the RAD platform UI form definition and any saved deployment tfvars for references before removing the variable outright.

### VMware Engine `prevent_destroy` blocks `tofu destroy`

The `google_project_iam_member.vmmigration_sa_user` resource carries a `lifecycle` block, but it is set to `prevent_destroy = false` (`modules/VMware_Engine/main.tf:68`) — it does **not** block `tofu destroy`, and nothing needs removing before decommissioning. If a destroy is blocked, the cause is elsewhere. Only flip that flag to `true` if the VM Migration service agent binding genuinely must survive a partial destroy, and expect the platform destroy pipeline to fail with "Instance cannot be destroyed" once you do.

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

### CSM revision label ↔ GKE release channel (Bank_GKE, MC_Bank_GKE)

| `release_channel` | `istio.io/rev` label | 
|---|---|
| `REGULAR` (default) | `asm-managed` |
| `RAPID` | `asm-managed-rapid` |
| `STABLE` | `asm-managed-stable` |

Always derive this from `local.asm_revision`, never hardcode `asm-managed` — see §8's CSM entries for the failure mode.

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

## 10. Standalone Lab Scripts (`scripts/`)

The scripts under `scripts/gcp-istio-traffic/` and `scripts/gcp-istio-security/`
are self-contained bash demos of Istio, independent of `modules/Istio_GKE` —
neither is invoked by the Terraform module and neither shares its lifecycle.
They exist to teach Istio concepts interactively (menu-driven, step-numbered)
rather than to operate a specific deployment. This section documents the
conventions both scripts share, and the mistakes that are easy to make when
extending them.

### 10.1 The menu/`.env`/`MODE` mechanism

Both scripts share one structure:

- A `while :` loop prints a numbered menu and reads a **full line** (plain
  `read`, not `read -n 1`) into `$REPLY`, then dispatches on
  `case "${REPLY^^}" in`. Because it reads a full line, multi-character
  replies work — this is what makes the lettered sub-step pattern in §10.2
  possible without any input-handling changes.
- Option `0` selects one of three modes, stored in `$MODE` for the rest of
  the process: `1` = preview (echo commands, run nothing), `2` = create
  (actually run them), `3` = delete (tear down). Every other step's `case`
  block branches on `$MODE`, and in preview mode the echoed command must
  match the real one printed in create mode — verify this by hand when
  editing a step; it is the most common place for drift (e.g. an escaped
  `\$VAR` in the preview echo not matching an unescaped `$VAR` in the
  real command it's supposed to preview).
- Persistent configuration lives in `./<script-dir>/.env`, sourced with
  `source $PROJDIR/.env` at the top of every step and re-exported as shell
  vars. **`.env` is not append-only** — it gets fully rewritten via
  `cat <<EOF > $PROJDIR/.env` at several points (the initial bootstrap
  before the menu loop starts, and inside option `0`'s create/delete
  branches, once per script). **Any new variable you want to persist across
  a restart or a re-run of option `0` must be added to every one of those
  heredocs**, not just wherever it's first set — otherwise the next time a
  user runs option `0` (a normal, expected action per each script's own
  README: "run option 0 again ... to switch projects later"), the rewrite
  silently drops the variable back to unset. `ISTIO_MODE` (§10.3) is a
  concrete example: it's set by step `4A`/`4B`, but also has to appear in
  all three `.env`-rewrite heredocs, each pinned to `${ISTIO_MODE:-sidecar}`
  so a rewrite preserves whatever the current shell value is instead of
  discarding it.
- A `STEP` string accumulates every step executed this session (e.g.
  `,0,1,4A,5`) and is printed in the menu header purely for the user's own
  orientation — it is not read by the script itself.

### 10.2 Adding a mode choice: lettered sub-steps, not new step numbers

When `gcp-istio-security.sh` and `gcp-istio-traffic.sh` needed a
sidecar-vs-ambient choice at install time, the install step became `4A`
(sidecar) / `4B` (ambient) instead of either renumbering every later step or
re-asking the choice at each one. The pattern, if you need it again:

1. Split the single step into lettered variants covering only the command
   that actually differs (the `istioctl install` invocation).
2. Have each variant persist its choice to `.env` as its own variable
   (`ISTIO_MODE`), following the rewrite rule in §10.1.
3. Every *later* step reads that variable and branches **internally** where
   its behavior genuinely differs — it does not get its own lettered
   variant unless its command, not just a parameter, diverges. Step `5`
   (namespace configuration) is a single step with an `if`/`else` on
   `$ISTIO_MODE`, not `5A`/`5B`.
4. Only add a new step when the divergent behavior doesn't fit as a branch
   in an existing one — `gcp-istio-security.sh`'s step `9` (ambient L7
   policy attachment, §10.5) is a full new step because it demonstrates a
   contrast, not a mode-conditional variant of existing content.

### 10.3 Gotcha: steps that reset the namespace must respect the active mode

Some steps intentionally delete and recreate the application namespace at
their end, to hand the next step a clean slate (`gcp-istio-security.sh`
steps `6` and `8` both do this). Before ambient mode existed, that reset
could safely hardcode `kubectl label namespace ... istio-injection=enabled`
— there was only one mode. Once a step earlier in the flow (`4B`/`5`) can
put the namespace in ambient mode, a reset that still hardcodes sidecar
labeling **silently reverts ambient mode** the moment the user runs the next
step, with no error — the namespace still exists, it's just wrong, and
nothing downstream fails loudly. The fix is the same `if [ "$ISTIO_MODE" ==
"ambient" ]` branch used in step `5`, reapplying the
`istio.io/dataplane-mode=ambient` label **and** redeploying the waypoint
(`istioctl waypoint apply`) — the recreate also destroyed the waypoint,
since it's a namespaced resource. When adding any new "clean slate" reset to
either script, check whether it re-establishes mode state, not just the
workloads.

### 10.4 Gateway API vs legacy Istio API: what each one can and can't express

Both scripts now use the Kubernetes Gateway API (`gateway.networking.k8s.io`
`Gateway`/`HTTPRoute`) for ingress and for traffic mirroring, and keep the
legacy `networking.istio.io` API (`VirtualService`/`DestinationRule`) for
everything else. This isn't a stylistic choice — Gateway API genuinely
cannot express some of what these demos need:

| Feature | Gateway API | Legacy Istio API |
|---|---|---|
| Ingress routing (host/path → Service) | `Gateway` + `HTTPRoute`; the `Gateway` resource auto-provisions its own proxy Deployment/Service | `Gateway` + `VirtualService` (proxy must be provisioned separately) |
| Traffic mirroring | `HTTPRoute` `RequestMirror` filter, including `percent` — native, and can attach directly to a `Service` via `parentRefs` for east-west routing with no `Gateway`/waypoint involved | `VirtualService.mirror`/`mirrorPercentage` |
| Weighted/version-based (subset) routing | `backendRefs` point at distinct **Services**, not label-selected subsets of one Service — there is no Gateway API equivalent of `DestinationRule.subsets` | `VirtualService` + `DestinationRule.subsets` |
| Fault injection (delay/abort) | **Not supported.** No core filter exists, and upstream declined to add one (istio/istio#54196) | `VirtualService.http[].fault` |
| Circuit breaking / connection pool / outlier detection | Not supported | `DestinationRule.trafficPolicy` |
| Egress TLS to external services | Not supported | `DestinationRule.trafficPolicy.tls` + `ServiceEntry` |

Consequence for anyone converting a VirtualService-based mirroring or
subset-routing example to Gateway API: if the resource being mirrored/routed
is defined as one Service with version labels (the `DestinationRule.subsets`
pattern), it has to be split into one real Service per version first —
`backendRefs` cannot select by label. `gcp-istio-security.sh`'s mirroring
step does exactly this (added `httpbin-v1`/`httpbin-v2` Services alongside
the pre-existing shared `httpbin` Service).

### 10.5 Ambient mode: L7 needs a waypoint, and `AuthorizationPolicy` needs `targetRefs`

Ambient mode's per-node `ztunnel` proxy is **L4-only** — mTLS, L4
authorization (principal/namespace/port), and telemetry. Any L7 feature
(HTTP routing, header matching, fault injection, `RequestAuthentication`,
method/path-scoped `AuthorizationPolicy` rules) is only enforced once a
**waypoint proxy** exists for the destination — deploy one with
`istioctl waypoint apply --namespace <ns>` (§10.1's mode-choice step does
this once, up front, so every later L7 feature in both scripts keeps
working without further changes). A waypoint is itself a Gateway API
`Gateway` object (`gatewayClassName: istio-waypoint`) — `kubectl get gateway`
in the namespace will show it.

The one landmine a waypoint alone does **not** fix: `AuthorizationPolicy`
resources that select their target workload with `selector` (the idiom used
throughout `gcp-istio-security.sh`'s step `8`) rather than `targetRefs`
pointing at a `Service`/`Gateway`. Under ambient, an L7 rule attached with
`selector` **fails closed** — ztunnel can't evaluate it, so it's treated as
a deny-everything policy, not skipped or left permissive. This is silent:
nothing in `kubectl get authorizationpolicy` flags it as broken. Step `8`'s
examples are deliberately left as `selector`-based (they're correct for
their own always-sidecar `foo`/`bar`/`legacy` namespaces); step `9` exists
specifically to demonstrate the `selector` failure and the `targetRefs` fix
side by side, rather than silently rewriting step `8`.

### 10.6 Keep standalone scripts consistent with the Terraform module

When either script needs an `istioctl install`/`waypoint`/label command for
ambient or sidecar mode, copy it from `modules/Istio_GKE/istioambient.tf` /
`istiosidecar.tf` rather than inventing new flags — those files are the
canonical, already-tested source for these commands. Note one deliberate
divergence: the Terraform module's ambient install explicitly enables a
`components.ingressGateways[0]` component (a classic Istio-managed ingress
deployment), because the module doesn't use Gateway API for ingress. The
standalone scripts do use Gateway API for ingress (§10.4), so they omit that
component — the `Gateway` resource created in a later step provisions its
own proxy. Don't "fix" this by adding it back for consistency; it would
leave two competing ingress proxies.

### 10.7 `ISTIO_VERSION` is tracked in three places, independently

`modules/Istio_GKE/variables.tf`'s `istio_version` default,
`scripts/gcp-istio-traffic/gcp-istio-traffic.sh`'s hardcoded
`ISTIO_VERSION=...` in its `.env` bootstrap, and the equivalent line in
`scripts/gcp-istio-security/gcp-istio-security.sh` are three independent
defaults with no shared source of truth. Bumping one does not bump the
others — this repo has already shipped that drift once (the module moved to
a current release while both scripts stayed on an EOL version until a
follow-up commit synced them). When updating the default Istio version
repo-wide, grep for `ISTIO_VERSION=` and `istio_version` and update every
hit, including the two `docs/` files that quote the version in prose.

## Naming limits and shared-resource races (2026-08-20)

**A length rule must be derived from the TIGHTEST consumer of the name, not the most visible one (2026-08-20).** `tenant_id` was validated at 1-20 characters and failed MID-APPLY with `INVALID_ARGUMENT: The account ID "..." does not have a length between 6 and 30`, from a local-exec provisioner, after the project and its IAM already existed. A precondition guarding Cloud Run service names at 63 characters already existed, was correct, and would have admitted every value that failed.

Every service account is named `<role>-sa-<tenant_id><8-char tenant hash>`. The longest role prefix is `clouddeploy-sa-` (15 chars, `Services_GCP/sa.tf`, `count = 1`, so it exists for every tenant), against GCP's 30-character `account_id` cap:

```
15 + len(tenant_id) + 8 <= 30   =>   len(tenant_id) <= 7
```

Same omission found in `gke_cluster_name_prefix` — character class present, length absent, against GKE's 40-char cluster name (`prefix-<i>-<tenant><hash>`, so <= 21) — and in `Project_GCP.project_id`, which had NO validation while its own description stated the rule verbatim. **When adding a name-shaped variable, find every attribute the name reaches and take the smallest limit.** Deliberately NOT bounded: `sql_instance_name`, `nfs_volume_name`, `static_ip_name`, `firestore_database_id` all land in 63-character sinks behind short prefixes, and a speculative rule on a field nobody has broken is a future false refusal.

**Anything TENANT-SHARED is created concurrently, so create it idempotently.** `cloudrun-sa-`/`cloudbuild-sa-`/`gke-sa-` are named from the tenant prefix and shared by every module deployed into that tenant. The provisioner was `describe && exit 0` then `create` — a TOCTOU. Three CloudRun apps launched into one tenant within a second of each other on 2026-08-20; one won and the other two died on "already exists", having done nothing wrong. **"Already exists" IS the desired end state**: let the create fail and treat only a STILL-ABSENT resource as fatal, the same resolution `App_Common/modules/app_db_clients` already used for its shared staging bucket.

**A `count`/`for_each` gate that is UNKNOWN at plan is a different failure from one that is `false`.** `App_GKE` gates its Kubernetes resources on data sources readable only once the cluster exists, documented as a two-apply pattern — which works when the gate resolves to `false` and the first apply merely skips them. When the cluster does not exist at all the gate is *unknown*, Terraform refuses to plan `count` on it, and the build dies in PLAN having created nothing — so a retry reproduces it exactly and it cannot self-heal. Open as at 2026-08-20; deploy `Services_GCP` into the target project first.
