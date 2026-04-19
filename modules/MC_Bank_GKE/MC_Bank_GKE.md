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

## Multi-Cluster Ingress and Global Load Balancing

### The Problem Multi-Cluster Ingress Solves

In a single-cluster deployment, a standard Kubernetes `Ingress` resource provisions a regional Google Cloud Load Balancer with backends in one region. Users in other regions are served from that single region, introducing latency. If that region experiences an outage, the application becomes unavailable.

**Multi-Cluster Ingress (MCI)** solves this by provisioning a single **Global External Application Load Balancer** whose backends span multiple GKE clusters across regions. Google's network routes each user's request to the nearest healthy cluster — the same anycast routing used by Google's own global services.

### Architecture

```
User (Europe)          User (US East)         User (Asia)
      │                      │                      │
      └──────────────────────┼──────────────────────┘
                             │
                  Global Anycast IP (single IP)
                             │
                  Google Cloud Load Balancer
                  (globally distributed POPs)
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
   NEG (us-west1 cluster1)       NEG (us-east1 cluster2)
   frontend pods                 frontend pods
```

A single global IP address is reserved and used across all regions. Google's Premium Tier network routes traffic to the closest point of presence, then carries it over Google's backbone to the nearest healthy cluster.

### MultiClusterIngress Resource

The `MultiClusterIngress` custom resource is applied to the **config cluster** (`cluster1`). The GKE Hub Multi-Cluster Ingress controller watches this resource and provisions the underlying Google Cloud load balancer infrastructure.

```yaml
apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: bank-of-anthos-mci
  namespace: bank-of-anthos
spec:
  template:
    spec:
      backend:
        serviceName: bank-of-anthos-mcs
        servicePort: 80
```

**Key points:**
- Applied only to the config cluster — the MCI controller propagates load balancer configuration across all fleet clusters automatically
- References a `MultiClusterService` (not a regular Kubernetes Service) as its backend
- The MCI controller creates and manages Network Endpoint Groups (NEGs) in every cluster where matching pods are running

### MultiClusterService Resource

The `MultiClusterService` (MCS) resource defines which pods across which clusters should be included as backends for the global load balancer.

```yaml
apiVersion: networking.gke.io/v1
kind: MultiClusterService
metadata:
  name: bank-of-anthos-mcs
  namespace: bank-of-anthos
spec:
  template:
    spec:
      selector:
        app: frontend
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 8080
  clusters:
  - link: "us-west1/gke-cluster-1"
  - link: "us-east1/gke-cluster-2"
```

The `clusters` list explicitly enumerates which cluster deployments contribute backends. The MCI controller creates a corresponding `NodePort` service (for load balancer health checks) and a NEG in each listed cluster.

**MCS vs standard Kubernetes Service**: A standard `Service` of type `LoadBalancer` provisions a regional load balancer — one per cluster, one per region, with separate IPs. An MCS with MCI provisions one global load balancer with backends in all listed clusters. You manage one resource, not N.

### NodePort Service and BackendConfig

Each cluster also runs a `NodePort` service for the frontend, which the global load balancer uses to reach pods. This service is annotated to reference a `BackendConfig`:

```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: bank-of-anthos
  namespace: bank-of-anthos
spec:
  healthCheck:
    checkIntervalSec: 2
    timeoutSec: 1
    healthyThreshold: 1
    unhealthyThreshold: 10
    type: HTTP
    requestPath: /
  iap:
    enabled: false
```

**BackendConfig** customises the behaviour of the Google Cloud load balancer backend service. Key settings here:

- **Health check interval of 2 seconds** with an unhealthy threshold of 10 — the load balancer marks a backend unhealthy only after 10 consecutive failures (20 seconds), avoiding flapping during brief pod restarts
- **Healthy threshold of 1** — a single successful probe immediately marks a backend healthy, minimising the time new pods take to receive traffic after startup
- **IAP disabled** — Identity-Aware Proxy is not enabled, but the `BackendConfig` structure is in place so IAP can be switched on without changing the service configuration

### Managed Certificates

