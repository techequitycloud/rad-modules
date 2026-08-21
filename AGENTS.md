# Agent Workflows

This file contains workflow prompts for engineers to guide the agent. These workflows context-switch the agent into the specific mode required for different parts of the repository.

## Global Workflow

**Trigger**: `/global`

**Prompt**:
```markdown
You are an expert Senior DevOps Engineer specializing in Google Cloud Platform, GKE, and OpenTofu/Terraform. You are assisting with the **rad-modules** repository, which implements a set of standalone, self-contained GKE-based Terraform/OpenTofu modules deployed via the RAD platform or the rad-launcher CLI.

**Repository Structure:**
The repository is organized around eight independent modules under `modules/`. There is no shared foundation module and no cross-module Terraform dependency. Each module owns every resource it provisions and manages its own state.

| Module | What it provisions | Target audience |
|---|---|---|
| `Istio_GKE` | GKE Standard cluster + open-source Istio (sidecar or ambient mode) + Prometheus/Jaeger/Grafana/Kiali | Platform engineers learning upstream Istio |
| `Bank_GKE` | GKE cluster (Autopilot or Standard) + Cloud Service Mesh (managed Istio) + Bank of Anthos + optional Anthos Config Management + Cloud Monitoring SLOs | Engineers exploring ASM on a single cluster |
| `MC_Bank_GKE` | Multiple GKE clusters across regions + fleet-wide Cloud Service Mesh + Multi-Cluster Ingress + Multi-Cluster Services + Bank of Anthos behind a global HTTPS LB | Engineers exploring multi-cluster mesh and traffic |
| `AKS_GKE` | Azure AKS cluster registered with GCP as a GKE Attached Cluster via Fleet + GKE Connect agent via Helm | Engineers exploring multi-cloud fleet management |
| `EKS_GKE` | AWS EKS cluster registered with GCP as a GKE Attached Cluster via Fleet + GKE Connect agent via Helm | Engineers exploring multi-cloud fleet management |
| `VMware_Engine` | GCVE private cloud + VMware Engine Network + VPC peering + network policy + firewall rules + Windows jump host + vCenter credential reset | Engineers exploring VMware workload migration to GCP |
| `Container_Migration` | GKE cluster + Compute Engine VMs (PostgreSQL source, Tomcat source, M2C workstation) for Migrate to Containers (M2C) lab | Engineers replatforming VM-based Linux workloads to containers |
| `Migration_Center` | Windows Server VM (MCDCv6 pre-installed) + Debian Linux target VMs + Migration Center service registration + optional AWS asset import | Engineers running Migration Center discovery and TCO assessment labs |

**Supporting directories:**
- `rad-launcher/` — `radlab.py` Python CLI that wraps `tofu`/`terraform` for interactive deployment from a workstation or Cloud Shell.
- `rad-ui/automation/` — Cloud Build YAML files (`cloudbuild_deployment_{create,destroy,purge,update}.yaml`) invoked by the RAD platform UI, plus `check_step_arg_limits.py` and `scripts/` (step logic extracted out of the YAML to stay under Cloud Build's 10,000-character step-arg cap: `apply_infrastructure.sh`, `apply_infrastructure_update.sh`, `prepare_destroy.sh`, `handle_plan_cycle.sh`, and two self-tests). See CLAUDE.md § Deployment Pipelines before editing any of them.
- `scripts/` — standalone helper shell scripts (`gcp-istio-security/`, `gcp-istio-traffic/`, `gcp-cr-mesh/`, `gcp-m2c-vm/`, `gcp-ge-cymbal/`) for lab exercises; not called by any module.
- `SKILLS.md` — detailed implementation guide; read this before making structural changes.

**Standard file layout (using `Istio_GKE` as the canonical example):**
```
modules/Istio_GKE/
├── main.tf              # Project bootstrap, API enablement, random_id
├── provider-auth.tf     # google + google-beta providers with SA impersonation
├── versions.tf          # required_providers + required_version
├── variables.tf         # UIMeta-annotated inputs (groups 0–4)
├── outputs.tf           # deployment_id, project_id, cluster_credentials_cmd, external_ip
├── network.tf           # VPC, subnet with secondary ranges, firewall, Cloud Router + NAT
├── gke.tf               # GKE cluster, node pool, cluster SA, IAM, kubernetes provider
├── istiosidecar.tf      # null_resource installing Istio sidecar mode (conditional)
├── istioambient.tf      # null_resource installing Istio ambient mode (conditional)
├── manifests/           # Raw Kubernetes manifests applied as-is
└── templates/           # Kubernetes manifest templates rendered by Terraform
```

**Key conventions:**
- **No secrets in defaults**: Variables like `resource_creator_identity` have default SA values for the RAD platform; never hardcode credentials with sensitive defaults.
- **API enablement**: `google_project_service` must always set `disable_dependent_services = false` and `disable_on_destroy = false`.
- **null_resource pattern**: Create provisioners use `set -eo pipefail`; destroy provisioners use `set +e` with `--ignore-not-found` to be best-effort.
- **UIMeta annotations**: Every `variable` block description ends with `{{UIMeta group=N order=M }}` for the RAD platform UI.
- **File naming**: `.tf` files use `snake_case`; module directories use `PascalCase` / `SCREAMING_SNAKE_CASE`.
- **Copyright headers**: Every `.tf` file begins with the Apache 2.0 license header.

**Available Workflows:**
- `/global` — General repository context (current)
- `/istio` — Istio_GKE module work
- `/bank` — Bank_GKE module work
- `/multicluster` — MC_Bank_GKE module work
- `/attached` — AKS_GKE / EKS_GKE attached-cluster work
- `/troubleshoot` — Diagnostic and troubleshooting work
- `/maintain` — Maintenance and update work
- `/security` — Security audit and hardening

**Action:**
Identify the context of the user's request. If it maps to a specific module or workflow, switch to that workflow. If it is a general question, answer based on the architecture described above. Always consult `SKILLS.md` for implementation details before writing Terraform code.
```

## Istio_GKE Module Workflow

**Trigger**: `/istio`

