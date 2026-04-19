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

## 8. GKE Connect and the Connect Agent

### 8.1 How the Connect Agent Works

The GKE Connect agent is a lightweight Deployment installed on the AKS cluster during the attachment process. It maintains a persistent, encrypted, outbound-only connection from AKS to Google Cloud's `gkeconnect.googleapis.com` endpoint.

The significance of outbound-only cannot be overstated. It means the AKS API server does not need a public endpoint. No inbound firewall rules need to be opened in Azure. No VPN or VPC peering is required between Azure and Google Cloud. The cluster can sit behind a NAT gateway with no public IP and the Connect agent will still function. All management traffic — `kubectl` commands via Connect Gateway, log collection, metrics — is multiplexed over this single outbound gRPC stream. The agent reconnects automatically after network interruptions.

### 8.2 Viewing the Connect Agent in the Console

After deployment, navigate to:

**Kubernetes Engine > Clusters > azure-aks-cluster**

The cluster detail page shows a **Connect** status indicator. A green status confirms the agent tunnel is active and Google Cloud can reach the cluster. If the status shows a warning, the agent pod logs are the first place to investigate.

Fleet membership status is also visible at:

**Kubernetes Engine > Fleet > Clusters**

Each cluster entry shows its connection health, last heartbeat time, and which fleet features are active.

### 8.3 Verifying the Connect Agent from the Command Line

```bash
# Connect to the cluster via Connect Gateway
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project

# Confirm the Connect agent pod is running
kubectl get pods -n gke-connect

# View the Connect agent pod details
kubectl describe pod -n gke-connect -l app=gke-connect-agent

# Stream Connect agent logs to check tunnel health
kubectl logs -n gke-connect -l app=gke-connect-agent --follow

# Check all resources deployed by the bootstrap manifests
kubectl get all -n gke-connect
```

A healthy agent shows a Running pod and log lines confirming an active connection to `gkeconnect.googleapis.com`.

### 8.4 Exploring the Cluster via Connect Gateway

With credentials fetched via `get-credentials`, all standard `kubectl` commands work against the AKS cluster through the Connect Gateway tunnel:

```bash
# Inspect nodes and their Azure VM details
kubectl get nodes -o wide

# View resource consumption across all nodes
kubectl top nodes

# List all namespaces
kubectl get namespaces

# Browse workloads across all namespaces
kubectl get pods --all-namespaces

# Inspect cluster-level events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# View RBAC roles granted to connected users
kubectl get clusterrolebindings | grep gke-connect
```

### 8.5 Understanding the Bootstrap Manifests

The Kubernetes resources installed by the bootstrap process are all scoped to the `gke-connect` namespace. Exploring them reveals how Google Cloud establishes and maintains the cluster relationship:

```bash
# List all resources in the gke-connect namespace
kubectl get all,configmap,secret,serviceaccount -n gke-connect

# View the ConfigMap containing the cluster's GCP identity
kubectl describe configmap -n gke-connect

# Inspect the ClusterRoles granted to the Connect agent
kubectl get clusterrole | grep gke-connect
kubectl describe clusterrole gke-connect-agent-cluster-role
```

---

## 9. Google Cloud APIs Enabled by This Module

Deploying this module enables ten Google Cloud APIs on the destination project. Understanding what each one does gives platform engineers a clear picture of Google Cloud's multi-cloud Kubernetes management capabilities.

### 9.1 Viewing Enabled APIs in the Console

Navigate to:

**APIs & Services > Enabled APIs & Services**

Filter by `gke` or `anthos` to see the APIs activated by this module. Each API entry shows its current usage, quota limits, and a link to its documentation.

### 9.2 Inspecting Enabled APIs from the Command Line

```bash
# List all APIs enabled on the project
gcloud services list --enabled --project=my-gcp-project

# Check whether a specific API is enabled
gcloud services list --enabled \
  --filter="name:gkemulticloud.googleapis.com" \
  --project=my-gcp-project

# View details of a specific API
gcloud services describe gkemulticloud.googleapis.com \
  --project=my-gcp-project
```

### 9.3 What Each API Enables

