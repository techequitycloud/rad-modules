# MC_Bank_GKE Module

## Overview

The **MC_Bank_GKE** module deploys a production-grade, multi-cluster microservices banking application on Google Kubernetes Engine (GKE). It is designed as a comprehensive learning environment for platform engineers who want to gain hands-on experience with advanced GKE capabilities, including multi-cluster networking, service mesh, global load balancing, and cloud-native observability.

The application deployed is **Bank of Anthos** — an open-source, HTTP-based banking simulation built by Google Cloud Platform. It consists of nine microservices written in Python and Java, communicating over a service mesh, and exposed to the internet via a globally distributed load balancer with automatic TLS certificate management.

This module is intended for **educational purposes**. It is not a production banking system. Its value lies in the breadth and depth of Google Cloud and Kubernetes features it exercises simultaneously in a realistic, working application context.

---

## What You Will Learn

By deploying and exploring this module, a platform engineer will gain practical experience with:

- Deploying and managing **multiple GKE clusters** across regions from a single control plane
- Registering clusters in a **GKE Fleet** for unified multi-cluster management
- Enabling and operating **Cloud Service Mesh (Anthos Service Mesh)** with automatic sidecar injection
- Configuring **Multi-Cluster Ingress (MCI)** and **Multi-Cluster Services (MCS)** for cross-cluster traffic routing
- Using **Google-managed SSL/TLS certificates** with automatic provisioning
- Applying **GKE Security Posture** scanning and vulnerability detection
- Working with **Workload Identity** to securely bind Kubernetes workloads to GCP service accounts
- Using **Managed Prometheus** for cluster and workload observability
- Configuring the **GCS FUSE CSI driver** for mounting Cloud Storage buckets as pod volumes
- Enabling the **GKE Gateway API** for advanced traffic management
- Designing and operating a **custom VPC** with subnet isolation, Cloud NAT, and firewall policies for GKE

---

## Architecture Overview

The module creates the following high-level architecture:

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
Multi-Cluster Ingress (GKE Hub Feature)
    │  ├─ Routes to frontend pods across all clusters
    │  └─ Backed by MultiClusterService
    │
    ├──────────────────────┐
    ▼                      ▼
GKE Cluster 1          GKE Cluster 2
(us-west1)             (us-east1)
    │                      │
    └──── GKE Fleet ───────┘
              │
              ├─ Cloud Service Mesh (ASM)
              ├─ Multi-Cluster Services
              └─ Shared Fleet Config
