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
