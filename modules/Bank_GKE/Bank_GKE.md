# Bank_GKE Module

## Overview

The **Bank_GKE** module deploys a production-grade microservices banking application on a single Google Kubernetes Engine (GKE) cluster. It is designed as a focused learning environment for platform engineers who want hands-on experience with core GKE capabilities, Cloud Service Mesh, Anthos Config Management, and cloud-native observability — within a single-region, single-cluster deployment that is simpler to reason about than a multi-cluster setup.

The application deployed is **Bank of Anthos** — an open-source, HTTP-based banking simulation built by Google Cloud Platform. It consists of nine microservices written in Python and Java, communicating over a service mesh, and exposed to the internet via a GKE-managed global HTTPS load balancer with automatic TLS certificate management.

This module is intended for **educational purposes**. It is not a production banking system. Its value lies in the breadth of GKE Enterprise features it exercises in a realistic, working application context.

> **Relationship to MC_Bank_GKE**: This module covers the same application and most of the same GKE features as `MC_Bank_GKE`, but deploys to a single cluster in a single region. It adds **Anthos Config Management** and **Service Level Objectives (SLOs)** which are not covered by `MC_Bank_GKE`. If you have completed `MC_Bank_GKE`, treat this module as a complement focused on Config Management, SLOs, and single-cluster ingress patterns.

---

## What You Will Learn

By deploying and exploring this module, a platform engineer will gain practical experience with:

- Deploying and managing a **GKE cluster** (Autopilot or Standard) in a single region
- Registering a cluster in a **GKE Fleet** for centralised management and feature enablement
- Enabling and operating **Cloud Service Mesh (Anthos Service Mesh)** with automatic sidecar injection and mTLS
- Configuring **GKE Ingress** with a regional backend, managed TLS certificate, HTTPS redirect, and BackendConfig health checks
- Using **Google-managed SSL/TLS certificates** with automatic provisioning via `ManagedCertificate`
- Applying **GKE Security Posture** scanning and workload vulnerability detection
- Working with **Workload Identity** to bind Kubernetes workloads to GCP service accounts without key files
- Using **Managed Prometheus** for cluster and workload observability
- Defining and monitoring **Service Level Objectives (SLOs)** for each microservice in Cloud Monitoring
- Enabling **Anthos Config Management** (Config Sync) to synchronise Kubernetes configuration from a Git repository
- Configuring the **GCS FUSE CSI driver** for mounting Cloud Storage buckets as pod volumes
- Enabling the **GKE Gateway API** for advanced traffic management
- Designing and operating a **custom VPC** with subnet isolation, Cloud NAT, and firewall policies

---

## Architecture Overview

The module creates the following architecture:

```
Internet
    │
    ▼
Global External Load Balancer (Google Cloud)
    │  ┌─ HTTPS redirect (HTTP 301)
    │  ├─ Google-managed TLS certificate
    │  └─ sslip.io dynamic DNS domain
    │
    ▼
GKE Ingress
    │  ├─ BackendConfig (health checks, IAP placeholder)
    │  └─ NEG (Network Endpoint Group)
    │
    ▼
GKE Cluster (single region)
    │
    ├─ bank-of-anthos namespace (ASM-injected)
    │    └─ 9 microservices + 2 PostgreSQL StatefulSets
    │
    ├─ Cloud Service Mesh (ASM)
    │    └─ mTLS, telemetry, traffic management
    │
    └─ GKE Fleet
         ├─ ASM feature
         └─ Config Management feature (optional)
```

### Key Architectural Decisions

**Single cluster, single region**: All workloads run in one cluster in one GCP region. This simplifies the architecture and focuses attention on application-level features (service mesh, ingress, observability) without the additional complexity of cross-cluster coordination.

**Standard GKE Ingress vs Multi-Cluster Ingress**: Unlike `MC_Bank_GKE`, this module uses a standard Kubernetes `Ingress` resource backed by a GKE-managed Global Layer 7 load balancer. This is the most common ingress pattern for single-cluster GKE deployments and is suitable for most production workloads that do not require multi-region failover.

**Anthos Config Management**: This module optionally enables Config Sync, which continuously reconciles cluster configuration against a Git repository. This enables a GitOps workflow where the desired state of the cluster is expressed as code in a repository.

**Service Level Objectives**: The module creates Cloud Monitoring SLOs for all nine Bank of Anthos microservices, providing a ready-made framework for understanding SLO-based reliability engineering.

