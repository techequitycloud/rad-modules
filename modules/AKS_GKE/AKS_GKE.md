# AKS_GKE Module: Google Kubernetes Engine Multi-Cloud Deep Dive

## 1. Overview and Learning Objectives

This module deploys a Microsoft Azure Kubernetes Service (AKS) cluster and registers it with Google Cloud as a **GKE Attached Cluster**, making it a full member of a **GKE Fleet**. From that point forward, the cluster is visible and manageable from the Google Cloud Console alongside any native GKE clusters in the same project.

The primary purpose of this module is educational: it gives platform engineers hands-on exposure to Google Cloud's multi-cloud Kubernetes management layer. By working with a live deployment, engineers develop a concrete understanding of how Google Cloud extends its Kubernetes management plane beyond its own infrastructure.

**After deploying this module, engineers will have practical experience with:**

- How **GKE Attached Clusters** bring non-GKE Kubernetes clusters under Google Cloud management without migrating workloads.
- How **GKE Fleet** creates a unified management boundary spanning Azure, AWS, on-premises, and Google Cloud clusters.
- How **GKE Connect** and the **Connect Gateway** enable secure `kubectl` access to remote clusters using Google Cloud identity, with no VPN or public API endpoints required.
- How **OIDC federation** establishes cryptographic trust between AKS and Google Cloud, eliminating shared credentials between clouds.
- How **Cloud Logging** and **Managed Prometheus** centralise observability for clusters running in Azure.
- How **Anthos Service Mesh** can be installed on non-GKE clusters, bringing Istio-compatible service mesh capabilities to workloads in Azure.

---

## 2. What This Module Deploys

The module provisions infrastructure across two clouds in three sequential phases.

**Phase 1 — Azure Infrastructure**

An Azure Resource Group and an AKS cluster are created in Azure. The cluster is configured with a system-assigned managed identity, an OIDC issuer endpoint, and a default node pool. The cluster's managed identity is granted the Network Contributor role on the resource group so that AKS can manage Azure load balancers and network resources on behalf of Kubernetes workloads.

**Phase 2 — GKE Attachment**

Bootstrap manifests are fetched from Google's API and installed on the AKS cluster via Helm. These manifests deploy the GKE Connect agent, which establishes a persistent outbound connection from AKS to Google Cloud. Once the agent is running, the AKS cluster is registered as a GKE Attached Cluster, enrolled in a GKE Fleet, and configured with managed logging, Managed Prometheus, and admin user authorization.

**Phase 3 — Service Mesh (Optional)**

An optional sub-module downloads Google Cloud's `asmcli` tool and uses it to install Anthos Service Mesh on the AKS cluster, enabling mTLS, advanced traffic management, and distributed observability for workloads running in Azure.

---

## 3. GKE Attached Clusters

### 3.1 What Problem This Solves

Many organisations run Kubernetes on multiple cloud providers simultaneously. Managing these clusters typically means learning separate tooling for each: Azure Portal and `az` CLI for AKS, and the Google Cloud Console and `gcloud` for GKE. Observability, access control, and policy enforcement are each siloed per cloud.

GKE Attached Clusters solves this by extending Google Cloud's Kubernetes management plane to clusters that Google did not provision. The AKS cluster continues to run entirely in Azure — its control plane, nodes, and networking are unchanged — but Google Cloud gains the ability to observe, access, and manage it through the same interfaces used for native GKE clusters.

### 3.2 Platform Version

Every GKE Attached Cluster is assigned a **platform version** — the version of the GKE Connect agent and supporting components installed on the cluster. The platform version must be compatible with the AKS cluster's Kubernetes version. An AKS cluster running Kubernetes 1.34 uses platform version `1.34.0-gke.1`.

To explore available platform versions for any Google Cloud region:

```bash
gcloud alpha container attached get-server-config --location=us-central1
```

### 3.3 Viewing the Attached Cluster in the Console

After deployment, the AKS cluster appears in the Google Cloud Console at:

**Kubernetes Engine → Clusters**

It is listed alongside any native GKE clusters in the project. The cluster entry shows its type as `Attached`, its Kubernetes version, node count, and status. Clicking the cluster name opens its detail view, where nodes, workloads, namespaces, and Kubernetes events are all browsable from the same Console interface used for GKE.

To inspect the cluster record from the command line:

```bash
# List all attached clusters in a project
gcloud container attached clusters list \
  --location=us-central1 \
  --project=my-gcp-project

# Describe the cluster registration details
gcloud container attached clusters describe azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project
```

The `describe` output shows the cluster's OIDC issuer URL, platform version, fleet project, logging and monitoring configuration, and admin user list — the complete picture of how Google Cloud sees the cluster.

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

