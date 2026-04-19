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