**Namespace as mesh boundary**: The `bank-of-anthos` namespace is labelled with `istio.io/rev=asm-managed`, triggering automatic Envoy sidecar injection into every pod in that namespace.

---

## GKE Cluster Features

### Autopilot vs Standard Clusters

This module supports both GKE **Autopilot** and **Standard** cluster modes, selectable at deployment time. Autopilot is the default.

| Feature | Autopilot | Standard |
|---|---|---|
| Node management | Fully managed by Google | Self-managed node pools |
| Node provisioning | Automatic, per-pod | Manual or cluster autoscaler |
| Pricing model | Per-pod resource usage | Per-node (always-on) |
| Spot/preemptible nodes | Supported via pod config | Spot nodes configured in node pool |
| Workload Identity | Enabled automatically | Must be explicitly enabled |
| Security hardening | Enforced by default | Configurable |
| Best for | Simplicity and cost efficiency | Maximum control and customisation |

In **Standard mode**, this module provisions a node pool with the following defaults:
- **Machine type**: `e2-standard-2` (2 vCPU, 8 GB RAM)
- **Disk**: 50 GB SSD (`pd-ssd`)
- **Spot instances**: enabled — nodes are preemptible, reducing cost by up to 80%, appropriate for a learning environment
- **Node count**: 2 nodes, spread across all available zones in the region

**Explore in the Console**: Navigate to **Kubernetes Engine → Clusters** to see the cluster, its mode (Autopilot/Standard), version, and node count. Click the cluster name and select the **Nodes** tab to see individual node status, machine type, and zone placement.

**Inspect via CLI:**
```bash
# Confirm cluster mode and version
gcloud container clusters describe gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="table(name,autopilot.enabled,currentMasterVersion,status)"

# List nodes and their status
kubectl get nodes -o wide

# List node pools (Standard only)
gcloud container node-pools list \
  --cluster gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="table(name,config.machineType,config.spot,initialNodeCount,status)"
```

### Release Channel

The cluster is enrolled in the **REGULAR release channel** by default. GKE release channels automate cluster upgrades and ensure nodes and control planes stay on a supported, tested version.

| Channel | Update cadence | Best for |
|---|---|---|
| RAPID | Immediately after release | Feature testing, dev environments |
| REGULAR | 2–4 weeks after RAPID | Most production workloads |
| STABLE | 2–4 weeks after REGULAR | Risk-averse, compliance-sensitive workloads |
| EXTENDED | Up to 24 months support | Long-running, infrequently updated clusters |

**Explore in the Console**: Navigate to **Kubernetes Engine → Clusters → (cluster name) → Details** and look for the **Release channel** field. The console shows the current master version and the next available upgrade.

**Inspect via CLI:**
```bash
# Check release channel and current version
gcloud container clusters describe gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="value(releaseChannel.channel,currentMasterVersion)"

# Check what versions are available in each channel
gcloud container get-server-config \
  --region REGION --project PROJECT_ID \
  --format="yaml(channels)"
```

### Security Posture

The cluster has **Security Posture** enabled in `BASIC` mode with `VULNERABILITY_BASIC` scanning. This continuously evaluates the cluster against security best practices and scans running workload container images for known CVEs.

**What Security Posture provides:**
- **Workload configuration auditing**: flags pods running as root, containers without resource limits, missing liveness/readiness probes, and other misconfigurations
- **Vulnerability scanning**: scans container images in running workloads against OS and language package vulnerability databases
- **Actionable findings**: surfaces issues in the Security Posture dashboard with severity ratings and remediation guidance

This is distinct from Artifact Registry vulnerability scanning (which scans images at push time) — Security Posture scans *running* workloads, catching drift between what was pushed and what is deployed.

**Explore in the Console**: Navigate to **Kubernetes Engine → Security Posture** to see workload configuration findings and vulnerability scan results grouped by severity.

**Inspect via CLI:**
```bash
# View the cluster's security posture configuration
gcloud container clusters describe gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="value(securityPostureConfig)"
```

### Workload Identity

For **Standard clusters**, **Workload Identity** is enabled. This is the recommended mechanism for granting Kubernetes workloads access to Google Cloud APIs without static service account key files.

