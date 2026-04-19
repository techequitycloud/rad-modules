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
