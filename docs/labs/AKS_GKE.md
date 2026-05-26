# Azure Kubernetes Service on GKE Fleet — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/AKS_GKE)**

This lab guide walks you through deploying an **Azure Kubernetes Service (AKS)** cluster and
registering it as a GKE Attached Cluster in **Google Cloud Fleet** using the **AKS_GKE** module.
You will then explore unified multi-cloud operations: accessing the AKS cluster via Google Cloud's
Connect Gateway, centralised logging and monitoring through Google Cloud Observability, and fleet-
wide access control — all without leaving Google Cloud.

**Estimated time:** 45–60 minutes (includes ~15 minutes of background provisioning)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Verify the Fleet Membership](#exercise-1--verify-the-fleet-membership)
6. [Exercise 2 — Access via Connect Gateway](#exercise-2--access-via-connect-gateway)
7. [Exercise 3 — Deploy a Sample Workload](#exercise-3--deploy-a-sample-workload)
8. [Exercise 4 — Centralised Logging with Cloud Logging](#exercise-4--centralised-logging-with-cloud-logging)
9. [Exercise 5 — Managed Prometheus and Cloud Monitoring](#exercise-5--managed-prometheus-and-cloud-monitoring)
10. [Exercise 6 — Fleet Access Control](#exercise-6--fleet-access-control)
11. [Exercise 7 — OIDC Federation and Connect Gateway API](#exercise-7--oidc-federation-and-connect-gateway-api)
12. [Exercise 8 — Platform Version Management](#exercise-8--platform-version-management)
13. [Cleanup](#13-cleanup)
14. [Reference](#14-reference)

---

## 1. Overview

### What Is GKE Fleet?

Google Cloud **Fleet** (formerly Anthos) provides a unified control plane for Kubernetes clusters
across clouds and on-premises environments. By registering an Azure AKS cluster as a **GKE
Attached Cluster**, you gain:

| Capability | What It Enables |
|---|---|
| **Connect Gateway** | `kubectl` access to AKS clusters via Google Cloud IAM — no VPN or bastion required |
| **Cloud Logging** | Unified Kubernetes system and workload logs from AKS in Cloud Logging |
| **Managed Prometheus** | AKS cluster metrics collected and queryable in Cloud Monitoring |
| **Fleet IAM** | Single IAM model for access control across all fleet clusters |
| **Multi-cloud visibility** | Single pane of glass for cluster health, nodes, and workloads |

### How GKE Attached Clusters Work

GKE Attached Clusters use **OIDC federation** to establish trust between Azure AD (the AKS OIDC
issuer) and Google Cloud. A lightweight **GKE Connect Agent** runs inside the AKS cluster and
maintains an outbound connection to Google Cloud — no inbound firewall rules are required.

```
Azure Cloud                          Google Cloud
┌─────────────────────┐              ┌──────────────────────────────┐
│  AKS Cluster        │              │  GKE Fleet Hub               │
│  ┌───────────────┐  │              │  ┌──────────────────────────┐ │
│  │ GKE Connect   │◄─┼──outbound───►│  │ Fleet Membership         │ │
│  │ Agent         │  │  HTTPS       │  │ (OIDC trust established) │ │
│  └───────────────┘  │              │  └──────────────────────────┘ │
│  ┌───────────────┐  │              │                               │
│  │ Cloud Logging │  │              │  Connect Gateway API          │
│  │ DaemonSet     │  │              │  Cloud Logging                │
│  └───────────────┘  │              │  Cloud Monitoring             │
└─────────────────────┘              └──────────────────────────────┘
```

### What the Module Automates

The `AKS_GKE` Terraform module handles all infrastructure provisioning automatically:

- Enabling required GCP APIs
- Creating the Azure Resource Group
- Deploying the AKS cluster with OIDC issuer enabled
- Assigning the Network Contributor role to the AKS cluster identity
- Fetching the GKE Attached Clusters install manifest from Google Cloud
- Installing the bootstrap Helm chart onto the AKS cluster
- Registering the AKS cluster as a `google_container_attached_cluster` in GKE Hub with Cloud Logging and Managed Prometheus enabled
- Granting cluster-admin access to the listed trusted users

### What You Do Manually

- Verifying the attached cluster appears in the Google Cloud console
- Configuring `kubectl` to access the cluster via Connect Gateway
- Exploring fleet membership and cluster status
- Exploring Cloud Logging for system and workload logs
- Exploring Cloud Monitoring and Managed Prometheus metrics
- Deploying a sample workload to the AKS cluster
- Exploring Connect Gateway-based access control
- Reviewing advanced features: IAM roles, audit logs, cluster upgrades

---

## 2. Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│  Azure (westus2)                                                   │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Resource Group: azure-aks-cluster-<id>                      │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │  AKS Cluster                                           │  │  │
│  │  │  • Kubernetes 1.34                                     │  │  │
│  │  │  • System-assigned managed identity                    │  │  │
│  │  │  • OIDC issuer enabled                                 │  │  │
│  │  │  • Node pool: Standard_D2s_v3 (3 nodes default)        │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
          │ OIDC Federation + GKE Connect Agent (outbound HTTPS)
          ▼
┌────────────────────────────────────────────────────────────────────┐
│  Google Cloud (us-central1)                                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  GKE Fleet Hub                                               │  │
│  │  • Fleet membership: azure-aks-cluster-<id>                  │  │
│  │  • Platform version: 1.34.0-gke.1                           │  │
│  │  • Logging: SYSTEM + WORKLOADS                               │  │
│  │  • Managed Prometheus enabled                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────────────┐ │
│  │ Cloud Logging  │  │Cloud Monitoring│  │  Connect Gateway API  │ │
│  │ (AKS logs)     │  │(AKS metrics)   │  │  (kubectl access)     │ │
│  └────────────────┘  └────────────────┘  └───────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  AKS_GKE
    client_id / client_secret /
    tenant_id / subscription_id  →  Azure Service Principal for AKS creation
    node_count     = 3           →  AKS default node pool size
    vm_size        = Standard_D2s_v3
    k8s_version    = "1.34"
    trusted_users  = ["user@example.com"]  →  cluster-admin via Connect Gateway
```

---

## 3. Prerequisites

### Required Tools

| Tool | Minimum Version | Install |
|---|---|---|
| `gcloud` CLI | 480.0.0 | [Install guide](https://cloud.google.com/sdk/docs/install) |
| `kubectl` | 1.29+ | `gcloud components install kubectl` |
| `gke-gcloud-auth-plugin` | Any | `gcloud components install gke-gcloud-auth-plugin` |
| `az` CLI | Any | [Azure CLI install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| `curl` / `jq` | Any | System package manager |
| OpenTofu / Terraform | >= 1.3 | [OpenTofu install](https://opentofu.org/docs/intro/install/) |

### Azure Requirements

You need an **Azure Service Principal** with at least `Contributor` rights on the target
subscription. Collect these four values before deploying:

- **Client ID** (`client_id`) — Azure AD Application (client) ID
- **Client Secret** (`client_secret`) — Azure AD client secret value
- **Tenant ID** (`tenant_id`) — Azure AD Directory (tenant) ID
- **Subscription ID** (`subscription_id`) — Azure Subscription ID

If you do not already have a service principal, create one with the Azure CLI:

```bash
az ad sp create-for-rbac \
  --name "aks-gke-lab-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --output json
```

This returns the `appId` (client_id), `password` (client_secret), and `tenant` (tenant_id)
values required by the module.

### GCP Permissions

```
roles/container.admin
roles/gkehub.admin
roles/iam.serviceAccountAdmin
roles/logging.admin
roles/monitoring.admin
```

> The identity running `tofu apply` must hold `roles/iam.serviceAccountTokenCreator` on the
> Terraform provisioning service account, which must hold `roles/owner` on the target GCP project.

### Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export GCP_REGION="us-central1"
export CLUSTER_NAME="azure-aks-cluster"   # adjust if deployment_id was set

gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${GCP_REGION}"
```

### REST API Shell Variables

If you plan to use the REST API equivalents throughout this lab, set these additional variables
once before running any API command:

```bash
export TOKEN=$(gcloud auth print-access-token)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
export MULTICLOUD_BASE="https://${GCP_REGION}-gkemulticloud.googleapis.com/v1"
export HUB_BASE="https://gkehub.googleapis.com/v1"
```

All mutating REST API operations return a long-running Operation. Poll for completion:

```bash
curl -s "${MULTICLOUD_BASE}/projects/${PROJECT_ID}/locations/${GCP_REGION}/operations/OPERATION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.done, .error'
```

`done: true` with no `error` means the operation succeeded.

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `AKS_GKE` module via the RAD UI. In the variable form, set the following key variables:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `gcp_location` | `us-central1` | GCP region for Fleet membership |
| `azure_region` | `westus2` | Azure region for AKS cluster |
| `client_id` | `<your-app-client-id>` | Azure Service Principal App ID |
| `client_secret` | `<your-app-secret>` | Azure Service Principal secret |
| `tenant_id` | `<your-tenant-id>` | Azure AD Tenant ID |
| `subscription_id` | `<your-subscription-id>` | Azure Subscription ID |
| `node_count` | `3` | Default AKS node count |
| `k8s_version` | `1.34` | Kubernetes version |
| `trusted_users` | `["your-email@example.com"]` | Users granted cluster-admin |

Click **Deploy** and wait for provisioning to complete (approximately 15–20 minutes).

> **What this provisions:** An Azure Resource Group, AKS cluster with OIDC issuer enabled,
> GKE Attached Cluster registration in Fleet Hub with OIDC trust, Cloud Logging for system
> and workload logs, and Managed Prometheus for metrics collection.

### 4.2 Deploy via Terraform CLI (Alternative)

If you prefer to deploy directly with the Terraform CLI instead of the RAD UI:

```bash
cd modules/AKS_GKE
tofu init
tofu validate
tofu plan -out=plan.tfplan
tofu apply plan.tfplan
```

A minimum `terraform.tfvars` example:

```hcl
project_id      = "your-project-id"
trusted_users   = ["your-email@example.com"]

client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_secret   = "your-client-secret"
tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Expected provisioning duration:**

| Resource | Typical time |
|---|---|
| API enablement | 1–2 minutes |
| Azure Resource Group creation | < 1 minute |
| AKS cluster provisioning | 5–10 minutes |
| Bootstrap Helm chart install | 1–2 minutes |
| GKE Hub cluster registration | 1–2 minutes |

> The `tofu apply` command will not return until all resources are fully provisioned, including
> the fleet registration. When complete, record the cluster name, resource group name, and OIDC
> issuer URL from the outputs — these are referenced throughout the rest of the lab.

```bash
# Record key identifiers after apply completes
tofu show | grep -E "cluster_id|resource_group|oidc_issuer"
```

| Value | Where to find it | Used in |
|---|---|---|
| Cluster name | `var.cluster_name_prefix` + deployment ID suffix | All `kubectl` and API commands |
| Resource Group name | Azure portal or `tofu state show azurerm_resource_group.aks` | Azure console verification |
| OIDC Issuer URL | `tofu state show azurerm_kubernetes_cluster.aks` | Exercise 7 verification |
| GCP Project ID | Your `project_id` variable | All GCP console and API steps |

### 4.3 Configure Azure CLI (Optional)

Optionally verify your Azure credentials are working:

```bash
az login --service-principal \
  --username "${AZURE_CLIENT_ID}" \
  --password "${AZURE_CLIENT_SECRET}" \
  --tenant "${AZURE_TENANT_ID}"

az aks list --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --output table
```

---

## Exercise 1 — Verify the Fleet Membership

### Objective

Confirm that the AKS cluster is correctly registered in Google Cloud Fleet and all managed
components are healthy.

### Step 1.1 — List Fleet Memberships

**gcloud:**
```bash
gcloud container fleet memberships list --project="${PROJECT_ID}"
```

Expected output:
```
NAME                              EXTERNAL_ID                            LOCATION
azure-aks-cluster-<id>            xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   global
```

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.resources[] | {name, state: .state.code}'
```

### Step 1.2 — Inspect Membership Details

**gcloud:**
```bash
gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}"
```

Look for:
- `state.code: READY` — membership is active
- `endpoint.kubernetesMetadata.kubernetesApiServerVersion` — Kubernetes version
- `authority.issuer` — OIDC issuer URL from AKS

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, state: .state.code, k8sVersion: .endpoint.kubernetesMetadata.kubernetesApiServerVersion}'
```

### Step 1.3 — View in Google Cloud Console

Navigate to:
**Kubernetes Engine** → **Clusters** → look for the Azure cluster (shown with an Azure icon)

Or directly:
```bash
echo "https://console.cloud.google.com/kubernetes/list/overview?project=${PROJECT_ID}"
```

1. Confirm the cluster appears with **Type: Attached** and **Location** set to your `gcp_location` region.
2. Click the cluster name to open its details page and verify **Status** is **Running**.

**gcloud equivalent — describe the attached cluster:**
```bash
gcloud container attached clusters describe ${CLUSTER_NAME} \
  --location=${GCP_REGION} \
  --project=${PROJECT_ID} \
  --format='yaml(name,state,kubernetesVersion,platformVersion)'
```

**REST API equivalent — describe the attached cluster:**
```bash
curl -s \
  "${MULTICLOUD_BASE}/projects/${PROJECT_ID}/locations/${GCP_REGION}/attachedClusters/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '{name: .name, state: .state, kubernetesVersion: .kubernetesVersion, platformVersion: .platformVersion}'
```

### Step 1.4 — Verify Platform Version and Managed Features

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**.
2. Click the cluster name to open its details page, then click the **Details** tab.
3. Review the **Platform version** field — it should match the `platform_version` variable.
4. Review the **Logging** and **Monitoring** sections — both should show as **Enabled**.

**Expected result:** The platform version, logging, and monitoring settings match the Terraform
configuration. The bootstrap Helm chart installed by Terraform placed the GKE Hub agent onto
the AKS cluster, enabling these managed features.

### Step 1.5 — Verify GKE Connect Agent

```bash
# Configure kubectl (done in Exercise 2 Step 2.1 below)
# Then verify the Connect agent namespace:
kubectl get pods -n gke-connect
```

Expected:
```
NAME                             READY   STATUS    RESTARTS
gke-connect-agent-xxxxxxx        1/1     Running   0
```

### Step 1.6 — View Fleet Feature Status

GKE Hub features provide centralised capabilities — such as logging, monitoring, and service
mesh — across all fleet members from a single control plane.

1. In the Google Cloud console, navigate to **Kubernetes Engine > Features**.
2. Review the list of fleet features. Note which features are enabled for your fleet, including:
   - **Cloud Logging and Cloud Monitoring**
   - **Config Management**
   - **Service Mesh**

**Expected result:** The Logging and Monitoring feature shows as enabled, consistent with the
`logging_config` and `monitoring_config` blocks in the Terraform resource.

**gcloud equivalent — list fleet features:**
```bash
gcloud container fleet features list \
  --project=${PROJECT_ID} \
  --format='table(name,resourceState.state)'
```

**REST API equivalent — list fleet features:**
```bash
curl -s \
  "${HUB_BASE}/projects/${PROJECT_ID}/locations/global/features" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.resources[] | {name: .name, state: .state}'
```

### Step 1.7 — Inspect the Managed Components Namespace

The bootstrap install manifest installed system components into the cluster.

```bash
kubectl get namespaces | grep -E "gke|anthos|cloud"
```

```bash
kubectl get pods -n gke-managed-system 2>/dev/null || \
  kubectl get pods -n gke-system 2>/dev/null || \
  kubectl get pods -n kube-system | grep -E "gke|anthos"
```

**Expected result:** GKE-managed system pods are visible, confirming the Helm bootstrap chart
was applied successfully during Terraform provisioning.

---

## Exercise 2 — Access via Connect Gateway

### Objective

Use Google Cloud's **Connect Gateway** to access the AKS cluster with `kubectl` using your
Google Cloud IAM identity — without needing Azure credentials, a VPN, or direct network access.

### Step 2.1 — Configure kubectl via Connect Gateway

```bash
gcloud container fleet memberships get-credentials "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}"

# Verify the context was added
kubectl config get-contexts
kubectl config current-context
```

**Expected result:** The context name contains `connectgateway` and your project and cluster
identifiers, for example:
`connectgateway_your-project-id_global_azure-aks-cluster`.

### Step 2.2 — Verify Cluster Connectivity

```bash
kubectl cluster-info

# Expected:
# Kubernetes control plane is running at https://connectgateway.googleapis.com/...

kubectl get nodes -o wide
```

Expected node output:
```
NAME                             STATUS   ROLES    AGE   VERSION
aks-nodepool1-xxxxxxxx-vmss0     Ready    agent    10m   v1.34.x
aks-nodepool1-xxxxxxxx-vmss1     Ready    agent    10m   v1.34.x
aks-nodepool1-xxxxxxxx-vmss2     Ready    agent    10m   v1.34.x
```

```bash
kubectl get pods --all-namespaces
```

**Expected result:** System pods are visible, including GKE Hub components in the `gke-connect`
namespace and any other system namespaces.

### Step 2.3 — Inspect Cluster Namespaces

```bash
kubectl get namespaces

# Standard AKS namespaces:
# default
# kube-system
# kube-public
# kube-node-lease
# gke-connect        ← GKE Connect Agent
```

### Step 2.4 — Verify Admin Access

```bash
# Verify the trusted_users entry grants cluster-admin
kubectl auth can-i list pods --all-namespaces
# Expected: yes

kubectl auth can-i create clusterrolebindings
# Expected: yes
```

### Step 2.5 — Inspect the GKE Connect Agent Pod

```bash
kubectl describe pod -n gke-connect -l app=gke-connect-agent

# Key information:
# - Image version (platform version)
# - Environment variables (project number, membership name)
# - Resource limits
```

> **Note:** Connect Gateway requests are authenticated and authorised via Google Cloud IAM and
> the RBAC bindings configured in the attached cluster authorisation block. The `trusted_users`
> variable grants cluster-admin to the listed identities.

---

## Exercise 3 — Deploy a Sample Workload

### Objective

Deploy an nginx application to the AKS cluster via Connect Gateway and verify it appears in
Cloud Logging and Cloud Monitoring.

### Step 3.1 — Create a Namespace

```bash
kubectl create namespace sample-workload
kubectl label namespace sample-workload app=sample
```

### Step 3.2 — Deploy nginx

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: sample-workload
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: sample-workload
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

```bash
kubectl apply -f nginx-deployment.yaml

# Wait for pods to be ready
kubectl get pods -n sample-workload -w
```

### Step 3.3 — Get the Service External IP

```bash
kubectl get service nginx -n sample-workload -w

# Wait for EXTERNAL-IP to be assigned (Azure load balancer provisioning takes ~2 minutes)
NGINX_IP=$(kubectl get service nginx -n sample-workload \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Nginx IP: ${NGINX_IP}"

# Test the endpoint
curl -s "http://${NGINX_IP}" | grep "<title>"
# Expected: <title>Welcome to nginx!</title>
```

### Step 3.4 — Verify Pod Distribution

```bash
# Check which nodes the pods landed on
kubectl get pods -n sample-workload -o wide

# Check pod resource usage
kubectl top pods -n sample-workload
kubectl top nodes
```

### Step 3.5 — Generate Traffic for Logs

```bash
for i in $(seq 1 50); do
  curl -s -o /dev/null "http://${NGINX_IP}"
  sleep 0.5
done
```

### Step 3.6 — Verify Workload Logs Appear in Cloud Logging

In **Cloud Logging > Logs Explorer**, run:

```
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"
resource.labels.namespace_name="sample-workload"
resource.labels.container_name="nginx"
```

**Expected result:** Nginx access log entries appear in Cloud Logging within 1–2 minutes of
the traffic being generated, confirming that workload logs from the `sample-workload` namespace
are forwarded to Cloud Logging.

---

## Exercise 4 — Centralised Logging with Cloud Logging

### Objective

Explore Kubernetes system and workload logs from the AKS cluster collected automatically by
Cloud Logging.

### Step 4.1 — View Logs in Logs Explorer

Navigate to:
```bash
echo "https://console.cloud.google.com/logs/query?project=${PROJECT_ID}"
```

### Step 4.2 — Query System Component Logs

In **Logs Explorer**, enter the following query and click **Run Query**:

```
resource.type="k8s_cluster"
resource.labels.cluster_name="azure-aks-cluster"
log_name=~"system"
```

Expand individual log entries and review the `resource.labels` fields, including `cluster_name`,
`location`, and `project_id`.

**Expected result:** Log entries from AKS system components (scheduler, controller-manager, API
server) appear in Cloud Logging, streaming from the AKS cluster through the GKE Hub agent —
no separate log forwarder required.

**gcloud:**
```bash
gcloud logging read \
  "resource.type=k8s_cluster AND resource.labels.cluster_name=${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --limit=20 \
  --format=json \
  | jq '.[] | {timestamp, message: .textPayload}'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_cluster resource.labels.cluster_name=${CLUSTER_NAME}\",
    \"pageSize\": 10
  }" | jq '.entries[] | {timestamp, message: .textPayload}'
```

### Step 4.3 — Query Workload Logs (nginx)

In **Logs Explorer**, run:

```
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"
```

**Expected result:** Container logs from all namespaces on the AKS cluster appear alongside
logs from any other GKE clusters in the same project, providing a unified multi-cloud logging view.

**gcloud:**
```bash
gcloud logging read \
  "resource.type=k8s_container \
   AND resource.labels.namespace_name=sample-workload \
   AND resource.labels.container_name=nginx" \
  --project="${PROJECT_ID}" \
  --limit=20 \
  --format=json \
  | jq '.[] | {timestamp, httpRequest: .httpRequest}'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_container resource.labels.namespace_name=sample-workload\",
    \"orderBy\": \"timestamp desc\",
    \"pageSize\": 10
  }" | jq '.entries[].jsonPayload'
```

### Step 4.4 — Verify Log Ingestion with a Test Pod

Deploy a temporary pod to confirm that workload log forwarding is active:

```bash
kubectl run log-test --image=busybox --restart=Never \
  -- sh -c 'echo "AKS-GKE lab log entry $(date)" && sleep 5'
```

Wait 60 seconds, then check the log locally:

```bash
kubectl logs log-test
```

Then query Cloud Logging to confirm the entry was forwarded:

**gcloud:**
```bash
gcloud logging read \
  "resource.type=k8s_container AND resource.labels.cluster_name=${CLUSTER_NAME} AND resource.labels.pod_name=log-test" \
  --project="${PROJECT_ID}" \
  --limit=5 \
  --format='table(timestamp,textPayload)'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_container resource.labels.cluster_name=${CLUSTER_NAME} resource.labels.pod_name=log-test\",
    \"orderBy\": \"timestamp desc\",
    \"pageSize\": 5
  }" | jq '.entries[] | {timestamp: .timestamp, message: .textPayload}'
```

**Expected result:** The `AKS-GKE lab log entry` message appears in Cloud Logging, confirming
that workload log forwarding is active for the cluster.

```bash
# Clean up the test pod
kubectl delete pod log-test
```

### Step 4.5 — Log-Based Metrics

Create a log-based metric to count nginx requests:

**gcloud:**
```bash
gcloud logging metrics create nginx-request-count \
  --description="Count of nginx requests from AKS cluster" \
  --log-filter="resource.type=k8s_container \
    AND resource.labels.namespace_name=sample-workload \
    AND resource.labels.container_name=nginx" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/projects/${PROJECT_ID}/metrics" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "nginx-request-count",
    "description": "Count of nginx requests from AKS cluster",
    "filter": "resource.type=k8s_container AND resource.labels.namespace_name=sample-workload"
  }'
```

---

## Exercise 5 — Managed Prometheus and Cloud Monitoring

### Objective

Explore Kubernetes metrics from the AKS cluster collected by Managed Prometheus and visualised
in Cloud Monitoring.

### Step 5.1 — Open the Kubernetes Engine Dashboard

```bash
echo "https://console.cloud.google.com/monitoring/dashboards?project=${PROJECT_ID}"
```

Navigate to **Dashboards** → **Kubernetes Engine** → select the AKS cluster.

**Expected result:** The AKS cluster appears alongside native GKE clusters in the Kubernetes
Engine dashboard, providing a unified multi-cloud monitoring view from a single pane of glass.

### Step 5.2 — View Cluster Metrics in Metrics Explorer

1. In the Google Cloud console, navigate to **Monitoring > Metrics Explorer**.
2. Click **Select a metric**.
3. In the search box, type `kubernetes` and select the metric resource type **Kubernetes Container**.
4. Select the metric **CPU request utilization**.
5. In the **Filter** section, add a filter for `resource.labels.cluster_name = azure-aks-cluster`.
6. Click **Apply**.

**Expected result:** A time-series chart appears showing CPU request utilization for containers
running on the AKS cluster. Metrics stream into Cloud Monitoring via the Managed Prometheus
collector installed as part of the platform version bootstrap.

### Step 5.3 — Query Metrics via Cloud Monitoring API

**gcloud:**
```bash
gcloud monitoring metrics list \
  --filter="metric.type:kubernetes" \
  --project="${PROJECT_ID}" \
  | grep -E "container/cpu|container/memory|node/cpu"
```

> Note: Reading time-series data points is not supported by the `gcloud` CLI; use the REST API
> or Metrics Explorer in the console for that purpose.

**REST API (MQL query — CPU utilisation per node):**
```bash
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "fetch k8s_node::kubernetes.io/node/cpu/allocatable_utilization | within 1h | group_by [resource.cluster_name], mean(val())"
  }' | jq '.timeSeriesData[].pointData[-1].values'
```

**REST API — query time-series via the Monitoring API:**
```bash
START=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
        date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
curl -s \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries?filter=metric.type%3D%22kubernetes.io%2Fnode%2Fcpu%2Fallocatable_utilization%22%20AND%20resource.labels.cluster_name%3D%22${CLUSTER_NAME}%22&interval.startTime=${START}&interval.endTime=${END}" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.timeSeries[] | {node: .resource.labels.node_name, points: (.points | length)}'
```

### Step 5.4 — Node and Pod Resource Usage

```bash
# Current node resource consumption
kubectl top nodes

# Current pod resource consumption
kubectl top pods -n sample-workload

# All namespaces
kubectl top pods --all-namespaces | sort -k3 -rn | head -20
```

**Expected result:** CPU and memory utilization is shown per node and per pod. This data flows
from the Managed Prometheus collector on the cluster to Cloud Monitoring.

### Step 5.5 — Create an Alerting Policy

**gcloud (alert when CPU > 80%):**
```bash
gcloud alpha monitoring policies create \
  --notification-channels="" \
  --display-name="AKS High CPU" \
  --condition-filter="metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\" resource.type=\"k8s_node\" resource.label.\"cluster_name\"=\"${CLUSTER_NAME}\"" \
  --condition-threshold-value=0.8 \
  --condition-threshold-duration=300s \
  --condition-threshold-comparison=COMPARISON_GT \
  --project="${PROJECT_ID}"
```

---

## Exercise 6 — Fleet Access Control

### Objective

Understand the two-layer authorisation model for Connect Gateway access and grant a colleague
access to the AKS cluster using Google Cloud IAM and Kubernetes RBAC.

### Background: Two-Layer Authorisation

```
User
  │
  ▼
Google Cloud IAM
  (roles/gkehub.gatewayReader or roles/gkehub.gatewayEditor)
  │  Allows: traverse Connect Gateway
  ▼
Kubernetes RBAC
  (ClusterRoleBinding with Google identity)
  │  Allows: specific Kubernetes API actions
  ▼
AKS Cluster API Server
```

### Step 6.1 — View Current RBAC Bindings

```bash
kubectl get clusterrolebindings \
  | grep -v system

kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects: .subjects}'
```

**Expected result:** A cluster-admin binding exists for the identities listed in `trusted_users`.
These users can perform all Kubernetes operations through Connect Gateway.

### Step 6.2 — Grant a Colleague Read-Only Access

To allow another Google identity to access the cluster via `kubectl`, two things are needed:
a GCP IAM binding and a Kubernetes RBAC binding.

**Step A — Grant GCP IAM access via the console:**

1. In the Google Cloud console, navigate to **IAM & Admin > IAM**.
2. Click **Grant Access**.
3. Enter the colleague's email address.
4. Add the role **GKE Hub Gateway Editor** (`roles/gkehub.gatewayEditor`).
5. Click **Save**.

**gcloud equivalent:**
```bash
# Step 1: Grant IAM permission to use Connect Gateway
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="user:colleague@example.com" \
  --role="roles/gkehub.gatewayReader"
```

**REST API (IAM binding):**
```bash
curl -s -X POST \
  "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:setIamPolicy" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": {
      "bindings": [{
        "role": "roles/gkehub.gatewayReader",
        "members": ["user:colleague@example.com"]
      }]
    }
  }'
```

**Step B — Grant Kubernetes RBAC access:**

```bash
# Step 2: Create a Kubernetes RBAC binding for cluster-level read
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: colleague-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: User
  name: colleague@example.com
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Expected result:** The colleague can authenticate via `gcloud` and run read-only `kubectl`
commands against the AKS cluster through Connect Gateway, without needing direct network access
to the Azure API server.

### Step 6.3 — Verify Your Own Admin Permissions

```bash
kubectl auth can-i list pods --all-namespaces
kubectl auth can-i create deployments -n sample-workload
kubectl auth can-i delete namespaces
```

**gcloud equivalent — check fleet membership IAM policy:**
```bash
gcloud container fleet memberships get-iam-policy ${CLUSTER_NAME} \
  --project=${PROJECT_ID} \
  --format='yaml(bindings)'
```

**REST API equivalent — check fleet membership IAM policy:**
```bash
curl -s -X POST \
  "${HUB_BASE}/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER_NAME}:getIamPolicy" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.bindings[] | {role: .role, members: .members}'
```

### Step 6.4 — Review Audit Logs for Cluster Operations

Every API call to `gkemulticloud.googleapis.com` and `gkehub.googleapis.com` generates an entry
in Cloud Audit Logs.

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query editor, enter:

```
protoPayload.serviceName=("gkemulticloud.googleapis.com" OR "gkehub.googleapis.com")
```

3. Click **Run Query**.

**gcloud:**
```bash
gcloud logging read \
  'protoPayload.serviceName=("gkemulticloud.googleapis.com" OR "gkehub.googleapis.com")' \
  --project=${PROJECT_ID} \
  --limit=10 \
  --format='table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail,protoPayload.status.code)'
```

4. Expand individual entries and review:
   - `protoPayload.methodName` — the API method called (e.g. `google.cloud.gkemulticloud.v1.AttachedClusters.CreateAttachedCluster`)
   - `protoPayload.authenticationInfo.principalEmail` — the caller identity
   - `resource.labels.cluster_name` — the cluster affected

**Expected result:** Audit entries are visible for the Terraform provisioning operations (cluster
registration, feature enablement), confirming that all control-plane operations are logged
automatically with no additional configuration.

You can also query specifically for Connect Gateway access:

```bash
gcloud logging read \
  "protoPayload.serviceName=connectgateway.googleapis.com" \
  --project="${PROJECT_ID}" \
  --limit=10 \
  --format=json \
  | jq '.[] | {
    timestamp,
    caller: .protoPayload.authenticationInfo.principalEmail,
    method: .protoPayload.methodName
  }'
```

---

## Exercise 7 — OIDC Federation and Connect Gateway API

### Objective

Understand how OIDC federation enables Connect Gateway to authenticate Google identities to
the AKS API server, and make direct Connect Gateway API calls.

### Step 7.1 — Inspect the OIDC Trust Configuration

**gcloud:**
```bash
gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --format="yaml(authority)"
```

Expected:
```yaml
authority:
  issuer: https://oidc.prod-aks.azure.com/<tenant-id>/<cluster-id>/
  workloadIdentityPool: <project-id>.hub.id.goog
  identityProvider: https://gkehub.googleapis.com/projects/...
```

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.authority'
```

You can also view the full OIDC configuration via the Attached Clusters API:

```bash
# gcloud
gcloud container attached clusters describe ${CLUSTER_NAME} \
  --location=${GCP_REGION} \
  --project=${PROJECT_ID} \
  --format='yaml(oidcConfig)'

# REST API
curl -s \
  "${MULTICLOUD_BASE}/projects/${PROJECT_ID}/locations/${GCP_REGION}/attachedClusters/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.oidcConfig'
```

**Expected result:** The `issuerUrl` field matches the AKS OIDC issuer URL
(format: `https://oidc.prod-aks.azure.com/<tenant-id>/<cluster-id>/`). Google Cloud uses this
URL to validate tokens issued by the AKS API server, enabling Connect Gateway to verify the
identity of `kubectl` callers.

### Step 7.2 — Direct Connect Gateway API Call

Connect Gateway exposes a Kubernetes-compatible API at a Google-hosted endpoint:

```bash
# Get the Connect Gateway endpoint
GATEWAY_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "Connect Gateway URL: ${GATEWAY_URL}"

# Make a direct API call with your Google auth token
ACCESS_TOKEN=$(gcloud auth print-access-token)

curl -s \
  "${GATEWAY_URL}/api/v1/namespaces" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq '.items[].metadata.name'
```

### Step 7.3 — Verify the GKE Connect Agent Version

```bash
kubectl get pod -n gke-connect -o yaml \
  | grep "image:" | grep -v "imagePullPolicy"
```

The image tag corresponds to the `platform_version` variable (e.g., `1.34.0-gke.1`).

---

## Exercise 8 — Platform Version Management

### Objective

Understand how GKE Attached Cluster platform versions work and how to upgrade the Connect
Agent when a new version is available.

### Step 8.1 — List Available Platform Versions

**gcloud:**
```bash
gcloud container attached get-server-config \
  --location="${GCP_REGION}" \
  --project="${PROJECT_ID}"
```

This returns supported Kubernetes version ranges and the latest Connect Agent platform version
for each.

**REST API:**
```bash
curl -s \
  "https://gkemulticloud.googleapis.com/v1/projects/${PROJECT_ID}/locations/${GCP_REGION}/attachedServerConfig" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.validVersions[] | {kubernetesVersion, platformVersion}'
```

**REST API — list attached cluster versions with EOL dates:**
```bash
curl -s \
  "${MULTICLOUD_BASE}/projects/${PROJECT_ID}/locations/${GCP_REGION}:getServerConfig" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.attachedClusterVersions[] | select(.version | startswith("1.")) | {version: .version, eolDate: .endOfLifeDate}'
```

**Expected result:** A list of supported platform versions appears, each with an optional
end-of-life date. Use this output to plan upgrades before a version reaches end of life.

### Step 8.2 — Check Current Platform Version

```bash
gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --format="value(endpoint.kubernetesMetadata.kubernetesApiServerVersion)"
```

### Step 8.3 — Upgrade the Platform Version (via RAD UI)

To upgrade the Connect Agent to a newer platform version:

1. Return to the RAD UI and navigate to your `AKS_GKE` deployment.
2. Update the `platform_version` variable to the new version (e.g., `1.34.1-gke.1`).
3. Click **Update**.

The Terraform run updates only the attached cluster resource — the AKS cluster itself is not
affected.

### Step 8.4 — Import an Existing Cluster (Reference)

If you already have an AKS cluster and want to register it without recreating it, GKE Attached
Clusters supports an import flow. The import manifest installs the bootstrap components onto
the existing cluster:

```bash
# Generate an import manifest for an existing cluster
gcloud container attached clusters generate-install-manifest \
  --location="${GCP_REGION}" \
  --platform-version="1.34.0-gke.1" \
  --cluster=existing-aks-cluster \
  --format=json \
  --project="${PROJECT_ID}" \
  | jq -r '.manifest' > install-manifest.yaml

# Apply the manifest to the existing cluster (using its own kubeconfig)
kubectl apply --kubeconfig=existing-cluster.kubeconfig -f install-manifest.yaml
```

After the manifest is applied, register the cluster:

```bash
gcloud container attached clusters register existing-aks-cluster \
  --location="${GCP_REGION}" \
  --platform-version="1.34.0-gke.1" \
  --distribution=aks \
  --oidc-issuer-url="https://oidc.prod-aks.azure.com/TENANT_ID/CLUSTER_ID/" \
  --project="${PROJECT_ID}" \
  --fleet-project="${PROJECT_ID}"
```

**Expected result:** The existing cluster appears in the GKE Clusters view with **Type: Attached**
without any disruption to workloads running on it.

---

## 13. Cleanup

First, remove the sample workload namespace if you deployed one:

```bash
kubectl delete namespace sample-workload
```

### Cleanup via RAD UI

Return to the RAD UI and click **Undeploy** on the `AKS_GKE` deployment. This removes:
- The GKE Fleet membership
- The Azure AKS cluster
- The Azure Resource Group and all contained resources

### Cleanup via Terraform CLI (if deployed manually)

```bash
cd modules/AKS_GKE
tofu destroy
```

**Expected destruction order:**

| Resource | Typical time |
|---|---|
| GKE Hub fleet registration | 1–2 minutes |
| Bootstrap Helm chart uninstall | 1–2 minutes |
| AKS cluster deletion | 5–10 minutes |
| Azure Resource Group deletion | 1–2 minutes |

> `tofu destroy` will prompt for confirmation before deleting resources. Type `yes` to proceed.
> All Azure and GCP resources created by the module are removed; your GCP project and Azure
> subscription themselves are not affected.

### Manual Cleanup (if needed)

**gcloud — remove Fleet membership:**
```bash
gcloud container fleet memberships delete "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --quiet
```

**REST API — delete Fleet membership:**
```bash
curl -s -X DELETE \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

**az — delete Azure resources:**
```bash
az group delete \
  --name "azure-aks-cluster-<deployment-id>" \
  --subscription "${AZURE_SUBSCRIPTION_ID}" \
  --yes --no-wait
```

**Clean up kubectl context:**
```bash
kubectl config delete-context \
  "connectgateway_${PROJECT_ID}_global_${CLUSTER_NAME}"
```

---

## 14. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `gcp_location` | string | `us-central1` | GCP region for Fleet membership |
| `azure_region` | string | `westus2` | Azure region for AKS cluster |
| `cluster_name_prefix` | string | `azure-aks-cluster` | Resource name prefix |
| `k8s_version` | string | `1.34` | Kubernetes version for AKS |
| `platform_version` | string | `1.34.0-gke.1` | GKE Connect Agent platform version |
| `node_count` | number | `3` | AKS default node pool size |
| `vm_size` | string | `Standard_D2s_v3` | Azure VM SKU for AKS nodes |
| `trusted_users` | list(string) | `[]` | Google identities granted cluster-admin |
| `client_id` | string | — | Azure Service Principal App ID (required) |
| `client_secret` | string | — | Azure Service Principal secret (required) |
| `tenant_id` | string | — | Azure AD Tenant ID (required) |
| `subscription_id` | string | — | Azure Subscription ID (required) |

### IAM Roles for Connect Gateway and Attached Cluster Operations

| Role | Purpose |
|---|---|
| `roles/gkehub.gatewayReader` | Read-only kubectl access via Connect Gateway |
| `roles/gkehub.gatewayEditor` | Read-write kubectl access via Connect Gateway |
| `roles/gkehub.gatewayAdmin` | Full kubectl access via Connect Gateway |
| `roles/gkehub.viewer` | View Fleet membership details |
| `roles/gkehub.editor` | Manage Fleet memberships |
| `roles/gkemulticloud.viewer` | Read-only view of attached cluster resources |
| `roles/gkemulticloud.editor` | Create and update attached clusters |
| `roles/gkemulticloud.admin` | Full control including delete of attached clusters |

### GCP APIs Enabled by the Module

| API | Purpose |
|---|---|
| `gkemulticloud.googleapis.com` | GKE Attached Clusters management |
| `gkeconnect.googleapis.com` | Connect Agent |
| `connectgateway.googleapis.com` | Connect Gateway kubectl proxy |
| `anthos.googleapis.com` | Anthos/Fleet platform |
| `logging.googleapis.com` | Cloud Logging |
| `monitoring.googleapis.com` | Cloud Monitoring |
| `gkehub.googleapis.com` | Fleet Hub |
| `opsconfigmonitoring.googleapis.com` | Managed Prometheus |
| `kubernetesmetadata.googleapis.com` | Kubernetes metadata collection |

### Useful Commands Reference

```bash
# List fleet memberships
gcloud container fleet memberships list --project="${PROJECT_ID}"

# Configure kubectl via Connect Gateway
gcloud container fleet memberships get-credentials <cluster-name> --project="${PROJECT_ID}"

# Describe membership details
gcloud container fleet memberships describe <cluster-name> --project="${PROJECT_ID}"

# List available attached cluster versions
gcloud container attached get-server-config --location="${GCP_REGION}" --project="${PROJECT_ID}"

# View cluster audit logs
gcloud logging read "protoPayload.serviceName=connectgateway.googleapis.com" --project="${PROJECT_ID}"

# Check node resource usage (via Connect Gateway)
kubectl top nodes

# View all namespaces
kubectl get namespaces

# Verify RBAC permissions
kubectl auth can-i list pods --all-namespaces
```

### Lab Summary: Automated vs Manual Actions

The table below recaps every major action in the lab and whether it is automated by the
`AKS_GKE` Terraform module or performed manually.

| Action | Automated |
|---|---|
| Enable GCP APIs (gkemulticloud, gkeconnect, connectgateway, anthos, logging, monitoring, gkehub) | Yes — `main.tf` |
| Create Azure Resource Group | Yes — `main.tf` |
| Deploy AKS cluster with OIDC issuer | Yes — `main.tf` |
| Assign Network Contributor role to AKS identity | Yes — `main.tf` |
| Fetch GKE Attached Clusters install manifest | Yes — `attached-install-manifest` module |
| Install bootstrap Helm chart onto AKS cluster | Yes — `attached-install-manifest` module |
| Register AKS cluster in GKE Hub as attached cluster | Yes — `main.tf` |
| Enable Cloud Logging (system components + workloads) | Yes — `main.tf` |
| Enable Managed Prometheus monitoring | Yes — `main.tf` |
| Grant cluster-admin to trusted_users | Yes — `main.tf` |
| Verify cluster appears in GKE console | No — console verification |
| Verify fleet membership | No — console verification |
| Verify logging and monitoring enabled in cluster details | No — console verification |
| Configure kubectl via Connect Gateway | No — `gcloud` command |
| Verify cluster connectivity and list nodes | No — `kubectl` commands |
| View fleet feature status | No — console verification |
| Inspect GKE Connect agent pod | No — `kubectl` commands |
| Inspect managed components namespace | No — `kubectl` commands |
| View system component logs in Cloud Logging | No — Logs Explorer |
| View workload logs in Cloud Logging | No — Logs Explorer |
| Verify log ingestion with a test pod | No — `kubectl` and Logs Explorer |
| View cluster metrics in Metrics Explorer | No — Cloud Monitoring console |
| Explore Kubernetes Engine dashboard | No — Cloud Monitoring console |
| View node and pod resource utilization | No — `kubectl top` commands |
| Deploy nginx workload via Connect Gateway | No — `kubectl apply` |
| Verify workload pods and external IP | No — `kubectl` commands |
| Verify workload logs appear in Cloud Logging | No — Logs Explorer |
| Review authorization model and RBAC bindings | No — `kubectl` and console |
| Grant Connect Gateway access to a team member | No — IAM and `kubectl` |
| Verify admin access with `kubectl auth can-i` | No — `kubectl` command |
| Verify OIDC federation configuration | No — API inspection |
| List available platform versions | No — API query |
| Review audit logs for cluster operations | No — Cloud Logging |
| Import an existing cluster (awareness) | No — reference only |
| Destroy all Terraform-managed resources | Yes — `tofu destroy` |

### Further Reading

- [GKE Attached Clusters overview](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/use-attached-clusters)
- [Connect Gateway overview](https://cloud.google.com/anthos/multicluster-management/gateway)
- [Fleet management](https://cloud.google.com/kubernetes-engine/docs/fleets-overview)
- [Cloud Logging for GKE Attached Clusters](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/logging-monitoring)
- [Azure AKS documentation](https://learn.microsoft.com/en-us/azure/aks/)