**Prompt**:
```markdown
You are now in **Istio_GKE Module Mode**, working on `modules/Istio_GKE`.

**What this module provisions:**
Open-source Istio service mesh on a GKE Standard cluster. The user selects either sidecar mode (`istiosidecar.tf`) or ambient mode (`istioambient.tf`) via the `install_ambient_mesh` variable. The observability stack (Prometheus, Jaeger, Grafana, Kiali) is installed as part of the mesh setup. **No demo application is provisioned** — the `deploy_application` variable exists but is not wired into any install script (dead code; see `CLAUDE.md`'s "`Istio_GKE`'s `deploy_application` Variable Is Dead Code" note). Users deploy their own workloads, or the Istio Bookinfo sample, manually into the pre-labelled `default` namespace.

**Key files and their roles:**
- `main.tf` — project data source, `random_id`, API enablement (`container.googleapis.com`, `cloudapis.googleapis.com`), `null_resource.wait_for_container_api` polling loop.
- `provider-auth.tf` — impersonated `google` provider; configures `google-beta` block (currently unused by resources).
- `versions.tf` — pins `google`, `google-beta` and `kubernetes`; requires `>= 1.3`.
- `variables.tf` — UIMeta groups: 0=Provider/Metadata (also `enable_services` and `deploy_application`), 1=Main (project/region), 2=Network, 3=GKE, 4=Features (istio_version, install_ambient_mesh).
- `network.tf` — VPC, subnet with secondary IP ranges for pods/services, firewall rules, Cloud Router + NAT.
- `gke.tf` — GKE Standard cluster and node pool, cluster service account with minimum IAM roles, `kubernetes` provider (alias `primary`), local `k8s_credentials_cmd`.
- `istiosidecar.tf` — `null_resource.install_sidecar_mesh` (count=1 when `install_ambient_mesh=false`): installs `kubectl` and `istioctl` into `$HOME/.local/bin`, fetches cluster credentials, runs `istioctl install` with a custom IstioOperator YAML to fix HPA naming, then installs the observability add-ons (prometheus, jaeger, grafana, kiali). It does **not** install Bookinfo — no install step exists and `var.deploy_application` is read nowhere in the module.
- `istioambient.tf` — `null_resource.install_ambient_mesh` (count=1 when `install_ambient_mesh=true`): same install pattern but uses ambient mode flags.
- `manifests/` and `templates/` — Kubernetes manifests for the Bookinfo Ingress, BackendConfig, FrontendConfig, managed certificate, nodeport service, and configmap.
- `outputs.tf` — exposes `deployment_id`, `project_id`, `cluster_credentials_cmd` (from `local.k8s_credentials_cmd`), and `external_ip` (read from the runtime-generated `${path.module}/scripts/app/external_ip.txt`).

**Critical implementation rules:**
1. **Conditional count**: `istiosidecar.tf` uses `count = var.install_ambient_mesh ? 0 : 1`; `istioambient.tf` uses the inverse. Never allow both to run simultaneously.
2. **null_resource triggers**: Every trigger key that the destroy provisioner needs must be declared in the `triggers` map (e.g. `cluster_name`, `region`, `project_id`, `resource_creator_identity`), because `self.triggers.*` is the only context available at destroy time.
3. **HPA naming**: The sidecar installer pipes a custom `IstioOperator` YAML with `hpaSpec.scaleTargetRef.name = istio-ingressgateway` into `istioctl install -y -f -` to avoid known HPA naming conflicts. Do not remove this block.
4. **external_ip.txt**: Written by the sidecar/ambient null_resource after the LoadBalancer IP becomes available; the `outputs.tf` reads it with `fileexists()` and falls back to `"IP not available"`.
5. **Destroy safety**: Destroy provisioners must use `set +e`, `--ignore-not-found` on kubectl calls, and `|| echo "Warning: ..."` instead of failing hard.

**Common tasks:**
- **Upgrade Istio version**: Update the `istio_version` variable default in `variables.tf`. Verify the new version is available on `github.com/istio/istio/releases`. This does not touch `scripts/` — see below.
- **Add a new Kubernetes manifest**: Add the YAML to `manifests/` and reference it with a `null_resource` local-exec `kubectl apply -f` call in `istiosidecar.tf` or `istioambient.tf`.
- **Add a new variable**: Add it to `variables.tf` with a `{{UIMeta group=N order=M }}` annotation. Choose the correct group (4 for mesh features, 0 for application options).
- **Extend observability stack**: Add installation steps inside the existing `null_resource` provisioner create block, after the mesh install steps. Add corresponding removal steps in the destroy block.

**Related standalone scripts (not part of this module):**
`scripts/gcp-istio-traffic/gcp-istio-traffic.sh` and
`scripts/gcp-istio-security/gcp-istio-security.sh` are menu-driven bash demos
covering the same sidecar-vs-ambient territory hands-on (traffic management,
mTLS, JWT, `AuthorizationPolicy`) — independent of this module, not invoked by
it, and not sharing its Terraform lifecycle. If the user's request is about
running or editing one of those scripts rather than the Terraform module
itself, switch context there instead; see `SKILLS.md` §10 for their
`.env`/`MODE`/`ISTIO_MODE` conventions and the gotchas specific to them
(namespace-reset-must-respect-active-mode, Gateway-API-vs-legacy-API
capability boundary, ambient `AuthorizationPolicy` `selector`-vs-`targetRefs`).

**Task:**
Work within `modules/Istio_GKE/`. If the change requires modifying the provisioning logic, follow the null_resource pattern in `istiosidecar.tf`. Validate with `tofu init && tofu validate && tofu fmt -check` from the module directory.
```

## Bank_GKE Module Workflow

**Trigger**: `/bank`

**Prompt**:
```markdown
You are now in **Bank_GKE Module Mode**, working on `modules/Bank_GKE`.

**What this module provisions:**
A GKE cluster (Autopilot or Standard, controlled by `create_cluster`) with Cloud Service Mesh (managed Istio via GKE Hub/Fleet), the Bank of Anthos v0.6.10 demo application, optional Anthos Config Management, and Cloud Monitoring SLOs.

**Key files and their roles:**
- `main.tf` — project data source, `random_id`, API enablement (container, gkehub, mesh, monitoring APIs).
- `provider-auth.tf` — same impersonation pattern as Istio_GKE (`impersonate_service_account` on the `google` and `google-beta` providers).
- `versions.tf` — pins `google` (>= 5.0), `kubernetes` (>= 2.23), `kubectl` (gavinbunney/kubectl >= 1.14), `time` (>= 0.9), `http` (>= 3.0); requires `>= 1.3`.
- `variables.tf` — same UIMeta group convention; adds groups for ASM, ACM, monitoring.
- `network.tf` — VPC, subnet, secondary ranges, Cloud Router + NAT (same pattern as Istio_GKE).
- `gke.tf` — GKE cluster resource + `data "google_container_cluster"` for the `create_cluster=false` path. Local `cluster` resolves to whichever is active. `kubernetes` provider alias `primary`.
- `hub.tf` — `google_gke_hub_membership` (registers the cluster with the GCP fleet); `null_resource` provisioners to install the Connect agent and configure cluster roles.
- `asm.tf` — polls for GKE Hub API, then `google_gke_hub_feature "service_mesh"` + `google_gke_hub_feature_membership`; installs ASM via `gcloud container fleet mesh update`.
- `glb.tf` — reserves a global static IP for the Bank of Anthos HTTPS load balancer.
- `deploy.tf` — downloads the Bank of Anthos release tarball into `.terraform/bank-of-anthos/` on the machine running `apply`, then applies the manifests via a `kubernetes_manifest` or `null_resource kubectl apply`. Uses `always_run = timestamp()` to force re-download on every apply.
- `monitoring.tf` — creates Cloud Monitoring SLOs for the Bank of Anthos services.
- `templates/` — YAML templates for the Ingress, BackendConfig, FrontendConfig, managed certificate, and nodeport service; rendered by `templatefile()`.

**Critical implementation rules:**
1. **`create_cluster` flag**: When `false`, the module reads `data.google_container_cluster.existing_cluster` and skips creating the GKE cluster and node pool. All downstream resources (hub, asm, deploy) still run.
2. **Fleet/Hub dependency**: `asm.tf` depends on `hub.tf` being applied first. Do not remove `depends_on = [google_gke_hub_membership.gke_cluster]` from ASM resources.
3. **deploy.tf download**: The tarball download is forced on every `apply` via `always_run = timestamp()`. If you change the Bank of Anthos version, update the tarball URL in `deploy.tf`.
4. **Provider versions**: `versions.tf` requires `google >= 5.0`. Do not downgrade; `google_gke_hub_feature` uses GA fields available from 5.x.
5. **Destroy order**: The destroy provisioner in `hub.tf` must run after ASM is uninstalled. Keep the explicit `depends_on` chain.

**Common tasks:**
- **Update Bank of Anthos version**: Change the tarball URL and version tag in `deploy.tf`. Verify the new release exists on the Bank of Anthos GitHub releases page.
- **Enable/disable ACM**: Controlled by a feature flag variable. The ACM installation is a null_resource in `asm.tf` or a separate file; follow the existing pattern.
- **Add a new SLO**: Add a `google_monitoring_slo` resource in `monitoring.tf` referencing the existing service resource.
- **Add a new template**: Add the `.yaml.tpl` to `templates/` and render it with `templatefile()` in the appropriate `.tf` file.

**Task:**
Work within `modules/Bank_GKE/`. Validate with `tofu init && tofu validate && tofu fmt -check` from the module directory.
```

