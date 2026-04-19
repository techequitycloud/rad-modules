# AKS_GKE Module: Google Kubernetes Engine Multi-Cloud Deep Dive

## 1. Overview and Learning Objectives

This module deploys a Microsoft Azure Kubernetes Service (AKS) cluster and registers it with Google Cloud as a **GKE Attached Cluster**, making it a full member of a **GKE Fleet**. From that point forward, the cluster is visible and manageable from the Google Cloud Console alongside any native GKE clusters in the same project.

The primary purpose of this module is educational: it gives platform engineers hands-on exposure to Google Cloud's multi-cloud Kubernetes management layer — a set of capabilities that is increasingly central to enterprise platform engineering. By working with a live deployment, engineers develop a concrete understanding of how Google Cloud extends its Kubernetes management plane beyond its own infrastructure.

**After deploying this module, engineers will have practical experience with:**

- How **GKE Attached Clusters** bring non-GKE Kubernetes clusters under Google Cloud management without requiring migration of workloads.
- How **GKE Fleet** creates a unified management boundary that spans Azure, AWS, on-premises, and Google Cloud clusters.
- How **GKE Connect** and the **Connect Gateway** enable secure `kubectl` access to remote clusters using Google Cloud identity, with no VPN or public API endpoints required.
- How **OIDC federation** establishes cryptographic trust between AKS and Google Cloud, eliminating the need to share credentials between clouds.
- How **Google Cloud Managed Logging** and **Managed Prometheus** centralise observability for clusters running in Azure.
- How **Google Cloud Service Mesh (Anthos Service Mesh)** can be installed on non-GKE clusters using `asmcli`, bringing Istio-compatible service mesh capabilities to workloads in Azure.

---

## 2. What This Module Deploys

The module provisions infrastructure across two clouds in three sequential phases. Understanding the sequence matters, because each phase depends on the previous one completing successfully.

**Phase 1 — Azure Infrastructure**

An Azure Resource Group and an AKS cluster are created in Azure. The cluster is configured with a system-assigned managed identity, an OIDC issuer endpoint, and a default node pool. The cluster's managed identity is granted the Network Contributor role on the resource group so that AKS can manage Azure load balancers and network resources on behalf of Kubernetes workloads.

**Phase 2 — GKE Attachment**

A set of Google Cloud bootstrap manifests is fetched from Google's API and installed on the AKS cluster. These manifests deploy the GKE Connect agent, which establishes a persistent outbound connection from AKS to Google Cloud. Once the agent is running, the AKS cluster is registered in Google Cloud as a GKE Attached Cluster, enrolled in a GKE Fleet, and configured with managed logging, managed Prometheus monitoring, and admin user authorization.

**Phase 3 — Service Mesh (Optional)**

An optional sub-module (`attached-install-mesh`) downloads Google Cloud's `asmcli` tool and uses it to install Anthos Service Mesh on the AKS cluster, enabling mTLS, advanced traffic management, and distributed observability for workloads running in Azure.

---

## 3. Google Cloud Multi-Cloud and GKE Attached Clusters

### 3.1 What Problem This Solves

Many organisations run Kubernetes on multiple cloud providers simultaneously — often because different teams adopted different clouds, or because specific workloads have regulatory or latency requirements that tie them to a particular region or provider. Managing these clusters typically means learning separate tooling for each cloud: Azure Portal and `az` CLI for AKS, and Google Cloud Console and `gcloud` for GKE. Observability, access control, and policy enforcement are each siloed per cloud.

GKE Attached Clusters solves this by extending Google Cloud's Kubernetes management plane to clusters that Google did not provision. The AKS cluster continues to run entirely in Azure — its control plane, nodes, and networking are unchanged. But Google Cloud gains the ability to observe, access, and manage it through the same interfaces used for native GKE clusters.

### 3.2 How GKE Attached Clusters Works

The attachment process installs a lightweight **GKE Connect agent** on the AKS cluster. This agent maintains a persistent, outbound-only encrypted connection to Google Cloud. All management traffic from Google Cloud — including `kubectl` commands proxied through the Connect Gateway, log collection, and metrics scraping — travels through this agent tunnel.

Google Cloud identifies the attached cluster by a combination of its **cluster name**, **GCP region** (where the cluster record is stored), and **GCP project**. The cluster is assigned a **distribution type** of `aks`, which tells Google Cloud to use AKS-compatible bootstrap manifests and apply AKS-specific compatibility logic in the management plane.

