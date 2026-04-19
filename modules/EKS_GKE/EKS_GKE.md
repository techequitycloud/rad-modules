---
title: "EKS_GKE Module Documentation"
sidebar_label: "EKS_GKE"
---

# EKS_GKE Module

## Overview

The `EKS_GKE` module is a **multi-cloud infrastructure module** that provisions a fully configured Amazon Elastic Kubernetes Service (EKS) cluster on AWS and registers it with Google Cloud as a GKE Attached Cluster. This gives platform engineers a unified, Google-managed control plane over AWS workloads — enabling centralized logging, monitoring, fleet management, and optional service mesh from a single Google Cloud console.

The module bridges two cloud providers through Google Cloud's **Anthos Attached Clusters** capability (part of the GKE Multi-Cloud API), allowing teams to manage Kubernetes workloads across AWS and Google Cloud with the same tooling, policies, and observability they already use for native GKE clusters.

**Key value proposition for platform engineers:**
- Manage AWS EKS clusters from the Google Cloud console alongside native GKE clusters
- Unified observability: Cloud Logging and Cloud Managed Prometheus for EKS workloads
- Single Fleet for policy, config management, and service mesh across clouds
- OIDC-based identity federation — no static credentials crossing cloud boundaries
- Optional Anthos Service Mesh (ASM) installation via the `attached-install-mesh` sub-module

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EKS_GKE Module                                     │
│                                                                                 │
│   AWS (us-west-2)                      Google Cloud (us-central1)               │
│   ─────────────────────────────        ────────────────────────────────────     │
│                                                                                 │
│   ┌─────────────────────────┐          ┌──────────────────────────────────┐     │
│   │  VPC (10.0.0.0/16)      │          │  GKE Multi-Cloud API             │     │
│   │  ┌─────────────────┐    │          │  google_container_attached_       │     │
│   │  │ Public Subnets  │    │  OIDC    │  cluster "primary"               │     │
│   │  │ /24 × 3 AZs     │◄───┼──────── │  • distribution = "eks"          │     │
│   │  └─────────────────┘    │          │  • logging: SYSTEM + WORKLOADS   │     │
│   │  ┌─────────────────┐    │          │  • managed_prometheus enabled     │     │
│   │  │ Private Subnets │    │          │  • admin_users authorized         │     │
│   │  │ /24 × 3 AZs     │    │          └──────────────────────────────────┘     │
│   │  └─────────────────┘    │                         │                         │
│   └──────────┬──────────────┘                         │                         │
│              │                                        ▼                         │
│   ┌──────────▼──────────────┐          ┌──────────────────────────────────┐     │
│   │  AWS EKS Cluster        │          │  GKE Fleet (GKE Hub)             │     │
│   │  • Kubernetes 1.34      │          │  • Fleet membership              │     │
│   │  • 2–5 worker nodes     │          │  • Centralized policy            │     │
│   │  • OIDC provider        │          │  • Config management (optional)  │     │
│   └──────────┬──────────────┘          └──────────────────────────────────┘     │
│              │                                                                  │
│   ┌──────────▼──────────────┐          ┌──────────────────────────────────┐     │
│   │  Anthos Connector       │          │  Cloud Logging                   │     │
│   │  (Helm bootstrap chart) │─────────►│  Cloud Monitoring (Prometheus)   │     │
│   │  installed via          │          │  Connect Gateway                 │     │
│   │  attached-install-      │          └──────────────────────────────────┘     │
│   │  manifest sub-module    │                                                   │
│   └─────────────────────────┘                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

Deployment Order:
  1. GCP APIs enabled
  2. AWS VPC + subnets + routing
  3. AWS IAM roles
  4. AWS EKS cluster + node group
  5. Anthos bootstrap manifest (Helm) → attached-install-manifest
  6. google_container_attached_cluster registered in GCP
  7. (Optional) Service Mesh → attached-install-mesh