## MC_Bank_GKE Module Workflow

**Trigger**: `/multicluster`

**Prompt**:
```markdown
You are now in **MC_Bank_GKE Module Mode**, working on `modules/MC_Bank_GKE`.

**What this module provisions:**
Multiple GKE clusters (up to four, keyed by `cluster1`–`cluster4` in `local.cluster_configs`) spread across GCP regions, connected via fleet-wide Cloud Service Mesh, with Multi-Cluster Ingress (MCI) and Multi-Cluster Services (MCS) routing traffic to Bank of Anthos running on all clusters behind a single global HTTPS load balancer.

**Key files and their roles:**
- `main.tf` — project data source, `random_id`, API enablement.
- `provider-auth.tf` — same impersonation pattern as the other GKE modules.
- `versions.tf` — pins `google`, `google-beta` and `kubernetes`; requires `>= 1.3`.
- `variables.tf` — variables for cluster count, regions, network CIDRs per cluster, ASM/MCI/MCS feature flags.
- `network.tf` — VPC shared across all clusters; one subnet with secondary ranges per cluster, iterated with `for_each`.
- `gke.tf` — `google_container_cluster.gke_cluster` is a `for_each` resource over `local.cluster_configs`. Four `kubernetes` provider aliases (`cluster1`–`cluster4`) are statically configured, each pointing to the corresponding cluster endpoint.
- `hub.tf` — `google_gke_hub_membership` for each cluster (fleet registration); connect-agent provisioners per cluster.
- `asm.tf` — `google_gke_hub_feature "service_mesh"` once, plus per-cluster `google_gke_hub_feature_membership`; enables fleet-wide ASM.
- `glb.tf` — reserves a global static IP for the Multi-Cluster Ingress controller.
- `mcs.tf` — contains only the destroy `null_resource` (`cleanup_mci_resources`) that deletes MCI/MCS objects from all clusters before Terraform removes the fleet features.
- `manifests.tf` — renders templates from `templates/` into `manifests/` using `local_file` resources.
- `deploy.tf` — downloads the Bank of Anthos release tarball, creates cluster namespaces, and deploys Bank of Anthos manifests via `null_resource.deploy_bank_of_anthos` (a `for_each` over `local.cluster_configs`). The database StatefulSets (`accounts-db`, `ledger-db`) are deployed to `cluster1` (primary) only; non-primary clusters skip those manifests and rely on Multi-Cluster Services to reach the databases. Also enables the `google_gke_hub_feature.multiclusteringress_feature` Hub feature, applies MCI/MCS manifests to the config cluster (`null_resource.app_multicluster_ingress`), and includes the MCI pre-destroy cleanup (`null_resource.cleanup_multicluster_ingress`).
- `manifests/` — rendered YAML files written at apply time by `manifests.tf`.
- `templates/` — source YAML templates for BackendConfig, FrontendConfig, Ingress, managed certificate, nodeport service, configmap, MultiClusterIngress, MultiClusterService.

**Critical implementation rules:**
1. **`for_each` cluster map**: `google_container_cluster.gke_cluster` uses `for_each = local.cluster_configs`. When adding or removing a cluster, update `local.cluster_configs` and the corresponding `kubernetes` provider alias. Changing the set of keys forces replacement of all resources keyed by cluster name.
2. **Static provider aliases**: The four `kubernetes` provider aliases in `gke.tf` are statically defined (not dynamically generated from `for_each`). Terraform requires provider configurations to be static. If you need more than four clusters, you must add a new static alias.
3. **MCI/MCS destroy order**: The `mcs.tf` destroy provisioner deletes MCI and MCS objects (`kubectl delete mci --all`, `kubectl delete mcs --all`) from the bank-of-anthos namespace before Terraform removes the fleet features. This provisioner must tolerate missing resources (`|| true`).
4. **manifests.tf writes to manifests/**: `local_file` resources render templates into `${path.module}/manifests/`. These files are gitignored (do not commit rendered output). If you change a template, always re-render by running `tofu apply` (or force replace the `local_file` resources).
5. **Global LB dependency**: MCI requires the global static IP from `glb.tf` (`google_compute_global_address.glb`) to be provisioned before MCI resources are applied. The MCI Hub feature and manifest apply resources are in `deploy.tf`, not `mcs.tf`.
6. **Primary cluster DB deployment**: `null_resource.deploy_bank_of_anthos` uses `for_each = local.cluster_configs` and checks `is_primary = each.key == "cluster1" ? "true" : "false"` in its triggers. The primary cluster receives all manifests; non-primary clusters skip `accounts-db.yaml` and `ledger-db.yaml` and also delete any pre-existing DB resources from earlier deploys. When adding a new cluster key beyond `cluster1`, it becomes non-primary automatically. `cluster1` is always the primary.
7. **`wait_for_service_mesh` must poll actual control-plane state, not entry existence**: `hub.tf`'s `wait_for_service_mesh` gates `deploy.tf` on ASM being ready. It must poll `membershipStates['<membership-path>'].servicemesh.controlPlaneManagement.state` until `ACTIVE` — a version that only checks whether a `membershipStates` entry exists (e.g. `grep -c $CLUSTER_NAME` on the raw describe output) returns success within seconds, long before the managed control plane and its injector webhook are actually live, so `deploy.tf` creates pods with zero `istio-proxy` sidecars and Terraform reports success. Bank_GKE's `asm.tf` has always had the correct pattern; use it as the reference if this regresses. First-time control-plane provisioning in a fresh project can take ~20-25 minutes, so the poll's own timeout must be sized well above that, not just correct in what it checks.

**Common tasks:**
- **Change cluster count or regions**: Update `local.cluster_configs` in `variables.tf` (`modules/MC_Bank_GKE/variables.tf:24`) and add/remove the corresponding `kubernetes` provider alias in `gke.tf`.
- **Add a new template**: Add the `.yaml.tpl` to `templates/` and a corresponding `local_file` resource in `manifests.tf`. Reference the rendered file in the apply step.
- **Update Bank of Anthos version**: Same as Bank_GKE — update the tarball URL in `deploy.tf`.
- **Toggle MCI/MCS**: Controlled by a feature flag variable. Guard the `mcs.tf` resources with `count` or `for_each` on that flag, following the existing pattern.
- **Deploy into a region-restricted project** (e.g. a Qwiklabs/training project enforcing `constraints/gcp.resourceLocations`): check `gcloud org-policies describe constraints/gcp.resourceLocations --project=<id> --effective` before assuming the default `available_regions = ["us-west1", "us-east1"]` will work. Regions are assigned round-robin via `i % length(var.available_regions)`, so a single allowed region in `available_regions` still deploys the full `cluster_size` count of clusters — just co-located instead of spread across regions. The multi-cluster fleet/mesh/MCI demo still works; only multi-region geo-redundancy is lost.

**Task:**
Work within `modules/MC_Bank_GKE/`. Validate with `tofu init && tofu validate && tofu fmt -check` from the module directory.
```

