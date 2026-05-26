# Azure Kubernetes Service on GKE Fleet — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/AKS_GKE)**

This lab guide walks you through deploying an **Azure Kubernetes Service (AKS)** cluster and
registering it as a GKE Attached Cluster in **Google Cloud Fleet** using the **AKS_GKE** module.
You will then explore unified multi-cloud operations: accessing the AKS cluster via Google Cloud's
Connect Gateway, centralised logging and monitoring through Google Cloud Observability, and fleet-
wide access control — all without leaving Google Cloud.

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

### Step 5.2 — Query Metrics via Cloud Monitoring API

**gcloud:**
```bash
gcloud monitoring metrics list \
  --filter="metric.type:kubernetes" \
  --project="${PROJECT_ID}" \
  | grep -E "container/cpu|container/memory|node/cpu"
```

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

### Step 5.3 — Node and Pod Resource Usage

```bash
# Current node resource consumption
kubectl top nodes

# Current pod resource consumption
kubectl top pods -n sample-workload

# All namespaces
kubectl top pods --all-namespaces | sort -k3 -rn | head -20
```

### Step 5.4 — Create an Alerting Policy

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

kubectl describe clusterrolebinding \
  "$(kubectl get clusterrolebindings -o name | grep -i google | head -1)"
```

### Step 6.2 — Grant a Colleague Read-Only Access

Replace `colleague@example.com` with the actual Google identity:

```bash
# Step 1: Grant IAM permission to use Connect Gateway
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="user:colleague@example.com" \
  --role="roles/gkehub.gatewayReader"

# Step 2: Create a Kubernetes RBAC binding for cluster-level read
kubectl create clusterrolebinding colleague-view \
  --clusterrole=view \
  --user="colleague@example.com"
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

### Step 6.3 — Verify Your Own Admin Permissions

```bash
kubectl auth can-i list pods --all-namespaces
kubectl auth can-i create deployments -n sample-workload
kubectl auth can-i delete namespaces
```

### Step 6.4 — Review Audit Logs

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

### Further Reading

- [GKE Attached Clusters overview](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/use-attached-clusters)
- [Connect Gateway overview](https://cloud.google.com/anthos/multicluster-management/gateway)
- [Fleet management](https://cloud.google.com/kubernetes-engine/docs/fleets-overview)
- [Cloud Logging for GKE Attached Clusters](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/logging-monitoring)
- [Azure AKS documentation](https://learn.microsoft.com/en-us/azure/aks/)
