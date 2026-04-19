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
