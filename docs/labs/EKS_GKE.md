# AWS Elastic Kubernetes Service on GKE Fleet — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/EKS_GKE)**

This lab guide walks you through deploying an **AWS Elastic Kubernetes Service (EKS)** cluster
and registering it as a GKE Attached Cluster in **Google Cloud Fleet** using the **EKS_GKE**
module. You will then explore unified multi-cloud operations: accessing the EKS cluster via
Google Cloud's Connect Gateway, centralised logging and monitoring through Google Cloud
Observability, and fleet-wide access control — all from a single Google Cloud control plane.

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
11. [Exercise 7 — OIDC Federation Deep Dive](#exercise-7--oidc-federation-deep-dive)
12. [Exercise 8 — Network Topology and Private Subnets](#exercise-8--network-topology-and-private-subnets)
13. [Exercise 9 — Platform Version Management](#exercise-9--platform-version-management)
14. [Cleanup](#14-cleanup)
15. [Reference](#15-reference)

---

## 1. Overview

### What Is GKE Fleet?

Google Cloud **Fleet** (formerly Anthos) provides a unified control plane for Kubernetes clusters
across clouds and on-premises environments. By registering an AWS EKS cluster as a **GKE
Attached Cluster**, you gain:

| Capability | What It Enables |
|---|---|
| **Connect Gateway** | `kubectl` access to EKS clusters via Google Cloud IAM — no VPN or bastion required |
| **Cloud Logging** | Unified Kubernetes system and workload logs from EKS in Cloud Logging |
| **Managed Prometheus** | EKS cluster metrics collected and queryable in Cloud Monitoring |
| **Fleet IAM** | Single IAM model for access control across all fleet clusters |
| **Multi-cloud visibility** | Single pane of glass for cluster health, nodes, and workloads |

### Why AWS + GCP?

AWS and GCP represent the most common multi-cloud combination. Organisations choose this pattern
for several reasons:

- **Risk mitigation**: no single-cloud dependency for critical workloads
- **Regulatory requirements**: some sectors mandate multi-cloud resilience
- **Incremental migration**: move workloads to GCP gradually while keeping existing EKS investments
- **GCP service access**: use Cloud AI/ML, BigQuery, or Spanner from AWS-hosted services

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  AWS (us-west-2)                                                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  VPC (10.0.0.0/16)                                           │   │
│  │  ┌─────────────────────┐  ┌─────────────────────────────┐   │   │
│  │  │  Public Subnets     │  │  Private Subnets            │   │   │
│  │  │  (3 AZs)            │  │  (3 AZs) — optional         │   │   │
│  │  │  ┌───────────────┐  │  │  ┌─────────────────────┐   │   │   │
│  │  │  │  NAT Gateway  │  │  │  │  EKS Node Group     │   │   │   │
│  │  │  └───────────────┘  │  │  │  (2–5 nodes)        │   │   │   │
│  │  └─────────────────────┘  │  └─────────────────────┘   │   │   │
│  │                           └─────────────────────────────┘   │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  EKS Cluster                                         │   │   │
│  │  │  • Kubernetes 1.34                                   │   │   │
│  │  │  • OIDC issuer enabled                               │   │   │
│  │  │  • IAM roles for service accounts                    │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
          │ OIDC Federation + GKE Connect Agent (outbound HTTPS)
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Google Cloud (us-central1)                                         │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  GKE Fleet Hub                                               │   │
│  │  • Fleet membership: eks-cluster-<id>                        │   │
│  │  • Platform version: 1.34.0-gke.1                           │   │
│  │  • Logging: SYSTEM + WORKLOADS                               │   │
│  │  • Managed Prometheus enabled                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────────────┐  │
│  │ Cloud Logging  │  │Cloud Monitoring│  │  Connect Gateway API  │  │
│  │ (EKS logs)     │  │(EKS metrics)   │  │  (kubectl access)     │  │
│  └────────────────┘  └────────────────┘  └───────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  EKS_GKE
    aws_access_key / aws_secret_key  →  AWS API authentication
    aws_region     = "us-west-2"     →  EKS cluster region
    k8s_version    = "1.34"          →  EKS Kubernetes version
    min_size = 2, desired_size = 2,
    max_size = 5                     →  Node group auto-scaling bounds
    trusted_users  = ["user@example.com"]  →  cluster-admin via Connect Gateway
```

### Network Topology

The module creates a complete AWS VPC with both public and private subnets across three
availability zones. A NAT Gateway in the public subnet enables internet egress for nodes in
private subnets. The GKE Connect Agent communicates outbound over HTTPS — no inbound AWS
Security Group rules are required.

---

## 3. Prerequisites

### Required Tools

| Tool | Minimum Version | Install |
|---|---|---|
| `gcloud` CLI | 480.0.0 | [Install guide](https://cloud.google.com/sdk/docs/install) |
| `kubectl` | 1.29+ | `gcloud components install kubectl` |
| `gke-gcloud-auth-plugin` | Any | `gcloud components install gke-gcloud-auth-plugin` |
| `aws` CLI | 2.x | [AWS CLI install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| `curl` / `jq` | Any | System package manager |

### AWS Requirements

You need an **AWS IAM user** or **IAM role** with permissions to create:
- VPC, subnets, internet gateway, NAT gateway, route tables
- EKS cluster and managed node groups
- IAM roles and policies

Collect these two values before deploying:
- **Access Key ID** (`aws_access_key`)
- **Secret Access Key** (`aws_secret_key`)

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
export AWS_REGION="us-west-2"
export CLUSTER_NAME="eks-cluster"   # adjust if cluster_name_prefix was changed

gcloud config set project "${PROJECT_ID}"
```

### REST API Shell Variables

If you plan to use the REST API equivalents shown throughout this lab, set the following
variables once before running any API command:

```bash
export TOKEN=$(gcloud auth print-access-token)
export BASE="https://gkemulticloud.googleapis.com/v1"
export PROJECT="${PROJECT_ID}"
export LOCATION="${GCP_REGION}"
export CLUSTER="${CLUSTER_NAME}"
```

All mutating GKE Multi-Cloud API operations return a long-running Operation. Poll for
completion with:

```bash
curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/operations/OPERATION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.done, .error'
```

`done: true` with no `error` means the operation succeeded.

> **gcloud note:** `gcloud container attached clusters` commands are synchronous by default —
> they wait for the operation to finish before returning. Pass `--async` to return immediately
> with an operation name, then poll it with:
> ```bash
> gcloud container attached operations describe OPERATION_ID \
>   --location=$LOCATION \
>   --project=$PROJECT
> ```

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `EKS_GKE` module via the RAD UI. In the variable form, set the following key variables:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `gcp_location` | `us-central1` | GCP region for Fleet membership |
| `aws_region` | `us-west-2` | AWS region for EKS cluster |
| `aws_access_key` | `<your-access-key-id>` | AWS IAM credentials |
| `aws_secret_key` | `<your-secret-access-key>` | AWS IAM credentials |
| `k8s_version` | `1.34` | Kubernetes version |
| `platform_version` | `1.34.0-gke.1` | GKE Connect Agent version |
| `min_size` | `2` | Node group minimum nodes |
| `desired_size` | `2` | Node group desired nodes |
| `max_size` | `5` | Node group maximum nodes |
| `trusted_users` | `["your-email@example.com"]` | Users granted cluster-admin |

Click **Deploy** and wait for provisioning to complete (approximately 20–30 minutes).

> **What this provisions:** An AWS VPC with public and private subnets across 3 AZs, NAT
> Gateway, EKS cluster with OIDC issuer, managed node group (2 nodes, t3/m5 class), IAM roles
> for the cluster and nodes, GKE Attached Cluster registration in Fleet Hub with OIDC trust,
> Cloud Logging for system and workload logs, and Managed Prometheus for metrics collection.

### 4.2 Configure AWS CLI (Optional)

```bash
aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
aws configure set default.region "${AWS_REGION}"

# Verify EKS cluster was created
aws eks list-clusters --region "${AWS_REGION}"
```

---

## Exercise 1 — Verify the Fleet Membership

### Objective

Confirm that the EKS cluster is correctly registered in Google Cloud Fleet and all managed
components are healthy.

### Step 1.1 — List Fleet Memberships

**gcloud:**
```bash
gcloud container fleet memberships list --project="${PROJECT_ID}"
```

Expected output:
```
NAME                         EXTERNAL_ID                            LOCATION
eks-cluster-<id>             xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   global
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
- `authority.issuer` — OIDC issuer URL from EKS

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{
    name,
    state: .state.code,
    k8sVersion: .endpoint.kubernetesMetadata.kubernetesApiServerVersion,
    oidcIssuer: .authority.issuer
  }'
```

### Step 1.3 — View in Google Cloud Console

```bash
echo "https://console.cloud.google.com/kubernetes/list/overview?project=${PROJECT_ID}"
```

The EKS cluster appears in the Kubernetes Engine cluster list with an AWS icon.

### Step 1.4 — Check EKS Cluster in AWS Console

```bash
aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.{name:name,status:status,version:version,endpoint:endpoint}' \
  --output table
```

---

## Exercise 2 — Access via Connect Gateway

### Objective

Use Google Cloud's **Connect Gateway** to access the EKS cluster with `kubectl` using your
Google Cloud IAM identity — without needing AWS credentials or direct network access.

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
NAME                                           STATUS   ROLES    AGE   VERSION
ip-10-0-x-xxx.us-west-2.compute.internal       Ready    <none>   5m    v1.34.x
ip-10-0-x-xxx.us-west-2.compute.internal       Ready    <none>   5m    v1.34.x
```

### Step 2.3 — Inspect Cluster Namespaces

```bash
kubectl get namespaces

# Standard EKS namespaces:
# default
# kube-system
# kube-public
# kube-node-lease
# gke-connect        ← GKE Connect Agent
```

### Step 2.4 — Verify Admin Access

```bash
kubectl auth can-i list pods --all-namespaces
# Expected: yes

kubectl auth can-i create clusterrolebindings
# Expected: yes
```

### Step 2.5 — Inspect the GKE Connect Agent

```bash
kubectl get pods -n gke-connect -o wide

kubectl describe pod -n gke-connect -l app=gke-connect-agent
# Note: image tag corresponds to platform_version (e.g. 1.34.0-gke.1)
```

---

## Exercise 3 — Deploy a Sample Workload

### Objective

Deploy a sample application to the EKS cluster via Connect Gateway and verify it appears in
Cloud Logging and Cloud Monitoring.

### Step 3.1 — Create a Namespace

```bash
kubectl create namespace sample-workload
```

### Step 3.2 — Deploy nginx

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: sample-workload
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
  annotations:
    # AWS NLB annotation (for AWS load balancer)
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
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

kubectl get pods -n sample-workload -w
```

### Step 3.3 — Get the Service External Endpoint

```bash
# AWS NLB hostname (not IP) — may take 3-5 minutes to provision
kubectl get service nginx -n sample-workload -w

NGINX_HOST=$(kubectl get service nginx -n sample-workload \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Nginx endpoint: http://${NGINX_HOST}"

# Test the endpoint
curl -s "http://${NGINX_HOST}" | grep "<title>"
```

### Step 3.4 — Verify Pod Distribution

```bash
# Verify pods are spread across nodes/AZs
kubectl get pods -n sample-workload -o wide

# Check resource consumption
kubectl top pods -n sample-workload
kubectl top nodes
```

### Step 3.5 — Generate Traffic for Logs

```bash
for i in $(seq 1 100); do
  curl -s -o /dev/null "http://${NGINX_HOST}" || true
  sleep 0.3
done
```

---

## Exercise 4 — Centralised Logging with Cloud Logging

### Objective

Explore Kubernetes system and workload logs from the EKS cluster collected automatically by
Cloud Logging via the GKE Connect Agent.

### Step 4.1 — View Logs Explorer

```bash
echo "https://console.cloud.google.com/logs/query?project=${PROJECT_ID}"
```

### Step 4.2 — Query System Component Logs

**gcloud:**
```bash
gcloud logging read \
  "resource.type=k8s_cluster \
   AND resource.labels.cluster_name=${CLUSTER_NAME}" \
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
  }" | jq '.entries[] | {timestamp, severity}'
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
  | jq '.[] | {timestamp, httpRequest}'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_container resource.labels.cluster_name=${CLUSTER_NAME} resource.labels.namespace_name=sample-workload\",
    \"pageSize\": 10
  }" | jq '.entries[].jsonPayload'
```

### Step 4.4 — kube-system Logs

```bash
gcloud logging read \
  "resource.type=k8s_container \
   AND resource.labels.cluster_name=${CLUSTER_NAME} \
   AND resource.labels.namespace_name=kube-system" \
  --project="${PROJECT_ID}" \
  --limit=10 \
  --format=json \
  | jq '.[] | {timestamp, container: .resource.labels.container_name, message: .textPayload}'
```

---

## Exercise 5 — Managed Prometheus and Cloud Monitoring

### Objective

Explore Kubernetes metrics from the EKS cluster collected by Managed Prometheus and visualised
in Cloud Monitoring.

### Step 5.1 — Open the Kubernetes Engine Dashboard

```bash
echo "https://console.cloud.google.com/monitoring/dashboards?project=${PROJECT_ID}"
```

Navigate to **Dashboards** → **Kubernetes Engine** → select the EKS cluster.

### Step 5.2 — Node Resource Usage

```bash
kubectl top nodes

# Expected:
# NAME                                   CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# ip-10-0-x-xxx.us-west-2.compute.internal   120m      6%     512Mi           13%
```

### Step 5.3 — Query Metrics via Cloud Monitoring API

**gcloud (CPU allocatable utilisation per cluster):**
```bash
gcloud monitoring metrics list \
  --filter="metric.type:kubernetes.io/node" \
  --project="${PROJECT_ID}" \
  | head -20
```

**REST API (MQL query):**
```bash
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"fetch k8s_node::kubernetes.io/node/cpu/allocatable_utilization | filter resource.cluster_name = '${CLUSTER_NAME}' | within 1h | group_by [resource.node_name], mean(val())\"
  }" | jq '.timeSeriesData[].labelValues'
```

### Step 5.4 — Pod Memory Utilisation

**REST API (MQL):**
```bash
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"fetch k8s_container::kubernetes.io/container/memory/used_bytes | filter resource.cluster_name = '${CLUSTER_NAME}' AND resource.namespace_name = 'sample-workload' | within 30m | group_by [resource.pod_name], mean(val())\"
  }" | jq '.timeSeriesData[].labelValues'
```

### Step 5.5 — Create an Alert Policy

**gcloud:**
```bash
gcloud alpha monitoring policies create \
  --display-name="EKS High Memory" \
  --notification-channels="" \
  --condition-filter="metric.type=\"kubernetes.io/node/memory/allocatable_utilization\" resource.type=\"k8s_node\" resource.label.\"cluster_name\"=\"${CLUSTER_NAME}\"" \
  --condition-threshold-value=0.85 \
  --condition-threshold-duration=300s \
  --condition-threshold-comparison=COMPARISON_GT \
  --project="${PROJECT_ID}"
```

---

## Exercise 6 — Fleet Access Control

### Objective

Grant a colleague access to the EKS cluster using the two-layer authorisation model: Google
Cloud IAM for Connect Gateway traversal and Kubernetes RBAC for API-level access.

### Background: Authorisation Layers

```
Developer
  │
  ▼ Layer 1: Google Cloud IAM
  roles/gkehub.gatewayReader or gatewayEditor
  (controls who can send requests through Connect Gateway)
  │
  ▼ Layer 2: Kubernetes RBAC
  ClusterRoleBinding mapping Google identity → Kubernetes ClusterRole
  (controls what Kubernetes actions are allowed)
  │
  ▼
EKS API Server
```

### Step 6.1 — View Existing RBAC Bindings

```bash
kubectl get clusterrolebindings \
  | grep -v "^system:"

kubectl get rolebindings --all-namespaces \
  | grep -v "^kube-system"
```

### Step 6.2 — Grant Read-Only Access

```bash
# Step 1: IAM permission for Connect Gateway traversal
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="user:colleague@example.com" \
  --role="roles/gkehub.gatewayReader"

# Step 2: Kubernetes RBAC — view access to all namespaces
kubectl create clusterrolebinding colleague-view \
  --clusterrole=view \
  --user="colleague@example.com"
```

### Step 6.3 — Grant Namespace-Scoped Edit Access

```bash
# IAM permission (same as above — gateway access is project-level)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="user:developer@example.com" \
  --role="roles/gkehub.gatewayEditor"

# Namespace-scoped edit access
kubectl create rolebinding developer-edit \
  --rolebinding=edit \
  --user="developer@example.com" \
  --namespace=sample-workload
```

**REST API (IAM):**
```bash
curl -s -X POST \
  "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:setIamPolicy" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": {
      "bindings": [
        {"role": "roles/gkehub.gatewayReader", "members": ["user:colleague@example.com"]},
        {"role": "roles/gkehub.gatewayEditor", "members": ["user:developer@example.com"]}
      ]
    }
  }'
```

### Step 6.4 — Audit Who Has Accessed the Cluster

```bash
gcloud logging read \
  "protoPayload.serviceName=connectgateway.googleapis.com \
   AND protoPayload.request.cluster_name=${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --limit=20 \
  --format=json \
  | jq '.[] | {
    timestamp,
    caller: .protoPayload.authenticationInfo.principalEmail,
    method: .protoPayload.methodName,
    status: .protoPayload.status.code
  }'
```

---

## Exercise 7 — OIDC Federation Deep Dive

### Objective

Understand how OIDC federation works between AWS EKS and Google Cloud, enabling Google
identities to authenticate to the EKS API server via Connect Gateway.

### Step 7.1 — Inspect the OIDC Issuer

```bash
# View the EKS OIDC issuer URL registered in Fleet
gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --format="yaml(authority)"
```

Expected:
```yaml
authority:
  issuer: https://oidc.eks.us-west-2.amazonaws.com/id/<cluster-id>
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

### Step 7.2 — Verify OIDC Discovery Endpoint

```bash
# EKS publishes an OIDC discovery document (public endpoint)
OIDC_ISSUER=$(gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --format="value(authority.issuer)")

curl -s "${OIDC_ISSUER}/.well-known/openid-configuration" | jq '{issuer, jwks_uri}'
```

### Step 7.3 — Direct Connect Gateway API Call

```bash
# Get the Connect Gateway endpoint from kubeconfig
GATEWAY_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Direct REST call — list namespaces
curl -s "${GATEWAY_URL}/api/v1/namespaces" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq '.items[].metadata.name'

# Direct REST call — list pods in sample-workload
curl -s "${GATEWAY_URL}/api/v1/namespaces/sample-workload/pods" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq '.items[].metadata.name'
```

### Step 7.4 — Understand the Token Exchange Flow

When you run `kubectl` via Connect Gateway, the following happens:

1. `kubectl` sends the request with your Google OAuth2 access token
2. Connect Gateway validates the token against Google Cloud IAM
3. Gateway exchanges the Google token for a short-lived Kubernetes token via the OIDC issuer
4. The Kubernetes token is presented to the EKS API server
5. EKS validates the token via its OIDC provider configuration
6. Kubernetes RBAC evaluates the identity against ClusterRoleBindings

### Step 7.5 — Verify OIDC Issuer Registration

Confirm that the OIDC issuer URL recorded in GKE Hub matches the one published by the EKS
cluster — this URL is the trust anchor for the entire authentication chain:

```bash
# OIDC issuer as reported by AWS
aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query "cluster.identity.oidc.issuer" \
  --output text

# OIDC issuer as registered in GKE Hub
gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --format="value(authority.issuer)"
```

Both commands should return the same URL (e.g.
`https://oidc.eks.us-west-2.amazonaws.com/id/XXXXXXXXXX`). GKE Hub validates tokens signed
by this issuer to authenticate Connect Agent connections and `kubectl` requests through the
Connect Gateway.

---

## Exercise 8 — Network Topology and Private Subnets

### Objective

Explore the AWS VPC networking created by the module and understand how the Connect Agent
reaches Google Cloud without any inbound firewall rules.

### Step 8.1 — Inspect VPC Subnets from kubectl

```bash
# Node addresses reveal subnet assignment
kubectl get nodes -o json \
  | jq '.items[] | {
    name: .metadata.name,
    internalIP: (.status.addresses[] | select(.type=="InternalIP") | .address),
    externalIP: (.status.addresses[] | select(.type=="ExternalIP") | .address)
  }'
```

### Step 8.2 — Inspect Nodes via AWS CLI

```bash
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned" \
  --query 'Reservations[].Instances[] | [].{
    ID: InstanceId,
    State: State.Name,
    Type: InstanceType,
    PrivateIP: PrivateIpAddress,
    SubnetId: SubnetId,
    AZ: Placement.AvailabilityZone
  }' \
  --output table \
  --region "${AWS_REGION}"
```

### Step 8.3 — Verify Outbound Connectivity (NAT Gateway)

The GKE Connect Agent requires outbound HTTPS access to `gkehub.googleapis.com`. With the
NAT Gateway in place, nodes in private subnets can reach Google Cloud without public IPs:

```bash
# Verify Connect Agent is connected (Running = outbound connection maintained)
kubectl get pods -n gke-connect
kubectl describe pods -n gke-connect | grep -E "Status|Ready"
```

### Step 8.4 — Review Security Groups

```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:aws:eks:cluster-name,Values=${CLUSTER_NAME}" \
  --query 'SecurityGroups[].{
    GroupId: GroupId,
    GroupName: GroupName,
    InboundRules: IpPermissions | length(@),
    OutboundRules: IpPermissionsEgress | length(@)
  }' \
  --output table \
  --region "${AWS_REGION}"
```

Note: The Connect Agent only requires outbound port 443 egress. No inbound rules are needed
for Connect Gateway access.

### Step 8.5 — Inspect IAM Roles Created by the Module

Review the AWS IAM roles that Terraform created for the cluster and its node group:

```bash
# Trust policy for the EKS cluster role
aws iam get-role \
  --role-name "${CLUSTER_NAME}-eks-role" \
  --query "Role.AssumeRolePolicyDocument"

# Policies attached to the node group role
aws iam list-attached-role-policies \
  --role-name "${CLUSTER_NAME}-node-group-role" \
  --query "AttachedPolicies[].PolicyName"
```

The EKS cluster role has a trust relationship with `eks.amazonaws.com` and the
`AmazonEKSClusterPolicy` managed policy. The node group role has
`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and
`AmazonEC2ContainerRegistryReadOnly` — the minimum permissions required for worker nodes to
join the cluster and pull container images.

---

## Exercise 9 — Platform Version Management

### Objective

Understand how the GKE Attached Clusters platform version controls the managed components
installed on the EKS cluster, and how to upgrade them.

### Step 9.1 — List Available Platform Versions

The `platform_version` module variable controls which version of the managed components is
installed. Run the following to see all currently supported versions:

```bash
gcloud container attached get-server-config \
  --location="${GCP_REGION}" \
  --project="${PROJECT_ID}"
```

Each listed version is compatible with a range of Kubernetes minor versions. Choose a
platform version whose `validVersions` range includes your EKS cluster's Kubernetes version.

**REST API equivalent:**
```bash
curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedServerConfig" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.validVersions[] | {version, kubernetesVersions}'
```

### Step 9.2 — Verify the Current Platform Version

Confirm which platform version is currently active on the cluster:

```bash
gcloud container attached clusters describe "${CLUSTER_NAME}" \
  --location="${GCP_REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(platformVersion)"
```

**REST API equivalent:**
```bash
curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters/$CLUSTER" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.platformVersion'
```

The returned version string (e.g. `1.34.0-gke.1`) should match the `platform_version` value
set at deploy time.

### Step 9.3 — Understand the Upgrade Process

To upgrade the platform version (the managed components on the EKS cluster), update the
`platform_version` variable and redeploy via the RAD UI. Terraform will:

1. Fetch a new install manifest from the Attached Clusters service.
2. Use Helm to upgrade the `attached-bootstrap` chart on the EKS cluster.
3. Update the `google_container_attached_cluster` resource with the new platform version.

> **Note:** Platform version upgrades do not affect the EKS control plane or worker node
> Kubernetes version. EKS Kubernetes version upgrades are managed separately through AWS by
> updating `k8s_version` and redeploying.

---

## 14. Cleanup

Return to the RAD UI and click **Undeploy** on the `EKS_GKE` deployment. This removes all
provisioned resources in the correct dependency order (GKE Hub detach, EKS node group
termination, EKS cluster deletion, VPC and networking cleanup). Allow approximately 20–25
minutes for full teardown.

| Resource | Typical time |
|---|---|
| GKE Hub detach | 1–2 minutes |
| EKS node group termination | 3–5 minutes |
| EKS cluster deletion | 10–15 minutes |
| VPC and networking cleanup | 1–2 minutes |

> **Important:** Always use the RAD UI Undeploy (or `tofu destroy`) rather than deleting
> resources individually through the AWS or GCP consoles. The bootstrap cleanup hook must run
> before the node group is removed, and destroying resources out of order may cause the destroy
> to fail.

This removes:
- The GKE Fleet membership
- The AWS EKS cluster and node group
- The AWS VPC, subnets, NAT Gateway, internet gateway, and all associated resources
- IAM roles created for EKS

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

**aws — delete EKS cluster:**
```bash
# Delete node group first
aws eks delete-nodegroup \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "eks-node-group" \
  --region "${AWS_REGION}"

# Wait for node group deletion
aws eks wait nodegroup-deleted \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "eks-node-group" \
  --region "${AWS_REGION}"

# Then delete cluster
aws eks delete-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}"
```

**Clean up kubectl context:**
```bash
kubectl config delete-context \
  "connectgateway_${PROJECT_ID}_global_${CLUSTER_NAME}"
```

---

## 15. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `gcp_location` | string | `us-central1` | GCP region for Fleet membership |
| `aws_region` | string | `us-west-2` | AWS region for EKS cluster |
| `cluster_name_prefix` | string | `eks-cluster` | Resource name prefix |
| `k8s_version` | string | `1.34` | Kubernetes version for EKS |
| `platform_version` | string | `1.34.0-gke.1` | GKE Connect Agent platform version |
| `min_size` | number | `2` | Node group minimum nodes |
| `desired_size` | number | `2` | Node group desired nodes |
| `max_size` | number | `5` | Node group maximum nodes |
| `trusted_users` | list(string) | `[]` | Google identities granted cluster-admin |
| `aws_access_key` | string | — | AWS IAM Access Key ID (required) |
| `aws_secret_key` | string | — | AWS IAM Secret Access Key (required) |
| `vpc_cidr` | string | `10.0.0.0/16` | VPC CIDR block |
| `public_subnets` | bool | `true` | Create public subnets with IGW |

### IAM Roles Created by the Module

**AWS:**
| Role | Purpose |
|---|---|
| `eks-cluster-role-<id>` | EKS control plane (trust: eks.amazonaws.com) |
| `eks-node-group-role-<id>` | EC2 worker nodes (trust: ec2.amazonaws.com) |

**GCP APIs Enabled:**
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
| `kubernetesmetadata.googleapis.com` | Kubernetes metadata |

### Useful Commands Reference

```bash
# List fleet memberships
gcloud container fleet memberships list --project="${PROJECT_ID}"

# Configure kubectl via Connect Gateway
gcloud container fleet memberships get-credentials <cluster-name> --project="${PROJECT_ID}"

# Query EKS cluster info
aws eks describe-cluster --name <cluster-name> --region "${AWS_REGION}"

# List available platform versions
gcloud container attached get-server-config --location="${GCP_REGION}" --project="${PROJECT_ID}"

# Top nodes
kubectl top nodes

# Audit Connect Gateway access
gcloud logging read "protoPayload.serviceName=connectgateway.googleapis.com" --project="${PROJECT_ID}"
```

### Further Reading

- [GKE Attached Clusters overview](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/use-attached-clusters)
- [EKS Attached Clusters guide](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/eks/create-cluster)
- [Connect Gateway overview](https://cloud.google.com/anthos/multicluster-management/gateway)
- [AWS EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [OIDC federation for GKE Attached Clusters](https://cloud.google.com/kubernetes-engine/multi-cloud/docs/attached/oidc-config)
