---
name: attached-cluster-modules
description: How the AKS_GKE and EKS_GKE modules provision a Kubernetes cluster in Azure or AWS and register it with a GKE Fleet via GKE Attached Clusters.
---

# Attached Cluster Modules

`modules/AKS_GKE` and `modules/EKS_GKE` share a nearly identical three-phase pattern: provision a Kubernetes cluster in another cloud, bootstrap the GKE Connect agent onto it, then register it as a GKE Attached Cluster so it shows up in the GKE Fleet and the Google Cloud Console.

## Shared Shape

Both modules consist of:

```
modules/AKS_GKE/ (or EKS_GKE/)
├── main.tf               # Foreign-cloud cluster + helm bootstrap + google_container_attached_cluster
├── variables.tf          # Standard vars + foreign-cloud creds + k8s_version/platform_version
├── provider.tf           # Pattern A (direct providers, no impersonation)
├── vpc.tf / iam.tf       # (EKS_GKE only — AWS needs an explicit VPC + IAM roles; AKS bundles these)
├── modules/
│   ├── attached-install-manifest/   # Helm install of the GKE Connect bootstrap
│   └── attached-install-mesh/       # Optional: runs asmcli to install ASM (NOT invoked by main.tf)
├── README.md
└── <MODULE>.md
```

## The Three Phases

### Phase 1 — Foreign-Cloud Cluster

**AKS_GKE** (`azurerm`):

```hcl
resource "azurerm_resource_group" "aks"            { ... }
resource "azurerm_kubernetes_cluster" "aks" {
  oidc_issuer_enabled = true            # required for OIDC federation
  identity { type = "SystemAssigned" }  # managed identity
  default_node_pool { node_count, vm_size, ... }
}
resource "azurerm_role_assignment" "aks_network_contributor" { ... }
```

**EKS_GKE** (`aws`):

```hcl
resource "aws_vpc"                   "eks" { ... }   # in vpc.tf
resource "aws_subnet"                "public" / "private" { ... }
resource "aws_iam_role"              "eks" / "node" { ... }  # in iam.tf
resource "aws_eks_cluster"           "eks" { version = var.k8s_version ... }
resource "aws_eks_node_group"        "node" { scaling_config { ... } }
```

Both modules honour `var.k8s_version` (e.g. `"1.34"`) as a minor version and let the foreign cloud manage the patch level.

### Phase 2 — GKE Connect Bootstrap via Helm

A `helm` provider is configured with an alias `bootstrap_installer` that points at the newly-created foreign cluster using its kubeconfig fields:

```hcl
# AKS_GKE/main.tf
provider "helm" {
  alias = "bootstrap_installer"
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
    username / password
  }
}

# EKS_GKE/main.tf
provider "helm" {
  alias = "bootstrap_installer"
  kubernetes {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}
```

Then the `modules/attached-install-manifest` nested submodule is invoked with that aliased provider:

```hcl
module "attached_install_manifest" {
  source                         = "./modules/attached-install-manifest"
  attached_cluster_name          = var.cluster_name_prefix
  attached_cluster_fleet_project = local.project_id
  gcp_location                   = var.gcp_location
  platform_version               = var.platform_version
  providers = { helm = helm.bootstrap_installer }
  depends_on = [ azurerm_kubernetes_cluster.aks /* or aws_eks_node_group.node */ ]
}
```

The submodule uses `data.google_container_attached_install_manifest` to fetch Google's bootstrap YAML, writes it into a synthesized Helm chart under `${path.root}/.tmp/<gcp_location>-<platform_version>/bootstrap_helm_chart/`, and `helm install`s it. **Do not edit the submodule source when customizing a cluster** — change the parent module's inputs instead.

### Phase 3 — Attached Cluster Registration