### 3.3 Platform Version

Every GKE Attached Cluster is assigned a **platform version** — the version of the GKE Connect agent and supporting components that will be installed. Platform versions follow Kubernetes minor version compatibility: the platform version must be compatible with the AKS cluster's Kubernetes version. For example, an AKS cluster running Kubernetes 1.34 uses platform version `1.34.0-gke.1`.

To see available platform versions for a given Google Cloud region:

```bash
gcloud alpha container attached get-server-config --location=us-central1
```

Deploying with a mismatched platform version is one of the most common causes of attachment failures, so this module exposes both the Kubernetes version and platform version as separate configuration options.

### 3.4 Default Configuration

| Configuration | Default Value | Notes |
|---|---|---|
| Cluster name prefix | `azure-aks-cluster` | Used as the cluster name in both Azure and Google Cloud |
| AKS Kubernetes version | `1.34` | The Kubernetes minor version deployed on AKS |
| GKE platform version | `1.34.0-gke.1` | Must be compatible with the Kubernetes version |
| Azure region | `westus2` | Where the AKS cluster is physically deployed |
| Google Cloud region | `us-central1` | Where the attached cluster record is stored in GCP |
| Node count | `3` | Number of worker nodes in the default node pool |
| Node VM size | `Standard_D2s_v3` | Azure VM SKU for worker nodes |

---

## 4. OIDC Federation: Cross-Cloud Identity Without Shared Secrets

### 4.1 The Core Concept

One of the most architecturally significant features demonstrated by this module is **OIDC-based cross-cloud federation**. This is the mechanism by which Google Cloud trusts tokens issued by the AKS cluster — without any service account keys, certificates, or passwords being shared between Azure and Google Cloud.

AKS is configured with its OIDC issuer enabled. This means AKS publishes a public **OpenID Connect Discovery Endpoint** — a URL that exposes the cluster's cryptographic public keys (its JSON Web Key Set, or JWKS). These are the keys AKS uses to sign Kubernetes service account tokens.

When the AKS cluster is attached to Google Cloud, GCP fetches these public keys and stores them in its trust configuration for that cluster. From that point on, whenever the GKE Connect agent (or a workload) presents a Kubernetes service account token to Google Cloud, GCP validates the token's cryptographic signature against the stored keys. If the signature is valid, GCP knows the token genuinely originated from that AKS cluster — no Azure credentials required.

### 4.2 Why This Matters for Platform Engineers

This pattern — sometimes called **Workload Identity Federation** — represents the modern approach to cross-cloud authentication. The alternative (service account key files distributed as secrets) creates operational risk: keys can be leaked, forgotten, or left unrotated. OIDC federation eliminates the secret entirely. The trust relationship is mathematical: it works because the private signing key never leaves AKS, and the public verification key is freely published.

The same pattern underpins how native GKE Workload Identity works, how GitHub Actions authenticates to Google Cloud without storing credentials, and how Terraform Cloud authenticates to GCP without a service account key file. Understanding this module's OIDC setup gives engineers a transferable mental model for all of these systems.

### 4.3 Workload Identity for Applications

Once the AKS cluster is fleet-enrolled with OIDC, individual application pods running on AKS can authenticate directly to Google Cloud APIs — Cloud Storage, Pub/Sub, BigQuery, Firestore — without any credential files. A Kubernetes service account on AKS can be federated with a Google Cloud service account using an IAM binding, and the OIDC token exchange happens transparently at runtime. This means applications running in Azure can securely consume Google Cloud services using the same identity model as applications running on GKE.

---

## 5. GKE Fleet: Unified Multi-Cluster Management

### 5.1 What is a Fleet?

A **GKE Fleet** is a Google Cloud construct that groups Kubernetes clusters — regardless of where they run — into a single management boundary. Any cluster enrolled in a fleet can be governed, observed, and configured uniformly alongside every other cluster in that fleet.

Fleets are identified by a Google Cloud project. Every cluster enrolled in the fleet belongs to that project's fleet. In this module, the AKS cluster is enrolled in the fleet associated with the destination GCP project specified at deployment time.

### 5.2 What Fleet Membership Enables