```

---

## GCP APIs Enabled

When deployed, the module enables **10 Google Cloud APIs** on the target project. These are required for multi-cloud cluster registration, observability, and fleet management.

| API | Purpose |
|-----|---------|
| `gkemulticloud.googleapis.com` | Core API for registering non-GKE clusters (EKS, AKS) as attached clusters |
| `gkeconnect.googleapis.com` | Manages the Connect Agent that bridges the EKS cluster to Google Cloud |
| `connectgateway.googleapis.com` | Enables `kubectl` access to the EKS cluster via the Connect Gateway (no VPN required) |
| `cloudresourcemanager.googleapis.com` | Required for project-level resource lookups and IAM operations |
| `anthos.googleapis.com` | Core Anthos platform API — umbrella for all multi-cloud and service mesh features |
| `monitoring.googleapis.com` | Cloud Monitoring — receives Prometheus metrics forwarded from EKS |
| `logging.googleapis.com` | Cloud Logging — receives system and workload logs forwarded from EKS |
| `gkehub.googleapis.com` | GKE Fleet membership management for centralized policy and configuration |
| `opsconfigmonitoring.googleapis.com` | Operations config monitoring — enables managed observability agents on attached clusters |
| `kubernetesmetadata.googleapis.com` | Kubernetes metadata API — enables resource-based monitoring dashboards in Cloud Console |

> **Platform engineer note:** APIs are enabled with `disable_on_destroy = false` and `disable_dependent_services = false`. This means tearing down the module does not disable these APIs, preventing accidental disruption of other workloads that may depend on them in the same project.

---

## AWS Infrastructure

### VPC and Networking (`vpc.tf`)

The module creates a dedicated AWS VPC for the EKS cluster with full control over subnet topology. It supports two mutually exclusive networking modes selected by the `enable_public_subnets` boolean.

#### VPC Resources

| Resource | Name Pattern | Description |
|----------|-------------|-------------|
| `aws_vpc` | `{cluster_name_prefix}-vpc` | Custom VPC, DNS hostnames and DNS support enabled |
| `aws_subnet` (public) | `{prefix}-subnet-public-{az}` | Created when `enable_public_subnets = true` |
| `aws_subnet` (private) | `{prefix}-subnet-private-{az}` | Created when `enable_public_subnets = false` |
| `aws_internet_gateway` | `{cluster_name_prefix}-vpc` | Internet gateway — public topology only |
| `aws_route_table` (public) | `{prefix}-vpc-public` | Routes all egress to Internet Gateway |
| `aws_route` (public) | — | `0.0.0.0/0 → Internet Gateway` (5-minute create timeout) |
| `aws_route_table_association` (public) | — | Associates each public subnet with the public route table |
| `aws_eip` | — | Elastic IP for NAT Gateway — private topology only |
| `aws_nat_gateway` | `{prefix}-nat-gateway` | NAT Gateway in first public subnet — private topology egress |
| `aws_route_table` (private) | `{prefix}-vpc-private` | Routes all egress to NAT Gateway |
| `aws_route` (private) | — | `0.0.0.0/0 → NAT Gateway` |
| `aws_route_table_association` (private) | — | Associates each private subnet with the private route table |

#### Subnet Layout (Defaults)

| Topology | Subnet CIDRs | Availability Zones | Public IP on Launch |
|----------|--------------|--------------------|---------------------|
| Public (`enable_public_subnets = true`) | `10.0.101.0/24`, `10.0.102.0/24`, `10.0.103.0/24` | us-west-2a, us-west-2b, us-west-2c | Yes |
| Private (`enable_public_subnets = false`) | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` | us-west-2a, us-west-2b, us-west-2c | No |

All subnets carry the tag `kubernetes.io/cluster/{cluster_name} = shared`, which EKS requires for automatic subnet discovery and AWS Load Balancer Controller provisioning.

#### Public vs. Private Topology Decision Guide

| Requirement | Recommendation |
|-------------|---------------|
| Quick lab / learning / demo | `enable_public_subnets = true` (default) — simpler, no NAT cost |
| Production / security-hardened | `enable_public_subnets = false` — worker nodes not directly reachable from internet |
| Cost sensitivity | `enable_public_subnets = true` — NAT Gateway incurs hourly + data-transfer charges |
| Compliance / regulated workloads | `enable_public_subnets = false` with private subnets and NAT egress |

> **Important:** The Anthos bootstrap Helm chart and `terraform destroy` both require network access to the EKS API server. When using private subnets, ensure the Terraform execution environment has routing to the EKS private endpoint.

---

### AWS IAM Roles (`iam.tf`)

The module creates two AWS IAM roles with the minimum policies required for EKS operation. All role names include the `cluster_name_prefix` to allow multiple instances in the same AWS account.

#### EKS Cluster Role

| Resource | Name Pattern | Trust Principal | Attached Policy |
|----------|-------------|----------------|----------------|
| `aws_iam_role.eks` | `{cluster_name_prefix}-eks-role` | `eks.amazonaws.com` | `AmazonEKSClusterPolicy` |

`AmazonEKSClusterPolicy` grants the EKS control plane permission to manage EC2 resources (security groups, ENIs, load balancers) on behalf of the cluster.

#### EKS Node Group Role

| Resource | Name Pattern | Trust Principal | Attached Policies |
|----------|-------------|----------------|------------------|
| `aws_iam_role.node` | `{cluster_name_prefix}-node-group-role` | `ec2.amazonaws.com` | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |

| Policy | Purpose |
|--------|---------|
| `AmazonEKSWorkerNodePolicy` | Allows worker nodes to register and communicate with the EKS control plane |
| `AmazonEKS_CNI_Policy` | Grants the VPC CNI plugin permission to configure ENIs and assign pod IP addresses |
| `AmazonEC2ContainerRegistryReadOnly` | Allows nodes to pull container images from Amazon ECR |

