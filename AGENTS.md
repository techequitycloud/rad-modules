# Agent Workflows

This file contains workflow prompts for engineers to guide the agent. These workflows context-switch the agent into the specific mode required for different parts of the repository.

## Global Workflow

**Trigger**: `/global`

**Prompt**:
```markdown
You are an expert Senior DevOps Engineer specializing in Google Cloud Platform, GKE, and OpenTofu/Terraform. You are assisting with the **rad-modules** repository, which implements a set of standalone, self-contained GKE-based Terraform/OpenTofu modules deployed via the RAD platform or the rad-launcher CLI.

**Repository Structure:**
The repository is organized around five independent modules under `modules/`. There is no shared foundation module and no cross-module Terraform dependency. Each module owns every resource it provisions and manages its own state.

| Module | What it provisions | Target audience |
|---|---|---|
| `Istio_GKE` | GKE Standard cluster + open-source Istio (sidecar or ambient mode) + Prometheus/Jaeger/Grafana/Kiali + optional Bookinfo sample | Platform engineers learning upstream Istio |
| `Bank_GKE` | GKE cluster (Autopilot or Standard) + Cloud Service Mesh (managed Istio) + Bank of Anthos + optional Anthos Config Management + Cloud Monitoring SLOs | Engineers exploring ASM on a single cluster |
| `MC_Bank_GKE` | Multiple GKE clusters across regions + fleet-wide Cloud Service Mesh + Multi-Cluster Ingress + Multi-Cluster Services + Bank of Anthos behind a global HTTPS LB | Engineers exploring multi-cluster mesh and traffic |
| `AKS_GKE` | Azure AKS cluster registered with GCP as a GKE Attached Cluster via Fleet + GKE Connect agent via Helm | Engineers exploring multi-cloud fleet management |
| `EKS_GKE` | AWS EKS cluster registered with GCP as a GKE Attached Cluster via Fleet + GKE Connect agent via Helm | Engineers exploring multi-cloud fleet management |

**Supporting directories:**
- `rad-launcher/` — `radlab.py` Python CLI that wraps `tofu`/`terraform` for interactive deployment from a workstation or Cloud Shell.
- `rad-ui/automation/` — Cloud Build YAML files (`cloudbuild_deployment_{create,destroy,purge,update}.yaml`) invoked by the RAD platform UI.
- `scripts/` — standalone helper shell scripts (`gcp-istio-security/`, `gcp-istio-traffic/`, `gcp-cr-mesh/`, `gcp-m2c-vm/`) for lab exercises; not called by any module.
- `SKILLS.md` — detailed implementation guide; read this before making structural changes.

**Standard file layout (using `Istio_GKE` as the canonical example):**
```
modules/Istio_GKE/
├── main.tf              # Project bootstrap, API enablement, random_id
├── provider-auth.tf     # google + google-beta providers with SA impersonation
├── versions.tf          # required_providers + required_version
├── variables.tf         # UIMeta-annotated inputs (groups 0–6)
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
Open-source Istio service mesh on a GKE Standard cluster. The user selects either sidecar mode (`istiosidecar.tf`) or ambient mode (`istioambient.tf`) via the `install_ambient_mesh` variable. The observability stack (Prometheus, Jaeger, Grafana, Kiali) and the optional Bookinfo sample app are installed as part of the mesh setup.

**Key files and their roles:**
- `main.tf` — project data source, `random_id`, API enablement (`container.googleapis.com`, `cloudapis.googleapis.com`), `null_resource.wait_for_container_api` polling loop.
- `provider-auth.tf` — impersonated `google` provider; configures `google-beta` block (currently unused by resources).
- `versions.tf` — pins `google` and `kubernetes`; requires `>= 0.13`.
- `variables.tf` — UIMeta groups: 0=Provider/Metadata, 1=Main (project/region), 2=Network, 3=GKE, 4=Features (istio_version, install_ambient_mesh, enable_services), 6=Application (deploy_application).
- `network.tf` — VPC, subnet with secondary IP ranges for pods/services, firewall rules, Cloud Router + NAT.
- `gke.tf` — GKE Standard cluster and node pool, cluster service account with minimum IAM roles, `kubernetes` provider (alias `primary`), local `k8s_credentials_cmd`.
- `istiosidecar.tf` — `null_resource.install_sidecar_mesh` (count=1 when `install_ambient_mesh=false`): installs `kubectl` and `istioctl` into `$HOME/.local/bin`, fetches cluster credentials, runs `istioctl install` with a custom IstioOperator YAML to fix HPA naming, then installs the observability add-ons and optional Bookinfo.
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
- **Upgrade Istio version**: Update the `istio_version` variable default in `variables.tf`. Verify the new version is available on `github.com/istio/istio/releases`.
- **Add a new Kubernetes manifest**: Add the YAML to `manifests/` and reference it with a `null_resource` local-exec `kubectl apply -f` call in `istiosidecar.tf` or `istioambient.tf`.
- **Add a new variable**: Add it to `variables.tf` with a `{{UIMeta group=N order=M }}` annotation. Choose the correct group (4 for mesh features, 6 for application options).
- **Extend observability stack**: Add installation steps inside the existing `null_resource` provisioner create block, after the mesh install steps. Add corresponding removal steps in the destroy block.