**How it works:**
1. The cluster gets a Workload Identity Pool: `PROJECT_ID.svc.id.goog`
2. A Kubernetes Service Account (KSA) is annotated to link it to a Google Service Account (GSA)
3. The GSA is granted an IAM binding allowing the KSA to impersonate it
4. Pods using that KSA obtain short-lived tokens via the GKE metadata server — no key files required

In this module, Bank of Anthos uses Workload Identity to send traces to Cloud Trace and metrics to Cloud Monitoring.

**Explore in the Console**: Navigate to **Kubernetes Engine → Clusters → (cluster name) → Details** and confirm the Workload Identity field shows `PROJECT_ID.svc.id.goog`.

**Inspect via CLI:**
```bash
# Confirm Workload Identity pool
gcloud container clusters describe gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="value(workloadIdentityConfig.workloadPool)"

# View the KSA annotation linking it to a GSA
kubectl get serviceaccount bank-of-anthos \
  -n bank-of-anthos -o yaml | grep iam.gke.io
```

### Managed Prometheus

**Managed Service for Prometheus** is enabled — Google's fully managed, Prometheus-compatible monitoring solution built into GKE.

**What it provides:**
- Prometheus-compatible metrics collection without deploying or managing a Prometheus server
- Automatic scraping of Kubernetes system components (`kube-state-metrics`, `node-exporter`, `kubelet`)
- Long-term storage backed by Google's Monarch metrics infrastructure
- Query interface via Cloud Monitoring or PromQL
- Out-of-the-box dashboards for cluster health, node utilisation, and workload metrics

The module enables `SYSTEM_COMPONENTS` metric collection by default. Workload-level scraping requires a `PodMonitoring` or `ClusterPodMonitoring` custom resource (see the Hands-On Exercises section).

**Explore in the Console**: Navigate to **Monitoring → Dashboards → GKE** and open **GKE Cluster Overview** for node and pod metrics, or **Kubernetes Engine Prometheus Overview** for Prometheus metrics.

**Inspect via CLI:**
```bash
# Confirm Managed Prometheus is enabled
gcloud container clusters describe gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="value(monitoringConfig.managedPrometheusConfig.enabled)"

# List any PodMonitoring resources deployed
kubectl get podmonitoring -A
```

### GCS FUSE CSI Driver

The **Cloud Storage FUSE CSI driver** is enabled, allowing pods to mount Google Cloud Storage buckets as a POSIX-compatible filesystem volume.

**Use cases:**
- Sharing large static assets across pods without baking them into container images
- Mounting read-only reference data updated externally by a CI pipeline
- Offloading write workloads (logs, exports) directly to GCS

**Explore in the Console**: Navigate to **Kubernetes Engine → Clusters → (cluster name) → Details** and look for **GCS FUSE CSI driver** under the Storage section — it should show as **Enabled**.

**Inspect via CLI:**
```bash
# Confirm GCS FUSE CSI driver is enabled
gcloud container clusters describe gke-cluster \
  --region REGION --project PROJECT_ID \
  --format="value(addonsConfig.gcsFuseCsiDriverConfig.enabled)"

# Verify the driver pods are running
kubectl get pods -n kube-system -l k8s-app=gcs-fuse-csi-driver
```

### Gateway API

The **Gateway API** is enabled on `CHANNEL_STANDARD`. Gateway API is the successor to Kubernetes Ingress, providing a more expressive, role-oriented model for traffic routing.

| Capability | Ingress | Gateway API |
|---|---|---|
| Traffic splitting | Limited / annotation-based | Native (HTTPRoute weights) |
| Header-based routing | Annotation-based | Native |
| Role separation | Single resource | Separate Gateway + Route objects |
| Protocol support | HTTP/HTTPS | HTTP, HTTPS, TCP, gRPC, TLS |

**Inspect via CLI:**
```bash
# List available GatewayClasses
kubectl get gatewayclass

# List any deployed Gateway and HTTPRoute resources
kubectl get gateway,httproute -A
```

### Cost Management

**GKE Cost Management** is enabled. This attributes resource costs (CPU, memory, storage) to Kubernetes namespaces and labels, enabling per-team or per-workload cost visibility.

**Explore in the Console**: Navigate to **Billing → Reports** and add a grouping by **Label → k8s-namespace** to see cost attribution by workload. The per-cluster breakdown is also visible under **Kubernetes Engine → Clusters → (cluster name) → Observability → Cost**.

---

## Networking