One of the most architecturally significant features demonstrated by this module is **OIDC-based cross-cloud federation**. This is the mechanism by which Google Cloud trusts tokens issued by the AKS cluster without any service account keys, certificates, or passwords being shared between Azure and Google Cloud.

AKS exposes a public **OpenID Connect Discovery Endpoint** — a URL that publishes the cluster's cryptographic public keys (JSON Web Key Set, or JWKS). When the AKS cluster is attached to Google Cloud, GCP fetches these public keys and stores them in its trust configuration. From that point, whenever the GKE Connect agent presents a Kubernetes service account token to Google Cloud, GCP validates the token's cryptographic signature against the stored keys. If valid, GCP knows the token genuinely originated from that AKS cluster — no Azure credentials required.

### 4.2 Inspecting the OIDC Configuration

After deployment, the OIDC trust relationship can be inspected directly:

```bash
# View the OIDC issuer URL stored in the attached cluster record
gcloud container attached clusters describe azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project \
  --format="value(oidcConfig.issuerUrl)"

# View the Workload Identity Pool created for the fleet
gcloud iam workload-identity-pools list \
  --location=global \
  --project=my-gcp-project

# Describe the pool to see the OIDC provider configuration
gcloud iam workload-identity-pools describe PROJECT_ID.svc.id.goog \
  --location=global \
  --project=my-gcp-project
```

The Workload Identity Pool is visible in the Google Cloud Console at:

**IAM & Admin → Workload Identity Federation**

Each attached cluster that joins the fleet contributes an OIDC provider to this pool, representing the trust relationship between the cluster and Google Cloud.

### 4.3 Why This Matters for Platform Engineers

This pattern — **Workload Identity Federation** — is the modern approach to cross-cloud authentication. The alternative, distributing service account key files, creates operational risk: keys can be leaked, forgotten, or left unrotated for years. OIDC federation eliminates the secret entirely. The same pattern underpins how GitHub Actions authenticates to Google Cloud, how Terraform Cloud authenticates to GCP, and how native GKE Workload Identity works. Understanding it here provides a transferable mental model for all of these systems.

### 4.4 Enabling Application Workloads to Access Google Cloud APIs

Once the cluster is fleet-enrolled with OIDC, individual pods running on AKS can authenticate directly to Google Cloud APIs — Cloud Storage, Pub/Sub, BigQuery — without credential files. The setup involves annotating a Kubernetes service account on AKS to link it to a Google Cloud service account:

```bash
# Create a Google Cloud service account for the workload
gcloud iam service-accounts create aks-workload-sa \
  --project=my-gcp-project

# Grant it access to a Google Cloud resource (e.g. Storage)
gcloud projects add-iam-policy-binding my-gcp-project \
  --member="serviceAccount:aks-workload-sa@my-gcp-project.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Allow the Kubernetes service account on AKS to impersonate it
gcloud iam service-accounts add-iam-policy-binding \
  aks-workload-sa@my-gcp-project.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/default/sa/my-app-sa"
```

```bash
# On the AKS cluster: annotate the Kubernetes service account
kubectl annotate serviceaccount my-app-sa \
  --namespace default \
  iam.gke.io/gcp-service-account=aks-workload-sa@my-gcp-project.iam.gserviceaccount.com
```

Pods using this annotated service account will automatically receive short-lived GCP access tokens via the OIDC token exchange, with no key files mounted or managed.

---

## 5. GKE Fleet: Unified Multi-Cluster Management

### 5.1 What is a Fleet?

A **GKE Fleet** is a Google Cloud construct that groups Kubernetes clusters — regardless of where they run — into a single management boundary. Any cluster enrolled in a fleet can be governed, observed, and configured uniformly alongside every other fleet member.

Fleets are scoped to a Google Cloud project. In this module, the AKS cluster is enrolled in the fleet of the destination GCP project specified at deployment time.

### 5.2 Viewing Fleet Membership in the Console

After deployment, the fleet membership is visible in the Google Cloud Console at:

**Kubernetes Engine → Fleet**

The Fleet page shows all enrolled clusters, their registration status, health, and which fleet features are active on each cluster. The AKS cluster appears here with its distribution type (`aks`) and membership state.

To explore fleet membership from the command line:

```bash
# List all clusters enrolled in the fleet
gcloud container fleet memberships list \
  --project=my-gcp-project

# Describe the AKS cluster's fleet membership
gcloud container fleet memberships describe azure-aks-cluster \
  --project=my-gcp-project
```

### 5.3 What Fleet Membership Enables

Fleet enrollment activates a range of Google Cloud platform features that are not available to unregistered clusters:

**Connect Gateway** — Engineers run `kubectl` against the AKS cluster using Google Cloud IAM identity. No AKS credentials, no kubeconfig distribution, no VPN required.

