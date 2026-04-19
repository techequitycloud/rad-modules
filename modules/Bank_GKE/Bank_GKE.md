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