### VPC Design

The cluster is deployed into a **custom VPC** with GLOBAL routing mode. Using a global VPC means that even though only one region is used today, subnets in other regions can be added later without requiring VPC peering or additional routing configuration.

The VPC uses `auto_create_subnetworks = false` — no default subnets are created. Every subnet is explicitly defined with CIDR ranges sized to match the cluster's requirements. Private Google Access is enabled on the subnet so pods can reach Google APIs without traversing the internet.

**Explore in the Console**: Navigate to **VPC Network → VPC Networks → vpc-network** to see the subnet, its primary and secondary IP ranges, and the region.

**Inspect via CLI:**
```bash
# View the VPC and its subnets
gcloud compute networks describe vpc-network --project PROJECT_ID

# List subnets with all IP ranges
gcloud compute networks subnets list \
  --network vpc-network --project PROJECT_ID \
  --format="table(name,region,ipCidrRange,secondaryIpRanges[].rangeName,secondaryIpRanges[].ipCidrRange)"
```

### Subnet and IP Allocation

The cluster subnet uses the following default IP ranges, all configurable at deployment time:

| Range type | Default CIDR | Size | Purpose |
|---|---|---|---|
| Primary (nodes) | `10.132.0.0/16` | 65,536 IPs | Node VM addresses |
| Pod secondary range | `10.62.128.0/17` | 32,768 IPs | Pod IP addresses (VPC-native) |
| Service secondary range | `10.64.128.0/20` | 4,096 IPs | ClusterIP service addresses |

**VPC-native clusters**: GKE uses alias IP ranges, meaning pod IP addresses are drawn directly from the subnet's secondary range and are routable within the VPC without IP masquerading. This is a prerequisite for Container-native load balancing with Network Endpoint Groups (NEGs).

### Cloud Router and Cloud NAT

The subnet is paired with a **Cloud Router** and **Cloud NAT gateway**, providing outbound internet connectivity for nodes and pods without requiring public IP addresses on nodes.

**Cloud NAT** configuration:
- **IP allocation**: `AUTO_ONLY` — Google manages external IPs automatically
- **Scope**: applies to all IP ranges in the subnet (node, pod, and service ranges)
- **Logging**: errors only — NAT translation failures are sent to Cloud Logging

**Explore in the Console**: Navigate to **Network Services → Cloud NAT** to see the NAT gateway, its configuration, and connection counts.

**Inspect via CLI:**
```bash
# Describe the Cloud NAT gateway
gcloud compute routers nats describe nat-config \
  --router vpc-router \
  --region REGION --project PROJECT_ID

# Check for NAT errors in Cloud Logging
gcloud logging read \
  'resource.type="nat_gateway" severity>=WARNING' \
  --project PROJECT_ID --limit 20
```

### Firewall Rules

The module creates five firewall rules:

| Rule | Direction | Source | Ports | Purpose |
|---|---|---|---|---|
| `allow-lb-health-checks` | Ingress | `130.211.0.0/22`, `35.191.0.0/16` | TCP 80 | Load balancer health probes to pods |
| `allow-nfs-health-checks` | Ingress | `130.211.0.0/22`, `35.191.0.0/16` | TCP 2049 | NFS volume health checks |
| `allow-ssh-iap` | Ingress | `35.235.240.0/20` | TCP 22 | SSH access via Identity-Aware Proxy tunnel |
| `allow-internal-pods` | Ingress | Pod CIDR (`10.62.128.0/17`) | All | Pod-to-pod communication across nodes |
| `allow-http-https` | Ingress | `0.0.0.0/0` | TCP 80, 443 | External HTTP/HTTPS traffic to the load balancer |

**Notable differences from MC_Bank_GKE**: This module uses **IAP-tunnelled SSH** (`35.235.240.0/20`) instead of direct SSH from `0.0.0.0/0`, and includes an explicit **NFS health check rule** for port 2049. The IAP tunnel approach is more secure — SSH access to nodes requires an authenticated GCP identity and does not expose port 22 to the internet.

**Explore in the Console**: Navigate to **VPC Network → Firewall** and filter by network `vpc-network`.

**Inspect via CLI:**
```bash
# List all firewall rules on the VPC
gcloud compute firewall-rules list \
  --filter="network:vpc-network" --project PROJECT_ID \
  --format="table(name,direction,sourceRanges.list():label=SOURCES,allowed[].map().firewall_rule().list():label=ALLOW)"
```