```

### Key Architectural Decisions

**Multi-region placement**: Clusters are distributed across two GCP regions by default (us-west1 and us-east1). This mirrors a real high-availability deployment where workloads survive a regional failure.

**Single global VPC**: All clusters share one VPC network with GLOBAL routing mode. Each cluster has its own subnet with dedicated secondary IP ranges for pods and services, preventing address conflicts.

**Config cluster pattern**: Multi-Cluster Ingress is configured from `cluster1`, which acts as the configuration cluster. The GKE Hub multi-cluster ingress feature uses this cluster as the authoritative source for ingress configuration and distributes it across the fleet.

**Automatic service mesh**: Cloud Service Mesh is enabled at the fleet level with `MANAGEMENT_AUTOMATIC` mode. GKE manages the control plane, upgrades, and lifecycle of the mesh without manual intervention.

**Namespace as mesh boundary**: The `bank-of-anthos` namespace is labelled with `istio.io/rev=asm-managed` on both clusters, which triggers automatic Envoy sidecar injection into every pod in that namespace.

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

In **Standard mode**, this module provisions node pools with the following defaults:
- **Machine type**: `e2-standard-2` (2 vCPU, 8 GB RAM)
- **Disk**: 50 GB SSD (`pd-ssd`)
- **Spot instances**: enabled — nodes are preemptible, reducing cost by up to 80%, appropriate for a learning environment
- **Node count**: 2 nodes per pool, spread across available zones in the region

### Release Channel

Clusters are enrolled in the **REGULAR release channel**. GKE release channels automate cluster upgrades and ensure nodes and control planes stay on a supported, tested version.

| Channel | Update cadence | Best for |
|---|---|---|
| RAPID | Immediately after release | Feature testing, dev environments |
| REGULAR | 2–4 weeks after RAPID | Most production workloads |
| STABLE | 2–4 weeks after REGULAR | Risk-averse, compliance-sensitive workloads |
| EXTENDED | Up to 24 months support | Long-running, infrequently updated clusters |

### Security Posture

Each cluster has **Security Posture** enabled in `BASIC` mode with `VULNERABILITY_BASIC` scanning. This feature continuously evaluates your cluster against security best practices and scans workload container images for known CVEs.

**What Security Posture provides:**
- **Workload configuration auditing**: flags pods running as root, containers without resource limits, missing liveness/readiness probes, and other misconfigurations
- **Vulnerability scanning**: scans container images in running workloads against OS and language package vulnerability databases
- **Actionable findings**: surfaces issues in the GKE Security Posture dashboard with severity ratings and remediation guidance

This is distinct from Artifact Registry vulnerability scanning, which scans images at push time. Security Posture scans *running* workloads, catching drift between what was pushed and what is actually deployed.

### Workload Identity

For **Standard clusters**, **Workload Identity** is enabled. This is the recommended mechanism for granting Kubernetes workloads access to Google Cloud APIs without static service account keys.

**How it works:**
1. Each GKE cluster gets a Workload Identity Pool: `PROJECT_ID.svc.id.goog`
2. A Kubernetes Service Account (KSA) is annotated to link it to a Google Service Account (GSA)
3. The GSA is granted an IAM binding that allows the KSA to impersonate it
4. Pods using that KSA call GCP APIs using short-lived tokens — no key files, no secrets

**Why this matters**: Traditional approaches mount a JSON key file as a Kubernetes Secret. If that secret leaks via a compromised pod, the key can be used from anywhere. With Workload Identity, credentials are short-lived tokens issued by GKE's metadata server and are only valid from within the cluster.

In this module, Bank of Anthos uses Workload Identity to send traces to Cloud Trace and metrics to Cloud Monitoring.

### Managed Prometheus

**Managed Service for Prometheus** is enabled on each cluster — Google's fully managed, Prometheus-compatible monitoring solution built into GKE.

**What it provides:**
- Prometheus-compatible metrics collection without deploying or managing a Prometheus server
- Automatic scraping of Kubernetes system components (`kube-state-metrics`, `node-exporter`, `kubelet`)
- Long-term storage backed by Google's Monarch metrics infrastructure
- Query interface via Cloud Monitoring or PromQL
- Out-of-the-box dashboards for cluster health, node utilisation, and workload metrics

The module enables `SYSTEM_COMPONENTS` metric collection by default. Workload-level scraping of custom `/metrics` endpoints requires a `PodMonitoring` or `ClusterPodMonitoring` custom resource.

### GCS FUSE CSI Driver

The **Cloud Storage FUSE CSI driver** is enabled on all clusters, allowing pods to mount Google Cloud Storage buckets as a POSIX-compatible filesystem.

**Use cases in a microservices context:**
- Sharing large static assets (ML models, media files, config bundles) across pods without baking them into container images
- Mounting read-only reference data updated externally (e.g. a bucket populated by a CI pipeline)
- Offloading large write workloads (logs, exports) directly to GCS without a separate sidecar

To use the driver, annotate your service account and reference a GCS bucket in your pod's volume spec. The driver handles mounting, credential negotiation via Workload Identity, and FUSE kernel integration transparently.

### Gateway API

The **Gateway API** is enabled on `CHANNEL_STANDARD`. Gateway API is the successor to the Kubernetes Ingress resource, providing a more expressive, role-oriented model for configuring traffic routing.

| Capability | Ingress | Gateway API |
|---|---|---|
| Traffic splitting | Limited / annotation-based | Native (HTTPRoute weights) |
| Header-based routing | Annotation-based | Native |
| Role separation | Single resource | Separate Gateway + Route objects |
| Protocol support | HTTP/HTTPS | HTTP, HTTPS, TCP, gRPC, TLS |

### Cost Management

**GKE Cost Management** is enabled on all clusters. This feature attributes resource costs (CPU, memory, storage) to Kubernetes namespaces and labels, enabling per-team or per-workload cost visibility within a shared cluster. Cost data is available in the Google Cloud Billing console and exportable to BigQuery.

---

## Networking

### VPC Design

All clusters share a single **custom VPC network** with GLOBAL routing mode. Using a global VPC means that subnets in different regions can communicate over Google's private backbone without requiring VPC peering or additional routing configuration. This simplifies multi-cluster networking — pods in us-west1 can reach services in us-east1 using internal RFC 1918 addresses.

The VPC uses `auto_create_subnetworks = false`, meaning no default subnets are created. Every subnet is explicitly defined and sized to match the requirements of each cluster.

**Why a custom VPC over the default VPC?**
The default VPC uses auto-mode subnets with pre-assigned, fixed CIDR ranges. Custom VPCs give you full control over IP address planning, which matters when:
- You need to avoid overlapping with on-premises or partner networks (VPN/Interconnect)
- You are planning for a specific number of nodes, pods, and services per cluster
- You want to enforce network segmentation between environments

### Subnet Design and IP Allocation

Each cluster receives a dedicated subnet with three IP ranges:

| Range type | CIDR (cluster 1 example) | Size | Purpose |
|---|---|---|---|
| Primary (nodes) | 10.0.0.0/20 | 4,096 IPs | Node VM addresses |
| Pod secondary range | 10.0.16.0/20 | 4,096 IPs | Pod IP addresses (VPC-native) |
| Service secondary range | 10.0.32.0/20 | 4,096 IPs | ClusterIP service addresses |

Subsequent clusters increment these ranges to avoid overlap (cluster 2 uses 10.0.64.0/20, 10.0.80.0/20, 10.0.96.0/20, and so on).

**VPC-native clusters**: GKE is configured to use VPC-native networking (alias IP ranges). This means pod IP addresses are drawn from the subnet's secondary range and are directly routable within the VPC — no IP masquerading is required for pod-to-pod communication across nodes. This is a prerequisite for Multi-Cluster Services and for using Container-native load balancing with Network Endpoint Groups (NEGs).

### Cloud Router and Cloud NAT

Each cluster subnet is paired with a **Cloud Router** and a **Cloud NAT gateway**. These provide outbound internet connectivity for nodes and pods without requiring public IP addresses on the nodes themselves.

**Cloud Router** establishes a BGP session used by Cloud NAT and, optionally, by Cloud Interconnect or Cloud VPN for hybrid connectivity.

**Cloud NAT** translates outbound traffic from private node and pod IP addresses to ephemeral external IPs managed by Google. Configuration details:

- **IP allocation**: `AUTO_ONLY` — Google automatically allocates and manages the external IPs. No static IPs need to be reserved for NAT.
- **Subnet targeting**: `LIST_OF_SUBNETWORKS` — NAT is applied only to the specific subnet for that cluster, avoiding conflicts when multiple clusters share the same region.
- **Log level**: `ERRORS_ONLY` — NAT translation errors are logged to Cloud Logging, helping diagnose connectivity failures without generating excessive log volume.

**Why private nodes with Cloud NAT?**
Running nodes without public IPs reduces the attack surface — nodes are not directly reachable from the internet. Outbound traffic (pulling container images, calling APIs) flows through NAT. Inbound traffic enters only through the load balancer.

### Firewall Rules

The module creates five explicit firewall rules. Understanding these is important for troubleshooting connectivity issues:

| Rule name | Direction | Source | Ports | Purpose |
|---|---|---|---|---|
| `allow-ssh` | Ingress | `0.0.0.0/0` | TCP 22 | SSH access to nodes (for debugging) |
| `allow-internal` | Ingress | All node, pod, and service CIDRs | TCP/UDP all, ICMP | Full communication between all cluster components |
| `allow-gke-masters` | Ingress | `172.16.0.0/28` | TCP, UDP, ICMP | GKE control plane to node communication |
| `allow-health-checks` | Ingress | Google health checker ranges | TCP | Load balancer health probes reaching pods |
| `allow-webhooks` | Ingress | Node CIDRs | TCP 443, 8443, 9443, 15017 | Istio/ASM admission webhook calls from API server to sidecar injector |

**The webhook rule** (`allow-webhooks`) is critical for ASM operation. When a pod is created in a mesh-enabled namespace, the Kubernetes API server calls the ASM sidecar injector webhook — an HTTPS call from the control plane to a pod running in the cluster. Without this rule, pod creation hangs or fails with a webhook timeout error.

**The health check rule** allows Google's load balancer probers to reach backend pods. These probers originate from four specific Google-owned CIDR ranges. Without this rule, all backends appear unhealthy and the load balancer returns 502 errors.

### Static External IP Addresses

One static external IP address is reserved per cluster. These are used for cluster-level ingress and for identity purposes when establishing cross-cluster communication. Static IPs persist across cluster recreations, allowing DNS records and firewall allowlists to remain stable even if the cluster is rebuilt.

---

## GKE Fleet Management

### What is a GKE Fleet?

A **GKE Fleet** (formerly Anthos fleet) is a logical grouping of Kubernetes clusters that can be managed, configured, and monitored together as a single unit. Fleets are the foundation for all multi-cluster features in GKE — including Multi-Cluster Ingress, Multi-Cluster Services, and Cloud Service Mesh.

Clusters in a fleet share:
- A common **configuration namespace** for fleet-wide policy distribution
- A unified **identity trust domain** enabling cross-cluster service authentication
- Access to **fleet-level features** that span all registered clusters simultaneously

### Fleet Registration

Each cluster is registered as a **Fleet Membership** immediately after creation. The membership:
- Links the cluster to the fleet using its GKE resource path
- Establishes an **OIDC issuer** (`container.googleapis.com`) so the fleet can verify tokens issued by the cluster's API server
- Assigns the cluster a membership ID matching its cluster name

After registration, the module waits for the membership state to reach `READY` before proceeding — checking up to 60 times over 10 minutes. This wait is necessary because fleet registration involves certificate exchange and identity bootstrapping that happens asynchronously.

**Checking fleet membership status manually:**
```bash
gcloud container fleet memberships list --project=PROJECT_ID

