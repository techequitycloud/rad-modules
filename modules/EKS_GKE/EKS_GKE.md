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