### Static External IP

One global static external IP address is reserved and named `bank-of-anthos`. This IP is referenced by the GKE `Ingress` resource annotation `kubernetes.io/ingress.global-static-ip-name`, which pins the load balancer to a known, stable address.

**Inspect via CLI:**
```bash
# View reserved global IP addresses
gcloud compute addresses list --global --project PROJECT_ID \
  --format="table(name,address,status)"
```

---

## GKE Fleet and Cloud Service Mesh

### GKE Fleet

The cluster is registered as a **Fleet Membership** immediately after creation. The fleet provides a unified control plane for enabling and managing features across clusters — even when there is only one cluster, fleet membership is required to use Cloud Service Mesh and Anthos Config Management.

**Explore in the Console**: Navigate to **Kubernetes Engine → Fleets** to see the registered cluster, its membership state, and the features enabled on it.

**Inspect via CLI:**
```bash
# View fleet membership state
gcloud container fleet memberships list --project PROJECT_ID

gcloud container fleet memberships describe gke-cluster \
  --location global --project PROJECT_ID

# List all fleet features and their per-cluster states
gcloud container fleet features list --project PROJECT_ID
```

### Cloud Service Mesh (ASM)

**Cloud Service Mesh (CSM)** is enabled by default with `MANAGEMENT_AUTOMATIC` mode. Google provisions and manages the Istio control plane entirely — no `istiod` pods appear in the cluster, and control plane upgrades happen automatically aligned with the cluster's release channel.

**Data plane**: Envoy proxy sidecars are injected into every pod in the `bank-of-anthos` namespace. All pod-to-pod traffic passes through the sidecar, which enforces mTLS, collects telemetry, and applies traffic policies.

**Control plane**: Google-managed, running in Google's infrastructure. You interact with the mesh only through Kubernetes custom resources (`VirtualService`, `DestinationRule`, `PeerAuthentication`, `AuthorizationPolicy`).

**Explore in the Console**: Navigate to **Kubernetes Engine → Service Mesh** to see the live service topology graph, per-service golden signals (latency, traffic, errors, saturation), and control plane health.

**Inspect via CLI:**
```bash
# Overall mesh health
gcloud container fleet mesh describe --project PROJECT_ID

# Verify ASM components are running
kubectl get pods -n istio-system
kubectl get pods -n asm-system

# View the managed ASM revision
kubectl get controlplanerevision -n istio-system

# Confirm sidecar injection label on the namespace
kubectl get namespace bank-of-anthos --show-labels

# Confirm every pod has an istio-proxy sidecar
kubectl get pods -n bank-of-anthos \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'
```

### Mutual TLS

With ASM enabled, all pod-to-pod communication within the `bank-of-anthos` namespace is encrypted with **mutual TLS** by default. Each sidecar receives a short-lived X.509 certificate encoding its SPIFFE workload identity:

```
spiffe://PROJECT_ID.svc.id.goog/ns/bank-of-anthos/sa/bank-of-anthos
```

**Inspect via CLI:**
```bash
# List PeerAuthentication policies (controls mTLS mode)
kubectl get peerauthentication -n bank-of-anthos
kubectl get peerauthentication -n istio-system

# Inspect the mTLS certificate from inside a running sidecar
FRONTEND_POD=$(kubectl get pod -n bank-of-anthos \
  -l app=frontend -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n bank-of-anthos $FRONTEND_POD -c istio-proxy -- \
  openssl s_client \
  -connect userservice.bank-of-anthos.svc.cluster.local:8080 \
  -showcerts 2>/dev/null | openssl x509 -noout -text | \
  grep -E "Subject:|URI:"
```

### ASM Observability

ASM automatically generates the four golden signals for every service-to-service call from sidecar telemetry — no application instrumentation required.

**Service metrics** in Cloud Monitoring under the `istio.io` namespace:

| Metric | Description |
|---|---|
| `istio.io/service/server/request_count` | Inbound request volume per service |
| `istio.io/service/server/response_latencies` | Inbound latency distribution |
| `istio.io/service/client/request_count` | Outbound requests per source/destination |
| `istio.io/service/client/roundtrip_latencies` | End-to-end client-side latency |

**Distributed tracing** is enabled via the Stackdriver ConfigMap applied to `istio-system`. Every inbound request generates a trace spanning all microservice hops, visible in **Trace → Trace List** in the Cloud Console.