**Task:**
Work within `modules/Istio_GKE/`. If the change requires modifying the provisioning logic, follow the null_resource pattern in `istiosidecar.tf`. Validate with `tofu init && tofu validate && tofu fmt -check` from the module directory.
```

## Bank_GKE Module Workflow

**Trigger**: `/bank`

**Prompt**:
```markdown
You are now in **Bank_GKE Module Mode**, working on `modules/Bank_GKE`.

**What this module provisions:**
A GKE cluster (Autopilot or Standard, controlled by `create_cluster`) with Cloud Service Mesh (managed Istio via GKE Hub/Fleet), the Bank of Anthos v0.6.7 demo application, optional Anthos Config Management, and Cloud Monitoring SLOs.

**Key files and their roles:**
- `main.tf` — project data source, `random_id`, API enablement (container, gkehub, mesh, monitoring APIs), `null_resource.wait_for_container_api`.
- `provider-auth.tf` — same impersonation pattern as Istio_GKE; token lifetime is `3600s` (vs 1800s in Istio_GKE).
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
- `main.tf` — project data source, `random_id`, API enablement, `null_resource.wait_for_container_api`.
- `provider-auth.tf` — same impersonation pattern as the other GKE modules.
- `versions.tf` — pins `google` and `kubernetes`; requires `>= 0.13`.
- `variables.tf` — variables for cluster count, regions, network CIDRs per cluster, ASM/MCI/MCS feature flags.
- `network.tf` — VPC shared across all clusters; one subnet with secondary ranges per cluster, iterated with `for_each`.
- `gke.tf` — `google_container_cluster.gke_cluster` is a `for_each` resource over `local.cluster_configs`. Four `kubernetes` provider aliases (`cluster1`–`cluster4`) are statically configured, each pointing to the corresponding cluster endpoint.
- `hub.tf` — `google_gke_hub_membership` for each cluster (fleet registration); connect-agent provisioners per cluster.
- `asm.tf` — `google_gke_hub_feature "service_mesh"` once, plus per-cluster `google_gke_hub_feature_membership`; enables fleet-wide ASM.
- `glb.tf` — reserves a global static IP for the Multi-Cluster Ingress controller.
- `mcs.tf` — creates the MultiClusterIngress and MultiClusterService resources; contains a destroy `null_resource` that deletes MCI/MCS objects from all clusters before Terraform removes the fleet features.
- `manifests.tf` — renders templates from `templates/` into `manifests/` using `local_file` resources, then applies them to each cluster.
- `deploy.tf` — downloads and applies the Bank of Anthos manifests to each cluster.
- `manifests/` — rendered YAML files written at apply time by `manifests.tf`.
- `templates/` — source YAML templates for BackendConfig, FrontendConfig, Ingress, managed certificate, nodeport service, configmap, MultiClusterIngress, MultiClusterService.