> **Dependency ordering:** `aws_eks_cluster` declares `depends_on` for the cluster policy attachment, and `aws_eks_node_group` declares `depends_on` for all three node policies. This ensures IAM propagation completes before EKS attempts to use the roles — avoiding the race condition where EKS tries to create security groups before it has EC2 permissions.

---

### EKS Cluster and Node Group (`main.tf`)

| Resource | Name | Description |
|----------|------|-------------|
| `aws_eks_cluster.eks` | `{cluster_name_prefix}` | EKS managed control plane |
| `data.aws_eks_cluster_auth.eks` | — | Short-lived bearer token for Helm provider authentication |
| `aws_eks_node_group.node` | `{prefix}-node-group` | Managed node group with configurable auto-scaling |

#### EKS Cluster

The cluster Kubernetes version is configurable via `k8s_version` (default `"1.34"`). Subnets are selected dynamically — either the complete set of public or private subnets — based on `enable_public_subnets`. The OIDC issuer URL emitted by the cluster (`aws_eks_cluster.eks.identity[0].oidc[0].issuer`) is passed directly into `google_container_attached_cluster` for cross-cloud identity federation without any static credentials crossing cloud boundaries.

#### Node Group Auto-Scaling

| Parameter | Default | Variable |
|-----------|---------|----------|
| Desired node count | 2 | `node_group_desired_size` |
| Minimum node count | 2 | `node_group_min_size` |
| Maximum node count | 5 | `node_group_max_size` |

The node group is placed in the same subnets as the cluster. Scaling beyond `desired_size` requires an external autoscaler (Cluster Autoscaler or Karpenter) — this module does not install one.

#### Helm Provider for Bootstrap

A named Helm provider alias (`bootstrap_installer`) authenticates directly against the EKS cluster using the cluster endpoint, CA certificate, and a short-lived token. This provider is explicitly passed to the `attached-install-manifest` child module, ensuring Helm operations run against the EKS cluster rather than any local kubeconfig context:

```hcl
provider "helm" {
  alias = "bootstrap_installer"
  kubernetes {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}
```

---

## GKE Attached Cluster Registration (`main.tf`)

After the EKS cluster is running and the Anthos bootstrap connector is installed, the module registers the cluster in Google Cloud as a `google_container_attached_cluster`. This is the core of the multi-cloud capability — it creates a Google-managed representation of the EKS cluster that appears in the Cloud Console alongside native GKE clusters.

```
Resource: google_container_attached_cluster "primary"
  name        = var.cluster_name_prefix
  project     = local.project_id
  location    = var.gcp_location
  distribution = "eks"
```

### OIDC Configuration

```hcl
oidc_config {
  issuer_url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}
```

The OIDC issuer URL is taken directly from the EKS cluster's built-in OIDC provider. Google Cloud uses this to validate Kubernetes service account tokens without requiring any static AWS credentials — a key security property of the attached clusters integration. When a workload on EKS presents a signed service account JWT, Google Cloud can verify its authenticity by fetching the OIDC discovery document from AWS.

### Fleet Registration

```hcl
fleet {
  project = "projects/${local.project_number}"
}
```

The cluster is enrolled in a GKE Fleet using the GCP project number. Fleet membership unlocks:
- **Policy Controller** (OPA Gatekeeper) — enforce governance across all fleet clusters
- **Config Management** — GitOps-based configuration sync
- **Multi-cluster Ingress** — route traffic across clusters
- **Cloud Service Mesh** — Anthos Service Mesh (ASM) management plane

### Logging Configuration

```hcl
logging_config {
  component_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
}
```

| Component | What is Collected |
|-----------|------------------|
| `SYSTEM_COMPONENTS` | Kubernetes control plane logs: kube-apiserver, kube-scheduler, kube-controller-manager, etcd, kube-proxy |
| `WORKLOADS` | Application container stdout/stderr from all namespaces |

Logs are forwarded to Cloud Logging via the Connect Agent installed by the bootstrap Helm chart. They appear in Cloud Logging under the resource type `k8s_container` and are queryable with the same Log Explorer queries used for native GKE workloads.

### Managed Prometheus Monitoring

```hcl
monitoring_config {
  managed_prometheus_config {
    enabled = true
  }
}
```

When enabled, Google Cloud Managed Service for Prometheus (GMP) deploys a collection agent on the EKS cluster (via the Anthos connector) that scrapes Prometheus metrics and forwards them to Google Cloud Monitoring. Platform engineers can:
- Query metrics with PromQL in Cloud Monitoring
- Use pre-built GKE dashboards for CPU, memory, network, and storage
- Create alerting policies on EKS workload metrics in the same place as native GKE alerts

### Admin User Authorization

```hcl
authorization {
  admin_users = local.trusted_users
}
```

`local.trusted_users` is constructed by merging the Terraform executor's identity (`google_client_openid_userinfo.me.email`) with the `trusted_users` variable list, deduplicating with `distinct(compact(...))`. These users receive Kubernetes RBAC `cluster-admin` access to the EKS cluster when connecting through the Connect Gateway, enabling `kubectl` access without direct AWS credentials.