| API | What It Enables |
|---|---|
| **GKE Multi-Cloud** (`gkemulticloud`) | Core API for managing attached clusters — registration, platform version management, and cluster lifecycle |
| **GKE Connect** (`gkeconnect`) | Manages the Connect agent's communication channel between AKS and Google Cloud |
| **Connect Gateway** (`connectgateway`) | Powers the `kubectl` proxy that lets engineers access the AKS cluster using Google Cloud identity |
| **Cloud Resource Manager** (`cloudresourcemanager`) | Access to the GCP project hierarchy — required for project ID and number lookups |
| **Anthos** (`anthos`) | Activates Anthos platform entitlements, enabling fleet features including Config Management, Policy Controller, and Service Mesh |
| **Cloud Monitoring** (`monitoring`) | Receives Managed Prometheus metrics and powers alerting, dashboards, and PromQL queries |
| **Cloud Logging** (`logging`) | Receives AKS system component and workload logs into Log Explorer |
| **GKE Hub** (`gkehub`) | Manages Fleet membership registrations and fleet feature configurations |
| **Operations Config Monitoring** (`opsconfigmonitoring`) | Monitors the health of the cluster's observability pipeline |
| **Kubernetes Metadata** (`kubernetesmetadata`) | Collects Kubernetes metadata (namespace labels, workload annotations) to enrich log and metric records |

These APIs are enabled non-destructively. Removing the module deployment does not disable them, protecting other workloads in the same project that may depend on them.

---

## 10. Google Cloud Service Mesh on Attached Clusters

### 10.1 What Anthos Service Mesh Brings to AKS

The optional `attached-install-mesh` sub-module installs **Google Cloud Service Mesh (ASM)** — Google's distribution of Istio — on the AKS cluster. This gives workloads running in Azure the full Istio service mesh feature set, managed through the same Google Cloud interfaces used for service mesh on GKE.

### 10.2 Core Service Mesh Capabilities

**Mutual TLS (mTLS)** encrypts all pod-to-pod communication at the Envoy sidecar layer automatically. Applications do not implement TLS themselves. mTLS applies even to applications that predate the mesh deployment.

**Traffic Management** uses Istio's VirtualService and DestinationRule resources to control traffic flow between services: canary deployments by percentage, circuit breaking, retry policies, and traffic mirroring for shadow testing.

**Observability** generates distributed traces, service-to-service metrics (request rate, error rate, latency), and access logs for all inter-service communication — without application code changes. Telemetry flows to Cloud Trace, Cloud Monitoring, and Cloud Logging.

**Security Policies** use AuthorizationPolicy resources to define which services may communicate with which others, implementing zero-trust networking at the application layer.

### 10.3 Viewing the Service Mesh in the Console

After installing the service mesh, navigate to:

**Anthos > Service Mesh**

This page shows a topology graph of all services in the mesh, with live metrics for request rate, error rate, and p99 latency on each edge. Clicking a service shows its traffic details, health, and any active security policies.

The mesh dashboard is also accessible from:

**Kubernetes Engine > Clusters > azure-aks-cluster > Observability**

### 10.4 Exploring the Mesh from the Command Line

```bash
# Confirm Istio control plane is running
kubectl get pods -n istio-system

# Check the Istio version installed
kubectl get deployment istiod -n istio-system -o jsonpath='{.spec.template.spec.containers[0].image}'

# List all services currently in the mesh
kubectl get svc --all-namespaces -l istio

# Check sidecar injection status across namespaces
kubectl get namespace -L istio-injection

# Enable sidecar injection for a namespace
kubectl label namespace default istio-injection=enabled

# Verify sidecar is injected in a pod
kubectl describe pod my-pod | grep istio-proxy

# View mesh-wide configuration
kubectl get meshconfig -n istio-system -o yaml
```

### 10.5 Exploring mTLS Enforcement

```bash
# Check the current mTLS mode across the mesh
kubectl get peerauthentication --all-namespaces

# View the default mesh-wide mTLS policy
kubectl get peerauthentication -n istio-system

# Inspect a certificate issued to a pod's sidecar
kubectl exec my-pod -c istio-proxy -- \
  openssl s_client -connect other-service:8080 2>&1 | grep -A5 "Certificate chain"

# Check Envoy's view of upstream cluster TLS settings
kubectl exec my-pod -c istio-proxy -- \
  pilot-agent request GET clusters | grep tls
```

### 10.6 Certificate Authority Options

When installing the service mesh, the certificate authority for mTLS certificates is selected from three options:

**Mesh CA** (default) is a Google-managed CA built into Anthos Service Mesh. Certificates are automatically provisioned, rotated, and revoked with no infrastructure overhead. Recommended for most deployments.

**Google Certificate Authority Service (GCP CAS)** integrates the mesh with Google Cloud's enterprise CA product. Suited to regulated environments requiring a fully auditable CA, custom root certificates, and compliance reporting. Navigate to **Certificate Authority Service** in the Console to view issued certificates and CA configuration.

**Citadel** (Istiod CA) uses Istio's built-in CA. Primarily useful when migrating an existing open-source Istio installation to Anthos Service Mesh.

### 10.7 Exploring Traffic Management