**Critical implementation rules:**
1. **`for_each` cluster map**: `google_container_cluster.gke_cluster` uses `for_each = local.cluster_configs`. When adding or removing a cluster, update `local.cluster_configs` and the corresponding `kubernetes` provider alias. Changing the set of keys forces replacement of all resources keyed by cluster name.
2. **Static provider aliases**: The four `kubernetes` provider aliases in `gke.tf` are statically defined (not dynamically generated from `for_each`). Terraform requires provider configurations to be static. If you need more than four clusters, you must add a new static alias.
3. **MCI/MCS destroy order**: The `mcs.tf` destroy provisioner deletes MCI and MCS objects (`kubectl delete mci --all`, `kubectl delete mcs --all`) from the bank-of-anthos namespace before Terraform removes the fleet features. This provisioner must tolerate missing resources (`|| true`).
4. **manifests.tf writes to manifests/**: `local_file` resources render templates into `${path.module}/manifests/`. These files are gitignored (do not commit rendered output). If you change a template, always re-render by running `tofu apply` (or force replace the `local_file` resources).
5. **Global LB dependency**: MCI requires the global static IP from `glb.tf` to be provisioned before MCI resources are created. Keep `depends_on = [google_compute_global_address.ingress_ip]` in `mcs.tf`.

**Common tasks:**
- **Change cluster count or regions**: Update `local.cluster_configs` in `main.tf` (or wherever it is defined) and add/remove the corresponding `kubernetes` provider alias in `gke.tf`.
- **Add a new template**: Add the `.yaml.tpl` to `templates/` and a corresponding `local_file` resource in `manifests.tf`. Reference the rendered file in the apply step.
- **Update Bank of Anthos version**: Same as Bank_GKE — update the tarball URL in `deploy.tf`.
- **Toggle MCI/MCS**: Controlled by a feature flag variable. Guard the `mcs.tf` resources with `count` or `for_each` on that flag, following the existing pattern.

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
- `EKS_GKE`: `google`, `aws` (AWS credentials via environment variables), `helm` (pointing at the EKS cluster), `random`.

There is no top-level `versions.tf`; provider version constraints live in the nested submodule `versions.tf` files.

**GCP APIs enabled (in `main.tf`):**
`gkemulticloud.googleapis.com`, `gkeconnect.googleapis.com`, `connectgateway.googleapis.com`, `cloudresourcemanager.googleapis.com`, `anthos.googleapis.com`, `monitoring.googleapis.com`, `logging.googleapis.com`, `gkehub.googleapis.com`, `opsconfigmonitoring.googleapis.com`, `kubernetesmetadata.googleapis.com`.

**Nested submodules:**
- `attached-install-manifest` — fetches the GKE Attached Cluster bootstrap manifest via `data "google_container_attached_install_manifest"`, writes it as a Helm chart (`local_file`), and applies it to the attached cluster via the `helm_release` resource. This submodule is invoked automatically by the parent module after the cluster is registered.
- `attached-install-mesh` — optional ASM installer. **Not invoked by the parent module automatically.** Invoke it from your own root module if you want ASM on the attached cluster.

**No Terraform outputs at the top level:**
These modules expose no `output` blocks. The equivalent of `get-credentials` is documented in the module README: `gcloud container attached clusters get-credentials <cluster-name> --location=<region> --project=<project-id>`.

**Critical implementation rules:**
1. **Credentials via environment variables**: Azure credentials are set via `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`. AWS credentials are set via `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`. Never add these as Terraform variable defaults.
2. **AKS VNet inline**: The Azure Virtual Network and subnet are created directly in `main.tf`, not in a separate `network.tf`. Follow this pattern when adding Azure networking resources.
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
- If ASM/Istio sidecar injection is enabled, verify the namespace label `istio-injection=enabled` is set: `kubectl get namespace bank-of-anthos --show-labels`.

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
- Update the `release_channel` variable (e.g. `REGULAR` → `STABLE`) or pin a specific `min_master_version` in `gke.tf`.
- Check that the new GKE version supports the Istio / ASM version in use. Cross-reference GKE release notes with the Istio support matrix.
- Apply with `tofu plan` first to preview the change. GKE control-plane upgrades are rolling and in-place for Standard clusters; Autopilot upgrades are fully managed.

### 2. Istio version upgrades (Istio_GKE)
- Update the `istio_version` variable default in `variables.tf`.
- The `istiosidecar.tf` provisioner re-runs when any trigger value changes. To force re-install on the next apply, uncomment `always_run = timestamp()` in the triggers block, apply once, then re-comment it.
- After upgrading, run `istioctl verify-install` to confirm the new version is healthy.

### 3. Bank of Anthos version upgrades (Bank_GKE, MC_Bank_GKE)
- Update the tarball URL and version tag in `deploy.tf`. The download is forced on every apply via `always_run = timestamp()`, so no trigger change is needed.
- Review the Bank of Anthos release notes for breaking changes to the manifest structure.

### 4. Adding or removing clusters (MC_Bank_GKE)
- Update `local.cluster_configs` in `main.tf` to add or remove a cluster key (`cluster1`–`cluster4`).
- Add or remove the corresponding static `kubernetes` provider alias in `gke.tf`.
- Run `tofu plan` and review the diff carefully — changes to the cluster map may trigger replacement of dependent resources (Hub memberships, ASM feature memberships).
- **Warning**: Removing a cluster key from `local.cluster_configs` will cause `tofu destroy` to attempt removal of that cluster's Hub membership and ASM feature membership. Ensure the cluster's workloads are drained first.

### 5. Updating UIMeta variable annotations
- Change `group=N` or `order=M` in the variable description to reorganize the RAD platform UI.
- Order values are compared numerically within a group; gaps are allowed (e.g. order 101, 103, 105 is fine).
- The `updatesafe` tag marks variables safe to change on an in-place apply. Do not add `updatesafe` to variables that force resource replacement (e.g. `gcp_region`, `existing_project_id`).

### 6. Updating the RAD platform service account default
- The `resource_creator_identity` variable defaults to the platform SA email. If the platform SA changes, update the default in `variables.tf` for each affected module.

**Pre-maintenance checklist:**
- [ ] `tofu plan -var="existing_project_id=<project>"` — review the diff for unexpected replacements (red `-/+`)
- [ ] For destructive changes: confirm all cluster workloads are backed up or stateless
- [ ] For MC_Bank_GKE cluster map changes: drain workloads from clusters being removed
- [ ] For Istio version upgrades: verify the target version is available at `github.com/istio/istio/releases`

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
- [ ] Impersonation token lifetime is appropriately short (`1800s` for Istio_GKE; `3600s` for Bank_GKE). Do not extend unnecessarily.

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