Fleet enrollment is not merely cosmetic. It is a prerequisite for a range of Google Cloud platform features that only become available once a cluster joins a fleet:

**Connect Gateway** — Fleet membership activates the Connect Gateway, which allows platform engineers to run `kubectl` against the AKS cluster using their Google Cloud identity. No AKS credentials, no kubeconfig distribution, no VPN. Commands are authenticated by Google Cloud IAM and proxied through the Connect agent tunnel.

**Unified Console View** — The AKS cluster appears in the Kubernetes Engine page of the Google Cloud Console alongside any native GKE clusters. Workloads, nodes, namespaces, and Kubernetes events are all visible from the same interface.

**Anthos Config Management** — Fleet clusters can participate in Anthos Config Management (ACM), which synchronises Kubernetes configurations and policies from a Git repository across all clusters in the fleet simultaneously. A single commit to the policy repository can apply changes to both GKE and AKS clusters.

**Policy Controller** — Built on OPA Gatekeeper, Policy Controller can be deployed fleet-wide to enforce organisational policies (resource limits, required labels, image registry restrictions) across GKE and AKS clusters using identical policy definitions.

**Multi-Cluster Services** — Fleet clusters can participate in Google's Multi-Cluster Services (MCS) feature, which allows Kubernetes Services to be exported from one cluster and consumed by other clusters in the fleet without manual DNS configuration or network peering.

**Service Mesh** — Anthos Service Mesh can be installed and managed fleet-wide, providing uniform mTLS, traffic management, and distributed tracing across all fleet clusters.

### 5.3 Accessing the AKS Cluster via Connect Gateway

After deployment, admin users listed in the module's trusted users configuration can connect to the AKS cluster using only their Google Cloud identity:

```bash
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project

kubectl get nodes
kubectl get pods --all-namespaces
```

This is a significant operational difference from the traditional AKS access model, where each engineer requires a kubeconfig file obtained from Azure. With Connect Gateway, access is governed entirely by Google Cloud IAM — the same role assignments that control access to GKE clusters control access to the AKS cluster.

### 5.4 Admin User Authorization

The module accepts a list of trusted user email addresses. These users are granted cluster-admin access to the AKS cluster through Google Cloud's authorization layer. The engineer running the Terraform deployment is automatically included in the admin list, ensuring they are never accidentally locked out. Duplicate entries and empty strings are rejected at configuration time to prevent misconfiguration.

---

## 6. Google Cloud Managed Logging for AKS

### 6.1 The Multi-Cloud Observability Problem

Platform engineers operating clusters in multiple clouds face a persistent fragmentation challenge: AKS logs flow natively to Azure Monitor and Log Analytics, while GKE logs flow to Google Cloud Logging. Engineers must maintain expertise in two separate query languages, two alerting systems, and two log retention configurations. Cross-cloud incident investigation requires switching contexts between Azure Portal and Google Cloud Console, correlating timestamps and formats manually.

GKE Attached Clusters solves this by routing AKS logs to Google Cloud Logging, alongside any GKE cluster logs already present. The AKS cluster continues to run in Azure — but its logs arrive in one place.

### 6.2 What Gets Logged

This module enables two categories of log collection from the AKS cluster:

**System Component Logs** capture the operational output of the Kubernetes control plane and node-level components. This includes the API server, scheduler, controller manager, kubelet, and container network interface plugins. These logs are essential for diagnosing cluster-level failures: why a pod could not be scheduled, why a node went NotReady, why a service account token was rejected.

**Workload Logs** capture the standard output and standard error streams of every container running in user namespaces across the cluster. Any application that writes to stdout or stderr has its logs automatically forwarded to Cloud Logging — no application-side changes, log shippers, or sidecar containers required.

### 6.3 Querying AKS Logs in Cloud Logging

Once the cluster is attached and logging is active, all logs are queryable using Cloud Logging's query language. Logs carry standard Kubernetes resource labels — cluster name, namespace, pod name, container name — making them straightforward to filter:

```bash
# All logs from the attached AKS cluster
gcloud logging read \
  'resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project --limit=50

# Logs from a specific namespace
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.cluster_name="azure-aks-cluster" AND resource.labels.namespace_name="production"' \
  --project=my-gcp-project

# System component logs only
gcloud logging read \
  'resource.type="k8s_cluster" AND resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project
```