**Unified Console View** — The AKS cluster appears in Kubernetes Engine → Clusters alongside any native GKE clusters. Workloads, nodes, namespaces, and events are browsable from the same interface.

**Anthos Config Management** — Synchronises Kubernetes configurations and policies from a Git repository to all fleet clusters simultaneously. A single commit can apply namespace definitions, RBAC policies, or resource quotas to both GKE and AKS clusters.

**Policy Controller** — Built on OPA Gatekeeper, enforces organisational policies (resource limits, required labels, image registry restrictions) fleet-wide using identical constraint definitions across GKE and AKS clusters.

**Multi-Cluster Services** — Allows Kubernetes Services to be exported from one fleet cluster and consumed by other fleet clusters without manual DNS configuration or network peering.

**Service Mesh** — Anthos Service Mesh can be managed fleet-wide, providing uniform mTLS, traffic management, and distributed tracing across all member clusters.

### 5.4 Accessing the AKS Cluster via Connect Gateway

Connect Gateway is one of the most practical fleet features. After deployment, admin users connect to the AKS cluster using only their Google Cloud identity:

```bash
# Fetch credentials — this configures kubectl to use Connect Gateway
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 \
  --project=my-gcp-project

# All standard kubectl commands now work against the AKS cluster
kubectl get nodes
kubectl get namespaces
kubectl get pods --all-namespaces
kubectl top nodes
kubectl describe node NODE_NAME
```

The kubeconfig entry written by `get-credentials` points to Google Cloud's Connect Gateway endpoint, not to the AKS API server directly. All commands are authenticated by Google Cloud IAM and proxied through the Connect agent tunnel.

To verify which context is active and confirm the gateway endpoint:

```bash
kubectl config current-context
kubectl config view --minify
```

### 5.5 Exploring Fleet Features in the Console

Each fleet feature has a dedicated section in the Fleet page:

- **Kubernetes Engine → Fleet → Feature manager** shows which features are enabled and their health status across all fleet clusters.
- **Kubernetes Engine → Config** (when Anthos Config Management is enabled) shows the sync status of each cluster's configuration against the source Git repository.
- **Kubernetes Engine → Policy** (when Policy Controller is enabled) shows active constraints and any policy violations across fleet clusters.

---

## 6. Google Cloud Managed Logging for AKS

### 6.1 The Multi-Cloud Observability Problem

AKS logs flow natively to Azure Monitor and Log Analytics. GKE logs flow to Google Cloud Logging. Teams operating both must maintain expertise in two separate query languages, two alerting systems, and two retention configurations. Cross-cloud incident investigation means switching between Azure Portal and the Google Cloud Console, correlating timestamps manually.

This module routes AKS logs to Google Cloud Logging alongside any GKE cluster logs in the same project. The AKS cluster continues to run in Azure, but its logs arrive in one centralised place.

### 6.2 What Gets Logged

Two categories of logs are collected from the AKS cluster:

**System Component Logs** capture the operational output of the Kubernetes control plane and node-level components: the API server, scheduler, controller manager, kubelet, and CNI plugins. These are essential for diagnosing cluster-level failures — why a pod could not be scheduled, why a node went NotReady.

**Workload Logs** capture the stdout and stderr of every container running in user namespaces. Any application writing to stdout has its logs forwarded automatically — no log shippers, sidecar containers, or application changes required.

### 6.3 Exploring Logs in the Console

Open the Google Cloud Console and navigate to:

**Logging > Log Explorer**

In the query bar, filter to the attached AKS cluster by entering:

```
resource.labels.cluster_name="azure-aks-cluster"
```

The Log Explorer shows all log entries from the cluster, with filters for namespace, pod name, container name, and severity. The log schema is identical to GKE, so queries written for GKE clusters work without modification on the attached AKS cluster.

To explore specific log types, use these refined queries in the Log Explorer query bar:

```
# System component logs (control plane and node components)
resource.type="k8s_cluster"
resource.labels.cluster_name="azure-aks-cluster"

# All workload container logs
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"

# Logs from a specific namespace
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"
resource.labels.namespace_name="default"

# Error and critical logs only
resource.labels.cluster_name="azure-aks-cluster"
severity>=ERROR
```

### 6.4 Querying Logs from the Command Line

```bash
# All recent logs from the AKS cluster
gcloud logging read \
  'resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project \
  --limit=50 \
  --format=json

# Workload logs from a specific pod
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.cluster_name="azure-aks-cluster" AND resource.labels.pod_name:"my-app"' \
  --project=my-gcp-project \
  --limit=20

# System component logs in the last hour
gcloud logging read \
  'resource.type="k8s_cluster" AND resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project \
  --freshness=1h
```

### 6.5 Creating a Log-Based Metric

Log-based metrics turn log entries into numeric signals that can be charted and alerted on. Navigate to **Logging > Log-based Metrics > Create Metric**, or use the CLI:

```bash
gcloud logging metrics create aks-oomkilled-count \
  --description="Count of OOMKilled container restarts on AKS cluster" \
  --log-filter='resource.labels.cluster_name="azure-aks-cluster" AND jsonPayload.reason="OOMKilling"' \
  --project=my-gcp-project

# Confirm the metric was created
gcloud logging metrics list --project=my-gcp-project
```

Once created, this metric appears in Cloud Monitoring and can be used in dashboards and alerting policies.

### 6.6 Creating a Log-Based Alert

In **Log Explorer**, run the following query to find BackOff events on the AKS cluster:

```
resource.labels.cluster_name="azure-aks-cluster"
jsonPayload.reason="BackOff"
severity=WARNING
```

Click **Create alert** in the Log Explorer toolbar to open the alerting policy wizard pre-populated with this filter. Alternatively, navigate to **Monitoring > Alerting > Create Policy**, select **Log-based metric** as the signal source, and choose the metric created in the previous step.

---

## 7. Google Cloud Managed Prometheus for AKS

### 7.1 What Managed Prometheus Provides

This module enables **Google Cloud Managed Service for Prometheus (GMP)** on the AKS cluster. GMP accepts metrics in Prometheus format and stores them durably with up to 24 months of retention, without requiring engineers to run or maintain any Prometheus infrastructure.

When enabled, GMP installs a collector DaemonSet on AKS nodes. This collector scrapes Prometheus metrics from pods and forwards them to Cloud Monitoring. Scrape targets are configured using `PodMonitoring` and `ClusterPodMonitoring` custom resources, which follow the same specification as on native GKE clusters.

### 7.2 Exploring Metrics in the Console

After deployment, navigate to:

**Monitoring > Metrics Explorer**

In the **Select a metric** field, search for `kubernetes` to browse the Kubernetes metrics flowing from the AKS cluster. Filter any metric by `resource.cluster_name = "azure-aks-cluster"` to isolate the AKS cluster's data. Key metrics to explore:

- `kubernetes.io/container/cpu/core_usage_time` — CPU usage per container
- `kubernetes.io/container/memory/used_bytes` — Memory usage per container
- `kubernetes.io/node/cpu/total_cores` — Total CPU capacity per node
- `kubernetes.io/pod/network/received_bytes_count` — Network ingress per pod

### 7.3 Querying Metrics from the Command Line

```bash
# Confirm Kubernetes metrics are flowing from the AKS cluster
gcloud monitoring metrics list \
  --filter='metric.type=starts_with("kubernetes.io/container")' \
  --project=my-gcp-project

# List all Kubernetes metric types available
gcloud monitoring metrics list \
  --filter='metric.type=starts_with("kubernetes.io")' \
  --project=my-gcp-project \
  --format="value(metric.type)"
```

### 7.4 Querying with PromQL in the Console

In **Monitoring > Metrics Explorer**, switch the query mode from **MQL** to **PromQL**. Enter these expressions to explore AKS cluster metrics:

```promql
# CPU usage rate for all containers on the AKS cluster
rate(kubernetes_io:container_cpu_core_usage_time{cluster_name="azure-aks-cluster"}[5m])

# Memory usage summed by namespace
sum by (namespace_name) (
  kubernetes_io:container_memory_used_bytes{cluster_name="azure-aks-cluster"}
)

# Container restart count
kubernetes_io:container_restart_count{cluster_name="azure-aks-cluster"}
```

### 7.5 Scraping Custom Application Metrics

To configure GMP to scrape a custom application on the AKS cluster, first connect to the cluster, then apply a `PodMonitoring` resource:

```bash
# Connect to the cluster
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project

# Verify the GMP collector DaemonSet is running on AKS nodes
kubectl get daemonset -n gmp-system
kubectl get pods -n gmp-system

# Apply a PodMonitoring resource to scrape a custom app
kubectl apply -f - <<EOF
apiVersion: monitoring.googleapis.com/v1
kind: PodMonitoring
metadata:
  name: my-app-monitoring
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
EOF

# Confirm it was accepted
kubectl get podmonitoring -n default
```

Custom metrics appear in Cloud Monitoring within a few minutes under the `prometheus.googleapis.com` metric prefix.

### 7.6 Viewing Built-in Kubernetes Dashboards

Navigate to **Monitoring > Dashboards** and look for dashboards prefixed with **GKE**:

- **GKE — Cluster summary** — node-level CPU, memory, and disk usage for the AKS cluster
- **GKE — Workloads** — pod-level resource consumption, restart rates, and network activity
- **GKE — Node** — per-node drill-down into resource utilisation

These dashboards are populated automatically from Managed Prometheus metrics with no additional configuration after the cluster is attached.

---