gcloud container fleet memberships describe CLUSTER_NAME \
  --location=global \
  --project=PROJECT_ID
```

### Fleet IAM

The GKE Hub service identity (`gkehub.googleapis.com`) is granted two roles at the project level:

| Role | Purpose |
|---|---|
| `roles/gkehub.serviceAgent` | Allows the Hub service to manage fleet memberships and features |
| `roles/container.viewer` | Allows the Hub service to read cluster state for health reporting |

These are service-agent roles granted to Google-managed service accounts, not to end-user identities.

### Fleet Features

Fleet **features** are capabilities that are enabled at the fleet level and automatically apply to all registered member clusters. This module enables the following fleet features:

| Feature | API | Scope |
|---|---|---|
| Cloud Service Mesh | `mesh.googleapis.com` | All clusters |
| Multi-Cluster Ingress | `multiclusteringress.googleapis.com` | All clusters, config on cluster1 |
| Multi-Cluster Services | `multiclusterservicediscovery.googleapis.com` | All clusters |

Enabling a feature at the fleet level means you do not need to configure it cluster-by-cluster. New clusters added to the fleet can inherit these features automatically.

---

## Cloud Service Mesh (Anthos Service Mesh)

### What is Cloud Service Mesh?

**Cloud Service Mesh (CSM)**, formerly known as Anthos Service Mesh (ASM), is Google's managed distribution of Istio. It adds a network infrastructure layer — a **service mesh** — that sits between your application containers and the network, handling cross-cutting concerns such as mutual TLS encryption, traffic management, observability, and policy enforcement without requiring any changes to application code.

The mesh consists of two planes:

- **Data plane**: Envoy proxy sidecars injected into every pod. All inbound and outbound pod traffic passes through the sidecar. The sidecar enforces policies, collects telemetry, and performs load balancing.
- **Control plane**: Managed by Google (`istiod` running as a Google-managed component). The control plane pushes configuration to all sidecars and issues mTLS certificates via its built-in certificate authority.

### Automatic Management Mode

This module enables ASM with `MANAGEMENT_AUTOMATIC` mode at both the fleet level and per-cluster membership. In this mode:

- Google provisions and manages the Istio control plane entirely
- Control plane upgrades happen automatically, aligned with the cluster's release channel
- No `istiod` pods appear in your cluster — the control plane runs in Google's infrastructure
- You interact with the mesh only through Kubernetes custom resources (`VirtualService`, `DestinationRule`, `PeerAuthentication`, etc.)

This is distinct from **manual management mode**, where you install and upgrade `istiod` yourself using the `asmcli` tool.

**Checking mesh status:**
```bash
gcloud container fleet mesh describe --project=PROJECT_ID
```

### Sidecar Injection

Sidecar injection is controlled at the namespace level using a label. The `bank-of-anthos` namespace carries the label:

```
istio.io/rev=asm-managed
```

This tells the ASM mutating admission webhook to inject an Envoy sidecar into every new pod created in this namespace. The revision label (`asm-managed`) pins injection to the Google-managed control plane revision rather than a specific version string, ensuring injected sidecars automatically track the managed revision.

**What the sidecar does:**
- Intercepts all inbound and outbound TCP traffic using `iptables` rules set up by an init container
- Terminates and originates mTLS connections, encrypting all pod-to-pod traffic within the mesh
- Reports request telemetry (latency, error rate, traffic volume) to Cloud Monitoring
- Enforces `AuthorizationPolicy` rules (which services can talk to which)
- Participates in distributed tracing by propagating trace context headers to Cloud Trace

### Mutual TLS (mTLS)

With ASM enabled, all communication between pods in the mesh is encrypted with **mutual TLS** by default. Each sidecar is issued a short-lived X.509 certificate by the ASM certificate authority. The certificate encodes the workload's SPIFFE identity:

```
spiffe://PROJECT_ID.svc.id.goog/ns/NAMESPACE/sa/SERVICE_ACCOUNT
```

This identity is verifiable by any other sidecar in the mesh, enabling fine-grained `AuthorizationPolicy` rules such as:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-only
  namespace: bank-of-anthos
spec:
  selector:
    matchLabels:
      app: ledger-writer
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/bank-of-anthos/sa/bank-of-anthos"
```