The same queries work identically in the Cloud Console's Log Explorer UI, and can be used to create log-based metrics, alerting policies, and exports to BigQuery or Cloud Storage.

### 6.4 Unified Alerting Across Clouds

Because AKS and GKE logs share the same backend, a single Cloud Monitoring alerting policy can fire on conditions observed in either cluster type. For example, an alert on `"OOMKilled"` log entries will detect out-of-memory events on the AKS cluster and on any GKE clusters in the same project, sending a single notification through the same channels.

---

## 7. Google Cloud Managed Prometheus for AKS

### 7.1 What Managed Prometheus Provides

This module enables **Google Cloud Managed Service for Prometheus (GMP)** on the AKS cluster. GMP is Google Cloud's fully managed, Prometheus-compatible metrics backend. It accepts Prometheus-format metrics and stores them durably, with up to 24 months of retention, without requiring engineers to run, scale, or maintain any Prometheus infrastructure.

When enabled on an attached cluster, GMP installs a collector DaemonSet on the AKS nodes. This collector scrapes Prometheus metrics from pods that expose a `/metrics` endpoint and forwards them to Google Cloud Monitoring. Engineers configure what to scrape using standard Kubernetes custom resources (`PodMonitoring` and `ClusterPodMonitoring`), which follow the same specification as they would on a native GKE cluster.

### 7.2 Why This Matters Operationally

Self-managed Prometheus has well-known operational challenges at scale: storage sizing, retention configuration, high-availability setup, cross-cluster federation, and long-term storage integration (Thanos, Cortex, or Mimir). Each of these adds infrastructure complexity that competes with time spent on platform engineering.

Managed Prometheus eliminates all of these concerns. There is no Prometheus server to size or maintain. Retention is handled by Google Cloud. High availability is inherent. And because the same backend stores metrics from both GKE and AKS clusters, PromQL queries can reference metrics from either cloud without any cross-cluster federation configuration.

### 7.3 Querying Metrics with PromQL

Metrics collected from the AKS cluster are queryable using standard PromQL through Google Cloud Monitoring's Prometheus-compatible API endpoint, and through Grafana using the Google Cloud Monitoring data source:

```bash
# Query Kubernetes CPU usage across all nodes on the AKS cluster
# (via the Cloud Monitoring Prometheus endpoint or Grafana)
# Example PromQL:
# container_cpu_usage_seconds_total{cluster="azure-aks-cluster"}

# List available metrics from the attached cluster
gcloud monitoring metrics list \
  --filter='metric.type=starts_with("kubernetes.io")' \
  --project=my-gcp-project
```

### 7.4 Built-in Kubernetes Dashboards

Google Cloud Console includes pre-built dashboards for Kubernetes workloads that work with both GKE and GKE Attached Clusters. These dashboards display node CPU and memory usage, pod resource consumption, and container restart rates — populated from Managed Prometheus metrics, with no additional configuration required after the cluster is attached.

### 7.5 Cross-Cloud Monitoring

A single Grafana dashboard configured with the Google Cloud Monitoring data source can display metrics from GKE clusters and the AKS cluster side by side, using identical PromQL queries. This enables direct performance comparisons between workloads running in different clouds, and a unified operational view for platform teams that manage both environments.

---

## 8. GKE Connect and the Connect Agent

### 8.1 How the Connect Agent Works

The GKE Connect agent is a lightweight Deployment installed on the AKS cluster during the attachment process. Its role is to maintain a persistent, encrypted, outbound-only connection from the AKS cluster to Google Cloud's `gkeconnect.googleapis.com` endpoint.

The architectural significance of "outbound-only" cannot be overstated. It means:

- The AKS API server does not need to be publicly accessible.
- No inbound firewall rules need to be opened on Azure.
- No VPN tunnel or VPC peering is required between Azure and Google Cloud.
- The cluster can sit behind a NAT gateway with no public IP, and the Connect agent will still function.

All management traffic from Google Cloud — `kubectl` commands via Connect Gateway, log collection, metrics scraping instructions — is multiplexed over this single outbound gRPC stream. The agent handles network interruptions automatically, reconnecting with exponential backoff.

### 8.2 The Bootstrap Manifest Process

