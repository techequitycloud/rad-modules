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

## AWS Infrastructure

This section describes what the module creates on AWS and the design decisions behind each component. Understanding these choices is useful both for operating the deployed environment and for appreciating how AWS networking integrates with GKE Attached Clusters.

### Virtual Private Cloud (VPC)

The module creates a dedicated AWS VPC with a configurable CIDR block (default `10.0.0.0/16`). Using a dedicated VPC — rather than a default or shared VPC — gives the EKS cluster network isolation and prevents IP address conflicts with other workloads in the AWS account.

Both DNS hostnames and DNS resolution are enabled on the VPC. These are required for EKS: worker nodes use DNS to resolve the EKS API server endpoint, and Kubernetes service discovery relies on DNS for pod-to-pod communication within the cluster.

#### Subnet Topology

Subnets are spread across **three AWS Availability Zones** (default: `us-west-2a`, `us-west-2b`, `us-west-2c`). Distributing subnets across AZs is a core EKS high-availability pattern: if one AZ experiences an outage, the scheduler can still place pods on worker nodes in the remaining two zones. AWS Load Balancers created by the cluster also require multi-AZ subnets to serve traffic from multiple zones simultaneously.

The module supports two subnet topologies, controlled by the `enable_public_subnets` option:

**Public Subnet Topology** (default: `enable_public_subnets = true`)

Three subnets (default CIDRs: `10.0.101.0/24`, `10.0.102.0/24`, `10.0.103.0/24`) are created with direct internet access via an **Internet Gateway**. Worker nodes receive public IP addresses automatically. This topology is simpler and lower cost, making it well suited for learning environments and demonstrations where security hardening is not the primary concern.

**Private Subnet Topology** (`enable_public_subnets = false`)

Three subnets (default CIDRs: `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24`) are created without public IP assignment. Outbound internet access — needed for nodes to pull container images and for the Anthos Connect Agent to reach Google Cloud — is routed through a **NAT Gateway** deployed in a public subnet with an Elastic IP. Worker nodes are never directly reachable from the internet.

| Consideration | Public Subnets | Private Subnets |
|--------------|---------------|----------------|
| Worker node internet exposure | Nodes have public IPs | Nodes have no public IPs |
| Cost | Lower (no NAT Gateway) | Higher (NAT Gateway hourly + data transfer) |
| Setup complexity | Simpler | Requires NAT Gateway and routing table |
| Recommended for | Labs, demos, learning | Production, regulated workloads |

All subnets — regardless of topology — are tagged with the EKS cluster name. This tagging convention is required by EKS so that the cluster can discover which subnets belong to it when automatically provisioning AWS Load Balancers for Kubernetes `Service` objects of type `LoadBalancer`.

---

### AWS Identity and Access Management (IAM)

EKS requires specific AWS IAM roles to operate. The module creates two roles with the minimum permissions necessary, following the principle of least privilege.

#### EKS Cluster Role

This role is assumed by the EKS service itself — not by any human user or application. It grants the EKS control plane permission to manage AWS resources on behalf of the cluster: creating and configuring EC2 security groups, elastic network interfaces, and load balancers as workloads are scheduled and services are created. Without this role, the EKS control plane cannot interact with the AWS networking layer that Kubernetes relies on.

#### EKS Node Group Role

This role is assumed by the EC2 instances that serve as worker nodes. It carries three AWS-managed policies:

| Policy | What it Enables |
|--------|----------------|
| **AmazonEKSWorkerNodePolicy** | Allows worker nodes to authenticate with the EKS control plane and register themselves as cluster members |
| **AmazonEKS_CNI_Policy** | Grants the AWS VPC CNI plugin permission to create, attach, and configure elastic network interfaces on EC2 instances — this is how each pod gets its own VPC IP address |
| **AmazonEC2ContainerRegistryReadOnly** | Allows nodes to pull container images from Amazon ECR repositories in the same account |

**Understanding the AWS VPC CNI plugin:** Unlike some other Kubernetes networking plugins, the AWS VPC CNI gives each pod a real VPC IP address (not a secondary overlay address). This means pods are directly routable within the VPC and from other VPCs that are peered with it — a meaningful architectural difference from GKE's VPC-native networking, which achieves the same result using secondary IP ranges on the node's network interface.

---

### Amazon EKS Cluster

Amazon Elastic Kubernetes Service (EKS) is AWS's managed Kubernetes control plane service. With EKS, AWS operates the Kubernetes API server, etcd, and controller manager — the components that make up the control plane — as a managed service with built-in high availability and automatic version patching. You only manage the worker nodes.

#### Kubernetes Version

The cluster runs Kubernetes version `1.34` by default, configurable via `k8s_version`. The GKE attached cluster platform version (`platform_version`, default `1.34.0-gke.1`) must correspond to the same Kubernetes minor version — Google Cloud validates this alignment during registration. When you update the Kubernetes version on EKS, the platform version should be updated in the same deployment to maintain compatibility.