TLS termination is handled by a **Google-managed TLS certificate** provisioned automatically by GCP. No manual certificate procurement, CSR generation, or renewal is required.

```yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: bank-of-anthos
  namespace: bank-of-anthos
spec:
  domains:
  - boa.GLOBAL_IP.sslip.io
```

The domain uses **sslip.io** — a public DNS service that resolves any domain of the form `ADDRESS.sslip.io` to `ADDRESS`. This allows the module to provision a valid publicly-resolvable domain and obtain a real TLS certificate without requiring a custom domain or DNS zone configuration.

**Certificate lifecycle:**
1. The `ManagedCertificate` resource is created referencing the sslip.io domain
2. GCP provisions the certificate via Let's Encrypt (or Google's CA)
3. The certificate is attached to the load balancer frontend automatically
4. GCP handles renewal before expiry — typically 30 days before the certificate expires

**Certificate provisioning takes 10–60 minutes** after the load balancer is created, as GCP must perform DNS validation. During this window, HTTPS requests may fail or show a certificate warning.

### FrontendConfig and HTTPS Redirect

A `FrontendConfig` resource enforces an HTTPS redirect, ensuring all HTTP traffic is automatically upgraded:

```yaml
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: bank-of-anthos
  namespace: bank-of-anthos
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: MOVED_PERMANENTLY_DEFAULT
```

This configures the load balancer frontend to return HTTP 301 for any request arriving on port 80, redirecting the client to the HTTPS equivalent URL. This is enforced at the load balancer level — the redirect happens before traffic reaches any pod.

### Config Cluster Role

The Multi-Cluster Ingress feature requires one cluster to be designated as the **config cluster**. In this module, `cluster1` (us-west1) is the config cluster. The MCI controller runs in the GKE Hub control plane and watches the config cluster for `MultiClusterIngress` and `MultiClusterService` resources.

**Implications of the config cluster pattern:**
- All MCI/MCS resources must be applied to the config cluster, not to other clusters
- If the config cluster is unavailable, the load balancer continues serving traffic using its last known configuration — existing backends remain healthy
- The config cluster can be changed after deployment by updating the fleet feature configuration

### Traffic Flow End-to-End

1. A user's DNS query for `boa.GLOBAL_IP.sslip.io` resolves to the single global anycast IP
2. The user's TCP connection is terminated at the nearest Google point of presence
3. The load balancer selects the nearest healthy cluster backend using latency-based routing
4. The request is forwarded to a `NodePort` on a node in the selected cluster
5. The node routes the request to a frontend pod via the NEG
6. The frontend pod's Envoy sidecar intercepts the inbound request, applies policies, and records telemetry
7. The frontend calls downstream services (user-service, ledger-writer, etc.) over mTLS within the mesh

---

## Bank of Anthos Application

### Overview

**Bank of Anthos** (v0.6.7) is an open-source, HTTP-based banking simulation developed by Google Cloud Platform. It is the reference application deployed by this module and is the vehicle through which engineers interact with all the GKE features described in earlier sections. The application simulates a retail bank — users can create accounts, deposit funds, transfer money between accounts, and view transaction history.

The application is intentionally multi-language and multi-framework, reflecting the polyglot reality of real microservices platforms. This makes it a useful reference for understanding how a service mesh handles heterogeneous workloads consistently.