### Dependency Chain

The `google_container_attached_cluster` resource declares `depends_on = [module.attached_install_manifest]`. This is critical: the bootstrap connector must be running on the EKS cluster before Google Cloud attempts to register it. Without the connector, the registration call would succeed on the GCP side but the cluster would never become `READY` because there is no agent to receive instructions.

---

## Sub-Module: `attached-install-manifest`

**Source:** `./modules/attached-install-manifest`

This sub-module installs the Anthos Attached Clusters bootstrap connector onto the EKS cluster via Helm. It is the bridge that enables the EKS cluster to communicate with the Google Cloud control plane after registration.

### How It Works

The bootstrap process has three steps, orchestrated entirely within Terraform:

**Step 1 — Fetch the manifest from Google Cloud**

```hcl
data "google_container_attached_install_manifest" "bootstrap" {
  location         = var.gcp_location
  project          = var.attached_cluster_fleet_project
  cluster_id       = var.attached_cluster_name
  platform_version = var.platform_version
}
```

Google Cloud's GKE Multi-Cloud API generates a unique YAML manifest for this specific cluster registration. The manifest contains the Connect Agent deployment, associated RBAC rules, and the GCP project binding. It is scoped to `platform_version`, which must match between this call and the `google_container_attached_cluster` resource.

**Step 2 — Write a local Helm chart**

```
.tmp/{gcp_location}-{platform_version}/bootstrap_helm_chart/
  ├── Chart.yaml          (name: attached-bootstrap, version: 0.0.1)
  └── templates/
      └── bootstrap.yaml  (the manifest from Step 1)
```

Two `local_file` resources write a minimal Helm chart to a temporary directory. Using Helm (rather than `kubectl apply`) provides idempotent installation, proper resource ownership tracking, and clean uninstall on `terraform destroy`.

**Step 3 — Apply the Helm chart to EKS**

```hcl
resource "helm_release" "local" {
  name  = "attached-bootstrap"
  chart = local.helm_chart_dir
}
```

The Helm provider alias (`bootstrap_installer`) passed from the parent module is used here — Helm authenticates against the EKS API server using the cluster endpoint and token.

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `attached_cluster_name` | — | EKS cluster name (used as `cluster_id` in the manifest API call) |
| `attached_cluster_fleet_project` | — | GCP project ID for the fleet |
| `gcp_location` | — | GCP region for the manifest API endpoint |
| `platform_version` | — | GKE platform version string (e.g. `1.34.0-gke.1`) — must match the parent `google_container_attached_cluster` |
| `temp_dir` | `"./.tmp"` | Local directory for the generated Helm chart files |
| `helm_timeout` | (Helm default) | Optional timeout for the Helm install operation |

### Platform Version Coupling

`platform_version` must be identical between this sub-module and the parent `google_container_attached_cluster` resource. Google Cloud validates this on registration — a mismatch causes a 400 error. The manifest API endpoint is also versioned: the manifest content changes between platform versions as Google updates the Connect Agent components.

---

## Sub-Module: `attached-install-mesh`

**Source:** `./modules/attached-install-mesh`

This sub-module installs **Anthos Service Mesh (ASM)** on the EKS attached cluster using `asmcli`, Google's official service mesh installation tool. It is an optional post-registration step that adds full Istio-based service mesh capabilities to the EKS workloads.

### Installation Architecture

The module performs all installation steps as Terraform `null_resource` provisioners running `local-exec` commands. This pattern is used because service mesh installation requires CLI tools (gcloud, asmcli) that are not available as Terraform providers.

```
Terraform null_resource chain:
  prepare_cache
      │
      ├── download_gcloud  ──┐
      ├── download_jq        ├── decompress
      └── download_asmcli ───┘
                                  │
                             additional_components (check_components.sh)
                                  │
                          ┌───────┴────────────┐
                          │                    │
               gcloud_auth_service_    gcloud_auth_google_
               account_key_file        credentials
               (if key file provided)  (if GOOGLE_CREDENTIALS set)
                          │                    │
                          └────────┬───────────┘
                               run_command
                               (asmcli install)
```

### Tool Download and Setup

The module self-contains its toolchain by downloading all required binaries to a local cache directory (`{module_path}/.cache/{random_hex}/`):

| Tool | Default Version | Download Source |
|------|----------------|----------------|
| Google Cloud SDK (`gcloud`) | `491.0.0` | `https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/` |
| `jq` | `1.6` | `https://github.com/stedolan/jq/releases/` |
| `asmcli` | `1.22` | `https://storage.googleapis.com/csm-artifacts/asm/` |

All three tools are downloaded in parallel (three independent `null_resource` blocks with the same `depends_on = [null_resource.prepare_cache]`). After downloading, `decompress` extracts the gcloud SDK tarball and copies `jq` and `asmcli` into `google-cloud-sdk/bin/` so they are on the same PATH used by `asmcli`.