#### Worker Node Group

The cluster's compute capacity comes from a **managed node group** — a set of EC2 instances that EKS provisions, registers with the cluster, and keeps in sync with the control plane version. Using a managed node group (rather than self-managed nodes) means AWS handles node bootstrapping, AMI updates during Kubernetes version upgrades, and graceful node draining during replacements.

The node group is configured with auto-scaling bounds:

| Parameter | Default | Configuration Option |
|-----------|---------|---------------------|
| Starting node count | 2 | `node_group_desired_size` |
| Minimum node count | 2 | `node_group_min_size` |
| Maximum node count | 5 | `node_group_max_size` |

The maximum of 5 nodes defines the ceiling for automatic scale-out, but scaling beyond the desired count requires a cluster autoscaler to be deployed onto the cluster separately — this module does not install one.

**Comparing EKS managed nodes to GKE Autopilot:** This is a useful learning contrast. GKE Autopilot removes node management entirely — you never think about node counts, instance types, or node group configuration. EKS managed node groups are closer to GKE Standard mode, where you choose the node pool size and instance type. The EKS experience in this module helps platform engineers appreciate what GKE Autopilot abstracts away.

---

## GKE Attached Clusters

GKE Attached Clusters is the Google Cloud feature that makes this module's multi-cloud capability possible. It allows any CNCF-conformant Kubernetes cluster — running on AWS, Azure, bare metal, or any other environment — to be registered with Google Cloud and managed as if it were a native GKE cluster. This section explains each dimension of the attached cluster registration that the module configures.

### What "Attached" Means

When a cluster is attached, Google Cloud does not take over scheduling, does not run the Kubernetes control plane, and does not move any workloads. The EKS control plane continues to run entirely on AWS. What changes is that Google Cloud gains a management channel into the cluster through the Connect Agent, and the cluster gains access to Google Cloud's managed services for logging, monitoring, policy enforcement, and service mesh.

The relationship is additive: you keep everything AWS provides (EKS managed control plane, EC2 worker nodes, AWS Load Balancers, ECR) and gain everything Google Cloud's management plane provides on top.

### Distribution Type: EKS

The cluster is registered with distribution type `eks`, which tells the GKE Multi-Cloud API the origin and expectations of the cluster. Google Cloud uses the distribution type to:

- Apply the correct compatibility matrix for platform version support
- Select the appropriate Connect Agent configuration for the cluster's networking model
- Display the correct branding and metadata in the Cloud Console

Google Cloud currently supports `eks` (Amazon EKS), `aks` (Azure AKS), and `generic` (any other conformant cluster) as distribution types.

### OIDC-Based Identity Federation

OIDC (OpenID Connect) identity federation is the mechanism that lets Google Cloud trust the EKS cluster's identity — and the identity of workloads running on it — without any static credentials crossing cloud boundaries.

Every EKS cluster automatically runs an **OIDC identity provider** that issues signed JSON Web Tokens (JWTs) to Kubernetes service accounts. These tokens are cryptographically signed with a private key, and the OIDC discovery document (published at the issuer URL) contains the corresponding public key that any party can use to verify the signature.

When this module registers the cluster, it provides the EKS OIDC issuer URL to Google Cloud. From that point:

1. A workload on EKS requests a service account token from the Kubernetes API server
2. The token is a signed JWT identifying the pod's namespace and service account name
3. The workload presents this token to a Google Cloud API
4. Google Cloud fetches the public key from the EKS OIDC discovery endpoint and verifies the token's signature
5. If valid, Google Cloud accepts the identity and grants access according to Workload Identity Federation policies

This is the same mechanism used by GKE Workload Identity — the difference is that on GKE the OIDC provider is managed by Google, while on EKS it is managed by AWS. From Google Cloud's perspective, the trust model is identical.

**Why this matters for platform engineers:** Cross-cloud workload identity without static keys is a significant security improvement over the alternative of distributing GCP service account JSON keys into Kubernetes secrets on EKS. OIDC federation means credentials cannot be accidentally committed to source control, leaked from Kubernetes secrets, or persist beyond their short TTL.

### Fleet Registration

Every cluster registered through this module is automatically enrolled as a member of a **GKE Fleet** — a logical grouping of Kubernetes clusters that share a management boundary in Google Cloud.

The fleet is scoped to the Google Cloud project. All clusters registered to the same project belong to the same fleet. This means if you later create a native GKE cluster in the same project, it joins the same fleet as the attached EKS cluster and all fleet-level features apply to both simultaneously.

Fleet membership is the prerequisite for the following advanced capabilities:

**Policy Controller (Anthos Policy Controller)**
Deploys Open Policy Agent (OPA) Gatekeeper as a fleet-wide policy enforcement engine. You define constraints once — for example, requiring all pods to have resource limits, or prohibiting the use of the `default` namespace — and Policy Controller enforces them on every fleet member cluster, including EKS. Violations are reported in the Fleet dashboard in the Cloud Console.