```bash
# List all Istio traffic management resources
kubectl get virtualservice,destinationrule,gateway --all-namespaces

# Example: apply a canary split sending 10% of traffic to a new version
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
  namespace: default
spec:
  hosts:
  - my-app
  http:
  - route:
    - destination:
        host: my-app
        subset: stable
      weight: 90
    - destination:
        host: my-app
        subset: canary
      weight: 10
EOF

# View the traffic split taking effect
kubectl get virtualservice my-app -o yaml
```

### 10.8 Tool Bootstrapping and Air-Gap Support

The service mesh sub-module downloads `asmcli`, the Google Cloud SDK, and `jq` at installation time. All three download sources are configurable, enabling the URLs to point to an internal artifact repository. This makes the module deployable in air-gapped environments where direct internet access is restricted by security policy.

---

## 11. Configuration Reference

### 11.1 Cluster Configuration

| Option | Default | Description |
|---|---|---|
| Cluster name prefix | `azure-aks-cluster` | Base name for the AKS cluster and all associated Azure resources |
| Azure region | `westus2` | Azure region where the AKS cluster and resource group are deployed |
| Kubernetes version | `1.34` | Kubernetes minor version for the AKS control plane and nodes |
| GKE platform version | `1.34.0-gke.1` | Version of the GKE Connect agent and attached cluster components — must be compatible with the Kubernetes version |
| Node count | `3` | Number of worker nodes in the default node pool |
| Node VM size | `Standard_D2s_v3` | Azure VM SKU for all nodes in the default node pool |
| GCP region | `us-central1` | Google Cloud region where the attached cluster record and fleet membership are stored |

### 11.2 Access Control

| Option | Default | Description |
|---|---|---|
| Trusted users | *(deploying user)* | List of Google Cloud user email addresses granted cluster-admin access via Connect Gateway. The identity running the deployment is always included automatically. |

### 11.3 Azure Authentication

These four values are required to allow the module to create and manage resources in Azure. They are always treated as sensitive and never appear in logs or plan output.

| Option | Description |
|---|---|
| Azure Client ID | Application ID of the Azure Service Principal used for authentication |
| Azure Client Secret | Secret credential for the Azure Service Principal |
| Azure Tenant ID | Azure Active Directory tenant that owns the Service Principal |
| Azure Subscription ID | Azure subscription where resources will be created |

### 11.4 GCP Project

| Option | Description |
|---|---|
| GCP Project ID | Destination Google Cloud project where the attached cluster is registered and fleet membership is created |

### 11.5 Service Mesh Options (attached-install-mesh sub-module)

| Option | Default | Description |
|---|---|---|
| Certificate authority | `mesh_ca` | CA for mTLS certificates: `mesh_ca` (Google-managed), `gcp_cas` (Certificate Authority Service), or `citadel` (Istiod CA) |
| Enable cluster roles | `false` | Authorises creation of ClusterRoles required by ASM components |
| Enable cluster labels | `false` | Authorises addition of topology and mesh labels to cluster nodes |
| Enable GCP components | `false` | Installs GCP-specific mesh components including the Stackdriver telemetry adapter |
| Enable GCP APIs | `false` | Automatically enables additional GCP APIs required by the mesh |
| Enable GCP IAM roles | `false` | Grants required IAM roles to the mesh service account |
| Enable MeshConfig init | `false` | Initialises the MeshConfig resource with mesh-wide default settings |
| Enable namespace creation | `false` | Creates the `istio-system` namespace if it does not already exist |
| Enable registration | `false` | Re-registers the cluster with the fleet (redundant if the root module has already done this) |
| gcloud SDK version | `491.0.0` | Version of the Google Cloud SDK downloaded during installation |
| asmcli version | `1.22` | Version of the `asmcli` tool used for mesh installation |
| gcloud download URL | *(Google CDN)* | Override to point to an internal mirror for air-gapped environments |
| asmcli download URL | *(Google GCS)* | Override to point to an internal mirror for air-gapped environments |

---

## 12. Deployment Workflow

### 12.1 Prerequisites

1. A Google Cloud project with billing enabled.
2. An Azure subscription and a Service Principal with Contributor access.
3. The Google Cloud SDK installed and authenticated:

```bash
gcloud auth application-default login
gcloud config set project my-gcp-project
```

4. Azure CLI installed and Service Principal credentials exported:

```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

### 12.2 Deployment Steps

```bash
# Initialise and deploy
terraform init
terraform plan
terraform apply
```

Expect approximately 12–15 minutes. The longest phase is AKS cluster provisioning in Azure (6–9 minutes).

### 12.3 Expected Deployment Duration

| Phase | Duration |
|---|---|
| Google Cloud API enablement | 1–2 min |
| Azure resource group creation | < 1 min |
| AKS cluster provisioning | 6–9 min |
| Bootstrap manifest installation | 2–3 min |
| GKE attached cluster registration | 1–2 min |
| **Total** | **~12–15 min** |

### 12.4 Verifying a Successful Deployment

After `terraform apply` completes, run these commands to confirm every layer is working:

```bash
# 1. Confirm fleet membership is active
gcloud container fleet memberships list --project=my-gcp-project