Before the Connect agent can be installed, Google Cloud generates a set of **bootstrap manifests** specific to this cluster's identity, GCP region, and platform version. These manifests contain the Kubernetes resources that make up the Connect agent and its supporting RBAC configuration: the agent Deployment itself, a dedicated `gke-connect` namespace, ClusterRoles, ClusterRoleBindings, and ConfigMaps containing the cluster's GCP identity.

The bootstrap process uses Helm to apply these manifests to the AKS cluster, ensuring the installation is idempotent — running it multiple times produces the same result, and Helm tracks the installed state so upgrades and rollbacks are clean operations.

### 8.3 Verifying the Connect Agent

After deployment, engineers can verify the Connect agent is running correctly:

```bash
# Connect to the cluster via Connect Gateway
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project

# Confirm the Connect agent pod is running
kubectl get pods -n gke-connect

# View Connect agent logs
kubectl logs -n gke-connect -l app=gke-connect-agent
```

A healthy Connect agent pod in the `gke-connect` namespace confirms that the tunnel to Google Cloud is active and the cluster is reachable from the Google Cloud Console.

---

## 9. Google Cloud APIs Enabled by This Module

Deploying this module enables ten Google Cloud APIs on the destination project. Platform engineers benefit from understanding what each API does, because these APIs collectively define the scope of Google Cloud's multi-cloud Kubernetes management capabilities.

| API | What It Enables |
|---|---|
| **GKE Multi-Cloud API** (`gkemulticloud`) | The core API for managing attached clusters. Handles cluster registration, platform version management, and the lifecycle of attached cluster resources. |
| **GKE Connect API** (`gkeconnect`) | Manages the Connect agent's communication channel between the AKS cluster and Google Cloud. Required for the agent to establish and maintain its tunnel. |
| **Connect Gateway API** (`connectgateway`) | Powers the `kubectl` proxy that lets engineers run commands against the AKS cluster using Google Cloud identity. Without this API, Connect Gateway access is unavailable. |
| **Cloud Resource Manager API** (`cloudresourcemanager`) | Provides access to the GCP project hierarchy — required by the Google Cloud provider to look up project IDs and project numbers. |
| **Anthos API** (`anthos`) | Activates Anthos platform entitlements on the project, enabling fleet-level features such as Config Management, Policy Controller, and Service Mesh management. |
| **Cloud Monitoring API** (`monitoring`) | Receives Managed Prometheus metrics from the AKS cluster and powers alerting, dashboards, and the PromQL query endpoint. |
| **Cloud Logging API** (`logging`) | Receives log streams from AKS system components and workloads, making them available in Log Explorer, log-based metrics, and log exports. |
| **GKE Hub API** (`gkehub`) | Manages Fleet membership registrations. Every cluster enrolled in a fleet is registered through this API, which tracks membership state and fleet feature configurations. |
| **Operations Config Monitoring API** (`opsconfigmonitoring`) | Supports Google Cloud Operations configuration management for attached clusters, enabling health monitoring of the cluster's observability pipeline. |
| **Kubernetes Metadata API** (`kubernetesmetadata`) | Enables collection of Kubernetes metadata (namespace labels, workload annotations) that enriches log and metric records with Kubernetes context visible in the Cloud Console. |

These APIs are enabled non-destructively: removing the module deployment does not disable them, ensuring other modules or workloads in the same project that depend on these APIs are not affected.

---

## 10. Google Cloud Service Mesh on Attached Clusters

### 10.1 What Anthos Service Mesh Brings to AKS

The optional `attached-install-mesh` sub-module installs **Google Cloud Service Mesh (ASM)** — Google's distribution of Istio — on the AKS cluster. This is a significant capability extension: it means the full Istio service mesh feature set becomes available to workloads running in Azure, managed through the same Google Cloud interfaces used for service mesh on GKE.

Service mesh installation on an attached cluster uses Google's `asmcli` tool with the `--platform multicloud --option attached-cluster` profile, which configures Istio for the specific networking and identity model of AKS as a fleet-enrolled cluster.

### 10.2 Core Service Mesh Capabilities

**Mutual TLS (mTLS)** — All communication between pods in the mesh is automatically encrypted at the Envoy sidecar layer. Applications do not need to implement TLS themselves. mTLS is enforced at the network level, so it applies even to applications that predate the mesh deployment.