This policy permits only the `bank-of-anthos` service account (used by the frontend) to call the `ledger-writer` service — all other callers are denied, regardless of network-level access.

### Traffic Management

ASM provides rich traffic management through Istio custom resources. These operate at Layer 7 (HTTP/gRPC) and allow:

- **VirtualService**: define routing rules — route 10% of traffic to a canary version, retry failed requests up to 3 times, inject artificial delays for chaos testing
- **DestinationRule**: configure load balancing algorithm (round-robin, least-connections, consistent hashing), circuit breaker thresholds, and connection pool settings per destination service
- **ServiceEntry**: register external services (outside the mesh) so sidecars can apply policies and collect telemetry for egress traffic

**Example: Canary deployment with traffic splitting**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
  namespace: bank-of-anthos
spec:
  hosts:
  - frontend
  http:
  - route:
    - destination:
        host: frontend
        subset: stable
      weight: 90
    - destination:
        host: frontend
        subset: canary
      weight: 10
```

### Observability with ASM

ASM automatically generates the **golden signals** (latency, traffic, errors, saturation) for every service-to-service call in the mesh, with no instrumentation changes required in the application.

**Service metrics** are available in Cloud Monitoring under the `istio.io` metric namespace:
- `istio.io/service/server/request_count` — inbound request volume
- `istio.io/service/server/response_latencies` — inbound request latency distribution
- `istio.io/service/client/request_count` — outbound request volume per destination

**Service topology** is visualised in the **Cloud Service Mesh dashboard** in the Google Cloud Console. This shows a live graph of all services, their communication paths, error rates, and latency — built automatically from sidecar telemetry without any manual configuration.

**Distributed traces** are sent to Cloud Trace. Each request that enters the mesh generates a trace spanning all microservice hops, allowing engineers to pinpoint which service introduced a latency spike or error.

### Istio ConfigMap for Stackdriver

This module applies a ConfigMap to the `istio-system` namespace that explicitly enables **Stackdriver** (Cloud Monitoring/Trace) as the telemetry backend for ASM:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-asm-managed
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      tracing:
        stackdriver: {}
```

This ensures that trace spans from all sidecar proxies are exported to Cloud Trace using the Stackdriver exporter, making distributed traces visible in the Cloud Console without any per-pod instrumentation.

### Multi-Cluster Mesh

When ASM is enabled across multiple clusters in the same fleet, the mesh spans cluster boundaries. Services in `cluster1` can call services in `cluster2` using their Kubernetes DNS names, with the sidecar handling the cross-cluster routing, mTLS, and telemetry transparently.

This is possible because all clusters share the same **trust domain** (`PROJECT_ID.svc.id.goog`). Certificates issued by the ASM CA in either cluster are trusted by sidecars in all clusters, enabling mutual authentication across cluster boundaries.

---