```hcl
resource "google_container_attached_cluster" "primary" {
  name             = var.cluster_name_prefix
  project          = local.project_id
  location         = var.gcp_location
  distribution     = "aks"   # or "eks"
  platform_version = var.platform_version

  oidc_config {
    issuer_url = azurerm_kubernetes_cluster.aks.oidc_issuer_url
    # OR aws_eks_cluster.eks.identity[0].oidc[0].issuer
  }

  fleet { project = "projects/${local.project_number}" }

  logging_config    { component_config { enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"] } }
  monitoring_config { managed_prometheus_config { enabled = true } }
  authorization     { admin_users = local.trusted_users }

  depends_on = [ module.attached_install_manifest, google_project_service.enabled_services ]
}
```

This resource:
- Uses the foreign cluster's OIDC issuer URL to establish cross-cloud trust (no shared credentials).
- Enrolls the cluster into the fleet identified by `project_number`.
- Grants cluster-admin via Connect Gateway to every email in `var.trusted_users`.

## Required GCP APIs

Both modules enable the same ten APIs in `main.tf → local.default_apis`:

```
gkemulticloud.googleapis.com       gkeconnect.googleapis.com
connectgateway.googleapis.com      cloudresourcemanager.googleapis.com
anthos.googleapis.com              monitoring.googleapis.com
logging.googleapis.com             gkehub.googleapis.com
opsconfigmonitoring.googleapis.com kubernetesmetadata.googleapis.com
```

Keep this list in sync between the two modules. If one adds an API, the other almost certainly needs it too.

## trusted_users Handling

Both modules compute the admin list as:

```hcl
data "google_client_openid_userinfo" "me" {}

locals {
  trusted_users = distinct(compact(concat(
    [data.google_client_openid_userinfo.me.email],
    var.trusted_users == null ? [] : var.trusted_users,
  )))
}
```

So the deploying user is always included — callers pass `trusted_users = []` safely. The `tags = { owner = local.trusted_users[0] }` local is used to tag Azure/AWS resources.

## Foreign-Cloud Credentials

Credentials are declared as `sensitive = true` variables in `SECTION 5: IAM`:

| AKS_GKE | EKS_GKE |
|---|---|
| `client_id`, `client_secret`, `tenant_id`, `subscription_id` | `aws_access_key`, `aws_secret_key` |

They are consumed directly in `provider "azurerm"` / `provider "aws"` in `provider.tf`. The RAD UI and `rad-launcher` must redact these from logs — they are already marked `sensitive` at the variable level.

## Optional: Service Mesh Installation

`modules/<Module>/modules/attached-install-mesh/` ships with both modules and wraps Google's `asmcli` installer. **It is intentionally not invoked from `main.tf`.** Installing Anthos Service Mesh adds time, complexity, and requires extra cluster access, so it is left as a manual follow-up step. When adding mesh support to a future module, mirror this "helper submodule, opt-in" shape rather than embedding the install in the main apply.

## Gotchas When Modifying These Modules

- **`google_container_attached_cluster` has no `project_number` attribute exposed before creation.** Always source it from `data.google_project.existing_project.number` in locals; never hard-code.
- **Helm provider `alias`**: the bootstrap helm provider must be passed into the nested submodule via `providers = { helm = helm.bootstrap_installer }`. Forgetting this causes the helm release to use the default (unconfigured) provider and fail silently.
- **Destroy order**: `depends_on = [aws_eks_node_group.node, aws_route...]` on `module.attached_install_manifest` is present for a reason — during `destroy`, the helm release must run before the VPC routes are torn down, or `helm uninstall` can't reach the cluster. Preserve these dependencies when refactoring.
- **Platform-version compatibility**: `k8s_version = "1.34"` pairs with `platform_version = "1.34.0-gke.1"`. Bumping the Kubernetes version requires a matching bump of the GKE platform version. Discover valid combinations with `gcloud alpha container attached get-server-config --location=<gcp_location>`.
- **`azurerm_role_assignment.aks_network_contributor`**: needed so AKS can manage its own load balancers. Don't remove it unless you are also changing the AKS networking mode.
- **Random suffix in EKS_GKE**: `random_string.suffix` is added to the cluster name prefix but the attached-cluster resource uses `var.cluster_name_prefix` directly. Be careful when changing one to not break the other.