Source code and additional documentation: [https://github.com/GoogleCloudPlatform/bank-of-anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos)

### Microservices Architecture

The application consists of nine services, each running as an independent Kubernetes `Deployment`:

| Service | Language | Type | Role |
|---|---|---|---|
| **frontend** | Python (Flask) | Stateless | Web UI — serves HTML, handles login/signup, proxies API calls to backend services |
| **userservice** | Python (Flask) | Stateless | Account management — creates users, validates credentials, issues JWT tokens |
| **contacts** | Python (Flask) | Stateless | Contact list management — stores payee account numbers for a user |
| **ledgerwriter** | Java (Spring Boot) | Stateless | Transaction ingestion — validates and writes new transactions to the ledger database |
| **balancereader** | Java (Spring Boot) | Stateless | Balance cache — reads account balances from the ledger database with caching |
| **transactionhistory** | Java (Spring Boot) | Stateless | History cache — reads past transactions for a user with caching |
| **loadgenerator** | Python (Locust) | Stateless | Synthetic traffic — simulates realistic user activity against the frontend |
| **accounts-db** | PostgreSQL | Stateful | Stores user account records and contact data |
| **ledger-db** | PostgreSQL | Stateful | Stores the complete transaction ledger |

### Service Communication Map

```
                    ┌─────────────┐
          ┌────────▶│  userservice│
          │         └─────────────┘
          │         ┌─────────────┐
          ├────────▶│   contacts  │
          │         └─────────────┘
┌──────────┐        ┌─────────────┐
│ frontend │───────▶│ledgerwriter │───▶ ledger-db
└──────────┘        └─────────────┘
          │         ┌─────────────┐
          ├────────▶│balancereader│───▶ ledger-db
          │         └─────────────┘
          │         ┌──────────────────┐
          └────────▶│transactionhistory│───▶ ledger-db
                    └──────────────────┘

userservice ───▶ accounts-db
contacts    ───▶ accounts-db
```

All service-to-service calls are HTTP on port 8080. Within the mesh, these calls are transparently upgraded to mTLS by the Envoy sidecars. The frontend never calls a database directly — database access is encapsulated within the relevant backend service.

### Authentication: JWT Token Flow

Bank of Anthos implements stateless authentication using **JSON Web Tokens (JWT)**. Understanding this flow illustrates several important Kubernetes security patterns.

**JWT key pair**: A RSA key pair is generated at deployment time and stored as a Kubernetes `Secret` named `jwt-key` in the `bank-of-anthos` namespace. The private key is mounted into `userservice` (which signs tokens). The public key is mounted into all other services (which verify tokens).

**Login flow:**
1. User submits credentials to the frontend via an HTML form
2. Frontend forwards credentials to `userservice` over HTTP
3. `userservice` validates credentials against `accounts-db`
4. On success, `userservice` signs a JWT with the private key and returns it
5. Frontend stores the token in an HTTP-only cookie
6. All subsequent requests carry the JWT cookie

**Token verification:**
- Each service that handles authenticated requests mounts the JWT public key at `/tmp/.ssh/publickey`
- Incoming requests are verified locally — no call to `userservice` is needed per request
- Token expiry is set to 3600 seconds (1 hour) in `userservice`

**Why this matters for platform engineers**: The JWT secret is a textbook example of how to use Kubernetes Secrets for credential distribution across pods. The private key is only accessible to the one service that needs it; all other services receive only the public key. This principle of least privilege is enforced at the pod volume mount level.

### Kubernetes Resource Patterns

The Bank of Anthos manifests demonstrate production-grade Kubernetes resource configuration. The following patterns are worth studying in detail.

#### Resource Requests and Limits

Every container defines explicit CPU and memory requests and limits. This is required for the GKE scheduler to make informed placement decisions and for the Kubernetes resource quota system to function correctly.

Example (frontend):
```yaml
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 250m
    memory: 128Mi
```

Example (userservice — higher because it handles JWT cryptography):
```yaml
resources:
  requests:
    cpu: 260m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

**Requests vs limits:**
- **Requests** are used by the scheduler to select a node with sufficient available capacity. A pod is guaranteed at least its requested resources.
- **Limits** cap the maximum resources a container can consume. Exceeding the memory limit triggers an OOMKill. Exceeding the CPU limit causes throttling (not termination).
- Setting limits equal to requests creates a **Guaranteed** QoS class — the pod is the last to be evicted under memory pressure. Setting limits higher than requests creates **Burstable** QoS.

#### Security Contexts

Every container in Bank of Anthos runs with a strict security context:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - all
  privileged: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
```

**What each setting does:**

| Setting | Effect |
|---|---|
| `runAsNonRoot: true` | Pod fails to start if the container image runs as UID 0 |
| `runAsUser: 1000` | Overrides the image's default user to UID 1000 |
| `readOnlyRootFilesystem: true` | Container cannot write to its own filesystem — all writes must go to explicitly mounted volumes |
| `allowPrivilegeEscalation: false` | Prevents `setuid` binaries from elevating privileges within the container |
| `capabilities: drop: [all]` | Removes all Linux capabilities (e.g. `NET_RAW`, `SYS_CHROOT`) — the container runs with no kernel-level privileges |

These settings align with the **Pod Security Standards** `restricted` profile and are enforced by GKE Security Posture's workload auditing.

Because `readOnlyRootFilesystem` is set, writable directories needed at runtime are provided as `emptyDir` volumes — typically `/tmp`:

```yaml
volumeMounts:
- name: tmp
  mountPath: /tmp
volumes:
- name: tmp
  emptyDir: {}
```

#### Health Probes

Every deployment configures both liveness and readiness probes against the `/ready` endpoint:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
livenessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 15
```

**Readiness vs liveness:**
- **Readiness probe**: determines whether the pod should receive traffic. A failing readiness probe removes the pod from Service endpoints — it stays running but gets no requests. Used to hold traffic until the application has finished initialising (e.g. loaded caches, established database connections).
- **Liveness probe**: determines whether the pod is alive. A failing liveness probe causes kubelet to restart the container. The 60-second initial delay gives the JVM-based Java services time to complete startup before liveness checking begins.

#### Stateful Services: PostgreSQL

The two databases (`accounts-db`, `ledger-db`) run as Kubernetes `StatefulSets`. StatefulSets provide:
- **Stable pod identity**: pods are named `ledger-db-0`, `ledger-db-1` etc. rather than random hashes
- **Ordered startup and shutdown**: pods start in order (0, then 1) and terminate in reverse order
- **Stable DNS**: each pod gets a stable DNS entry (`ledger-db-0.ledger-db.bank-of-anthos.svc.cluster.local`)

For this module, each database runs as a single replica (`replicas: 1`) with storage on an `emptyDir` volume. This is appropriate for a learning environment — data does not persist across pod restarts, keeping the application stateless from a cluster lifecycle perspective.

In a production deployment, the databases would use `PersistentVolumeClaims` backed by GCP Persistent Disks or Cloud SQL.

#### ConfigMaps for Service Discovery

Service endpoint addresses are distributed to pods via Kubernetes `ConfigMap`s rather than hard-coded environment variables. The `service-api-config` ConfigMap maps each service name to its DNS address:

```yaml
LEDGER_ADDR: "ledgerwriter:8080"
BALANCES_ADDR: "balancereader:8080"
HISTORY_ADDR: "transactionhistory:8080"
CONTACTS_ADDR: "contacts:8080"
USERSERVICE_ADDR: "userservice:8080"
```

These resolve via Kubernetes DNS (`service-name.namespace.svc.cluster.local`). The frontend reads these at startup and uses them for all backend API calls — no hardcoded IPs or external DNS lookups.

### Load Generator

The `loadgenerator` service runs **Locust**, an open-source load testing framework, continuously generating realistic synthetic traffic against the frontend. It simulates:
- New user signups
- Login and session management
- Account balance checks
- Peer-to-peer transfers between accounts

This is important for observability exploration — the load generator ensures the ASM service topology dashboard, Cloud Monitoring dashboards, and Cloud Trace all show live data immediately after deployment, without requiring manual interaction with the application.

---

## Module Configuration Options

The following options are available when deploying this module. Defaults reflect the configuration used if no override is provided.

### Core Settings

| Option | Default | Description |
|---|---|---|
| **GCP Project ID** | *(required)* | The destination GCP project where all resources are created |
| **Deployment ID** | *(auto-generated)* | A short alphanumeric suffix appended to resource names to avoid collisions. Leave blank to generate a random 4-character hex ID |
| **Available Regions** | `us-west1`, `us-east1` | The list of GCP regions available for cluster placement. Clusters are assigned regions round-robin from this list. Add more regions to distribute clusters further |

### Cluster Settings

| Option | Default | Description |
|---|---|---|
| **Cluster Type** | Autopilot | Choose between GKE Autopilot (fully managed nodes) and Standard (self-managed node pools with spot instances). See the GKE Cluster Features section for a full comparison |
| **Number of Clusters** | 2 | The number of GKE clusters to create. Each cluster is placed in a region from the available regions list. Increasing this number adds more backends to the global load balancer |
| **Release Channel** | REGULAR | The GKE release channel controlling the cadence of automatic cluster upgrades. Options: RAPID, REGULAR, STABLE, EXTENDED |

### Service Mesh Settings

| Option | Default | Description |
|---|---|---|
| **Enable Cloud Service Mesh** | Yes | When enabled, ASM is installed on all clusters with automatic management mode. Disabling this removes mTLS, the service topology dashboard, and distributed tracing |
| **Cloud Service Mesh Version** | `1.23.4-asm.1` | The ASM version to install. This is pinned to a specific release for reproducibility. When upgrading, change this value and re-apply |

### Network Settings

| Option | Default | Description |
|---|---|---|
| **VPC Network Name** | `vpc-network` | The name assigned to the custom VPC |
| **Subnet Name Prefix** | `vpc-subnet` | Subnets are named `vpc-subnet-cluster1`, `vpc-subnet-cluster2`, etc. |

### Application Settings

| Option | Default | Description |
|---|---|---|
| **Deploy Application** | Yes | Controls whether Bank of Anthos is downloaded and deployed. Set to No to provision only the infrastructure (clusters, networking, mesh) without the application |

---

## GCP APIs Enabled

This module enables the following Google Cloud APIs on the destination project. These APIs are not disabled on teardown, preventing accidental disruption to other workloads that may depend on them.

### Core Platform APIs

| API | Purpose |
|---|---|
| `container.googleapis.com` | Google Kubernetes Engine — cluster creation and management |
| `cloudresourcemanager.googleapis.com` | Project resource management — required by Terraform for IAM and project operations |
| `iam.googleapis.com` | Identity and Access Management — service account and role management |
| `iamcredentials.googleapis.com` | Service account impersonation — used for Workload Identity token exchange |
| `compute.googleapis.com` | Compute Engine — VPC networks, subnets, firewall rules, static IPs, NAT |

### Observability APIs

| API | Purpose |
|---|---|
| `monitoring.googleapis.com` | Cloud Monitoring — metrics ingestion and dashboards |
| `logging.googleapis.com` | Cloud Logging — log ingestion from clusters and workloads |
| `cloudtrace.googleapis.com` | Cloud Trace — distributed trace collection from ASM sidecars |

### Fleet and Mesh APIs

| API | Purpose |
|---|---|
| `anthos.googleapis.com` | Anthos platform — umbrella API for fleet features |
| `anthosgke.googleapis.com` | Anthos GKE — GKE-specific Anthos features |
| `gkehub.googleapis.com` | GKE Hub — fleet membership and feature management |
| `gkeconnect.googleapis.com` | GKE Connect — secure tunnel between fleet and cluster API servers |
| `mesh.googleapis.com` | Cloud Service Mesh — ASM control plane |
| `meshconfig.googleapis.com` | Mesh configuration — ASM configuration distribution |
| `multiclusterservicediscovery.googleapis.com` | Multi-Cluster Services — cross-cluster service discovery |
| `multiclusteringress.googleapis.com` | Multi-Cluster Ingress — global load balancer management |
| `trafficdirector.googleapis.com` | Traffic Director — xDS-based traffic management underlying MCS/MCI |

### Security and Compliance APIs

| API | Purpose |
|---|---|
| `containersecurity.googleapis.com` | GKE Security Posture — workload auditing and vulnerability scanning |
| `containerscanning.googleapis.com` | Container image vulnerability scanning in Artifact Registry |
| `websecurityscanner.googleapis.com` | Web Security Scanner — automated web application vulnerability scanning |
| `anthospolicycontroller.googleapis.com` | Policy Controller — OPA Gatekeeper-based policy enforcement |
| `anthosconfigmanagement.googleapis.com` | Config Management — GitOps-based configuration distribution |
| `iap.googleapis.com` | Identity-Aware Proxy — application-level access control |

### Storage, Build, and Networking APIs

| API | Purpose |
|---|---|
| `storage.googleapis.com` | Cloud Storage — used by GCS FUSE CSI driver and build artefacts |
| `artifactregistry.googleapis.com` | Artifact Registry — container image storage |
| `cloudbuild.googleapis.com` | Cloud Build — CI/CD pipeline execution |
| `secretmanager.googleapis.com` | Secret Manager — secure storage for sensitive configuration |
| `servicenetworking.googleapis.com` | Service Networking — private service access for Cloud SQL and other managed services |
| `sqladmin.googleapis.com` | Cloud SQL Admin — managed relational database instances |
| `pubsub.googleapis.com` | Cloud Pub/Sub — asynchronous messaging |
| `dns.googleapis.com` | Cloud DNS — managed DNS zones |
| `networkmanagement.googleapis.com` | Network Intelligence Center — network topology and connectivity analysis |
| `billingbudgets.googleapis.com` | Billing Budgets — cost alerting and budget management |

---

## Deployment Lifecycle

### Apply Phase

When the module is deployed, resources are created in the following sequence. Each phase depends on the previous completing successfully.

**Phase 1 — Infrastructure (≈ 5–15 minutes)**
- Custom VPC and subnets are created
- Cloud Routers and NAT gateways are provisioned
- Static external IP addresses are reserved
- Firewall rules are applied
- GKE clusters are created (Autopilot or Standard)

GKE cluster creation is the most time-consuming step. Autopilot clusters typically provision in 5–8 minutes. Standard clusters provision in 3–5 minutes but require an additional 2–4 minutes for node pool nodes to join and become Ready.

**Phase 2 — Fleet Registration (≈ 5–10 minutes)**
- GKE Hub service identity is created
- Each cluster is registered as a Fleet membership
- The module polls for membership state `READY` — checking every 10 seconds for up to 10 minutes per cluster
- Memberships must reach READY before ASM can be enabled

**Phase 3 — Service Mesh (≈ 10–20 minutes)**
- Fleet-level ASM feature is enabled
- Per-cluster ASM membership management is set to `MANAGEMENT_AUTOMATIC`
- The module polls for mesh configuration state — checking every 15 seconds for up to 15 minutes
- If ASM does not reach configured state within the timeout, the module continues with a warning — ASM provisioning often completes shortly after

**Phase 4 — Application (≈ 5–10 minutes)**
- Bank of Anthos v0.6.7 is downloaded from GitHub
- The `bank-of-anthos` namespace is created on each cluster with the ASM injection label
- The JWT key pair secret is applied to each cluster
- All Kubernetes manifests are applied using server-side apply
- The module waits up to 10 minutes for all Deployments to reach `Available` condition
- Multi-Cluster Ingress feature is enabled in the fleet
- MCI, MCS, NodePort, BackendConfig, ManagedCertificate, FrontendConfig, and Istio ConfigMap are applied to the config cluster

**Total deployment time**: approximately 25–55 minutes end-to-end, depending on region and GCP service latency.

### Idempotency

All Kubernetes resources are applied using `--server-side --force-conflicts`. This means re-running the deployment:
- Creates resources that do not exist
- Updates resources whose configuration has changed
- Leaves unchanged resources unmodified
- Does not delete resources that are no longer referenced (use `kubectl delete` explicitly for removals)

This makes re-applies safe and predictable — running the deployment twice produces the same result as running it once.

### Destroy Phase

Teardown follows the reverse dependency order and includes several explicit cleanup steps that Terraform alone cannot handle:

**Step 1 — MCI resource cleanup**
MultiClusterIngress and MultiClusterService resources are deleted first. These resources instruct Google Cloud to deprovision the global load balancer backends and NEGs. The module waits up to 3 minutes for the `MultiClusterIngress` to be fully deleted before proceeding. Skipping this step leaves orphaned load balancer components that block VPC deletion.

**Step 2 — ASM membership disable**
ASM is disabled per-cluster membership (`--management manual`) before fleet unregistration. This allows the ASM control plane to cleanly withdraw from the cluster.

**Step 3 — MCI feature disable**
The Multi-Cluster Ingress fleet feature is disabled using `gcloud alpha container hub ingress disable --force`. This removes the MCI controller and cleans up fleet-level load balancer state.

**Step 4 — Fleet unregistration**
Each cluster membership is deleted from the fleet. This severs the cluster's connection to GKE Hub and removes it from all fleet features.

**Step 5 — Fleet-level ASM disable**
After all memberships are unregistered, the fleet-level ASM feature is disabled.

**Step 6 — Infrastructure teardown**
Kubernetes namespaces are deleted (with a 15-minute timeout to allow finalizers to complete), then GKE clusters, node pools, subnets, routers, NAT gateways, and finally the VPC are deleted.

**Step 7 — Network cleanup**
Before the VPC is deleted, a cleanup script removes GKE-managed firewall rules (matching `gke-*-mcsd`) and Network Endpoint Groups (matching `gsmrsvd*`) that were created by GKE but are not managed by this module's Terraform state. Without this step, VPC deletion fails with a "resource in use" error.

**Total destroy time**: approximately 15–30 minutes.

---

## Observability

This module enables a comprehensive, multi-layer observability stack. No additional tooling needs to be installed — everything is available immediately after deployment through the Google Cloud Console.

### Cloud Monitoring

Cloud Monitoring is the primary metrics platform for this deployment. GKE automatically exports metrics from multiple sources:

**System component metrics** (enabled by default on all clusters):
- `kubernetes.io/node/*` — node CPU, memory, disk, and network utilisation
- `kubernetes.io/pod/*` — pod CPU and memory consumption
- `kubernetes.io/container/*` — container restarts, resource requests vs actual usage
- `kubernetes.io/node_daemon/*` — kubelet and system daemon health

**Managed Prometheus metrics** (collected via the built-in Prometheus scraper):
- All standard Prometheus exposition format metrics from pods annotated for scraping
- Kubernetes control plane metrics (API server request rate, etcd latency, scheduler throughput)

**Viewing metrics in the Cloud Console:**

Navigate to **Monitoring → Metrics Explorer** and use the following resource types:
- `k8s_cluster` — cluster-level aggregates
- `k8s_node` — per-node metrics
- `k8s_pod` — per-pod metrics
- `k8s_container` — per-container metrics

**Pre-built GKE dashboards** are available under **Monitoring → Dashboards → GKE**:
- **GKE Cluster Overview**: node count, pod count, CPU/memory utilisation trends
- **GKE Workloads**: per-Deployment resource usage, restart counts, availability
- **Kubernetes Engine Prometheus Overview**: Prometheus metrics from all scraped targets

### Cloud Service Mesh Dashboard

The **Cloud Service Mesh dashboard** is the most valuable observability surface for understanding microservice behaviour. It is available under **Kubernetes Engine → Service Mesh** in the Google Cloud Console.

**What the dashboard shows:**
- **Service topology graph**: a live, auto-generated map of all services and their communication edges, built from sidecar telemetry. Each edge shows request rate, error rate, and latency.
- **Service-level SLOs**: for each service, the dashboard displays the four golden signals — latency, traffic (requests/sec), error rate, and saturation (resource utilisation)
- **Per-service details**: drill into any service to see inbound and outbound request breakdowns, latency percentiles (p50, p95, p99), and error code distributions

Because the load generator continuously sends traffic, all services will show populated metrics immediately after deployment. This makes the topology graph an excellent starting point for understanding how the microservices interact.

**ASM metrics in Cloud Monitoring** are accessible under the `istio.io` metric namespace:

| Metric | Description |
|---|---|
| `istio.io/service/server/request_count` | Total inbound requests per service |
| `istio.io/service/server/response_latencies` | Inbound request latency distribution |
| `istio.io/service/client/request_count` | Outbound requests per source/destination pair |
| `istio.io/service/client/roundtrip_latencies` | End-to-end client-side latency |

### Cloud Logging

All cluster logs are exported to Cloud Logging automatically. GKE collects logs from two sources:

**System component logs** (control plane and node-level):
- `kubelet` — node agent logs, pod scheduling decisions, volume mount events
- `kube-proxy` — iptables rule updates, service endpoint changes
- `container-runtime` — container start/stop events, image pull logs

**Workload logs** (application stdout/stderr):
- All container stdout and stderr streams are captured and indexed
- Logs are associated with Kubernetes metadata: cluster name, namespace, pod name, container name, and labels

**Querying logs in Log Explorer:**

Navigate to **Logging → Log Explorer** and use these resource filters:

```
resource.type="k8s_container"
resource.labels.cluster_name="gke-cluster-1"
resource.labels.namespace_name="bank-of-anthos"
resource.labels.container_name="frontend"
```

**Useful log queries for Bank of Anthos:**

View all errors across the application:
```
resource.type="k8s_container"
resource.labels.namespace_name="bank-of-anthos"
severity>=ERROR
```

View transaction writes to the ledger:
```
resource.type="k8s_container"
resource.labels.container_name="ledgerwriter"
resource.labels.namespace_name="bank-of-anthos"
```

View JWT authentication events:
```
resource.type="k8s_container"
resource.labels.container_name="userservice"
resource.labels.namespace_name="bank-of-anthos"
```

**Log-based metrics**: Cloud Logging allows you to create custom metrics from log patterns. For example, a count of `severity=ERROR` log entries from `ledgerwriter` can be turned into a Cloud Monitoring metric, enabling alerting on transaction failure rates without any application code changes.

### Cloud Trace

**Cloud Trace** receives distributed traces from ASM sidecars via the Stackdriver exporter configured in the Istio ConfigMap. Every inbound request to the frontend generates a trace that spans all microservice hops.

Navigate to **Trace → Trace List** in the Cloud Console to view traces.

**What a Bank of Anthos trace looks like:**

A payment transaction trace spans:
```
frontend (POST /payment)                     ~45ms total
  └─ ledgerwriter (POST /transactions)       ~30ms
       └─ ledger-db (SQL INSERT)             ~5ms
  └─ balancereader (GET /balances/{id})      ~10ms
       └─ ledger-db (SQL SELECT)             ~3ms
```

This trace shows the complete call graph, the latency contributed by each service, and whether any span returned an error. This is invaluable for identifying which microservice is the bottleneck in a slow request.

**Trace sampling**: ASM samples 100% of traces by default in this configuration. In high-throughput production environments, sampling rates are typically reduced to 1–5% to control cost and storage volume.

**Latency analysis**: The **Trace → Analysis Reports** view aggregates trace data to show latency distributions over time. This allows you to detect latency regressions after deployments — for example, confirming that a new version of `ledgerwriter` did not increase the p99 latency of `/transactions`.

### GKE Security Posture Dashboard

Navigate to **Kubernetes Engine → Security Posture** in the Google Cloud Console to view the security findings generated by the Security Posture feature enabled on each cluster.

**Workload configuration findings**: GKE scans all running pods and reports issues such as:
- Containers running as root
- Missing resource limits
- Containers with `allowPrivilegeEscalation: true`
- Pods without liveness or readiness probes

Because Bank of Anthos implements the `restricted` Pod Security Standards profile (non-root, read-only filesystem, dropped capabilities), most workload findings should be absent or informational, providing a clean baseline to compare against other workloads.

**Vulnerability findings**: GKE scans the OS packages and language dependencies in every running container image and reports CVEs with CVSS scores. Findings are grouped by severity (Critical, High, Medium, Low) and include remediation guidance such as the patched package version.

### Cost Breakdown

Navigate to **Billing → Cost breakdown** and filter by **Label: goog-k8s-cluster-name** to see per-cluster cost attribution. With GKE Cost Management enabled, you can further break down costs by namespace, enabling per-team chargeback visibility.

---
