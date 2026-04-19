---
title: "EKS_GKE Module Documentation"
sidebar_label: "EKS_GKE"
---

# EKS_GKE Module

## Overview

The EKS_GKE module provisions a complete Amazon Elastic Kubernetes Service (EKS) cluster on AWS and registers it with Google Cloud as a **GKE Attached Cluster**. Once registered, the EKS cluster is visible and manageable from the Google Cloud console alongside any native GKE clusters in the same project — giving platform engineers a single pane of glass across both clouds.

This module is designed as a hands-on learning environment for platform engineers who want to understand how Google Cloud's multi-cloud Kubernetes capabilities work in practice. By deploying it, you gain direct experience with:

- **GKE Attached Clusters** — Google Cloud's mechanism for bringing any conformant Kubernetes cluster under GCP management
- **GKE Fleet** — a logical grouping of clusters (across clouds and regions) that enables unified policy, configuration, and service management
- **Anthos** — Google's application management platform that provides a consistent operating model across GKE, EKS, AKS, and on-premises clusters
- **Cloud Logging and Cloud Monitoring** — unified observability for workloads running on AWS, queried and alerting in the same place as GCP-native workloads
- **Google Cloud Managed Service for Prometheus** — a fully managed Prometheus-compatible metrics backend that collects metrics from EKS without requiring you to operate a Prometheus server
- **Connect Gateway** — a secure proxy that lets you run `kubectl` against the EKS cluster using your Google identity, with no AWS credentials or VPN required

The module takes approximately **10 minutes** to deploy from a single configuration file. It requires an AWS account (for EKS) and a Google Cloud project (for registration and observability).

---

## What Gets Deployed

At a high level, the module creates two sets of resources in parallel and then connects them:

**On AWS:**
- A dedicated Virtual Private Cloud (VPC) with subnets spread across three availability zones
- An EKS cluster running Kubernetes 1.34 (configurable)
- A managed node group of 2–5 EC2 worker nodes
- The IAM roles and policies required for EKS to operate
- An Anthos Connect Agent installed onto the EKS cluster

**On Google Cloud:**
- Ten required Google Cloud APIs are enabled on the target project
- The EKS cluster is registered as a GKE Attached Cluster in the specified GCP region
- The cluster is enrolled in a GKE Fleet
- Cloud Logging is configured to receive system and workload logs from EKS
- Cloud Managed Prometheus is configured to collect metrics from EKS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            EKS_GKE Module                                   │
│                                                                             │
│   AWS (default: us-west-2)              Google Cloud (default: us-central1) │
│   ─────────────────────────             ────────────────────────────────    │
│                                                                             │
│   ┌─────────────────────────┐           ┌───────────────────────────────┐   │
│   │  VPC  (10.0.0.0/16)     │           │  GKE Multi-Cloud API          │   │
│   │  3 subnets × 3 AZs      │           │  Attached Cluster "primary"   │   │
│   └──────────┬──────────────┘           │  • distribution: eks          │   │
│              │                          │  • logging: system+workloads  │   │
│   ┌──────────▼──────────────┐   OIDC    │  • managed prometheus on      │   │
│   │  EKS Cluster            │◄─────────►│  • admin users authorized     │   │
│   │  Kubernetes 1.34        │           └──────────────┬────────────────┘   │
│   │  2–5 worker nodes       │                          │                    │
│   │                         │           ┌──────────────▼────────────────┐   │
│   │  ┌─────────────────┐    │           │  GKE Fleet                    │   │
│   │  │ Anthos Connect  │◄───┼──────────►│  • Cluster membership         │   │
│   │  │ Agent (on EKS)  │    │           │  • Unified policy + config    │   │
│   │  └─────────────────┘    │           └──────────────┬────────────────┘   │
│   └─────────────────────────┘                          │                    │
│                                          ┌─────────────▼─────────────────┐  │
│                                          │  Unified Observability         │  │
│                                          │  • Cloud Logging               │  │
│                                          │  • Cloud Monitoring            │  │
│                                          │  • Managed Prometheus          │  │
│                                          └───────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

Deployment sequence:
  1. Enable 10 GCP APIs on the target project
  2. Create AWS VPC, subnets, and routing
  3. Create AWS IAM roles for EKS
  4. Create EKS cluster and worker node group
  5. Install Anthos Connect Agent on EKS (via bootstrap manifest)
  6. Register cluster in GCP as a GKE Attached Cluster