Custom download URLs can be provided for air-gapped or mirror environments via `gcloud_download_url`, `jq_download_url`, and `asmcli_download_url`.

### `check_components.sh` — Component Verification

Before running `asmcli`, the module runs `scripts/check_components.sh` to ensure required gcloud components (e.g., `kubectl`) are installed:

```bash
# Script logic:
# 1. List currently installed gcloud components
# 2. Diff against required component list (argument: "kubectl")
# 3. Check if missing components exist as system binaries (avoid redundant install)
# 4. Run: gcloud components install {missing_components} --quiet
```

This avoids redundant installation when `kubectl` is already present as a system binary, and handles the case where gcloud's component manager must install it.

### Authentication Options

The module supports three mutually usable authentication methods for gcloud (used by asmcli to call GCP APIs):

| Method | Variable | When to Use |
|--------|----------|-------------|
| Service account key file | `service_account_key_file` | Path to a downloaded JSON key file |
| `GOOGLE_CREDENTIALS` env var | `use_tf_google_credentials_env_var = true` | When Terraform already has GCP credentials as an environment variable |
| No explicit auth | `activate_service_account = false` | When ADC (Application Default Credentials) is already configured |

When `use_tf_google_credentials_env_var = true`, the module writes `$GOOGLE_CREDENTIALS` to a temporary file (`terraform-google-credentials.json`) and runs `gcloud auth activate-service-account --key-file` against it.

### `asmcli` Installation Command

The final `run_command` null_resource executes:

```bash
PATH={gcloud_bin_path}:$PATH
asmcli install \
  --kubeconfig {kubeconfig} \
  --context {context} \
  --fleet_id {fleet_id} \
  --platform multicloud \
  --option attached-cluster \
  --ca {mesh_ca|gcp_cas|citadel} \
  [additional flags...]
```

| Flag | Purpose |
|------|---------|
| `--platform multicloud` | Tells asmcli this is a non-GKE cluster |
| `--option attached-cluster` | Uses the attached-cluster install profile optimized for Anthos-registered clusters |
| `--ca mesh_ca` | Uses Google-managed Mesh CA for mTLS certificate issuance (default) |
| `--ca gcp_cas` | Uses Certificate Authority Service — for custom PKI requirements |
| `--ca citadel` | Uses Istio's built-in Citadel CA — not recommended for production |

### asmcli Feature Flags

All flags below are boolean variables (default `false`). They map 1:1 to `asmcli` command-line options:

| Variable | asmcli Flag | Effect |
|----------|-------------|--------|
| `asmcli_enable_all` | `--enable_all` | Enables all permissions and components in a single flag |
| `asmcli_enable_cluster_roles` | `--enable_cluster_roles` | Creates required ClusterRole and ClusterRoleBinding resources |
| `asmcli_enable_cluster_labels` | `--enable_cluster_labels` | Adds required labels to the cluster resource |
| `asmcli_enable_gcp_components` | `--enable_gcp_components` | Installs GCP-managed control plane components |
| `asmcli_enable_gcp_apis` | `--enable_gcp_apis` | Enables required GCP APIs for service mesh |
| `asmcli_enable_gcp_iam_roles` | `--enable_gcp_iam_roles` | Grants required IAM roles to service accounts |
| `asmcli_enable_meshconfig_init` | `--enable_meshconfig_init` | Initializes the Mesh Config API |
| `asmcli_enable_namespace_creation` | `--enable_namespace_creation` | Creates the `istio-system` namespace if it does not exist |
| `asmcli_enable_registration` | `--enable_registration` | Registers the cluster with GKE Hub if not already registered |
| `asmcli_verbose` | `--verbose` | Enables verbose logging output during installation |

### Certificate Authority Selection Guide

| CA | `asmcli_ca` value | Use Case |
|----|-------------------|----------|
| Mesh CA | `mesh_ca` (default) | Google-managed, zero-ops cert rotation, best for most workloads |
| Certificate Authority Service | `gcp_cas` | Custom PKI hierarchy, enterprise/regulated environments |
| Citadel | `citadel` | Legacy/compatibility; Istio built-in CA, self-managed cert rotation |

### Destroy Behavior

The module includes matching `when = destroy` provisioners that re-authenticate (`gcloud_auth_google_credentials_destroy`, `gcloud_auth_service_account_key_file_destroy`) and re-run component checks (`additional_components_destroy`, `decompress_destroy`). This ensures gcloud is available during `terraform destroy` so asmcli can cleanly uninstall the service mesh components before the cluster registration is removed.

### Output: `wait`

```hcl
output "wait" {
  value = length(null_resource.additional_components[*].triggers) + ...
}
```