**Inspect via CLI:**
```bash
# List Istio traffic management resources
kubectl get virtualservice,destinationrule,serviceentry -n bank-of-anthos

# View Envoy's live routing table for the frontend sidecar
kubectl exec -n bank-of-anthos $FRONTEND_POD -c istio-proxy -- \
  pilot-agent request GET routes | python3 -m json.tool | head -60

# View AuthorizationPolicies
kubectl get authorizationpolicy -n bank-of-anthos
```

---

## Anthos Config Management

Anthos Config Management (ACM) brings GitOps-style configuration synchronisation to GKE clusters. In this module, **Config Sync** watches a Git repository and automatically reconciles the desired Kubernetes state declared in that repository with the live state in the cluster. This enables repeatable, auditable, and version-controlled configuration management without manual `kubectl apply` operations.

> **This section is unique to Bank_GKE.** The `MC_Bank_GKE` module does not enable Anthos Config Management.

### What Is Config Sync?

Config Sync is the component of ACM responsible for pulling manifests from a Git source and applying them to the cluster. It runs as a set of pods in the `config-management-system` namespace and continuously reconciles cluster state. If a resource is manually edited or deleted, Config Sync detects the drift and restores it.

Key characteristics:

| Property | Value |
|---|---|
| Source of truth | Git repository (configurable URL and branch) |
| Policy directory | Configurable subdirectory within the repo |
| Sync mechanism | Periodic poll + event-driven |
| Drift detection | Continuous — restores deleted or modified resources |
| Cluster scope | Cluster-scoped and namespace-scoped resources |

### Console Navigation

Navigate to the ACM dashboard in the Google Cloud Console:

**Kubernetes Engine → Config → Config Management**

From this view you can see:

- The sync status of each registered cluster (Synced / Pending / Error)
- The commit SHA currently applied on the cluster
- Any errors or conflicts preventing sync
- The configured sync source (repo URL, branch, policy directory)

### Viewing Config Sync Status

```bash
# Check Config Sync installation status
gcloud container fleet config-management status \
  --project=${PROJECT_ID}

# List Config Sync pods
kubectl get pods -n config-management-system

# List the RootSync resource that drives synchronisation
kubectl get rootsync -n config-management-system -o yaml

# View the current sync status — shows last synced commit and any errors
kubectl describe rootsync root-sync -n config-management-system

# View the RepoSync resources (namespace-scoped syncs, if any)
kubectl get reposync -A
```

The `RootSync` resource is the primary driver. Its `status.sync.commit` field shows the last applied Git commit SHA, and `status.conditions` reports any error messages if synchronisation has failed.

### How Config Sync Applies Resources

Config Sync uses a pull-based model:

1. The `reconciler` pod reads the configured Git repository and branch.
2. It computes the set of Kubernetes manifests present in the policy directory.
3. It applies any resources that are missing or differ from the live cluster state.
4. It records the applied commit SHA in the `RootSync` status.

Resources managed by Config Sync are annotated with `configmanagement.gke.io/managed: enabled` and `configsync.gke.io/resource-id`. If you try to manually edit or delete these resources, Config Sync will revert the change on its next reconciliation cycle.

```bash
# See which resources are managed by Config Sync
kubectl get all -n bank-of-anthos -o yaml | \
  grep -A2 "configmanagement.gke.io/managed"
```

### Exploring the Sync Repository

The module configures Config Sync to point at a Git repository. To see the current repository and branch configured:

```bash
# Show the sync source configuration
kubectl get rootsync root-sync -n config-management-system \
  -o jsonpath='{.spec.git}' | python3 -m json.tool
```

The output will show:
- `repo` — the Git repository URL
- `branch` — the branch being tracked
- `dir` — the subdirectory within the repo (policy directory)
- `auth` — authentication method (`none` for public repos, `token` or `ssh` for private)

### Policy Controller

ACM also enables **Policy Controller**, which is built on OPA Gatekeeper. Policy Controller enforces custom policy rules as Kubernetes admission webhooks. Any resource that violates a constraint is rejected at admission time, before it reaches the cluster.

**Console navigation**: **Kubernetes Engine → Config → Policy**

Policy Controller concepts:

| Concept | Description |
|---|---|
| ConstraintTemplate | Defines the schema and Rego logic for a policy rule |
| Constraint | An instance of a template that enforces the rule on specific resource types |
| Audit mode | Reports violations on existing resources without blocking them |
| Deny mode | Rejects non-compliant resources at admission |

```bash
# List installed ConstraintTemplates
kubectl get constrainttemplates

# List all active Constraints across all templates
kubectl get constraints -A

# Check Policy Controller pods
kubectl get pods -n gatekeeper-system

# View violation counts per constraint
kubectl get constraints -A \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.totalViolations}{"\n"}{end}'
```

### ACM Upgrade and Drift Recovery

Config Sync is managed as a Fleet feature and receives updates automatically when you update the ACM feature version in the Fleet. You do not need to manually upgrade the Config Sync pods.

If a sync error occurs (e.g. a network partition, invalid manifest, or RBAC conflict), Config Sync will continue retrying. Check the `RootSync` status for the error message:

```bash
# Show recent sync errors with full detail
kubectl get rootsync root-sync -n config-management-system \
  -o jsonpath='{.status.conditions}' | python3 -m json.tool
```

Restore sync by fixing the underlying cause (e.g. correcting the manifest in Git or resolving an RBAC conflict). Config Sync will detect the fix on the next poll cycle and resume normal operation.

---

## GKE Ingress and Load Balancing

Bank_GKE exposes the frontend microservice to the internet using the **GKE Ingress controller** backed by a Google Cloud External HTTP(S) Load Balancer. This is a single-cluster ingress pattern — it differs from the `MC_Bank_GKE` module which uses Multi-Cluster Ingress (MCI). The GKE Ingress approach is simpler and is appropriate when high availability across multiple clusters or regions is not required.

### Architecture Overview

The load balancing stack consists of five Kubernetes resources working together:

```
Internet
   │
   ▼
Global External HTTP(S) Load Balancer (Google-managed)
   │  Static external IP: "bank-of-anthos"
   │  TLS certificate: ManagedCertificate (sslip.io domain)
   │  HTTPS redirect: FrontendConfig (HTTP 301 → HTTPS)
   │
   ▼
Backend Service (GCP) ──── BackendConfig (health check + IAP config)
   │
   ▼
Network Endpoint Group (NEG)  ──── auto-created per node zone
   │
   ▼
frontend pods (port 8080) in bank-of-anthos namespace
```

The GKE Ingress controller creates and manages the underlying GCP load balancer resources automatically. You do not need to create load balancer rules, forwarding rules, or backend services manually.

### Kubernetes Ingress Resource

The `Ingress` resource is the entry point. It uses two GKE-specific annotations:

- `kubernetes.io/ingress.global-static-ip-name` — attaches the pre-allocated static external IP address named `bank-of-anthos`
- `networking.gke.io/managed-certificates` — references the `ManagedCertificate` resource for automatic TLS provisioning

Traffic routing rules:

| Host | Path | Backend Service | Port |
|---|---|---|---|
| `<app-domain>` | `/` | `bank-of-anthos` (frontend) | 80 |
| (default) | any | `bank-of-anthos` (frontend) | 80 |

The default backend catches any request that does not match the host rule, ensuring no requests return a 404 from the load balancer itself.

### Network Endpoint Groups (NEGs)

The frontend `Service` carries the annotation `cloud.google.com/neg: '{"ingress": true}'`. This instructs the GKE Ingress controller to use **container-native load balancing** via Network Endpoint Groups (NEGs) instead of node-port-based routing.

With NEG-based load balancing:

- The load balancer sends traffic directly to individual pod IP addresses, bypassing kube-proxy
- Each pod endpoint is registered in a zonal NEG
- Health checks are performed directly against pod IPs, not node IPs
- Pods are added to and removed from the NEG as they are scheduled and terminated

```bash
# List NEGs created for the frontend service
gcloud compute network-endpoint-groups list \
  --filter="name~bank-of-anthos" \
  --project=${PROJECT_ID}

# Describe a specific NEG
gcloud compute network-endpoint-groups describe ${NEG_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID}

# List endpoints registered in a NEG
gcloud compute network-endpoint-groups list-network-endpoints ${NEG_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID}
```

### BackendConfig — Health Checks and IAP

The `BackendConfig` resource customises the GCP backend service that the load balancer uses. It is referenced by the frontend `Service` via the annotation `cloud.google.com/backend-config`.

Health check configuration:

| Parameter | Value | Meaning |
|---|---|---|
| Check interval | 2 seconds | How often the load balancer probes each pod endpoint |
| Timeout | 1 second | Time allowed for the probe to respond |
| Healthy threshold | 1 | Consecutive successes before marking healthy |
| Unhealthy threshold | 10 | Consecutive failures before removing from rotation |
| Protocol | HTTP | Plain HTTP probe (not HTTPS) |
| Request path | `/` | The path the load balancer probes |

The aggressive unhealthy threshold (10) prevents pods from being prematurely removed during slow startup or transient errors. The frontend application responds to `GET /` with HTTP 200 when healthy.

IAP (Identity-Aware Proxy) is configured in the `BackendConfig` but set to `enabled: false`. It can be enabled without redeploying by updating the `BackendConfig` and providing an OAuth client secret.

```bash
# View the BackendConfig
kubectl get backendconfig -n bank-of-anthos -o yaml

# View the GCP backend service created by the Ingress controller
gcloud compute backend-services list \
  --filter="name~bank-of-anthos" \
  --global \
  --project=${PROJECT_ID}

# Describe the backend service health check
gcloud compute backend-services describe ${BACKEND_SERVICE_NAME} \
  --global \
  --project=${PROJECT_ID} \
  --format="yaml(healthChecks,backends)"
```

### FrontendConfig — HTTPS Redirect

The `FrontendConfig` resource configures the frontend of the load balancer. In this module it enforces an HTTP-to-HTTPS redirect with a permanent `301` response code. Any client that connects over plain HTTP on port 80 receives a redirect to the HTTPS equivalent URL.

```bash
# View the FrontendConfig
kubectl get frontendconfig -n bank-of-anthos -o yaml

# Verify the redirect is active (HTTP should return 301)
curl -I http://${APPLICATION_DOMAIN}/
```

The response should include `HTTP/1.1 301 Moved Permanently` and a `Location:` header pointing to `https://${APPLICATION_DOMAIN}/`.

### ManagedCertificate — Automatic TLS

The `ManagedCertificate` resource requests a Google-managed TLS certificate for the application domain. Google's Certificate Authority provisions the certificate automatically via the ACME protocol after verifying domain ownership through the load balancer.

Domain configuration: The module uses a subdomain under `sslip.io`, which is a public wildcard DNS service that resolves any subdomain to the IP address encoded in the hostname (e.g. `34-120-10-5.sslip.io` resolves to `34.120.10.5`). This allows TLS certificate provisioning without needing to own or configure a custom DNS zone.

Certificate lifecycle:

| State | Meaning |
|---|---|
| Provisioning | Google is requesting the certificate from the CA |
| FailedNotVisible | The load balancer IP is not yet reachable on port 80 |
| Active | Certificate is issued and serving |
| RenewalFailed | Automatic renewal failed — check domain reachability |

```bash
# View ManagedCertificate status
kubectl describe managedcertificate -n bank-of-anthos

# View the GCP SSL certificate resource
gcloud compute ssl-certificates list \
  --filter="name~bank-of-anthos" \
  --project=${PROJECT_ID}

# Describe the certificate including expiry
gcloud compute ssl-certificates describe ${CERT_NAME} \
  --project=${PROJECT_ID}
```

Certificate provisioning typically takes 10–30 minutes on first deployment. The load balancer will serve HTTP traffic and redirect to HTTPS before the certificate is active; HTTPS traffic will not be served until the certificate reaches `Active` state.

### Viewing the Full Ingress Stack

```bash
# View the Ingress resource and its address
kubectl get ingress -n bank-of-anthos

# Describe the Ingress — shows events, backend health, and certificate status
kubectl describe ingress -n bank-of-anthos

# View the GCP forwarding rules created by the Ingress controller
gcloud compute forwarding-rules list \
  --filter="name~bank-of-anthos" \
  --global \
  --project=${PROJECT_ID}

# View the URL map
gcloud compute url-maps list \
  --filter="name~bank-of-anthos" \
  --project=${PROJECT_ID}

# View the target HTTPS proxy
gcloud compute target-https-proxies list \
  --filter="name~bank-of-anthos" \
  --project=${PROJECT_ID}
```

**Console navigation**: **Network Services → Load balancing** — select the load balancer named `bank-of-anthos` to see the full configuration, backend health status, and traffic metrics.

---
