# AKS_GKE Module: Deep Dive Documentation

## 1. Executive Summary

The `modules/AKS_GKE` module is a production-grade Terraform solution that bridges Microsoft Azure and Google Cloud Platform, enabling platform engineers to manage an Azure Kubernetes Service (AKS) cluster directly from the Google Cloud console. It accomplishes this by registering the AKS cluster as a **GKE Attached Cluster** — a key capability of the **GKE Multi-Cloud / Anthos** product family — and enrolling it in a **GCP Fleet**.

The result is a unified multi-cloud control plane: engineers provision AKS clusters in Azure, but observe, authorize, log, and monitor them through Google Cloud's tooling (Cloud Console, Cloud Logging, Cloud Monitoring, Connect Gateway). An optional sub-module (`attached-install-mesh`) extends this by installing **Google Cloud Service Mesh (ASM)** on the attached cluster, bringing full Istio-compatible service mesh capabilities to workloads running in Azure.

**Key learning outcomes for platform engineers:**
- How GKE Attached Clusters enable centralized management of non-GKE Kubernetes clusters.
- How OIDC federation creates a secure, passwordless trust relationship between AKS and GCP.
- How GKE Fleet membership enables uniform observability across cloud boundaries.
- How `asmcli` automates the complex process of installing Anthos Service Mesh on attached clusters.

---

## 2. Module Structure

```
modules/AKS_GKE/
├── main.tf                              # Core infrastructure: AKS cluster + GKE attachment
├── provider.tf                          # Terraform provider configuration (azurerm, google, helm, random)
├── variables.tf                         # All input variables with UIMeta annotations
├── README.md                            # Quick-start guide
└── modules/
    ├── attached-install-manifest/       # Sub-module: installs GCP bootstrap manifests on AKS via Helm
    │   ├── main.tf
    │   ├── provider.tf
    │   ├── variables.tf
    │   └── README.md
    └── attached-install-mesh/           # Sub-module: installs Google Cloud Service Mesh (asmcli)
        ├── main.tf
        ├── outputs.tf
        ├── variables.tf
        ├── versions.tf
        ├── README.md
        └── scripts/
            └── check_components.sh      # Component verification and installation script
```

The module is composed of three distinct layers:

| Layer | Files | Responsibility |
|---|---|---|
| **Root module** | `main.tf`, `provider.tf`, `variables.tf` | AKS cluster provisioning + GKE Attached Cluster registration |
| **attached-install-manifest** | `modules/attached-install-manifest/` | Fetches and deploys GCP bootstrap manifests via Helm |
| **attached-install-mesh** | `modules/attached-install-mesh/` | Downloads tools and installs Anthos Service Mesh using `asmcli` |

---

## 3. Architecture Overview

The module implements a three-phase deployment sequence:

```
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1: Azure Infrastructure                                       │
│                                                                     │
│  ┌─────────────────────────┐      ┌──────────────────────────────┐  │
│  │  Azure Resource Group   │      │       AKS Cluster            │  │
│  │  (cluster_name_prefix   │◄─────│  - OIDC Issuer enabled       │  │
│  │   + "-rg")              │      │  - SystemAssigned Identity    │  │
│  │                         │      │  - Network Contributor RBAC   │  │
│  └─────────────────────────┘      └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │  OIDC Issuer URL + kubeconfig
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 2: GCP Attachment (attached-install-manifest)                 │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  google_container_attached_install_manifest (data source)    │  │
│  │  → Downloads platform-specific bootstrap manifests           │  │
│  │  → Wrapped in a local Helm chart                             │  │
│  │  → Applied to the AKS cluster via Helm                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  google_container_attached_cluster                           │  │
│  │  - distribution = "aks"                                      │  │
│  │  - OIDC trust configured with AKS issuer URL                 │  │
│  │  - Fleet membership                                          │  │
│  │  - Managed logging (SYSTEM_COMPONENTS + WORKLOADS)           │  │
│  │  - Managed Prometheus enabled                                │  │
│  │  - Admin user RBAC                                           │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │  (Optional)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 3: Service Mesh (attached-install-mesh)                       │
│                                                                     │
│  Download gcloud SDK + jq + asmcli → Verify kubectl → Auth GCP      │
│  → asmcli install --platform multicloud --option attached-cluster   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. GCP API Enablement

One of the first actions the module takes is enabling the set of GCP APIs required for cross-cloud cluster management. This is handled declaratively through the `google_project_service` resource, which iterates over a predefined list using `for_each`:

```hcl
locals {
  default_apis = [
    "gkemulticloud.googleapis.com",
    "gkeconnect.googleapis.com",
    "connectgateway.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "anthos.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "gkehub.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "kubernetesmetadata.googleapis.com"
  ]
}
```

**What each API enables and why it matters:**

| API | Purpose | Why Required |
|---|---|---|
| `gkemulticloud.googleapis.com` | Core multi-cloud cluster management | Enables `google_container_attached_cluster` resource |
| `gkeconnect.googleapis.com` | GKE Connect agent communication | Allows the Connect agent on AKS to phone home to GCP |
| `connectgateway.googleapis.com` | Connect Gateway for `kubectl` proxy | Lets engineers run `kubectl` against AKS from GCP |
| `cloudresourcemanager.googleapis.com` | GCP resource hierarchy API | Required by provider for project lookups |
| `anthos.googleapis.com` | Anthos platform umbrella | Activates Anthos entitlements on the project |
| `monitoring.googleapis.com` | Cloud Monitoring | Receives Managed Prometheus metrics from AKS |
| `logging.googleapis.com` | Cloud Logging | Receives log streams from AKS components and workloads |
| `gkehub.googleapis.com` | GKE Hub / Fleet management | Manages Fleet membership registrations |
| `opsconfigmonitoring.googleapis.com` | Operations config monitoring | Supports the Cloud Operations configuration for attached clusters |
| `kubernetesmetadata.googleapis.com` | Kubernetes metadata collection | Powers workload metadata visibility in Cloud Console |

**Important Terraform safety flags:**

```hcl
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.default_apis)
  disable_dependent_services = false
  disable_on_destroy         = false
}
```

Setting `disable_on_destroy = false` ensures that running `terraform destroy` does not inadvertently disable shared APIs that other modules in the same project may depend on. This is a deliberate safety choice for multi-module platform environments.

---

## 5. Identity & Access Management (IAM)

### 5.1 Terraform Provider Authentication

The module requires credentials for two cloud providers simultaneously, configured in `provider.tf`:

**Azure Provider** — authenticates using a Service Principal:
```hcl
provider "azurerm" {
  features {}
  tenant_id       = var.tenant_id       # Azure AD Tenant
  client_id       = var.client_id       # Service Principal App ID
  client_secret   = var.client_secret   # Service Principal Secret
  subscription_id = var.subscription_id # Target Azure subscription
}
```

All four Azure credential variables are declared `sensitive = true` in `variables.tf`, preventing their values from appearing in Terraform plan output, logs, or state diffs.

**Google Provider** — authenticates via Application Default Credentials (ADC), with the project pinned:
```hcl
provider "google" {
  project = var.existing_project_id
}
```

### 5.2 AKS Cluster Identity (SystemAssigned Managed Identity)

The AKS cluster is configured with a `SystemAssigned` managed identity:

```hcl
identity {
  type = "SystemAssigned"
}
```

This means Azure automatically creates and manages an Azure AD service principal scoped to the AKS cluster's lifecycle. When the cluster is deleted, the identity is deleted with it. This is the recommended approach for AKS clusters because it eliminates the need to manually rotate service principal credentials.

### 5.3 Network Contributor Role Assignment

The AKS cluster's managed identity is granted **Network Contributor** on the resource group:

```hcl
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
```

**Why this role is needed:** AKS needs to manage Azure Load Balancers, Public IPs, and Network Security Group rules on behalf of Kubernetes `Service` objects of type `LoadBalancer`. Without Network Contributor on the resource group, the AKS cloud controller manager cannot create or update Azure networking resources in response to Kubernetes API changes.

### 5.4 GCP Admin User Authorization

The module constructs a deduplicated list of trusted admin users from the current Terraform executor and any explicitly provided users:

```hcl
locals {
  trusted_users = distinct(compact(concat(
    [data.google_client_openid_userinfo.me.email],
    var.trusted_users == null ? [] : var.trusted_users
  )))
}
```

This list is applied to the attached cluster's authorization block:

```hcl
authorization {
  admin_users = local.trusted_users
}
```

This grants listed users **cluster-admin** RBAC access to the AKS cluster via GCP's Connect Gateway, without requiring direct AKS credentials or kubeconfig distribution. Platform engineers can run `kubectl` against an Azure cluster using only their GCP identity.

**Input validation** is enforced on `trusted_users` with two Terraform validation blocks:
1. No empty-string or whitespace-only email entries are allowed.
2. No duplicate email entries are allowed.

---

## 6. AKS Cluster Configuration

The AKS cluster is created with the `azurerm_kubernetes_cluster` resource. Understanding each configuration option is important for platform engineers who need to reason about what makes this cluster compatible with GKE Attached Clusters.

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name_prefix
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.cluster_name_prefix}-dns"
  kubernetes_version  = var.k8s_version

  oidc_issuer_enabled = true   # Critical for GKE Attached Clusters

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    tags       = local.tags
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}
```

### 6.1 Configurable Parameters

| Variable | Default | Description |
|---|---|---|
| `cluster_name_prefix` | `azure-aks-cluster` | Prefix used for the cluster name, resource group, and DNS prefix |
| `k8s_version` | `1.34` | Kubernetes minor version for the AKS cluster |
| `platform_version` | `1.34.0-gke.1` | GKE Attached Clusters platform version — must align with `k8s_version` |
| `node_count` | `3` | Number of nodes in the default node pool |
| `vm_size` | `Standard_D2s_v3` | Azure VM SKU for worker nodes |
| `azure_region` | `westus2` | Azure region where the cluster is provisioned |
| `gcp_location` | `us-central1` | GCP region where the attached cluster resource is registered |

### 6.2 OIDC Issuer — The Foundation of Cross-Cloud Trust

The single most important configuration flag for the GKE Attached Clusters integration is:

```hcl
oidc_issuer_enabled = true
```

When enabled, AKS exposes a public **OpenID Connect (OIDC) Discovery Endpoint** at a stable URL. This endpoint publishes the cluster's JSON Web Key Set (JWKS) — the cryptographic public keys used to sign Kubernetes service account tokens.

GCP reads this JWKS and uses it to verify that tokens presented by workloads or the Connect agent genuinely originated from the AKS cluster. This creates a **zero-secret trust relationship**: GCP never needs a credential or certificate from Azure; it simply validates cryptographic signatures against publicly available keys.

The OIDC issuer URL is automatically captured and passed to the attached cluster:
```hcl
oidc_config {
  issuer_url = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}
```

**What happens without OIDC issuer enabled:** If `oidc_issuer_enabled` were `false`, the cluster's JWKS would not be publicly accessible. In this case, engineers would need to manually retrieve the JWKS using `kubectl get --raw /openid/v1/jwks`, base64-encode it, and supply it directly in the `oidc_config.jwks` field — a brittle, manual process that breaks whenever keys rotate.

---

## 7. GKE Attached Clusters: Deep Dive

GKE Attached Clusters is the core GKE feature this module demonstrates. It is defined by the `google_container_attached_cluster` resource.

```hcl
resource "google_container_attached_cluster" "primary" {
  name             = var.cluster_name_prefix
  project          = local.project_id
  location         = var.gcp_location
  description      = "AKS attached cluster example"
  distribution     = "aks"
  platform_version = var.platform_version

  oidc_config {
    issuer_url = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  }

  fleet {
    project = "projects/${local.project_number}"
  }

  logging_config {
    component_config {
      enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    }
  }

  monitoring_config {
    managed_prometheus_config {
      enabled = true
    }
  }

  authorization {
    admin_users = local.trusted_users
  }
}
```