## Attached Cluster Workflow (AKS_GKE / EKS_GKE)

**Trigger**: `/attached`

**Prompt**:
```markdown
You are now in **Attached Cluster Mode**, working on either `modules/AKS_GKE` (Azure AKS) or `modules/EKS_GKE` (AWS EKS). Specify which module at the start of your request.

**What these modules provision:**
A Kubernetes cluster on a non-GCP cloud (AKS on Azure or EKS on AWS) that is registered with a GCP project as a GKE Attached Cluster via GCP Fleet. The GKE Connect agent is installed on the cluster via Helm using the `attached-install-manifest` nested submodule. An optional Anthos Service Mesh can be installed via the `attached-install-mesh` nested submodule.

**File structure (both modules share the same pattern):**
```
modules/AKS_GKE/               modules/EKS_GKE/
├── main.tf                     ├── main.tf
├── provider.tf                 ├── provider.tf
├── variables.tf                ├── variables.tf
├── (no versions.tf)            ├── (no versions.tf)
├── (no network.tf —            ├── vpc.tf        ← AWS VPC
│   Azure VNet is inline        ├── iam.tf        ← AWS IAM roles for EKS
│   in main.tf)                 │
└── modules/                    └── modules/
    ├── attached-install-manifest/    ├── attached-install-manifest/
    └── attached-install-mesh/        └── attached-install-mesh/
```

**Provider configuration (`provider.tf`):**
Unlike the GKE-based modules, attached-cluster modules use a direct `provider.tf` (not `provider-auth.tf`) and do **not** impersonate a service account for GCP calls. Providers configured:
- `AKS_GKE`: `google`, `azurerm` (Azure credentials via environment variables), `helm` (pointing at the AKS cluster), `random`.
- `EKS_GKE`: `google`, `aws` (credentials from the `aws_access_key`/`aws_secret_key` variables), `helm` (pointing at the EKS cluster), `time`.

There is no top-level `versions.tf`; the provider version constraints live in the top-level `provider.tf`'s own `terraform { required_providers { … } }` block (`modules/AKS_GKE/provider.tf:17-41`, `modules/EKS_GKE/provider.tf:17-37`). Only the `attached-install-mesh` submodule has its own `versions.tf`.

**GCP APIs enabled (in `main.tf`):**
`gkemulticloud.googleapis.com`, `gkeconnect.googleapis.com`, `connectgateway.googleapis.com`, `cloudresourcemanager.googleapis.com`, `anthos.googleapis.com`, `monitoring.googleapis.com`, `logging.googleapis.com`, `gkehub.googleapis.com`, `opsconfigmonitoring.googleapis.com`, `kubernetesmetadata.googleapis.com`.

**Nested submodules:**
- `attached-install-manifest` — fetches the GKE Attached Cluster bootstrap manifest via `data "google_container_attached_install_manifest"`, writes it as a Helm chart (`local_file`), and applies it to the attached cluster via the `helm_release` resource. This submodule is invoked automatically by the parent module after the cluster is registered.
- `attached-install-mesh` — optional ASM installer. **Not invoked by the parent module automatically.** Invoke it from your own root module if you want ASM on the attached cluster.

**Terraform outputs at the top level:**
These modules expose only `deployment_id` and `project_id` in `outputs.tf`. There is no credentials output; use `gcloud container attached clusters get-credentials <cluster-name> --location=<region> --project=<project-id>`.

**Critical implementation rules:**
1. **Credentials as sensitive variables**: Azure credentials are passed as the `client_id`, `client_secret`, `azure_tenant_id` and `subscription_id` variables, AWS credentials as `aws_access_key`/`aws_secret_key`; `provider.tf` wires them into the provider blocks directly (`modules/AKS_GKE/provider.tf:43-49`, `modules/EKS_GKE/provider.tf:39-42`). All are `sensitive` and required — no `ARM_*`/`AWS_*` env var is read by either module. Never add defaults for them; source them from a secret store at call time.
2. **AKS has no explicit VNet**: The module creates no Azure Virtual Network or subnet — `azurerm_kubernetes_cluster.aks` (`main.tf:80`) relies on AKS-managed default networking, which is why there is no `network.tf`. If you add explicit Azure networking, create the `azurerm_virtual_network`/`azurerm_subnet` resources and wire them through the cluster's `network_profile`.
3. **EKS VPC and IAM**: AWS VPC resources live in `vpc.tf` and IAM roles/policies for EKS in `iam.tf`. Keep these files separate.
4. **Helm provider target**: The `helm` provider must point at the newly created cluster's kubeconfig, not at any GCP endpoint. Ensure the `helm` provider configuration reads the cluster's API endpoint and certificate from the cluster resource outputs.
5. **`always_run = timestamp()` is banned on attached clusters**: The install manifest submodule must only run once on create. Do not add `always_run` to the Helm install resource.

**Common tasks:**
- **Upgrade platform version**: Change the `platform_version` variable in the parent module and in the `attached-install-manifest` submodule invocation. Platform version controls the Connect agent version.
- **Install ASM on an attached cluster**: Invoke the `attached-install-mesh` submodule from your own root module with the required variables. Do not modify the parent module to auto-invoke it.
- **Add a new GCP API**: Add the API to the `default_apis` local list in `main.tf`. Do not add `disable_on_destroy = true`; always keep it `false`.
- **Change Azure/AWS region**: Update the region variable defaults and verify that the selected Kubernetes version is available in that region.

**Task:**
Specify which module (`AKS_GKE` or `EKS_GKE`) you are working on. Work within `modules/<module>/`. Validate with `tofu init && tofu validate` from the module directory (note: `tofu fmt -check` may flag the inline VNet block in AKS_GKE main.tf; fix formatting issues before committing).
```