**Config Management (Anthos Config Management)**
Enables GitOps-based configuration synchronisation across all fleet clusters. A single Git repository serves as the source of truth for Kubernetes manifests. Config Management continuously syncs the desired state from Git to every fleet member, ensuring configuration drift is automatically corrected. A change committed to the Git repository propagates to both the EKS cluster and any GKE clusters in the fleet without manual intervention.

**Multi-cluster Services**
Allows Kubernetes services to be exported from one fleet cluster and consumed by workloads on another using the DNS name `<service>.<namespace>.svc.clusterset.local`. This enables cross-cloud service discovery: a workload on a GKE cluster can call a service running on the attached EKS cluster by name, with traffic routed automatically through the Connect Agent channel.

**Cloud Service Mesh**
Enables the Anthos Service Mesh management plane to govern Istio installations across all fleet clusters. With fleet-level mesh management, mTLS policies, traffic management rules, and observability configuration can be applied uniformly across both GKE and EKS workloads from the Cloud Console.

### System and Workload Logging

The module configures the attached cluster to forward two categories of logs to Cloud Logging:

**System Component Logs**
Logs from the Kubernetes control plane and node-level components: the API server request logs, scheduler decisions, controller manager events, kubelet activity, and kube-proxy. On a self-managed cluster, these logs are typically scattered across node filesystems or require a dedicated log aggregation stack. On an attached cluster, they flow automatically to Cloud Logging where they can be searched, filtered, and alerted on.

System logs are particularly valuable when troubleshooting cluster-level issues — for example, when a pod fails to schedule, the scheduler logs explain exactly why (insufficient CPU, no matching node selector, pod disruption budget preventing eviction). Having these in Cloud Logging alongside application logs makes root-cause analysis significantly faster.

**Workload Logs**
The stdout and stderr output of every container running in the cluster, from every namespace. These arrive in Cloud Logging structured with Kubernetes metadata — cluster name, namespace, pod name, container name — so they can be filtered by any of these dimensions. A query like "show me all ERROR-level logs from the `payments` namespace on this EKS cluster in the last hour" works exactly the same as it does for a native GKE cluster.

The log forwarding agent is deployed onto the EKS cluster automatically as part of the attached cluster registration. There is no log agent to configure or maintain.

### Google Cloud Managed Service for Prometheus

The module enables **Managed Prometheus** on the attached cluster. Google Cloud Managed Service for Prometheus (GMP) is a fully managed, Prometheus-compatible metrics backend that replaces the need to operate a self-managed Prometheus stack.

When enabled on an attached cluster, GMP deploys a managed collection agent that scrapes metrics from pods exposing Prometheus endpoints. The agent respects standard Prometheus scrape configuration via two Kubernetes custom resources:

- **PodMonitoring** — scrapes metrics from pods matching a label selector within a namespace
- **ClusterPodMonitoring** — scrapes metrics from pods across all namespaces

Scraped metrics are stored in Cloud Monitoring's globally distributed backend with automatic scaling and 24-month retention. Engineers query them using standard PromQL through the Cloud Monitoring API, the built-in Prometheus Query UI in the Cloud Console, or any Grafana instance pointed at Cloud Monitoring as a data source.

**What this replaces in a self-managed setup:**

| Self-managed component | GMP equivalent |
|----------------------|---------------|
| Prometheus server | Managed collection agent (auto-deployed) |
| Thanos / Cortex for long-term storage | Cloud Monitoring backend (automatic) |
| Prometheus Operator | PodMonitoring / ClusterPodMonitoring CRDs |
| Alertmanager | Cloud Monitoring alert policies |
| Grafana (with Prometheus data source) | Cloud Monitoring dashboards or Grafana with Cloud Monitoring data source |

The GKE dashboards built into Cloud Monitoring — covering node CPU and memory, pod resource utilisation, network throughput, and persistent volume usage — work for EKS clusters with Managed Prometheus enabled, exactly as they do for native GKE clusters.

### Admin User Authorisation

The module grants Kubernetes `cluster-admin` RBAC access to a configurable list of Google identities (`trusted_users`). These users can run `kubectl` against the EKS cluster through the Connect Gateway using their Google credentials — with full administrative access equivalent to running `kubectl` with a cluster admin kubeconfig directly against AWS.

The Terraform executor's own Google identity is always included in the admin list automatically, so the person or service account that deploys the module always has access. Additional users are added via the `trusted_users` configuration option.

This authorisation model bridges two identity systems: AWS IAM (which EKS natively uses for RBAC via `aws-auth` ConfigMap) and Google Cloud IAM (which the Connect Gateway uses to authenticate `kubectl` requests). Users in `trusted_users` authenticate with Google but receive Kubernetes RBAC permissions — they never need an AWS IAM identity to access the cluster after registration.

---