### 7.1 The `distribution` Field

```hcl
distribution = "aks"
```

This field tells GCP which Kubernetes distribution the cluster is running. GKE Multi-Cloud uses this to:
- Select the correct bootstrap manifests for the Connect agent.
- Apply distribution-specific compatibility logic (e.g., AKS-specific networking assumptions).
- Display the correct cluster type icon and metadata in the Cloud Console.

Other valid values in the broader GKE Attached Clusters ecosystem include `eks` (for AWS EKS), `generic` (for any CNCF-conformant cluster), and others. The `EKS_GKE` sibling module in this repository uses `eks`.

### 7.2 Platform Version Alignment

```hcl
platform_version = var.platform_version   # e.g., "1.34.0-gke.1"
```

The platform version is the GKE Attached Clusters agent version, not the AKS Kubernetes version. It must be compatible with the Kubernetes minor version. For example:
- AKS `k8s_version = "1.34"` pairs with `platform_version = "1.34.0-gke.1"`.

To find valid platform versions for a given GCP location:
```bash
gcloud alpha container attached get-server-config --location=us-central1
```

Mismatching these versions is a common source of deployment failures — the module's variable descriptions call this out explicitly.

### 7.3 Dependency Chain

The `google_container_attached_cluster` resource declares explicit dependencies:

```hcl
depends_on = [
  module.attached_install_manifest,
  google_project_service.enabled_services,
]
```

This ordering is semantically critical:
1. **APIs must be enabled first** — the `google_container_attached_cluster` API call itself requires `gkemulticloud.googleapis.com`.
2. **Bootstrap manifests must be installed first** — GCP validates that the Connect agent is running and reachable on the cluster before it will accept the cluster registration. If the agent isn't running, the `terraform apply` will fail with a timeout.

---

## 8. GKE Fleet Management

### 8.1 What is a Fleet?

A **GKE Fleet** (formerly called "Environ") is a logical grouping of Kubernetes clusters — across GKE, GKE Attached, GKE on AWS, GKE on Azure, and even GKE on-prem — that share a common management boundary. A fleet is identified by a GCP project.

```hcl
fleet {
  project = "projects/${local.project_number}"
}
```

Note the use of `local.project_number` (numeric) rather than `local.project_id` (string). The Fleet API requires the numeric project identifier in the `projects/{number}` format.

### 8.2 Fleet Benefits for Platform Engineers

Once enrolled in a fleet, the AKS cluster gains access to fleet-level features:

| Fleet Feature | What it Enables |
|---|---|
| **Connect Gateway** | Run `kubectl` against the AKS cluster using GCP identity, no direct AKS credential needed |
| **Unified Console View** | AKS cluster appears alongside GKE clusters in the Kubernetes Engine console page |
| **Fleet Workload Identity** | Kubernetes service accounts on AKS can be federated with GCP service accounts |
| **Config Management** | Apply Anthos Config Management (ACM) policies uniformly across the fleet |
| **Policy Controller** | Enforce OPA Gatekeeper policies fleet-wide |
| **Service Mesh** | Install and manage Anthos Service Mesh across fleet clusters (via `attached-install-mesh` sub-module) |

### 8.3 Accessing the Cluster via Connect Gateway

After the module deploys successfully, admin users can connect to the AKS cluster without any Azure credentials:

```bash
# Retrieve cluster credentials via Connect Gateway
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project

# Use kubectl normally — traffic flows through GCP's Connect Gateway to Azure
kubectl get nodes
kubectl get pods --all-namespaces
```

This works because the GKE Connect agent (installed via the bootstrap manifests) maintains a persistent outbound connection from AKS to GCP. `kubectl` commands travel through this tunnel, eliminating the need to expose the AKS API server publicly or manage kubeconfig distribution.

---

## 9. Observability: Managed Logging

### 9.1 Logging Configuration

```hcl
logging_config {
  component_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
}
```

This configuration instructs the GKE logging agent installed on AKS to forward two categories of logs to **Google Cloud Logging**:

| Component | What is Logged |
|---|---|
| `SYSTEM_COMPONENTS` | Logs from core Kubernetes system pods: `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, `etcd`, `kubelet`, CNI plugins, and other control plane/node components |
| `WORKLOADS` | Logs from all user workload pods (stdout/stderr from every container in user namespaces) |

### 9.2 Why Cloud Logging for AKS Logs?

Platform engineers working in multi-cloud environments face a fragmentation problem: AKS logs natively go to Azure Monitor / Log Analytics, while GKE logs go to Cloud Logging. Teams using both clouds must learn, license, and query two separate observability systems.

By routing AKS logs to Cloud Logging via GKE Attached Clusters:
- **Single pane of glass**: All cluster logs — GKE and AKS — appear in one Cloud Logging project.
- **Unified query language**: Engineers use Log Query Language (LQL) and BigQuery for all cluster logs.
- **Consistent alerting**: Cloud Monitoring alerting policies work identically for GKE and AKS log-based metrics.
- **Log-based metrics**: Custom metrics derived from log patterns can be created in Cloud Monitoring.

### 9.3 Log Exploration

After deployment, logs are accessible in Cloud Logging with standard Kubernetes resource labels:

```bash
# View AKS system component logs
gcloud logging read \
  'resource.type="k8s_cluster" AND resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project \
  --format=json

# View pod logs for a specific workload
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.cluster_name="azure-aks-cluster" AND resource.labels.namespace_name="default"' \
  --project=my-gcp-project