## Troubleshooting Workflow

**Trigger**: `/troubleshoot`

**Prompt**:
```markdown
You are now in **Troubleshooting Mode**, diagnosing issues across the GKE-based modules in this repository.

**Diagnostic approach — start here:**
1. Identify which module is involved: `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`, `AKS_GKE`, or `EKS_GKE`.
2. Identify the phase: initial `tofu apply`, post-provisioning workload install, steady-state operation, or `tofu destroy`.
3. Gather the error message and the last successful step.

**Common failure patterns and fixes:**

### null_resource provisioner failures

**Symptom**: `Error: local-exec provisioner error` during apply.
- Check that `gcloud`, `kubectl`, and (for Istio) `istioctl` are available on the machine running `tofu apply`. The `istiosidecar.tf` provisioner installs `kubectl` and `istioctl` into `$HOME/.local/bin` on demand — verify this path is on `$PATH` after the install step.
- Verify ADC is configured: `gcloud auth application-default login` or that `resource_creator_identity` is set and the SA holds `roles/owner` on the project.
- Check `set -eo pipefail` — any command that exits non-zero aborts the provisioner. Review each command in the failing block.

### Cluster credentials fail in a null_resource

**Symptom**: `gcloud container clusters get-credentials` returns an error inside a local-exec provisioner.
- The local-exec runs on the machine running `tofu apply`, not in GCP. Confirm `gcloud` is authenticated.
- If using impersonation, verify `--impersonate-service-account=${var.resource_creator_identity}` is appended to the credentials command and that the SA has `container.clusters.get` on the project.
- If the cluster is in a private network with no public endpoint, ensure the machine has VPC connectivity or the cluster has an authorized network entry for the runner's IP.

### `istioctl install` fails with HPA naming conflicts

**Symptom**: Error referencing HPA or `scaleTargetRef` during sidecar-mode install.
- The custom `IstioOperator` YAML in `istiosidecar.tf` sets `hpaSpec.scaleTargetRef.name = istio-ingressgateway`. Verify this block is present and unmodified.
- If you are reinstalling over an existing mesh, uninstall first: `istioctl uninstall --purge -y`.

### Istio / ASM pods stuck in Pending

**Symptom**: Mesh control-plane pods never become Ready.
- Check node pool resources: `kubectl describe nodes` — verify CPU and memory are not exhausted.
- For Istio_GKE, verify the node pool has enough capacity for the istiod deployment (default request: ~500m CPU, 2Gi memory).
- For Bank_GKE/MC_Bank_GKE with ASM, the managed control plane runs in GCP; check fleet feature status: `gcloud container fleet mesh describe --project=<project>`.

### Bank of Anthos pods stuck in Pending or CrashLoopBackOff

**Symptom**: Bank of Anthos workloads never become Ready after `deploy.tf` runs.
- The `deploy.tf` `null_resource` downloads the release tarball into `.terraform/bank-of-anthos/` on the apply machine. Verify the download succeeded; the path is shown in the provisioner stdout.
- Check that the namespace `bank-of-anthos` was created before the manifests were applied: `kubectl get namespace bank-of-anthos`.
- Verify the correct label is present — `Bank_GKE`/`MC_Bank_GKE` use managed Cloud Service Mesh, which reads `istio.io/rev=<revision>` (`asm-managed`/`asm-managed-rapid`/`asm-managed-stable`, matching the cluster's `release_channel`), **not** `istio-injection=enabled` (that label is `Istio_GKE`'s open-source sidecar-mode convention and does nothing on a CSM-managed cluster). Check with `kubectl get namespace bank-of-anthos --show-labels`.

### Bank_GKE apply hangs ~5 minutes then fails on the mesh API guard

**Symptom**: `asm.tf`'s `verify_mesh_api_activation` (or `verify_gke_hub_api_activation`) times out after exactly 300s during apply.
- `mesh.googleapis.com` alone is not sufficient for managed CSM — `meshconfig.googleapis.com` must also be enabled. Check both: `gcloud services list --enabled --project=<project> --filter="name:mesh.googleapis.com OR name:meshconfig.googleapis.com"`. If `meshconfig` is missing, add it to the module's `default_apis` in `main.tf` (it belongs alongside `mesh.googleapis.com`) and re-apply.

### Bank of Anthos pods are Running with sidecars injected, but `tofu apply` reported no errors and the app still looks meshless

**Symptom**: `gcloud container fleet mesh describe` shows the control plane `ACTIVE`, but pods that should have an `istio-proxy` container don't, or vice versa the deploy silently used the wrong revision.
- Check that the namespace's `istio.io/rev` label matches the revision the cluster's `release_channel` actually maps to (`asm-managed`↔REGULAR, `asm-managed-rapid`↔RAPID, `asm-managed-stable`↔STABLE). A mismatched label does not error at apply time — sidecar injection is simply skipped for that namespace. `gcloud container hub features describe servicemesh --project=<project> --format="value(membershipStates)"` shows which revision is actually active; compare it against `kubectl get namespace bank-of-anthos -o jsonpath='{.metadata.labels.istio\.io/rev}'`.
- If they don't match, either fix `release_channel` to match the label's expectation or (if the module still hardcodes the label rather than deriving it from `local.asm_revision`) that's the underlying bug — see `CLAUDE.md`'s "Managed Cloud Service Mesh Invariants".

### MC_Bank_GKE: Bank of Anthos pods have zero `istio-proxy` sidecars even though the namespace label is correct and `enable_cloud_service_mesh = true`

**Symptom**: Every pod in `bank-of-anthos` shows only its app container — `kubectl get pods -n bank-of-anthos -o jsonpath='{.items[*].spec.containers[*].name}'` never shows `istio-proxy` — and `gcloud container fleet mesh describe --project=<project>` shows `controlPlaneManagement.state` as `PROVISIONING`, not `ACTIVE`, even though `tofu apply` completed with no errors.
- This is the timing bug described in `CLAUDE.md`'s "Async GCP Feature Readiness" section and MC_Bank_GKE workflow rule 7 above: `deploy.tf` ran before the managed control plane was actually live, so the injector webhook wasn't there to act on the pods at creation time. Unlike the revision-mismatch case above, the label is already correct here — the problem is pure timing, and Deployments don't retroactively gain a sidecar once the control plane catches up.
- Fix for a live deployment: wait for `controlPlaneManagement.state` to reach `ACTIVE` (`gcloud container fleet mesh describe --project=<project> --format="value(membershipStates)"`), then `kubectl rollout restart deployment,statefulset -n bank-of-anthos` on the affected cluster(s) — this is the only way to trigger sidecar injection after the fact. First-time control-plane provisioning in a fresh project can take ~20-25 minutes.
- Fix for the module: confirm `hub.tf`'s `wait_for_service_mesh` polls the actual state field (see rule 7); if it only checks entry existence, this will recur on every apply.

### Regional resource creation fails with `violates constraint constraints/gcp.resourceLocations`

**Symptom**: `tofu apply` fails on a subnet, router, NAT gateway, or address with `Error 412: ... violates constraint constraints/gcp.resourceLocations ..., conditionNotMet` — not a quota or permission error, and easy to misdiagnose as one since the resource name and region look completely valid.
- The destination project enforces an org policy allowlisting specific regions/locations — common on ephemeral training/lab projects (e.g. Qwiklabs). Check the effective policy: `gcloud org-policies describe constraints/gcp.resourceLocations --project=<id> --effective` (enable `orgpolicy.googleapis.com` first if the command itself 403s).
- For `MC_Bank_GKE`, see the region-restricted-project common task above — a single allowed region in `available_regions` still deploys every cluster, just co-located.
- For single-region modules (`Istio_GKE`, `Bank_GKE`), change `region` to a value from the effective policy's allowlist.

### GKE cluster or node pool creation fails with `GCE_STOCKOUT`

**Symptom**: `tofu apply` fails after 30+ minutes with `Error waiting for creating GKE cluster: ... Instance '...' creation failed: The zone '...' does not have enough resources available to fulfill the request` — a transient capacity error, not a config or quota problem. It can recur in a *different* zone on the next retry within the same region.
- GKE always provisions a transient "default" node pool as part of `google_container_cluster` creation itself, even with `remove_default_node_pool = true` — a stockout here fails the whole cluster resource before Terraform ever reaches your own node pool.
- For `Istio_GKE`, `google_container_node_pool.preemptible_nodes` sets `node_locations` to every zone in the region (`data.google_compute_zones.available_zones.names`); for a regional pool, `node_count` applies **per zone**, so `node_count = 2` across 4 zones actually provisions 8 nodes, and a stockout in *any single* zone fails the whole pool.
- Killing/interrupting `tofu apply` does **not** cancel the GCP-side operation — check `gcloud container clusters describe <cluster> --region=<region> --format="value(status,statusMessage)"` directly rather than trusting local state after an interrupt. If the cluster shows `ERROR`, delete it with `gcloud container clusters delete` (it's likely not in `tofu state list` yet — `Create()` doesn't call `SetId()` until its ready-wait succeeds — so `tofu destroy` won't find it) and re-`apply`. See `CLAUDE.md`'s "Interrupted or Manual `tofu apply` Can Leave GCP Ahead of Local State" and "GKE Node Pool Creation and `GCE_STOCKOUT`".
- If the project is also org-policy-restricted to one region (previous entry), there is no fallback region to retry into — the only options are retrying the same region or waiting.

### `tofu plan`/`apply` fails with `PERMISSION_DENIED` on a project you can definitely access

**Symptom**: `data.google_project.existing_project` (or any early `google_*` data source) fails with a 403 even though you just authenticated to the right project, or a deploy that was working mid-session suddenly can't reach GCP.
- Application Default Credentials are a single file shared machine-wide (`~/.config/gcloud/application_default_credentials.json`) — running `gcloud auth application-default login` in *any* terminal, including a different unrelated task, overwrites it for every process on the machine, including one mid-`tofu apply`. `gcloud config configurations` does **not** protect against this; the configuration files themselves live in the same shared, globally-overwritable directory.
- Diagnose: `curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$(gcloud auth application-default print-access-token)"` and compare the `email` field against who you expect to be authenticated as.
- Fix for the current run: re-authenticate as the correct identity (`gcloud auth application-default login`, then `gcloud auth application-default set-quota-project <project>`), then retry.
- Fix to prevent recurrence when running two identities/projects on one machine concurrently: give each session its own `CLOUDSDK_CONFIG=<dir>` before authenticating. `CLOUDSDK_CORE_ACCOUNT`/`CLOUDSDK_CORE_PROJECT` only scope a script's own `gcloud` shell-outs (useful for pinning a module's `null_resource` provisioners to the right identity) — they do not affect ADC, which is what the `google`/`google-beta` Terraform providers actually read.
- **`CLOUDSDK_CONFIG` alone is not enough for `tofu`/`terraform` itself.** The Go-based `google` provider hardcodes `~/.config/gcloud/application_default_credentials.json` (or `GOOGLE_APPLICATION_CREDENTIALS` if set) and has no knowledge of `CLOUDSDK_CONFIG` — unlike `gcloud`'s own Python code. After isolating a session with `CLOUDSDK_CONFIG=<dir>` and authenticating inside it, also export `GOOGLE_APPLICATION_CREDENTIALS="<dir>/application_default_credentials.json"` before running `tofu`, or it silently reads whatever stale ADC file happens to be at the shared default path.