The `wait` output returns a combined trigger count from all null_resources. Parent modules can reference this output in their `depends_on` to ensure mesh installation completes before proceeding.

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kubeconfig` | — | Path to kubeconfig file (required) |
| `context` | — | Kubernetes context name in the kubeconfig (required) |
| `fleet_id` | — | GCP project ID of the fleet (required) |
| `platform` | `"linux"` | OS for binary downloads: `linux` or `darwin` |
| `activate_service_account` | `true` | Whether to run `gcloud auth activate-service-account` |
| `service_account_key_file` | `""` | Path to service account JSON key file |
| `use_tf_google_credentials_env_var` | `false` | Use `$GOOGLE_CREDENTIALS` env var for auth |
| `gcloud_sdk_version` | `"491.0.0"` | gcloud SDK version to download |
| `gcloud_download_url` | `null` | Custom gcloud download URL (overrides version-based URL) |
| `jq_version` | `"1.6"` | jq version to download |
| `jq_download_url` | `null` | Custom jq download URL |
| `asmcli_version` | `"1.22"` | asmcli version to download |
| `asmcli_download_url` | `null` | Custom asmcli download URL |
| `asmcli_ca` | `"mesh_ca"` | Certificate authority: `mesh_ca`, `gcp_cas`, or `citadel` |
| `asmcli_enable_all` | `false` | Enable all asmcli permissions/components |
| `asmcli_enable_cluster_roles` | `false` | Create cluster roles |
| `asmcli_enable_cluster_labels` | `false` | Add cluster labels |
| `asmcli_enable_gcp_components` | `false` | Install GCP-managed components |
| `asmcli_enable_gcp_apis` | `false` | Enable required GCP APIs |
| `asmcli_enable_gcp_iam_roles` | `false` | Grant required IAM roles |
| `asmcli_enable_meshconfig_init` | `false` | Initialize Mesh Config API |
| `asmcli_enable_namespace_creation` | `false` | Create `istio-system` namespace |
| `asmcli_enable_registration` | `false` | Register cluster with GKE Hub |
| `asmcli_verbose` | `false` | Verbose asmcli output |
| `asmcli_additional_arguments` | `null` | Any extra flags appended to the asmcli command |

---

## Input Variables Reference

### Section 0: Platform Metadata

These variables are consumed by the RAD platform UI and have no effect on resource provisioning.

| Variable | Default | Description |
|----------|---------|-------------|
| `module_description` | (long string) | Human-readable description displayed in the RAD UI |
| `module_dependency` | `["AWS Account", "GCP Project"]` | Prerequisite module names in deployment order |
| `module_services` | `["AWS", "EKS", "IAM", "VPC", "GCP", "GKE Hub", "Anthos"]` | Service tags for UI filtering |
| `credit_cost` | `100` | Platform credit cost (metadata only) |
| `require_credit_purchases` | `false` | Whether deployment requires credit purchase |
| `enable_purge` | `true` | Whether the module can be fully deleted |
| `public_access` | `true` | Whether the module is visible to all platform users |
| `deployment_id` | `null` | Fixed ID suffix for resources; auto-generated if null |
| `resource_creator_identity` | `rad-module-creator@…` | Terraform service account email |

### Section 2: Project and Region

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `existing_project_id` | — | **Yes** | GCP project ID where the cluster will be registered |
| `gcp_location` | `"us-central1"` | No | GCP region for cluster registration, logging, and monitoring |
| `aws_region` | `"us-west-2"` | No | AWS region where EKS and VPC resources are provisioned |

### Section 3: Cluster Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name_prefix` | `"aws-eks-cluster"` | Prefix for EKS cluster, node group, VPC, and IAM role names |
| `vpc_cidr_block` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `public_subnet_cidr_blocks` | `["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]` | CIDRs for public subnets (one per AZ) |
| `private_subnet_cidr_blocks` | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` | CIDRs for private subnets (one per AZ) |
| `subnet_availability_zones` | `["us-west-2a", "us-west-2b", "us-west-2c"]` | AZs for subnet creation |
| `enable_public_subnets` | `true` | `true` = public subnets + IGW; `false` = private subnets + NAT |
| `platform_version` | `"1.34.0-gke.1"` | GKE attached cluster platform version — must match manifest sub-module |
| `k8s_version` | `"1.34"` | Kubernetes version for the EKS cluster |
| `node_group_desired_size` | `2` | Initial/desired node count |
| `node_group_min_size` | `2` | Minimum node count |
| `node_group_max_size` | `5` | Maximum node count for auto-scaling |

### Section 4: IAM and Access

| Variable | Default | Sensitive | Description |
|----------|---------|-----------|-------------|
| `aws_access_key` | — | **Yes** | AWS Access Key ID for programmatic access |
| `aws_secret_key` | — | **Yes** | AWS Secret Access Key for programmatic access |
| `trusted_users` | `[]` | No | Email addresses granted `cluster-admin` RBAC on the EKS cluster via Connect Gateway. Validated: no empty strings, no duplicates. |

> **Security note:** The Terraform executor's own identity is always included as a trusted user (merged automatically from `google_client_openid_userinfo.me.email`). The `trusted_users` list adds additional admins on top of this.

---

## Usage Examples

### Minimal Configuration (Public Subnets, Default Region)

```hcl
module "eks_gke" {
  source = "./modules/EKS_GKE"