```

---

## 10. Observability: Managed Prometheus

### 10.1 Monitoring Configuration

```hcl
monitoring_config {
  managed_prometheus_config {
    enabled = true
  }
}
```

This enables **Google Cloud Managed Service for Prometheus (GMP)** on the attached AKS cluster. GMP is a fully managed, Prometheus-compatible monitoring backend that scales without any infrastructure management.

### 10.2 How Managed Prometheus Works on Attached Clusters

When `managed_prometheus_config.enabled = true`, the GKE bootstrap process installs a **PodMonitoring** controller and a **Prometheus collector** DaemonSet on the AKS cluster nodes. These agents:

1. **Scrape** Prometheus metrics from pods that expose `/metrics` endpoints (configured via `PodMonitoring` CRDs).
2. **Forward** scraped metrics to Google Cloud Monitoring's Prometheus-compatible storage backend.
3. **Retain** full PromQL compatibility — platform engineers query metrics using standard PromQL against Cloud Monitoring's Prometheus endpoint.

### 10.3 Monitoring Capabilities

| Capability | Details |
|---|---|
| **Metric Retention** | Up to 24 months (vs. Prometheus default of 15 days) |
| **Query Interface** | PromQL via Cloud Monitoring's Prometheus endpoint or Grafana data source |
| **Built-in Dashboards** | Pre-built dashboards for Kubernetes node/pod/workload metrics in Cloud Console |
| **Alerting** | Cloud Monitoring alerting policies using PromQL expressions |
| **No Thanos/Cortex** | No need to self-manage long-term storage infrastructure |

### 10.4 Cross-Cloud Unified Monitoring

Similar to logging, this gives platform engineers a single metrics backend for both GKE and AKS clusters. A Grafana dashboard that queries Cloud Monitoring can show metrics from GKE clusters and AKS clusters side by side, with identical PromQL queries, enabling meaningful cross-cloud performance comparisons.

---

## 11. Bootstrap Manifest Installation (`attached-install-manifest`)

This sub-module is the bridge between Azure and GCP. It installs the GKE Connect agent and supporting controllers onto the AKS cluster so that GCP can communicate with it.

### 11.1 How It Works

The process involves four steps orchestrated entirely in Terraform:

**Step 1: Fetch the bootstrap manifest from GCP**

```hcl
data "google_container_attached_install_manifest" "bootstrap" {
  location         = var.gcp_location
  project          = var.attached_cluster_fleet_project
  cluster_id       = var.attached_cluster_name
  platform_version = var.platform_version
}
```

This data source makes an API call to `gkemulticloud.googleapis.com` and retrieves a YAML manifest tailored to the specific cluster ID, GCP location, and platform version. The manifest contains Kubernetes resources such as:
- The **GKE Connect agent** Deployment (establishes the outbound tunnel to GCP).
- Necessary **RBAC** resources (ClusterRoles, ClusterRoleBindings) for the agent.
- A **Namespace** (`gke-connect`) for isolation.
- **ConfigMaps** with cluster identity and endpoint information.

**Step 2: Wrap the manifest in a local Helm chart**

```hcl
resource "local_file" "bootstrap_helm_chart" {
  filename = "${local.helm_chart_dir}/Chart.yaml"
  content  = <<-EOT
    apiVersion: v2
    name: attached-bootstrap
    version: 0.0.1
    appVersion: "${var.platform_version}"
    type: application
    EOT
}

resource "local_file" "bootstrap_manifests" {
  filename = "${local.helm_chart_dir}/templates/bootstrap.yaml"
  content  = data.google_container_attached_install_manifest.bootstrap.manifest
}
```

The manifest is written into a minimal Helm chart structure in a temporary directory (default: `.tmp/{gcp_location}-{platform_version}/bootstrap_helm_chart/`). Wrapping it in Helm enables idempotent installation: Helm tracks the release state and can upgrade or roll back the bootstrap components cleanly.

The chart directory layout:
```
.tmp/us-central1-1.34.0-gke.1/bootstrap_helm_chart/
├── Chart.yaml           ← Helm chart metadata
└── templates/
    └── bootstrap.yaml   ← The raw GCP-generated manifest
```

**Step 3: Apply via Helm**

```hcl
resource "helm_release" "local" {
  name    = "attached-bootstrap"
  chart   = local.helm_chart_dir
  timeout = var.helm_timeout
  depends_on = [local_file.bootstrap_helm_chart, local_file.bootstrap_manifests]
}
```

The Helm provider is pre-configured with the AKS cluster's credentials (from `kube_config`) in the root module:

```hcl
provider "helm" {
  alias = "bootstrap_installer"
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    username               = azurerm_kubernetes_cluster.aks.kube_config[0].username
    password               = azurerm_kubernetes_cluster.aks.kube_config[0].password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}
```

This is a sophisticated Terraform pattern: the Helm provider is instantiated dynamically with runtime values from the AKS cluster resource, and passed into the sub-module using provider aliasing:

```hcl
module "attached_install_manifest" {
  source = "./modules/attached-install-manifest"
  providers = {
    helm = helm.bootstrap_installer
  }
}
```

### 11.2 Why Helm Instead of `kubectl apply`?

Using Helm for the bootstrap provides several advantages:

| Concern | `kubectl apply` | Helm Release |
|---|---|---|
| **Idempotency** | Re-apply can fail on immutable fields | Helm diff-applies changes cleanly |
| **State tracking** | No native state — resources can drift | Helm tracks release state in a Kubernetes Secret |
| **Rollback** | Manual | `helm rollback attached-bootstrap 1` |
| **Upgrade** | Must diff and apply manually | `helm upgrade` handles resource diffs |
| **Terraform integration** | Requires `null_resource` + `local-exec` | Native `helm_release` resource |

### 11.3 Sub-module Variables

| Variable | Default | Description |
|---|---|---|
| `gcp_location` | required | GCP region for the attached resource |
| `platform_version` | required | Platform version string (e.g., `1.34.0-gke.1`) |
| `attached_cluster_fleet_project` | required | GCP project ID for the fleet |
| `attached_cluster_name` | required | Cluster resource name |
| `temp_dir` | `.tmp` | Temporary directory for the generated Helm chart |
| `helm_timeout` | `null` | Optional Helm operation timeout in seconds |

---

## 12. Service Mesh Installation (`attached-install-mesh`)

The `attached-install-mesh` sub-module installs **Google Cloud Service Mesh (ASM)** onto the AKS cluster using `asmcli` — Google's official ASM installation CLI. This is an optional but powerful extension that brings Istio-compatible service mesh capabilities to workloads running in Azure.

### 12.1 Tool Download and Bootstrapping

The sub-module downloads all required tools at apply time, making it self-contained and environment-agnostic:

```
null_resource.prepare_cache      → Creates .cache/{random_id}/ directory
        │
        ├── null_resource.download_gcloud  → curl gcloud SDK tar.gz (~500MB)
        ├── null_resource.download_jq      → curl jq binary
        └── null_resource.download_asmcli  → curl asmcli binary
                │
                └── null_resource.decompress → extract gcloud SDK, copy jq + asmcli into gcloud/bin/
                        │
                        └── null_resource.additional_components → verify kubectl via check_components.sh