**Traffic Management** — Istio's traffic management resources (VirtualService, DestinationRule, Gateway) enable fine-grained control over how traffic flows between services: percentage-based canary deployments, circuit breaking, retry policies, and traffic mirroring for shadow testing.

**Observability** — The mesh automatically generates distributed traces, service-to-service metrics (request rate, error rate, latency), and access logs for all inter-service communication, without requiring changes to application code. These telemetry signals flow to Cloud Trace, Cloud Monitoring, and Cloud Logging.

**Security Policies** — AuthorizationPolicy resources define which services are permitted to communicate with which other services, implementing zero-trust networking at the application layer.

### 10.3 Certificate Authority Options

When installing the service mesh, the certificate authority used to issue mTLS certificates must be selected. Three options are available:

**Mesh CA** is the default. It is a Google-managed certificate authority built into Anthos Service Mesh. Certificates are automatically provisioned, rotated, and revoked by Google Cloud with no infrastructure or operational overhead. This is the recommended choice for most deployments.

**Google Certificate Authority Service (GCP CAS)** integrates the mesh with Google Cloud's enterprise certificate authority product. This option is suited to regulated environments that require a fully auditable CA with custom root certificates, defined certificate policies, and compliance reporting. GCP CAS provides a complete audit trail of every certificate issued to every pod in the mesh.

**Citadel** (Istiod CA) uses Istio's built-in certificate authority, which is the default in open-source Istio deployments. This option is primarily useful when migrating an existing Istio installation to Anthos Service Mesh, where disrupting the existing CA would require workload restarts.

### 10.4 Installation Feature Flags

The service mesh installation exposes granular feature flags that control what `asmcli` is permitted to configure automatically. Understanding these flags helps engineers reason about what changes the installation makes to the cluster and the GCP project:

| Feature Flag | What It Authorises |
|---|---|
| Enable cluster roles | Creation of ClusterRoles required by ASM components |
| Enable cluster labels | Addition of topology and mesh labels to cluster nodes |
| Enable GCP components | Installation of GCP-specific mesh components (Stackdriver telemetry adapter) |
| Enable GCP APIs | Automatic enablement of additional GCP APIs required by the mesh (e.g., mesh telemetry) |
| Enable GCP IAM roles | Granting of required IAM roles to the mesh's service account |
| Enable MeshConfig init | Initialisation of the MeshConfig resource with mesh-wide default settings |
| Enable namespace creation | Creation of the `istio-system` namespace if it does not already exist |
| Enable registration | Re-registration of the cluster with the fleet (typically redundant if the root module already handled registration) |

Each flag defaults to disabled, giving engineers explicit control over what the installation is authorised to change.

### 10.5 Tool Bootstrapping and Air-Gap Support

The service mesh sub-module downloads `asmcli`, the Google Cloud SDK, and `jq` at installation time. All three download sources are configurable, allowing the URLs to point to an internal artifact repository in environments where direct internet access is restricted. This makes the module deployable in air-gapped enterprise environments where security policy prohibits downloading tools from public internet sources during CI/CD runs.

---

## 11. Configuration Reference

### 11.1 Cluster Configuration

These options control the Azure and Kubernetes cluster that is provisioned:

| Option | Default | Description |
|---|---|---|
| Cluster name prefix | `azure-aks-cluster` | Base name for the AKS cluster and all associated Azure resources |
| Azure region | `westus2` | Azure region where the AKS cluster and resource group are deployed |
| Kubernetes version | `1.34` | Kubernetes minor version for the AKS control plane and nodes |
| GKE platform version | `1.34.0-gke.1` | Version of the GKE Connect agent and attached cluster components |
| Node count | `3` | Number of worker nodes in the default node pool |
| Node VM size | `Standard_D2s_v3` | Azure VM SKU for all nodes in the default node pool |
| GCP region | `us-central1` | Google Cloud region where the attached cluster record and fleet membership are stored |

### 11.2 Access Control

| Option | Default | Description |
|---|---|---|
| Trusted users | *(deploying user)* | List of Google Cloud user email addresses granted cluster-admin access via Connect Gateway. The identity running the deployment is always included. |

### 11.3 Azure Authentication

Four Azure authentication values are required to allow the module to create and manage resources in Azure. These are always treated as sensitive values and are never surfaced in logs or plan output:

| Option | Description |
|---|---|
| Azure Client ID | The Application ID of the Azure Service Principal used for authentication |
| Azure Client Secret | The secret credential for the Azure Service Principal |
| Azure Tenant ID | The Azure Active Directory tenant that owns the Service Principal |
| Azure Subscription ID | The Azure subscription where resources will be created |

### 11.4 GCP Project

| Option | Description |
|---|---|
| GCP Project ID | The destination Google Cloud project where the attached cluster will be registered and fleet membership created |

---

## 12. Deployment Workflow

### 12.1 Prerequisites

Before deploying, the following must be in place:

1. A Google Cloud project with billing enabled.
2. An Azure subscription and a Service Principal with Contributor access.
3. The Google Cloud SDK (`gcloud`) installed and authenticated with Application Default Credentials.
4. The Azure CLI (`az`) installed.
5. Terraform 0.13 or later installed.

Set the Azure Service Principal credentials as environment variables before running Terraform:

```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

### 12.2 Deployment Steps

```bash
# Initialise Terraform and download providers
terraform init

# Preview what will be created
terraform plan

# Deploy — expect approximately 12-15 minutes
terraform apply
```

### 12.3 Expected Deployment Duration

| Phase | Approximate Duration |
|---|---|
| Google Cloud API enablement | 1–2 minutes |
| Azure resource group creation | < 1 minute |
| AKS cluster provisioning | 6–9 minutes |
| Bootstrap manifest installation (Connect agent) | 2–3 minutes |
| GKE attached cluster registration | 1–2 minutes |
| **Total** | **~12–15 minutes** |

### 12.4 Verifying a Successful Deployment

```bash
# Confirm the cluster is registered in the GCP fleet
gcloud container fleet memberships list --project=my-gcp-project

# Describe the attached cluster record
gcloud container attached clusters describe azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project

# Connect and verify node access via Connect Gateway
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project
kubectl get nodes

# Confirm the Connect agent is running on the AKS cluster
kubectl get pods -n gke-connect
```

### 12.5 Teardown

```bash
terraform destroy
```

This removes the attached cluster registration from Google Cloud, uninstalls the Connect agent Helm release from AKS, and deletes all Azure resources including the AKS cluster and resource group. The Google Cloud APIs enabled during deployment are intentionally left enabled to avoid disrupting other modules or workloads that share the same GCP project.

---

## 13. Key Learning Outcomes for Platform Engineers

Working through the deployment and operation of this module builds practical knowledge across several areas that are central to modern platform engineering on Google Cloud.

### 13.1 Multi-Cloud Kubernetes Management

This module provides direct experience with the most important architectural insight in Google's multi-cloud strategy: **the management plane can be decoupled from the data plane**. Workloads run in Azure on AKS infrastructure. But the management plane — access control, observability, policy, service mesh — runs in Google Cloud and applies uniformly to the Azure cluster. Engineers who understand this separation can apply it when designing platform strategies for organisations with heterogeneous cloud environments.

### 13.2 Zero-Trust Cross-Cloud Authentication

The OIDC federation pattern demonstrated here is the foundation of zero-trust authentication between cloud environments. Understanding how OIDC issuer endpoints, JWKS, and token validation work — and why this eliminates the need for shared credentials — gives engineers a transferable skill applicable to any cross-cloud or cross-system authentication challenge.

### 13.3 Centralised Observability Architecture

Routing AKS logs and metrics to Cloud Logging and Cloud Monitoring demonstrates a centralised observability architecture that reduces cognitive load for platform teams. The module illustrates that Google Cloud's observability tools are not limited to GKE: they are designed to be the observability backend for any Kubernetes cluster, regardless of where it runs.

### 13.4 Service Mesh Across Cloud Boundaries

Installing Anthos Service Mesh on an AKS cluster shows that service mesh is a platform-level concern, not a cluster-level one. The same mesh management interfaces, certificate authorities, and traffic policies apply whether the workload runs on GKE or on a fleet-enrolled AKS cluster. This is the foundation for building genuinely portable microservice architectures that span cloud providers.

### 13.5 GKE Fleet as a Platform Primitive

Fleet is the most important concept for platform engineers building multi-cluster environments on Google Cloud. This module's deployment of a single attached cluster is the simplest possible fleet topology, but it establishes the mental model that scales to dozens of clusters across multiple clouds and on-premises environments — all governed, observed, and configured from a single GCP project.