  existing_project_id = "my-gcp-project"
  aws_access_key      = var.aws_access_key
  aws_secret_key      = var.aws_secret_key
  trusted_users       = ["admin@example.com"]
}
```

### Private Subnet Topology

```hcl
module "eks_gke" {
  source = "./modules/EKS_GKE"

  existing_project_id   = "my-gcp-project"
  aws_access_key        = var.aws_access_key
  aws_secret_key        = var.aws_secret_key
  enable_public_subnets = false
  trusted_users         = ["platform-team@example.com", "devops@example.com"]

  # Custom networking
  vpc_cidr_block             = "172.16.0.0/16"
  private_subnet_cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  subnet_availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]
}
```

### Custom Cluster Sizing

```hcl
module "eks_gke" {
  source = "./modules/EKS_GKE"

  existing_project_id      = "my-gcp-project"
  aws_access_key           = var.aws_access_key
  aws_secret_key           = var.aws_secret_key
  cluster_name_prefix      = "prod-eks"
  k8s_version              = "1.34"
  platform_version         = "1.34.0-gke.1"
  node_group_desired_size  = 3
  node_group_min_size      = 2
  node_group_max_size      = 10
  trusted_users            = ["sre@example.com"]
}
```

### Connecting to the Registered Cluster

After `terraform apply` completes (approximately 10 minutes), connect to the EKS cluster via the Connect Gateway — no AWS credentials needed:

```bash
# Authenticate via gcloud
gcloud container attached clusters get-credentials aws-eks-cluster \
  --location us-central1 \
  --project my-gcp-project

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### Adding Service Mesh (using attached-install-mesh)

```hcl
module "asm" {
  source = "./modules/EKS_GKE/modules/attached-install-mesh"

  kubeconfig = "/path/to/kubeconfig"
  context    = "aws-eks-cluster"
  fleet_id   = "my-gcp-project"

  asmcli_ca                      = "mesh_ca"
  asmcli_enable_all              = true   # grant all permissions in one flag
  use_tf_google_credentials_env_var = true

  depends_on = [module.eks_gke]
}
```

---

## Key Concepts for Platform Engineers

### How GKE Attached Clusters Work

Anthos Attached Clusters is Google Cloud's mechanism for bringing non-GKE Kubernetes clusters under Google Cloud management. The workflow has three logical phases:

1. **Bootstrap**: A Google-generated manifest (fetched via the `google_container_attached_install_manifest` data source) is applied to the target cluster. This installs the Connect Agent — a lightweight proxy that maintains an outbound HTTPS connection to Google Cloud. The agent requires no inbound firewall rules.

2. **Registration**: `google_container_attached_cluster` is created in GCP, pointing to the cluster's OIDC issuer. Google Cloud validates the cluster by communicating through the Connect Agent and confirms OIDC endpoint reachability.

3. **Management**: After registration, the cluster appears in the Cloud Console. Google Cloud pushes configuration (logging agents, Prometheus collectors, mesh components) to the cluster through the Connect Agent channel.

### Connect Gateway: kubectl Without AWS Credentials

The Connect Gateway is one of the most powerful features for platform engineers. After registration:

```
kubectl → gcloud auth → Connect Gateway API → Connect Agent (on EKS) → kube-apiserver
```

Users authenticate with their Google identity (`gcloud auth login`). The Connect Gateway translates the Google OAuth token into a Kubernetes request, validated against the `admin_users` list in `google_container_attached_cluster`. No AWS IAM credentials, no VPN, no bastion host — just `gcloud container attached clusters get-credentials`.

### OIDC Federation: Cross-Cloud Identity Without Static Keys

The OIDC integration enables workload identity federation between AWS and GCP:

- EKS has a built-in OIDC provider that signs Kubernetes service account tokens as JWTs
- The `oidc_config.issuer_url` in `google_container_attached_cluster` points Google Cloud to this provider's public key endpoint
- Google Cloud can validate tokens from EKS workloads, enabling Workload Identity Federation for pods that need to access GCP APIs

This eliminates the need to distribute GCP service account keys into EKS pods.

### Fleet Management: Unified Cluster Governance

Fleet enrollment (via `fleet { project = ... }`) registers the EKS cluster as a fleet member alongside any native GKE clusters in the same GCP project. From a fleet perspective, all clusters are equal:

| Fleet Capability | Benefit |
|-----------------|---------|
| **Policy Controller** | Apply OPA Gatekeeper constraints across EKS and GKE simultaneously |
| **Config Management** | Sync the same GitOps repository to both EKS and GKE clusters |
| **Multi-cluster Services** | Cross-cluster service discovery via `<svc>.<ns>.svc.clusterset.local` |
| **Cloud Service Mesh** | Shared control plane for mTLS and traffic management across clouds |
| **Dashboard** | Single view of health, compliance, and configuration across all clusters |