```

**Download URLs (configurable via variables):**

| Tool | Default Source | Version Variable |
|---|---|---|
| gcloud SDK | `dl.google.com/dl/cloudsdk/channels/rapid/downloads/` | `gcloud_sdk_version` (default: `491.0.0`) |
| jq | `github.com/stedolan/jq/releases/download/` | `jq_version` (default: `1.6`) |
| asmcli | `storage.googleapis.com/csm-artifacts/asm/` | `asmcli_version` (default: `1.22`) |

All three download URLs can be overridden with custom URLs (`gcloud_download_url`, `jq_download_url`, `asmcli_download_url`), enabling use in air-gapped environments where internet access is restricted.

### 12.2 Component Verification (`check_components.sh`)

Before running `asmcli`, the module verifies that required tools are available using `scripts/check_components.sh`. This script implements a three-tier component resolution strategy:

```bash
# Tier 1: Check gcloud component manager
gcloud components list --quiet \
  --filter='state.name!="Not Installed"' \
  --format="csv[no-heading,terminator=','](id)"
# → If found: "Found kubectl via gcloud component manager"

# Tier 2: Check system PATH
command -v kubectl
# → If found: "Found kubectl via /usr/local/bin/kubectl"

# Tier 3: Install missing components
gcloud components install kubectl --quiet
# → Installs only what's actually missing
```

This design is important for CI/CD environments and Terraform Cloud runners where:
- The gcloud SDK is already installed system-wide (Tier 2 catches it).
- Some components are managed by the gcloud component manager (Tier 1 catches them).
- Missing components are auto-installed without failing (Tier 3 fills gaps).

### 12.3 Authentication Strategies

The sub-module supports two mutually exclusive authentication methods for GCP access during `asmcli` execution:

**Method A: Service Account Key File**
```hcl
service_account_key_file = "/path/to/service-account.json"
```
Triggers:
```bash
gcloud auth activate-service-account --key-file /path/to/service-account.json
```

**Method B: `GOOGLE_CREDENTIALS` Environment Variable** (recommended for CI/CD)
```hcl
use_tf_google_credentials_env_var = true
```
Triggers:
```bash
printf "%s" "$GOOGLE_CREDENTIALS" > ./terraform-google-credentials.json
gcloud auth activate-service-account --key-file ./terraform-google-credentials.json
```
This method reads GCP credentials from the `GOOGLE_CREDENTIALS` environment variable (which Terraform Cloud and many CI systems set automatically), writes them to a temp file, and activates the service account. Setting `activate_service_account = false` skips this step entirely when ADC is already configured.

### 12.4 The `asmcli install` Command

The final installation command is constructed dynamically from variables and executed as a `local-exec` provisioner:

```bash
PATH=/path/to/.cache/{id}/google-cloud-sdk/bin:$PATH
asmcli install \
  --kubeconfig /path/to/kubeconfig \
  --context my-cluster-context \
  --fleet_id my-gcp-project \
  --platform multicloud \
  --option attached-cluster \
  --ca mesh_ca \
  [--enable_cluster_roles] \
  [--enable_cluster_labels] \
  [--enable_gcp_components] \
  [--enable_gcp_apis] \
  [--enable_gcp_iam_roles] \
  [--enable_meshconfig_init] \
  [--enable_namespace_creation] \
  [--enable_registration] \
  [--verbose]
```

### 12.5 asmcli Feature Flags Explained

| Flag Variable | asmcli Flag | What it Does |
|---|---|---|
| `asmcli_enable_all` | `--enable_all` | Enables all feature flags at once (shorthand for development) |
| `asmcli_enable_cluster_roles` | `--enable_cluster_roles` | Creates ClusterRoles required by ASM components |
| `asmcli_enable_cluster_labels` | `--enable_cluster_labels` | Adds required topology labels to cluster nodes |
| `asmcli_enable_gcp_components` | `--enable_gcp_components` | Installs GCP-specific mesh components (e.g., Stackdriver telemetry) |
| `asmcli_enable_gcp_apis` | `--enable_gcp_apis` | Enables required GCP APIs (e.g., `meshtelemetry.googleapis.com`) |
| `asmcli_enable_gcp_iam_roles` | `--enable_gcp_iam_roles` | Grants required IAM roles to the mesh service account |
| `asmcli_enable_meshconfig_init` | `--enable_meshconfig_init` | Initializes the MeshConfig resource with default settings |
| `asmcli_enable_namespace_creation` | `--enable_namespace_creation` | Creates the `istio-system` namespace if it doesn't exist |
| `asmcli_enable_registration` | `--enable_registration` | Registers the cluster with the fleet (redundant if already done by root module) |
| `asmcli_verbose` | `--verbose` | Enables verbose asmcli output for debugging |

### 12.6 Certificate Authority Options

```hcl
variable "asmcli_ca" {
  default = "mesh_ca"
  validation {
    condition = contains(["mesh_ca", "gcp_cas", "citadel"], var.asmcli_ca)
  }
}
```

| CA Option | Description | Best For |
|---|---|---|
| `mesh_ca` | Google-managed CA built into ASM; no infrastructure required | Most deployments; managed, rotated automatically by Google |
| `gcp_cas` | Google Certificate Authority Service; enterprise-grade, auditable | Regulated industries requiring CA audit trails and custom root CAs |
| `citadel` | Istio's built-in CA (deprecated, now called Istiod CA) | Legacy Istio migrations or environments with existing Citadel infrastructure |

### 12.7 Destruction Lifecycle

The sub-module includes destroy-time provisioners that re-run authentication, component verification, and decompression steps during `terraform destroy`. This ensures the environment is correctly authenticated when cleanup operations are needed:

```hcl
resource "null_resource" "gcloud_auth_google_credentials_destroy" {
  provisioner "local-exec" {
    when    = destroy
    command = self.triggers.gcloud_auth_google_credentials_command
  }
}
```

The `wait` output aggregates all resource trigger lengths, providing a numeric dependency handle that other modules can reference to ensure the mesh installation has fully completed before proceeding.

---

## 13. Provider Configuration

The module requires four Terraform providers, declared in `provider.tf`:

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">=3.17.0" }
    google  = { source = "hashicorp/google",  version = ">=5.0.0"  }
    helm    = { source = "hashicorp/helm",     version = "~> 2.0"   }
    random  = { source = "hashicorp/random",   version = "3.6.2"    }
  }
  required_version = ">= 0.13"
}
```