```

---

## Google Cloud APIs

Deploying this module enables ten Google Cloud APIs on the target project. Understanding what each API does gives you a map of the Google Cloud capabilities that underpin multi-cloud Kubernetes management.

### GKE Multi-Cloud API (`gkemulticloud.googleapis.com`)

This is the foundational API for the entire module. The GKE Multi-Cloud API is Google Cloud's service for registering and managing Kubernetes clusters that run outside of Google Cloud — on AWS, Azure, or on-premises — as if they were native GKE clusters. It provides the registration endpoint that accepts the EKS cluster, stores its configuration (OIDC issuer, fleet project, logging and monitoring preferences), and tracks its health and version status.

Without this API, there is no concept of an "attached cluster" in Google Cloud. Everything else in this module depends on it.

### GKE Connect API (`gkeconnect.googleapis.com`)

The GKE Connect API manages the lifecycle of the **Connect Agent** — a lightweight proxy process that runs inside the EKS cluster and maintains a persistent, outbound-only HTTPS connection back to Google Cloud. This is the communication channel through which Google Cloud sends management instructions to the EKS cluster and receives status updates from it.

Because the connection is outbound-only from EKS, no inbound firewall rules are needed on AWS. The cluster does not need a public API server endpoint — it only needs to be able to reach `gkeconnect.googleapis.com` on port 443.

### Connect Gateway API (`connectgateway.googleapis.com`)

The Connect Gateway API is what makes `kubectl` access to the EKS cluster possible using a Google identity, with no AWS credentials required. When you run `kubectl` against a Connect Gateway endpoint, your request travels:

```
Your terminal → Connect Gateway API → Connect Agent (on EKS) → EKS API server
```

Google Cloud authenticates your identity, checks that you are in the cluster's `admin_users` list, and proxies the request through the Connect Agent channel already established by GKE Connect. This eliminates the need for VPNs, bastion hosts, or AWS IAM credentials just to run `kubectl get pods`.

### Cloud Resource Manager API (`cloudresourcemanager.googleapis.com`)

This is a foundational GCP API used by nearly every service. In the context of this module, it is required to look up the numeric project number from the project ID, and to perform IAM policy checks during cluster registration and fleet enrollment. The GKE Multi-Cloud API uses it to validate that the service account running Terraform has the necessary permissions on the target project.

### Anthos API (`anthos.googleapis.com`)

The Anthos API is the umbrella platform API that enables the Anthos product suite on a Google Cloud project. Enabling it activates the licensing and entitlement layer that allows the project to use features such as:

- Anthos Service Mesh (ASM) — Istio-based service mesh management
- Anthos Config Management — GitOps-based configuration sync across clusters
- Anthos Policy Controller — Open Policy Agent (OPA) Gatekeeper for governance

Even if you do not use these features immediately, enabling the Anthos API is a prerequisite for the GKE Multi-Cloud API to register external clusters into a fleet.

### Cloud Monitoring API (`monitoring.googleapis.com`)

Cloud Monitoring is Google Cloud's managed observability service. Enabling it on the project allows the EKS cluster's metrics — collected by Google Cloud Managed Service for Prometheus — to be stored, queried, and alerted on in the same place as any other GCP resource metrics.

Platform engineers who have previously operated a Prometheus stack (Prometheus server, Thanos or Cortex for long-term storage, Grafana for dashboards, Alertmanager for notifications) will find that Cloud Monitoring replaces all of those components with a fully managed service. You write PromQL; Google Cloud handles storage, scalability, and availability.

### Cloud Logging API (`logging.googleapis.com`)

Cloud Logging is Google Cloud's managed log aggregation service. Enabling it allows the EKS cluster's system component logs and workload container logs to be forwarded to Cloud Logging via the Connect Agent. Logs are stored in Cloud Logging's Log Buckets and are searchable with the same Log Explorer queries you use for GCP-native resources.

The EKS cluster ships two categories of logs to Cloud Logging:
- **System component logs** — the Kubernetes control plane (API server, scheduler, controller manager) and node-level components (kubelet, kube-proxy)
- **Workload logs** — stdout and stderr from every container running in the cluster

This means a platform team can use a single log query interface for applications running on EKS and on GKE, without deploying or operating a log aggregation stack on AWS.

### GKE Hub API (`gkehub.googleapis.com`)

GKE Hub is the backbone of the Fleet concept in Google Cloud. When the EKS cluster is registered, it is enrolled as a **Fleet Member** — an entry in GKE Hub that represents the cluster and its capabilities. GKE Hub is what makes the following cross-cluster features possible:

| Feature | What it enables |
|---------|----------------|
| **Policy Controller** | Apply and enforce OPA Gatekeeper constraints across all fleet members simultaneously |
| **Config Management** | Sync a single Git repository to all fleet clusters, keeping their configuration identical |
| **Multi-cluster Services** | Discover and route to services on other fleet clusters using `<svc>.<ns>.svc.clusterset.local` |
| **Cloud Service Mesh** | Manage a shared Istio control plane and mTLS policy across fleet clusters |
| **Fleet Dashboard** | View the compliance, health, and configuration status of all clusters in one console view |

An EKS cluster enrolled in a GKE Hub fleet can participate in all of these features alongside native GKE clusters in the same fleet.

### Operations Config Monitoring API (`opsconfigmonitoring.googleapis.com`)

This API enables the managed observability agents that Google Cloud deploys onto attached clusters. Specifically, it governs the configuration and lifecycle of the log forwarding agent and the metrics collection agent that are installed on the EKS cluster as part of the attached cluster registration. Without this API, the `SYSTEM_COMPONENTS` and `WORKLOADS` logging components and the Managed Prometheus scraping would not function even if configured.

### Kubernetes Metadata API (`kubernetesmetadata.googleapis.com`)

The Kubernetes Metadata API collects Kubernetes object metadata — namespaces, deployments, pods, services, nodes — from the registered cluster and makes it available to Cloud Monitoring. This powers the Kubernetes-aware monitoring dashboards in the Cloud Console, where you can browse metrics grouped by namespace, workload, or pod rather than just by raw metric name. It is what enables the **Kubernetes Engine** section of Cloud Monitoring to show EKS workloads alongside GKE workloads in the same workload-centric views.

---