### Managed Observability: No Prometheus Infrastructure to Operate

The `monitoring_config.managed_prometheus_config.enabled = true` setting deploys Google Cloud Managed Service for Prometheus (GMP) components on the EKS cluster. GMP is a fully managed, Prometheus-compatible metrics backend:

- **Collection**: A managed collector scrapes Prometheus endpoints on EKS pods using standard `PodMonitoring` and `ClusterPodMonitoring` CRDs
- **Storage**: Metrics are stored in Cloud Monitoring's globally distributed, managed backend — no Prometheus server or Thanos to operate
- **Querying**: Standard PromQL queries work via the Cloud Monitoring API or the built-in Prometheus Query UI
- **Alerting**: Create alert policies in Cloud Monitoring that fire on PromQL conditions, sending notifications to PagerDuty, Slack, email, or Pub/Sub

Similarly, `logging_config` with `SYSTEM_COMPONENTS` and `WORKLOADS` routes all EKS logs to Cloud Logging with zero infrastructure to operate — the Connect Agent handles forwarding.

### Platform Version Management

The `platform_version` variable (default `"1.34.0-gke.1"`) is a GKE-managed version string that governs:
1. The bootstrap manifest content (what version of the Connect Agent is installed)
2. The API compatibility surface of the attached cluster
3. The asmcli version compatibility for service mesh installation

Google releases new platform versions as Kubernetes versions advance. To upgrade:
1. Update `platform_version` in `variables.tf`
2. Run `terraform apply` — the manifest sub-module fetches a new manifest and Helm upgrades the Connect Agent
3. The `google_container_attached_cluster` resource updates the registered version in GCP

---

## Deployment Guide

### Prerequisites

| Prerequisite | Details |
|-------------|---------|
| AWS Account | With IAM permissions to create VPC, EKS, IAM roles |
| AWS credentials | Access Key ID and Secret Access Key (stored as sensitive variables) |
| GCP Project | With billing enabled |
| GCP permissions | `roles/owner` or `roles/gkemulticloud.admin` + `roles/gkehub.admin` + `roles/logging.admin` + `roles/monitoring.admin` |
| Terraform | >= 0.13 |
| AWS Provider | >= 4.5.0 |
| Google Provider | >= 5.0.0 |
| Helm Provider | ~> 2.0 |

### Deployment Steps

```bash
# 1. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project ID, AWS credentials, trusted users

# 2. Initialize providers and modules
terraform init

# 3. Preview the plan
terraform plan

# 4. Apply (approximately 10 minutes)
terraform apply

# 5. Connect to the cluster (no AWS credentials needed)
gcloud container attached clusters get-credentials aws-eks-cluster \
  --location us-central1 \
  --project <your-project-id>

# 6. Verify
kubectl get nodes
kubectl get pods -A
```

### Destruction Steps

```bash
# Tear down all resources (EKS cluster, VPC, GCP registration)
terraform destroy
```

> **Note:** On destroy, Terraform first uninstalls the Anthos bootstrap Helm chart (via the manifest sub-module's destroy-time provisioner), then removes the `google_container_attached_cluster` registration from GCP, then tears down the EKS node group and cluster, then removes the VPC and IAM roles. The destroy requires network access to the EKS API server — ensure the cluster endpoint is reachable from the Terraform executor.

---

## Resource Summary

| Provider | Resource | Count | Purpose |
|----------|----------|-------|---------|
| Google | `google_project_service` | 10 | Enable required GCP APIs |
| Google | `google_container_attached_cluster` | 1 | Register EKS cluster in GCP |
| AWS | `aws_vpc` | 1 | Dedicated VPC for EKS |
| AWS | `aws_subnet` | 3 | One per AZ (public or private) |
| AWS | `aws_internet_gateway` | 0–1 | Public topology only |
| AWS | `aws_nat_gateway` | 0–1 | Private topology only |
| AWS | `aws_eip` | 0–1 | Elastic IP for NAT Gateway |
| AWS | `aws_route_table` | 1 | Routing for chosen topology |
| AWS | `aws_route` | 1 | Default route to IGW or NAT |
| AWS | `aws_route_table_association` | 3 | One per subnet |
| AWS | `aws_iam_role` | 2 | EKS cluster role + node group role |
| AWS | `aws_iam_role_policy_attachment` | 4 | Cluster policy + 3 node policies |
| AWS | `aws_eks_cluster` | 1 | EKS managed control plane |
| AWS | `aws_eks_node_group` | 1 | Managed worker node group |
| Helm | `helm_release` | 1 | Anthos bootstrap connector chart |
| Local | `local_file` | 2 | Generated Helm chart files |
| Random | `random_id` | 0–1 | Deployment ID suffix |
| Random | `random_string` | 1 | Cluster name suffix |