| Provider | Version | Purpose |
|---|---|---|
| `hashicorp/azurerm` | `>=3.17.0` | Manages Azure Resource Group, AKS cluster, and RBAC assignments |
| `hashicorp/google` | `>=5.0.0` | Manages GCP APIs, attached cluster resource, and data sources |
| `hashicorp/helm` | `~> 2.0` | Applies the bootstrap manifest Helm chart to AKS |
| `hashicorp/random` | `3.6.2` | Generates a fallback deployment ID when none is provided |

The `random` provider is pinned to an exact version (`3.6.2`) for reproducibility — avoiding unexpected ID changes across Terraform upgrades that could cause resource recreation.

### 13.1 Dynamic Deployment ID

The module uses a random ID with a safety fallback pattern:

```hcl
resource "random_id" "default" {
  byte_length = 2   # Produces a 4-character hex string, e.g., "a3f2"
}

locals {
  random_id = var.deployment_id != null ? var.deployment_id : random_id.default.hex
}
```

If `deployment_id` is provided (e.g., from the RAD platform), it is used directly — ensuring consistent naming across re-deployments. If not provided, a random hex ID is generated, preventing naming collisions in shared projects.

---

## 14. Complete Variables Reference

### 14.1 Root Module Variables

**Group 0: Module Metadata**

| Variable | Type | Default | Description |
|---|---|---|---|
| `module_description` | `string` | *(see variables.tf)* | UI display description |
| `module_dependency` | `list(string)` | `["Azure Account", "GCP Project"]` | Prerequisite modules |
| `module_services` | `list(string)` | `["Azure", "AKS", "Resource Group", "GCP", "GKE Hub", "Anthos"]` | Platform service tags |
| `credit_cost` | `number` | `100` | Deployment cost in platform credits |
| `require_credit_purchases` | `bool` | `false` | Whether credits must be purchased first |
| `enable_purge` | `bool` | `true` | Whether module can be force-deleted |
| `public_access` | `bool` | `true` | Whether module is visible to all platform users |
| `deployment_id` | `string` | `null` | Custom ID suffix; auto-generated if omitted |
| `resource_creator_identity` | `string` | *(platform SA)* | Service account used to create resources |

**Group 2: Project & Location**

| Variable | Type | Default | Required |
|---|---|---|---|
| `existing_project_id` | `string` | — | **yes** |
| `gcp_location` | `string` | `us-central1` | no |
| `azure_region` | `string` | `westus2` | no |

**Group 3: Cluster Configuration**

| Variable | Type | Default | Required |
|---|---|---|---|
| `cluster_name_prefix` | `string` | `azure-aks-cluster` | no |
| `k8s_version` | `string` | `1.34` | no |
| `platform_version` | `string` | `1.34.0-gke.1` | no |
| `node_count` | `number` | `3` | no |
| `vm_size` | `string` | `Standard_D2s_v3` | no |

**Group 4: IAM (all `sensitive = true`)**

| Variable | Type | Default | Required |
|---|---|---|---|
| `client_id` | `string` | — | **yes** |
| `client_secret` | `string` | — | **yes** |
| `tenant_id` | `string` | — | **yes** |
| `subscription_id` | `string` | — | **yes** |

**Group 1: Access Control**

| Variable | Type | Default | Validation |
|---|---|---|---|
| `trusted_users` | `list(string)` | `[]` | No empty strings, no duplicates |

### 14.2 `attached-install-manifest` Variables

| Variable | Type | Default | Required |
|---|---|---|---|
| `gcp_location` | `string` | — | **yes** |
| `platform_version` | `string` | — | **yes** |
| `attached_cluster_fleet_project` | `string` | — | **yes** |
| `attached_cluster_name` | `string` | — | **yes** |
| `temp_dir` | `string` | `""` (→ `.tmp`) | no |
| `helm_timeout` | `number` | `null` | no |

### 14.3 `attached-install-mesh` Variables

| Variable | Type | Default | Required |
|---|---|---|---|
| `kubeconfig` | `string` | — | **yes** |
| `context` | `string` | — | **yes** |
| `fleet_id` | `string` | — | **yes** |
| `platform` | `string` | `linux` | no |
| `activate_service_account` | `bool` | `true` | no |
| `service_account_key_file` | `string` | `""` | no |
| `use_tf_google_credentials_env_var` | `bool` | `false` | no |
| `gcloud_sdk_version` | `string` | `491.0.0` | no |
| `gcloud_download_url` | `string` | `null` | no |
| `jq_version` | `string` | `1.6` | no |
| `jq_download_url` | `string` | `null` | no |
| `asmcli_version` | `string` | `1.22` | no |
| `asmcli_download_url` | `string` | `null` | no |
| `asmcli_ca` | `string` | `mesh_ca` | no |
| `asmcli_enable_all` | `bool` | `false` | no |
| `asmcli_enable_cluster_roles` | `bool` | `false` | no |
| `asmcli_enable_cluster_labels` | `bool` | `false` | no |
| `asmcli_enable_gcp_components` | `bool` | `false` | no |
| `asmcli_enable_gcp_apis` | `bool` | `false` | no |
| `asmcli_enable_gcp_iam_roles` | `bool` | `false` | no |
| `asmcli_enable_meshconfig_init` | `bool` | `false` | no |
| `asmcli_enable_namespace_creation` | `bool` | `false` | no |
| `asmcli_enable_registration` | `bool` | `false` | no |
| `asmcli_verbose` | `bool` | `false` | no |
| `asmcli_additional_arguments` | `string` | `null` | no |