### Multi-Cluster Ingress never gets a VIP

**Symptom**: `kubectl get mci -n bank-of-anthos` shows `ADDRESS` as empty.
- MCI requires the Hub Ingress feature to be enabled at fleet level. Check: `gcloud container fleet ingress describe --project=<project>`.
- The config cluster (the cluster from which MCI reads the MultiClusterIngress resource) must be set. Check: `gcloud container fleet ingress describe --format="value(spec.multiclusteringress.configMembership)"`.
- The global static IP from `glb.tf` must be annotated on the MCI resource as `kubernetes.io/ingress.global-static-ip-name`.

### AKS/EKS attached cluster never appears in GCP Console

**Symptom**: The cluster is not visible under `Kubernetes Engine > Clusters` after apply.
- The GKE Connect agent must be installed on the attached cluster. Verify the `attached-install-manifest` submodule's Helm release succeeded: check Helm release status on the AKS/EKS cluster.
- Confirm `gkemulticloud.googleapis.com` and `gkehub.googleapis.com` are enabled: `gcloud services list --project=<project>`.
- Check Fleet membership: `gcloud container fleet memberships list --project=<project>`.

### Destroy hangs, loops, or leaves orphaned resources

**Symptom**: `tofu destroy` times out or a null_resource destroy provisioner keeps retrying.
- Every destroy provisioner must use `set +e` (not `set -e`), `--ignore-not-found` on `kubectl delete` calls, and `|| echo "Warning: ..."` to be best-effort.
- If a destroy provisioner is hanging on a `kubectl` call, the cluster may already be deleted. Check the provisioner code for unconditional `set -e` or missing error tolerances.
- For MC_Bank_GKE, the MCI/MCS resources must be deleted before Terraform removes the fleet features. If this step was skipped, manually run: `kubectl delete mci --all -n bank-of-anthos` and `kubectl delete mcs --all -n bank-of-anthos` on the config cluster, then re-run `tofu destroy`.

### API disabled after destroy

**Symptom**: After running `tofu destroy`, other deployments start failing with "API not enabled" errors.
- Ensure every `google_project_service` resource has `disable_on_destroy = false`. If this was `true`, change it and run `tofu apply` to update the resource state before the next destroy.

