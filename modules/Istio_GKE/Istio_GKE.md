---
title: "Istio_GKE Module Documentation"
sidebar_label: "Istio_GKE"
---

# Istio_GKE Module

## Overview

The Istio_GKE module provisions a complete Google Kubernetes Engine (GKE) Standard cluster and installs the **open-source Istio service mesh** onto it. Unlike Google Cloud Service Mesh (which is Google's managed, commercially supported Istio distribution), this module works directly with upstream Istio — the same project maintained by the Cloud Native Computing Foundation (CNCF) — giving platform engineers hands-on experience with the technology in its original, unmodified form.

This module is designed as a deep learning environment for platform engineers who want to understand how Istio works from the ground up: how the control plane manages the data plane, how proxies intercept and observe traffic, and how the two fundamentally different data plane architectures — **sidecar mode** and **ambient mode** — approach the same problems with different trade-offs.

By deploying this module, you gain direct experience with:

- **Open-source Istio** — the CNCF project that underpins both Google Cloud Service Mesh and many other managed mesh offerings, installed directly via `istioctl`
- **Sidecar mode** — the traditional and battle-tested Istio architecture where an Envoy proxy runs as a sidecar container alongside every application pod
- **Ambient mode** — Istio's newer, sidecar-free architecture where a shared per-node proxy (ztunnel) handles Layer 4 traffic and optional per-namespace waypoint proxies handle Layer 7
- **GKE Standard** — Google's fully configurable Kubernetes offering, distinct from GKE Autopilot, where you manage node pools and cluster-level settings directly
- **Istio traffic management** — VirtualService, DestinationRule, Gateway, and the full set of routing and resilience primitives
- **Istio observability** — the full open-source stack: Prometheus for metrics, Jaeger for distributed tracing, Grafana for dashboards, and Kiali for service mesh visualisation
- **GKE enterprise features** — Workload Identity, VPC-native networking, Security Posture, Managed Prometheus, and Gateway API running on GKE Standard

The module deploys approximately **10–12 minutes** to a single GCP project and requires no AWS account — everything runs on Google Cloud.

---

## What Gets Deployed

**On Google Cloud:**
- Two GCP APIs enabled: Cloud APIs and Container API
- A VPC network with a subnet, secondary IP ranges for pods and services, and firewall rules
- A Cloud Router and Cloud NAT for outbound traffic from cluster nodes
- A GKE Standard cluster with VPC-native networking, Workload Identity, Security Posture, Managed Prometheus, and Gateway API
- A node pool of 2 preemptible `e2-standard-2` nodes

**On the GKE Cluster (one of two choices):**

| | Sidecar Mode (default) | Ambient Mode |
|-|----------------------|--------------|
| **Data plane** | Envoy proxy sidecar in every pod | Shared ztunnel per node, optional waypoint proxies |
| **Installation** | `istioctl install --set profile=default` | `istioctl install --set profile=ambient` |
| **Namespace label** | `istio-injection=enabled` | `istio.io/dataplane-mode=ambient` |
| **Observability add-ons** | Prometheus, Jaeger, Grafana, Kiali | Prometheus, Jaeger, Grafana, Kiali |
| **Layer 7 policies** | Per-pod Envoy sidecar | Optional waypoint proxy per namespace |

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          Istio_GKE Module                                  │
│                                                                            │
│   Google Cloud Project                                                     │
│   ────────────────────────────────────────────────────────────────────     │
│                                                                            │
│   ┌──────────────────────────────────────────────────────────────────┐     │
│   │  VPC Network                                                     │     │
│   │  ┌──────────────────────────────────────────────────────────┐   │     │
│   │  │  Subnet (10.132.0.0/16)                                  │   │     │
│   │  │  Pod secondary range:     10.62.128.0/17                 │   │     │
│   │  │  Service secondary range: 10.64.128.0/20                 │   │     │
│   │  │                                                          │   │     │
│   │  │  ┌──────────────────────────────────────────────────┐   │   │     │
│   │  │  │  GKE Standard Cluster                            │   │   │     │
│   │  │  │  • VPC-native networking                         │   │   │     │
│   │  │  │  • Workload Identity                             │   │   │     │
│   │  │  │  • Security Posture                              │   │   │     │
│   │  │  │  • Managed Prometheus                            │   │   │     │
│   │  │  │  • Gateway API                                   │   │   │     │
│   │  │  │                                                  │   │   │     │
│   │  │  │  Node Pool (2 × e2-standard-2, preemptible)      │   │   │     │
│   │  │  │                                                  │   │   │     │
│   │  │  │  Istio Control Plane (istio-system)              │   │   │     │
│   │  │  │  • istiod (service discovery + config + CA)      │   │   │     │
│   │  │  │  • Ingress Gateway (LoadBalancer)                │   │   │     │
│   │  │  │                                                  │   │   │     │
│   │  │  │  SIDECAR MODE              AMBIENT MODE          │   │   │     │
│   │  │  │  ┌──────────────┐          ┌──────────────────┐  │   │   │     │
│   │  │  │  │ App Pod      │          │ ztunnel (per node│  │   │   │     │
│   │  │  │  │ ┌──────────┐ │          │ L4 mTLS + policy)│  │   │   │     │
│   │  │  │  │ │ App      │ │          └────────┬─────────┘  │   │   │     │
│   │  │  │  │ │ Envoy    │ │                   │            │   │   │     │
│   │  │  │  │ │ sidecar  │ │          ┌────────▼─────────┐  │   │   │     │
│   │  │  │  │ └──────────┘ │          │ Waypoint Proxy   │  │   │   │     │
│   │  │  │  └──────────────┘          │ (optional, L7)   │  │   │   │     │
│   │  │  │                            └──────────────────┘  │   │   │     │
│   │  │  │  Observability: Prometheus · Jaeger · Grafana · Kiali   │   │     │
│   │  │  └──────────────────────────────────────────────────┘   │   │     │
│   │  └──────────────────────────────────────────────────────────┘   │     │
│   │  Cloud Router + Cloud NAT (outbound egress)                      │     │
│   └──────────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────────┘

Deployment sequence:
  1. Enable GCP APIs (cloudapis, container)
  2. Create VPC, subnet with secondary ranges, firewall rules
  3. Create Cloud Router and Cloud NAT
  4. Create GKE Standard cluster and node pool
  5. Download and install Istio via istioctl
  6. Label default namespace for mesh enrolment
  7. Install observability add-ons (Prometheus, Jaeger, Grafana, Kiali)
```

---

## GCP Networking

The module creates a dedicated VPC network and configures all the networking components that GKE and Istio require to operate. Understanding this layer is important both for appreciating GKE's networking model and for diagnosing connectivity issues in the mesh.

### VPC Network

A custom-mode VPC is created with global routing. Using **global routing** means that Cloud Routers in any region can learn routes from all subnets across all regions — a prerequisite for multi-region GKE deployments and for Cloud NAT to function correctly. A custom-mode VPC (as opposed to auto-mode) gives complete control over subnet CIDR ranges, which is necessary when GKE requires non-overlapping secondary ranges for pod and service IPs.

The VPC uses `auto_create_subnetworks = false`, meaning only the explicitly configured subnet is created — no automatic subnets appear in other regions that could create unexpected IP overlap with other projects or on-premises networks.

### Subnet and Secondary IP Ranges

GKE's **VPC-native networking** requires a subnet with two secondary IP ranges in addition to the primary range:

| Range | Default CIDR | Purpose |
|-------|-------------|---------|
| Primary subnet range | `10.132.0.0/16` | IP addresses for GKE cluster nodes (EC2-equivalent) |
| Pod secondary range | `10.62.128.0/17` | One IP address per pod — 32,766 pod IPs available |
| Service secondary range | `10.64.128.0/20` | One IP per Kubernetes Service ClusterIP — 4,094 service IPs |

**Why secondary ranges matter for Istio:** In sidecar mode, every pod has both an application container and an Envoy sidecar. Both share the pod's IP address — there is no secondary IP for the sidecar. However, the sidecar intercepts traffic using `iptables` rules set up by the `istio-init` init container, which requires the `NET_ADMIN` capability. The GKE cluster is configured with `allow_net_admin = true` specifically to permit this. In ambient mode this is not required because the ztunnel — which runs as a DaemonSet on each node — handles traffic interception at the node level rather than inside pods.

**Private Google Access** is enabled on the subnet, allowing nodes without external IPs to reach Google APIs (Cloud Logging, Artifact Registry, Cloud Monitoring) over internal Google network paths rather than the public internet.

### Firewall Rules

The module creates six firewall rules that together define the network security boundary for the cluster:

| Rule | Direction | Source | Ports | Purpose |
|------|-----------|--------|-------|---------|
| `fw-allow-lb-hc` | INGRESS | `35.191.0.0/16`, `130.211.0.0/22` | TCP 80 | Google Cloud Load Balancer health checks — required for the Istio Ingress Gateway's external load balancer to report healthy |
| `fw-allow-nfs-hc` | INGRESS | `35.191.0.0/16`, `130.211.0.0/22` | TCP 2049 | NFS health checks — present for compatibility with storage workloads |
| `fw-allow-iap-ssh` | INGRESS | `35.235.240.0/20` | TCP 22 | SSH to cluster nodes via Identity-Aware Proxy — eliminates the need for a public SSH port or bastion host |
| `fw-allow-intra-vpc` | INGRESS | Configured VPC CIDRs | All | Unrestricted traffic between all resources within the VPC — covers pod-to-pod, node-to-node, and node-to-pod communication including Istio's own control plane traffic |
| `fw-allow-gce-nfs-tcp` | INGRESS | VPC CIDRs | TCP 2049 | NFS service traffic to instances tagged `nfs-server` |
| `fw-allow-http-tcp` | INGRESS | All sources (`0.0.0.0/0`) | TCP 80, 443 | External HTTP and HTTPS traffic to instances tagged `http-server` — this is what makes the Istio Ingress Gateway reachable from the internet |

**Why no explicit Istio-specific rules are needed:** Istio's control plane traffic (istiod to proxies on port 15012, webhook on port 15017, mTLS between proxies on port 15443) all flows within the VPC. The `fw-allow-intra-vpc` rule covers all of this without requiring individual rules per Istio component. This is a deliberate simplification for a learning environment — production deployments typically use more granular rules.

**Explore firewall rules in the Cloud Console:**

Navigate to **VPC Network → Firewall** in the Cloud Console. Filter by the network name to see all six rules. For each rule, you can view the matched traffic in **VPC Network → Firewall → Firewall Rules Logging** — useful for understanding which traffic Istio's data plane is actually generating.

```bash
# List all firewall rules for the module's VPC
gcloud compute firewall-rules list \
  --filter="network:vpc-network" \
  --project=GCP_PROJECT_ID

# View a specific rule in detail
gcloud compute firewall-rules describe fw-allow-lb-hc \
  --project=GCP_PROJECT_ID
```

### Cloud Router and Cloud NAT

Cluster nodes use private IP addresses (from the `10.132.0.0/16` subnet) and have no external IPs. For nodes to reach the internet — to pull container images from Docker Hub, download Istio from GitHub, or reach any external endpoint — outbound traffic is routed through **Cloud NAT**.

**Cloud Router** provides the BGP routing infrastructure that Cloud NAT relies on. It is configured with ASN 64514 (a private ASN in the range reserved for internal use). For this module, the router serves only the NAT function; it does not peer with on-premises networks.

**Cloud NAT** is configured with `AUTO_ONLY` IP allocation, meaning Google Cloud automatically assigns external IP addresses from its pool rather than requiring a static IP reservation. This is simpler for learning environments. Logging is set to `ERRORS_ONLY` to avoid generating log noise from normal NAT operations.

**Why this matters for Istio:** During installation, `istioctl` downloads Istio components from `github.com` and the Istio release bucket. The observability add-ons (Prometheus, Jaeger, Grafana, Kiali) are pulled from their respective container registries. All of this outbound traffic flows through Cloud NAT. Without it, the installation would fail silently as download commands hang waiting for connections that never complete.

```bash
# Verify Cloud NAT is healthy and view NAT allocation statistics
gcloud compute routers get-nat-mapping-info cr-region \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID

# View NAT gateway configuration
gcloud compute routers nats describe nat-gw-region \
  --router=cr-region \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID
```

---

## GKE Standard Cluster

The module provisions a **GKE Standard** cluster — Google's fully configurable Kubernetes offering where you control node pools, machine types, and cluster-level settings. This is deliberately different from GKE Autopilot, which abstracts all node management away. Using GKE Standard for this module is an intentional learning choice: it exposes the configuration decisions that Autopilot makes automatically, making the trade-offs visible.

### GKE Standard vs. GKE Autopilot

Understanding the distinction is a core learning objective of this module:

| Dimension | GKE Standard (this module) | GKE Autopilot |
|-----------|---------------------------|---------------|
| Node management | You configure machine type, count, disk size | Google manages all nodes invisibly |
| Pricing model | Per node (pay for provisioned capacity) | Per pod (pay for requested resources only) |
| Istio sidecar injection | Requires `allow_net_admin = true` | Not required — Autopilot handles this automatically |
| Cluster-level control | Full access to all Kubernetes settings | Some settings are locked for security |
| Best for | Learning internals, custom configurations | Production workloads, ops simplicity |

### Release Channel

The cluster is enrolled in the **REGULAR release channel** (configurable via `release_channel`). GKE release channels are Google's mechanism for delivering Kubernetes version updates and GKE feature updates with different risk and velocity profiles:

| Channel | Update cadence | Use case |
|---------|---------------|----------|
| `RAPID` | Earliest access to new Kubernetes versions and GKE features | Testing and experimentation |
| `REGULAR` (default) | ~2–3 months after RAPID; most users | Balanced — current features without bleeding edge risk |
| `STABLE` | ~2–3 months after REGULAR | Production workloads requiring maximum stability |

By enrolling in a release channel, the cluster receives automatic Kubernetes patch version upgrades and GKE component upgrades without manual intervention. The minor version is managed by Google within the bounds of the selected channel.

**Explore release channel status in the Cloud Console:**

Navigate to **Kubernetes Engine → Clusters → [your cluster] → Details** and look for the **Release channel** field. You can also see the current Kubernetes version and whether an upgrade is available.

```bash
# View the cluster's current version and release channel
gcloud container clusters describe gke-cluster \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID \
  --format="value(currentMasterVersion,releaseChannel.channel)"

# List available Kubernetes versions in the REGULAR channel
gcloud container get-server-config \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID \
  --format="yaml(channels)"
```

### VPC-Native Networking

The cluster uses **VPC-native** (also called alias IP) networking, enabled by setting the networking mode to `VPC_NATIVE`. In this mode, every pod receives a real IP address from the pod secondary range (`10.62.128.0/17`) rather than an overlay address that is NAT'd to a node IP.

This has significant implications for Istio:

- **No double-NAT:** Traffic between pods flows directly at the IP layer — the Envoy sidecar sees the real source and destination pod IPs in both sidecar and ambient modes
- **Cloud Load Balancer integration:** GKE can create Network Endpoint Groups (NEGs) that point directly to pod IPs, enabling the Istio Ingress Gateway to receive traffic without node-level port forwarding
- **Network policy enforcement:** VPC firewall rules and GKE network policies operate on real pod IPs, making security policies easier to reason about

```bash
# Verify VPC-native mode and view pod/service CIDR configuration
gcloud container clusters describe gke-cluster \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID \
  --format="yaml(ipAllocationPolicy)"

# View the pod IP range allocated to each node
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,POD-CIDR:.spec.podCIDR'
```

### Workload Identity

**Workload Identity** is GKE's mechanism for giving Kubernetes service accounts a Google Cloud identity, allowing pods to call GCP APIs without static service account keys.

When Workload Identity is enabled on the cluster, each Kubernetes service account can be bound to a Google Cloud service account (GSA). Pods that use that Kubernetes service account automatically receive a short-lived token for the corresponding GSA, issued by the GKE metadata server running on each node. The pod never sees a JSON key file — the credential is injected transparently.

**Why this matters for Istio:** The `istiod` control plane and the Istio Ingress Gateway both need to call GCP APIs (Cloud Logging, Cloud Monitoring, Certificate Manager). With Workload Identity, they authenticate using their Kubernetes service accounts bound to the GKE node service account — no key files distributed inside the cluster.

```bash
# Verify Workload Identity is enabled on the cluster
gcloud container clusters describe gke-cluster \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID \
  --format="value(workloadIdentityConfig.workloadPool)"
# Expected output: GCP_PROJECT_ID.svc.id.goog

# View the Kubernetes service accounts used by Istio components
kubectl get serviceaccounts -n istio-system

# Describe istiod's service account to see its annotations
kubectl describe serviceaccount istiod -n istio-system
```

**Explore in the Cloud Console:** Navigate to **Kubernetes Engine → Clusters → [your cluster] → Security** to confirm Workload Identity is enabled and see the workload pool identifier.

### Security Posture

The cluster has **Security Posture** enabled at the `BASIC` level with `VULNERABILITY_BASIC` scanning. Security Posture is GKE's built-in security assessment capability that continuously evaluates the cluster against security best practices and known vulnerability databases.

At the BASIC tier, it provides:

- **Workload configuration scanning** — evaluates running pods against Kubernetes security best practices (privileged containers, host network usage, root filesystem writes, missing resource limits)
- **Vulnerability scanning** — scans container images running in the cluster against the CVE database and reports known vulnerabilities by severity

This is particularly relevant for a learning environment with Istio because the Istio sidecar injector runs as a privileged admission webhook. Security Posture will flag any misconfigured workloads that conflict with security best practices, making it a useful tool for understanding the security implications of mesh configurations.

**Explore Security Posture in the Cloud Console:**

Navigate to **Kubernetes Engine → Security → Security Posture**. The dashboard shows concerns grouped by severity across all clusters in the project. Select your cluster to see workload-specific findings — for example, whether any pods are running without resource limits or with overly permissive capabilities.

```bash
# View Security Posture findings via gcloud
gcloud container clusters describe gke-cluster \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID \
  --format="value(securityPostureConfig)"
```

### Cloud Logging and Managed Prometheus

The cluster is configured to send both **system component logs** and **workload logs** to Cloud Logging, and has **Managed Prometheus** enabled — the same observability integration described in the EKS_GKE module, now running on a native GKE cluster.

This creates an interesting learning comparison: the Istio observability add-ons (Prometheus, Jaeger, Grafana, Kiali) are open-source tools running *inside* the cluster, while GKE's Managed Prometheus collects metrics *from* the cluster and forwards them to Google Cloud Monitoring. Both exist simultaneously — you can query the same Kubernetes metrics either through the in-cluster Prometheus instance or through Cloud Monitoring's PromQL interface.

```bash
# Confirm Managed Prometheus is collecting metrics
kubectl get pods -n gmp-system

# Query a Kubernetes metric via Cloud Monitoring PromQL
# (run in Cloud Console: Monitoring → Metrics Explorer → PromQL)
# kubernetes_io:container_memory_used_bytes{cluster="gke-cluster"}
```

### Gateway API

The cluster has the **Gateway API** standard channel enabled. Gateway API is the CNCF successor to the Kubernetes Ingress resource, providing a more expressive and extensible API for routing traffic into and within the cluster.

Istio 1.24 has first-class Gateway API support — you can use `HTTPRoute`, `TCPRoute`, and `Gateway` resources from the CNCF Gateway API spec as an alternative to Istio's own `VirtualService` and `DestinationRule` resources. Having Gateway API enabled on the GKE cluster means both approaches work side by side, giving platform engineers the opportunity to compare the two traffic management APIs directly.

```bash
# Verify Gateway API CRDs are installed
kubectl get crd | grep gateway

# List any Gateway API resources in the cluster
kubectl get gateways,httproutes -A
```

### Node Pool

The cluster has a single node pool of **2 preemptible `e2-standard-2`** nodes:

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Machine type | `e2-standard-2` | 2 vCPU, 8 GB RAM — enough for istiod, Envoy sidecars, and the observability stack |
| Disk type | `pd-ssd` | SSD for faster pod scheduling and image pull |
| Disk size | 50 GB | Sufficient for Istio images and the observability add-on images |
| Preemptible | Yes | Up to 80% cost reduction — acceptable for a learning environment, not for production |
| Node count | 2 | Minimum for high availability of the Istio control plane |

**Understanding preemptible nodes:** GCE can reclaim preemptible VMs with 30 seconds notice when it needs the capacity. GKE handles this gracefully by draining the node and rescheduling pods on the remaining node. However, if both nodes are reclaimed simultaneously, the cluster becomes temporarily unavailable. For production Istio deployments, regular (non-preemptible) nodes across multiple zones are recommended.

```bash
# View node pool details including machine type and preemptibility
gcloud container node-pools describe default-pool \
  --cluster=gke-cluster \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID

# Check node status and resource capacity
kubectl get nodes -o wide
kubectl describe nodes | grep -A 10 "Allocatable:"
```

### GKE Node Service Account

A dedicated Google Cloud service account is created for GKE nodes with the minimum permissions required for cluster operation:

| Role | Purpose |
|------|---------|
| `storage.objectAdmin` / `storage.objectViewer` | Read and write access to Cloud Storage (for GCS Fuse CSI driver) |
| `artifactregistry.reader` | Pull container images from Artifact Registry |
| `monitoring.metricWriter` / `monitoring.viewer` | Write metrics to Cloud Monitoring (for Managed Prometheus) |
| `logging.logWriter` | Write logs to Cloud Logging |
| `compute.networkViewer` | Read VPC network configuration (required by GKE networking components) |
| `stackdriver.resourceMetadata.writer` | Write resource metadata for Stackdriver integrations |
| `container.defaultNodeServiceAccount` | Base GKE node permissions |

Using a dedicated service account with only the required roles — rather than the Compute Engine default service account with broad Editor permissions — follows the principle of least privilege and is a GKE security best practice.

```bash
# View the node service account and its IAM roles
gcloud iam service-accounts list \
  --filter="displayName:gke" \
  --project=GCP_PROJECT_ID

# Verify the node pool uses the dedicated service account
gcloud container node-pools describe default-pool \
  --cluster=gke-cluster \
  --region=GCP_REGION \
  --project=GCP_PROJECT_ID \
  --format="value(config.serviceAccount)"
```

---