---

## 15. Deployment Workflow

### 15.1 Prerequisites

1. **Google Cloud SDK** (`gcloud`) installed and authenticated:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_GCP_PROJECT_ID
   ```

2. **Azure CLI** (`az`) installed and logged in:
   ```bash
   az login
   ```

3. **Terraform** >= 0.13 installed.

4. **Azure Service Principal** with Contributor or Owner role on the target subscription. Set environment variables:
   ```bash
   export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
   export ARM_CLIENT_SECRET="12345678-0000-0000-0000-000000000000"
   export ARM_TENANT_ID="10000000-0000-0000-0000-000000000000"
   export ARM_SUBSCRIPTION_ID="20000000-0000-0000-0000-000000000000"
   ```

5. **Enable the GKE Multi-Cloud API** on your GCP project:
   ```bash
   gcloud services enable gkemulticloud.googleapis.com --project=YOUR_GCP_PROJECT_ID
   ```

### 15.2 Deployment Steps

```bash
# 1. Navigate to the module directory
cd modules/AKS_GKE

# 2. Initialize Terraform (downloads providers)
terraform init

# 3. Review the execution plan
terraform plan -var="existing_project_id=my-gcp-project" \
               -var="client_id=$ARM_CLIENT_ID" \
               -var="client_secret=$ARM_CLIENT_SECRET" \
               -var="tenant_id=$ARM_TENANT_ID" \
               -var="subscription_id=$ARM_SUBSCRIPTION_ID"

# 4. Apply — takes approximately 10-15 minutes
terraform apply

# 5. After apply: connect to the AKS cluster via GCP
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project

# 6. Verify cluster access
kubectl get nodes
kubectl get pods --all-namespaces
```

### 15.3 Expected Timeline

| Phase | Duration | What Happens |
|---|---|---|
| API enablement | ~1 min | 10 GCP APIs enabled in parallel |
| Azure resource group creation | ~30 sec | Resource group created in Azure |
| AKS cluster provisioning | ~5-8 min | Control plane and node pool brought up in Azure |
| RBAC assignment | ~30 sec | Network Contributor role assigned |
| Bootstrap manifest installation | ~2-3 min | Helm deploys Connect agent to AKS |
| GKE attached cluster registration | ~1-2 min | GCP validates agent, registers cluster |
| **Total** | **~10-15 min** | |

### 15.4 Verifying the Deployment

```bash
# Confirm the cluster appears in GCP fleet
gcloud container fleet memberships list --project=my-gcp-project

# Confirm attached cluster details
gcloud container attached clusters describe azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project

# Check Connect agent pod is running on AKS
kubectl get pods -n gke-connect

# View AKS logs in Cloud Logging
gcloud logging read \
  'resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project --limit=20

# Check metrics are flowing
gcloud monitoring metrics list \
  --filter='metric.type=starts_with("kubernetes.io")' \
  --project=my-gcp-project
```

### 15.5 Teardown

```bash
terraform destroy
```

This will:
1. Deregister the AKS cluster from GCP fleet.
2. Uninstall the Helm release (Connect agent) from AKS.
3. Delete the AKS cluster and all Azure resources.

**Note:** APIs enabled by the module are **not** disabled on destroy (`disable_on_destroy = false`), ensuring other modules sharing the same GCP project are not affected.

---

## 16. Advanced GKE Concepts for Platform Engineers

### 16.1 Understanding the Connect Agent Architecture

The GKE Connect agent is a lightweight Deployment running in the `gke-connect` namespace on the AKS cluster. Its key architectural characteristics:

- **Outbound-only connection**: The agent initiates a persistent connection from AKS to `gkeconnect.googleapis.com`. No inbound firewall rules are needed on Azure.
- **Long-lived gRPC stream**: Commands from GCP (including `kubectl` via Connect Gateway) are multiplexed over this stream.
- **Automatic reconnection**: The agent handles network interruptions and reconnects with exponential backoff.
- **No direct API server exposure**: The AKS API server never needs to be publicly accessible. All GCP-to-AKS communication goes through the Connect agent tunnel.

This is fundamentally different from other multi-cloud approaches that require VPN tunnels, VPC peering, or public API server endpoints.

### 16.2 OIDC Federation In Depth

The trust chain between AKS and GCP works as follows:

```
AKS Cluster
  │ Signs service account tokens with cluster private key
  │ Publishes public key at: https://{oidc_issuer_url}/.well-known/jwks.json
  │
  ▼
GCP GKE Multi-Cloud Service
  │ Reads JWKS from AKS OIDC endpoint (at attachment time)
  │ Stores JWKS in GCP's trust store for this attached cluster
  │
  ▼
Token Validation
  │ When the Connect agent presents a Kubernetes service account token to GCP
  │ GCP validates the JWT signature using the stored JWKS
  │ If valid, GCP grants the agent its fleet-level permissions
```

Key insight: GCP does not need to contact AKS at token validation time. Once the JWKS is fetched during registration, GCP validates tokens offline using the stored public keys. This makes the authentication path resilient to temporary AKS API server unavailability.

### 16.3 Multi-Cloud Identity Federation for Workloads

Once the AKS cluster is fleet-enrolled with OIDC, individual workloads can federate their Kubernetes service account identities with GCP service accounts. This is the Kubernetes equivalent of Workload Identity on GKE:

```yaml
# Annotate a Kubernetes service account on AKS
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: my-sa@my-gcp-project.iam.gserviceaccount.com
```

```bash
# Bind the GCP service account to the Kubernetes service account
gcloud iam service-accounts add-iam-policy-binding \
  my-sa@my-gcp-project.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/default/sa/my-app"