**Useful diagnostic commands:**
```bash
# GKE cluster status
gcloud container clusters list --project=<project>

# Fleet/Hub membership status
gcloud container fleet memberships list --project=<project>

# ASM/CSM fleet mesh status
gcloud container fleet mesh describe --project=<project>

# Kubernetes pod status
kubectl get pods --all-namespaces
kubectl describe pod <pod> -n <namespace>

# Helm release status (for attached clusters)
helm list --all-namespaces

# Istio installation status
istioctl verify-install
istioctl proxy-status

# Cloud Build logs (for RAD platform deployments)
gcloud builds list --project=<project> --limit=10
gcloud builds log <build-id> --project=<project>
```

**Task:**
Systematically diagnose the issue using the patterns above. Start with the error message and the failing phase, narrow down the root cause, and propose a targeted fix.
```

## Maintenance Workflow

**Trigger**: `/maintain`

**Prompt**:
```markdown
You are now in **Maintenance Mode**, performing updates or configuration changes on existing module deployments.

**Maintenance categories:**

### 1. Kubernetes / GKE version upgrades
- None of the GKE-based modules pin `min_master_version` — they all set `release_channel` (default `REGULAR`) and let Google manage the actual version. **Do not add a `min_master_version` pin as the mechanism for a version upgrade**; the channel already tracks current. Changing `release_channel` (e.g. `REGULAR` → `STABLE`) shifts which live version the cluster gets, but there is no variable that hardcodes a specific master version to bump.
- `AKS_GKE`/`EKS_GKE` are the exception — `k8s_version` (AKS/EKS-side) and `platform_version` (GKE Attached Clusters-side) genuinely are pinned variables and do need periodic bumping. `platform_version`'s minor must equal `k8s_version`'s minor or be exactly one below it (attached-cluster requirement, not a suggestion). Get the versions the platform currently offers with `gcloud container attached get-server-config --location=<gcp_location>` before picking new values — don't guess from AKS/EKS release notes alone, since GKE's attached-clusters support lags upstream.
- Before bumping `istio_version` (see #2), check what GKE actually serves each channel right now — `gcloud container get-server-config --region=<region> --format=json` — and cross-reference against Istio's official Kubernetes-compatibility table (istio.io/latest/docs/releases/supported-releases/, not just its own release notes) rather than assuming the currently-pinned Istio version still covers the channel's current Kubernetes version. Istio versions go EOL roughly every 6 months and their supported-K8s window is only about 4 minor versions wide, so this check needs re-running periodically, not just once.
- Apply with `tofu plan` first to preview the change. GKE control-plane upgrades are rolling and in-place for Standard clusters; Autopilot upgrades are fully managed.

### 2. Istio version upgrades (Istio_GKE)
- Update the `istio_version` variable default in `variables.tf` (and the matching assertion in `tests/validate.tftest.hcl`, or `tofu test` will fail on the stale expected value).
- Confirm the target release's addon manifests still exist before relying on the installer: `istiosidecar.tf`/`istioambient.tf` both `kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-<X.Y>/samples/addons/{prometheus,jaeger,grafana,kiali}.yaml` in a loop with `|| echo "Warning: ..."` — a missing file degrades silently to a warning, not a failure, so the observability stack can quietly not install.
- The `istiosidecar.tf` provisioner re-runs when any trigger value changes. To force re-install on the next apply, uncomment `always_run = timestamp()` in the triggers block, apply once, then re-comment it.
- After upgrading, run `istioctl verify-install` to confirm the new version is healthy.
- **This module bump does not touch `scripts/`.** `scripts/gcp-istio-traffic/gcp-istio-traffic.sh` and `scripts/gcp-istio-security/gcp-istio-security.sh` pin their own `ISTIO_VERSION` (and, for `gcp-istio-traffic.sh`, `ISTIO_RELEASE_VERSION`) independently in the `.env` bootstrap block — they are standalone scripts, not consumers of `variables.tf`. Confirmed live: a version-refresh commit scoped to `modules/`/`docs/` bumped `istio_version` to `1.30.3` but left both scripts and two `docs/` references on the EOL `1.24.2`, caught only when a user ran the script and saw it download the old release. `grep -rn "1\.24\.2\|release-1\.24" scripts/ docs/` (substituting the version being retired) after any `istio_version` bump to catch every hardcoded copy, not just the module's.

### 3. Bank of Anthos version upgrades (Bank_GKE, MC_Bank_GKE)
- Update `local.bank_of_anthos_version` in `deploy.tf` (both modules keep their own copy — update both). The download is forced on every apply via `always_run = timestamp()`, so no trigger change is needed.
- Before assuming a version bump is a drop-in swap, diff the release tarball's `kubernetes-manifests/` and `extras/jwt/` directory listings against the currently-pinned version (`curl -s "https://api.github.com/repos/GoogleCloudPlatform/bank-of-anthos/contents/kubernetes-manifests?ref=<tag>"`). Specifically check whether the `bank-of-anthos` KSA's `iam.gke.io/gcp-service-account` annotation still points at the upstream `bank-of-anthos-ci` project's SA — if so, the module's Workload Identity re-annotation step in `deploy.tf` (patches it to the local project's `bank-of-anthos@<project>.iam.gserviceaccount.com`) is still required and still correct as-is.
- Review the Bank of Anthos release notes for breaking changes to the manifest structure.

### 4. Adding or removing clusters (MC_Bank_GKE)
- Update `local.cluster_configs` in `variables.tf` to add or remove a cluster key (`cluster1`–`cluster4`).
- Add or remove the corresponding static `kubernetes` provider alias in `gke.tf`.
- Run `tofu plan` and review the diff carefully — changes to the cluster map may trigger replacement of dependent resources (Hub memberships, ASM feature memberships).
- **Warning**: Removing a cluster key from `local.cluster_configs` will cause `tofu destroy` to attempt removal of that cluster's Hub membership and ASM feature membership. Ensure the cluster's workloads are drained first.

### 5. Updating UIMeta variable annotations
- Change `group=N` or `order=M` in the variable description to reorganize the RAD platform UI.
- Order values are compared numerically within a group; gaps are allowed (e.g. order 101, 103, 105 is fine).
- The `updatesafe` tag marks variables safe to change on an in-place apply. Do not add `updatesafe` to variables that force resource replacement — `project_id`, `cluster_name_prefix`, and every region variable (`region`, `gcp_location`, `azure_region`, `aws_region`) were all stripped of it on 2026-08-19 and must stay unflagged. Its **absence** is what the platform acts on, so an over-generous flag is a silent data-loss path while a missing one only costs a warning: when in doubt, leave it off.
- The sibling `notradmanaged` tag removes a variable from the deploy form in a RAD-managed project and reverts it server-side, so its module default must be benign.
- `enable_rad_gcpproject` (`{{UIMeta group=0 order=110 }}`, `bool`, default `false`) is declared by seven of the eight modules — every one except `Istio_GKE` — and hides the "GCP Project on RAD" option for modules that enable APIs the RAD-managed tier policies deny. Its description names the specific APIs; keep that list in step with the module's `default_apis` if you change either.

### 6. Updating the RAD platform service account default
- The `resource_creator_identity` variable defaults to the platform SA email. If the platform SA changes, update the default in `variables.tf` for each affected module.

### 7. Provider version drift on re-init
- Provider constraints without an upper bound (`">=X.Y.Z"` with no `~>` or `< N`) can silently jump a major version on the next `tofu init -upgrade` (or any fresh `init`, since lock files are gitignored here). Confirmed: `AKS_GKE`'s `azurerm = ">=3.17.0"` resolved 5.0.1 and broke `plan` on a newly-required `node_provisioning_profile` block. If a module that validated cleanly last week suddenly fails `tofu validate`/`plan` with schema errors referencing a block or attribute you don't recognize, check `tofu init` output for which provider version it actually resolved before assuming the Terraform code regressed.
- The fix is a version bound, not a code workaround: pin `~> <major>.0` (or narrower) in `versions.tf`/`provider.tf`, matching the major version the module was actually written against, then re-run `tofu init -upgrade`.

**Pre-maintenance checklist:**
- [ ] `tofu plan -var="project_id=<project>"` — review the diff for unexpected replacements (red `-/+`)
- [ ] For destructive changes: confirm all cluster workloads are backed up or stateless
- [ ] For MC_Bank_GKE cluster map changes: drain workloads from clusters being removed
- [ ] For Istio version upgrades: verify the target version is available at `github.com/istio/istio/releases` **and** check its Kubernetes-compatibility range against what the target `release_channel` is currently serving (`istio.io/latest/docs/releases/supported-releases/`) — a version that installs fine can still be past its supported K8s window for the channel in use.
- [ ] For provider version bumps: confirm the constraint in `versions.tf`/`provider.tf` has an explicit upper bound before running `tofu init -upgrade`, not just after something breaks.

**Post-maintenance validation:**
- [ ] `tofu state list` — verify all expected resources are present
- [ ] `kubectl get pods --all-namespaces` — verify all pods are Running/Completed
- [ ] For mesh modules: `istioctl verify-install` or `gcloud container fleet mesh describe`
- [ ] For Bank of Anthos: access the frontend URL and verify login works

**Task:**
Execute the maintenance task following the checklist above. For any change that causes resource replacement, flag it to the user before proceeding.
```

## Security Workflow

**Trigger**: `/security`

**Prompt**:
```markdown
You are now in **Security Audit Mode**, reviewing and hardening the GKE and mesh modules in this repository.

**Security review checklist:**

### 1. IAM and service accounts
- [ ] `resource_creator_identity` SA holds only `roles/owner` on the destination project (the minimum the impersonation pattern requires). No broader project-level bindings.
- [ ] `trusted_users` contains only specific email addresses, not domain-level wildcards (e.g. `allUsers` or `domain:example.com`).
- [ ] GKE node pool SA is a dedicated SA with minimal roles (`roles/logging.logWriter`, `roles/monitoring.metricWriter`, `roles/monitoring.viewer`, `roles/stackdriver.resourceMetadata.writer`). Not the Compute Engine default SA.
- [ ] No `roles/owner` or `roles/editor` granted to the node pool SA.

### 2. Secret and credential handling
- [ ] No secrets or private keys in `variables.tf` defaults — especially `client_secret` (AKS_GKE) and `aws_secret_key` (EKS_GKE).
- [ ] Azure and AWS credentials are sourced from environment variables (`ARM_CLIENT_SECRET`, `AWS_SECRET_ACCESS_KEY`), not from Terraform state or `.tfvars` files committed to the repo.
- [ ] `resource_creator_identity` is a service account email, not a key file path or private key value.
- [ ] Impersonation is configured via the provider's `impersonate_service_account` attribute in `provider-auth.tf` — no service account key files or long-lived tokens in the module.

### 3. Network security
- [ ] GKE clusters use VPC-native networking (IP alias ranges). Verify `ip_allocation_policy` is set in `gke.tf`.
- [ ] Cloud Router + NAT is configured for outbound traffic from private nodes (nodes should not have public IPs).
- [ ] Firewall rules are additive (no `deny all` baseline — GKE manages its own rules). Avoid overly permissive `0.0.0.0/0` source ranges on custom rules.
- [ ] For Istio_GKE: the Istio Ingress Gateway LoadBalancer is the only public entry point. Verify that `istio-ingressgateway` is of type `LoadBalancer` and that direct node access is not exposed.
- [ ] For Bank_GKE/MC_Bank_GKE: the global HTTPS load balancer uses a Google-managed certificate. Verify the `managed_certificate.yaml.tpl` template references the correct domain.

### 4. GKE cluster hardening
- [ ] `deletion_protection = false` is acceptable for lab modules but should be `true` in production forks.
- [ ] Verify Workload Identity is enabled if Bank_GKE or MC_Bank_GKE workloads need GCP API access (Bank of Anthos uses it for Cloud Spanner / Cloud SQL access).
- [ ] Binary Authorization — not currently enabled in these modules. Flag as a hardening opportunity if deploying to a regulated environment.
- [ ] Private cluster option — not currently enabled. For production use, consider enabling `private_cluster_config` in `gke.tf` and adding authorized networks.

### 5. Mesh / ASM security
- [ ] For Istio_GKE (sidecar mode): verify `PeerAuthentication` resources enforce `STRICT` mTLS across the mesh namespace.
- [ ] For Bank_GKE/MC_Bank_GKE with ASM: the managed control plane enforces mTLS by default; verify with `gcloud container fleet mesh describe`.
- [ ] `AuthorizationPolicy` resources — check that no policy grants `*` for principal or source; policies should be scoped to specific service accounts.
- [ ] Bookinfo sample app (if deployed in Istio_GKE) is for demonstration only. Do not expose it permanently on a public IP in production.

### 6. Terraform / OpenTofu state security
- [ ] State files are stored in GCS with versioning and object-level encryption. Never store state locally for shared environments.
- [ ] State bucket is not publicly readable. Verify the bucket IAM policy.
- [ ] `.terraform/` directory is in `.gitignore` (confirmed in repo root `.gitignore`). Sensitive provider cache data is not committed.

**Security commands:**
```bash
# GKE cluster IAM
gcloud container clusters get-iam-policy <cluster> --region=<region> --project=<project>

# Project IAM — check for overly permissive bindings
gcloud projects get-iam-policy <project> --format=json | \
  jq '.bindings[] | select(.role=="roles/owner" or .role=="roles/editor")'

# GKE node pool SA
gcloud container clusters describe <cluster> --region=<region> --project=<project> \
  --format="value(nodePools[].config.serviceAccount)"

# Mesh mTLS enforcement
kubectl get peerauthentication --all-namespaces
kubectl get authorizationpolicy --all-namespaces

# Fleet mesh status
gcloud container fleet mesh describe --project=<project>

# Firewall rules
gcloud compute firewall-rules list --project=<project> \
  --format="table(name,direction,sourceRanges,allowed[].ports)"
```

**Task:**
Perform a systematic security review using the checklist above for the specified module. Identify gaps and provide specific, actionable remediation steps targeting the Terraform source files in this repository.
```