# 2. Confirm the attached cluster record is healthy
gcloud container attached clusters describe azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project

# 3. Fetch credentials and connect via Connect Gateway
gcloud container attached clusters get-credentials azure-aks-cluster \
  --location=us-central1 --project=my-gcp-project

# 4. Verify node access
kubectl get nodes -o wide

# 5. Confirm the Connect agent is running
kubectl get pods -n gke-connect

# 6. Confirm Managed Prometheus collector is running
kubectl get pods -n gmp-system

# 7. Confirm logs are flowing in Cloud Logging
gcloud logging read \
  'resource.labels.cluster_name="azure-aks-cluster"' \
  --project=my-gcp-project --limit=5

# 8. Confirm metrics are flowing in Cloud Monitoring
gcloud monitoring metrics list \
  --filter='metric.type=starts_with("kubernetes.io/node")' \
  --project=my-gcp-project
```

Then open the Google Cloud Console and verify visually:

- **Kubernetes Engine > Clusters** — AKS cluster appears with type `Attached` and a green status.
- **Kubernetes Engine > Fleet** — Cluster is listed as a fleet member.
- **Logging > Log Explorer** — Logs are visible with `resource.labels.cluster_name="azure-aks-cluster"`.
- **Monitoring > Metrics Explorer** — Kubernetes metrics are queryable for the cluster.

### 12.5 Teardown

```bash
terraform destroy
```

This deregisters the cluster from Google Cloud, removes the Connect agent from AKS, and deletes all Azure resources. The Google Cloud APIs enabled during deployment are intentionally left enabled to avoid disrupting other workloads sharing the same project.

---

## 13. Key Learning Outcomes for Platform Engineers

### 13.1 Multi-Cloud Kubernetes Management

This module demonstrates Google Cloud's core multi-cloud insight: **the management plane can be decoupled from the data plane**. Workloads run in Azure on AKS infrastructure. The management plane — access control, observability, policy, service mesh — runs in Google Cloud and applies uniformly to the Azure cluster. Engineers who internalise this separation are equipped to design platform strategies for organisations with heterogeneous cloud environments.

### 13.2 Zero-Trust Cross-Cloud Authentication

The OIDC federation pattern shown here is the foundation of zero-trust authentication across cloud environments. Understanding how OIDC issuer endpoints, JWKS, and token validation eliminate the need for shared credentials is a transferable skill that applies to GKE Workload Identity, GitHub Actions, Terraform Cloud, and any other system that uses federated identity.

### 13.3 Centralised Observability Architecture

Routing AKS logs and metrics to Cloud Logging and Cloud Monitoring demonstrates that Google Cloud's observability stack is not limited to GKE. It is designed to be the observability backend for any Kubernetes cluster, regardless of where it runs. The single-pane-of-glass this creates reduces the operational burden on platform teams managing mixed cloud environments.

### 13.4 Service Mesh as a Platform Concern

Installing Anthos Service Mesh on an AKS cluster shows that service mesh is a platform-level concern, not a per-cluster one. The same mesh management interfaces, certificate authorities, traffic policies, and observability signals apply whether workloads run on GKE or on a fleet-enrolled AKS cluster — the foundation for portable microservice architectures that span cloud providers.

### 13.5 GKE Fleet as a Platform Primitive

Fleet is the most important concept for platform engineers building multi-cluster environments on Google Cloud. This module's single attached cluster is the simplest possible fleet topology, but it establishes the mental model that scales to dozens of clusters across multiple clouds and on-premises environments — all governed, observed, and configured from a single GCP project.

### 13.6 Console Navigation Summary

| Feature | Console Location |
|---|---|
| Attached cluster status and details | Kubernetes Engine > Clusters |
| Fleet membership and feature health | Kubernetes Engine > Fleet |
| Log Explorer for AKS logs | Logging > Log Explorer |
| Log-based metrics | Logging > Log-based Metrics |
| Metrics Explorer and PromQL | Monitoring > Metrics Explorer |
| Built-in Kubernetes dashboards | Monitoring > Dashboards |
| Alerting policies | Monitoring > Alerting |
| Service Mesh topology and metrics | Anthos > Service Mesh |
| Workload Identity Federation pools | IAM & Admin > Workload Identity Federation |
| Enabled APIs | APIs & Services > Enabled APIs & Services |
| Certificate Authority (GCP CAS option) | Certificate Authority Service |
| Fleet feature configuration | Kubernetes Engine > Fleet > Feature manager |