```

With this configuration, pods running on AKS using the `my-app` service account can call GCP APIs (Cloud Storage, Pub/Sub, BigQuery, etc.) without any service account key files — using the same OIDC token exchange mechanism.

### 16.4 Anthos Service Mesh on Attached Clusters

Installing ASM on an attached AKS cluster (via the `attached-install-mesh` sub-module) enables:

- **mTLS between all services** — all east-west traffic is encrypted at the Envoy sidecar layer.
- **Traffic management** — VirtualService, DestinationRule, and Gateway resources for fine-grained routing, retries, and circuit breaking.
- **Observability** — Automatic generation of distributed traces (Stackdriver Trace), metrics (Stackdriver Monitoring), and access logs for all service-to-service calls without application code changes.
- **Security policies** — AuthorizationPolicy resources for zero-trust access control between services.

The `--option attached-cluster` flag passed to `asmcli` activates the specific installation profile optimized for non-GKE clusters, which adjusts component configurations to work correctly on AKS's networking model.

---

## 17. Feature Summary

| Feature | Implementation | GKE Capability Demonstrated |
|---|---|---|
| **AKS cluster provisioning** | `azurerm_kubernetes_cluster` | Foundation for cross-cloud management |
| **SystemAssigned Managed Identity** | `identity { type = "SystemAssigned" }` | Cloud-native identity without credential management |
| **OIDC Issuer** | `oidc_issuer_enabled = true` | Cryptographic trust for cross-cloud token validation |
| **Network Contributor RBAC** | `azurerm_role_assignment` | Azure RBAC for AKS cloud controller manager |
| **GCP API Enablement** | `google_project_service` (10 APIs) | Declarative API lifecycle management |
| **Bootstrap Manifest Fetch** | `google_container_attached_install_manifest` | Platform-specific agent distribution |
| **Helm-based Agent Install** | `helm_release` with dynamic provider | Idempotent Kubernetes resource management |
| **GKE Attached Cluster** | `google_container_attached_cluster` | Non-GKE cluster management from GCP console |
| **Fleet Enrollment** | `fleet { project = ... }` | Unified multi-cluster management boundary |
| **Connect Gateway** | Enabled via fleet membership | Zero-credential `kubectl` access via GCP identity |
| **Admin User Authorization** | `authorization { admin_users = ... }` | GCP identity-based cluster-admin RBAC |
| **Managed Logging** | `SYSTEM_COMPONENTS` + `WORKLOADS` | Centralized log routing to Cloud Logging |
| **Managed Prometheus** | `managed_prometheus_config.enabled` | Scalable metrics without self-managed Prometheus infra |
| **Service Mesh (optional)** | `asmcli install --platform multicloud` | Istio-compatible mesh on non-GKE clusters |
| **Multi-CA Support** | `mesh_ca` / `gcp_cas` / `citadel` | Flexible certificate authority strategy |
| **Air-gap support** | Custom download URL overrides | Secure environments without internet access |
| **Destroy lifecycle** | Destroy-time provisioners | Clean teardown of agent and mesh components |

---

## 18. Potential Enhancements

### 18.1 Security Hardening

1. **Private AKS Cluster**: The current configuration does not use a private AKS cluster (one where the API server has no public endpoint). For production, consider adding:
   ```hcl
   private_cluster_config {
     enable_private_endpoint = true
     enable_private_nodes    = true
   }
   ```
   The Connect agent's outbound architecture means a private API server is fully compatible with GKE Attached Clusters.

2. **Azure Key Vault for Secrets**: The Azure client secret is currently passed as a Terraform variable. In production, secrets should be retrieved from Azure Key Vault using a data source rather than stored in `terraform.tfvars` or environment variables.

3. **Customer-Managed Encryption Keys (CMEK)**: Add Azure Disk Encryption with a customer-managed key for the node pool OS disks. Similarly, enable CMEK for Cloud Logging and Cloud Monitoring data retention.

4. **Network Policy on AKS**: Enable Azure Network Policy (or Calico) on the AKS cluster to enforce pod-level network segmentation — a complement to ASM's application-level mTLS.

### 18.2 Reliability & High Availability

1. **Node Pool Autoscaling**: The current configuration uses a fixed `node_count`. Add Azure Cluster Autoscaler:
   ```hcl
   default_node_pool {
     enable_auto_scaling = true
     min_count           = 1
     max_count           = 10
   }
   ```

2. **Multi-Availability Zone Node Pools**: Configure nodes to be distributed across Azure Availability Zones for node-level HA:
   ```hcl
   default_node_pool {
     zones = ["1", "2", "3"]
   }
   ```

3. **Cluster Upgrade Management**: The module pins `kubernetes_version` but does not define an upgrade channel. Adding `automatic_channel_upgrade = "stable"` enables AKS managed upgrades.

### 18.3 Observability Extensions

1. **Log Export to BigQuery**: Add a Cloud Logging sink to route AKS logs to BigQuery for long-term retention, cost analysis, and SQL-based querying across cluster log history.

2. **Custom Prometheus Rules**: Deploy `ClusterPodMonitoring` CRDs to define scrape targets for application-specific metrics, enabling application-level SLO alerting through Cloud Monitoring.

3. **Distributed Tracing**: If the `attached-install-mesh` sub-module is used, configure the Stackdriver trace exporter in the mesh's `MeshConfig` to automatically capture distributed traces from all instrumented services.

### 18.4 Multi-Cluster Federation

1. **Anthos Config Management**: Apply `ConfigManagement` fleet feature to sync policies, RBAC, and namespaces from a Git repository across the AKS cluster and any GKE clusters in the same fleet.

2. **Multi-Cluster Services**: Implement the GKE Multi-Cluster Services (MCS) fleet feature to export Kubernetes Services from GKE clusters and make them accessible from the AKS cluster (and vice versa) without manual DNS or VPN configuration.

3. **Fleet-wide Policy Controller**: Enable OPA Gatekeeper via the fleet's Policy Controller feature to enforce organizational policies (e.g., resource limits, label requirements) uniformly across AKS and GKE clusters.

