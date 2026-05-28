# Multi-Cluster Bank of Anthos on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/MC_Bank_GKE)**

This lab guide walks you through deploying and operating the **Bank of Anthos** reference
application across **multiple GKE clusters in multiple regions** using the **MC_Bank_GKE**
module. You will explore active-active geo-redundant architecture, fleet-wide Cloud Service
Mesh, Multi-Cluster Ingress for global load balancing, Multi-Cluster Services for cross-cluster
service discovery, and resilience testing through deliberate failure injection.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Verify Multi-Cluster Infrastructure](#exercise-1--verify-multi-cluster-infrastructure)
6. [Exercise 2 — GKE Fleet Exploration](#exercise-2--gke-fleet-exploration)
7. [Exercise 3 — Cloud Service Mesh (Fleet-Wide)](#exercise-3--cloud-service-mesh-fleet-wide)
8. [Exercise 4 — Access the Application](#exercise-4--access-the-application)
9. [Exercise 5 — Multi-Cluster Ingress and Global Load Balancing](#exercise-5--multi-cluster-ingress-and-global-load-balancing)
10. [Exercise 6 — Resilience Testing: Regional Failover](#exercise-6--resilience-testing-regional-failover)
11. [Exercise 7 — Observability Across Clusters](#exercise-7--observability-across-clusters)
12. [Exercise 8 — Advanced Operations](#exercise-8--advanced-operations)
13. [Cleanup](#13-cleanup)
14. [Reference](#14-reference)

---

## 1. Overview

### Why Multi-Cluster?

Single-cluster deployments face inherent limitations for mission-critical financial workloads:
a regional outage takes the entire application offline. The `MC_Bank_GKE` module deploys Bank
of Anthos in an **active-active** configuration across two or more GKE clusters in separate
Google Cloud regions, eliminating the single cluster as a single point of failure.

| Capability | What It Enables |
|---|---|
| **Active-active geo-redundancy** | Traffic served from the nearest healthy cluster; automatic failover on cluster/region failure |
| **Fleet-wide Cloud Service Mesh** | mTLS, L7 traffic policies, and observability across all clusters |
| **Multi-Cluster Ingress (MCI)** | Single global IP with traffic directed to the nearest backend |
| **Multi-Cluster Services (MCS)** | DNS-based cross-cluster service discovery without manual configuration |
| **SLA target** | Architecture supports 99.99%+ availability |

### Supported Configurations

The module supports 2–4 clusters across configurable regions:

```
cluster_size = 2  →  us-west1, us-east1     (default)
cluster_size = 3  →  us-west1, us-east1, europe-west1
cluster_size = 4  →  us-west1, us-east1, europe-west1, asia-east1
```

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Global                                                              │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Multi-Cluster Ingress (Global L7 Load Balancer)              │    │
│  │  Single public IP → nearest healthy cluster                   │    │
│  └────────────┬─────────────────────────────┬────────────────┘    │
│               │                             │                      │
│       ┌───────▼──────────┐         ┌────────▼─────────┐           │
│       │  us-west1        │         │  us-east1        │  (+ more)  │
│       │  GKE Autopilot   │         │  GKE Autopilot   │           │
│       │  Cluster         │         │  Cluster         │           │
│       │  ┌────────────┐  │         │  ┌────────────┐  │           │
│       │  │Bank of     │  │         │  │Bank of     │  │           │
│       │  │Anthos      │◄─┼────MCS──┼─►│Anthos      │  │           │
│       │  │(all 9 svcs)│  │         │  │(all 9 svcs)│  │           │
│       │  │+ Envoy     │  │         │  │+ Envoy     │  │           │
│       │  │sidecars    │  │         │  │sidecars    │  │           │
│       │  └────────────┘  │         │  └────────────┘  │           │
│       └──────────────────┘         └──────────────────┘           │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Google Cloud Fleet Hub                                       │    │
│  │  • Fleet membership for each cluster                          │    │
│  │  • servicemesh feature: MANAGEMENT_AUTOMATIC (all clusters)  │    │
│  │  • multiclusteringress feature (config cluster: cluster-0)   │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  MC_Bank_GKE
    cluster_size            = 2               →  2 GKE clusters
    available_regions       = ["us-west1",
                               "us-east1"]    →  one cluster per region
    create_autopilot_cluster = true           →  GKE Autopilot for each
    enable_cloud_service_mesh = true          →  Fleet-wide managed Istio
    deploy_application       = true           →  Bank of Anthos on all clusters
```

---

## 3. Prerequisites

### Required Tools

| Tool | Minimum Version | Install |
|---|---|---|
| `gcloud` CLI | 480.0.0 | [Install guide](https://cloud.google.com/sdk/docs/install) |
| `kubectl` | 1.29+ | `gcloud components install kubectl` |
| `istioctl` | 1.20+ | `curl -L https://istio.io/downloadIstio \| sh -` |
| `curl` / `jq` | Any | System package manager |

### GCP Permissions

```
roles/owner                    # or the following fine-grained set:
roles/container.admin
roles/gkehub.admin
roles/iam.serviceAccountAdmin
roles/compute.networkAdmin
roles/monitoring.admin
roles/logging.admin
```

### Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION_1="us-west1"
export REGION_2="us-east1"
export CLUSTER_1="gke-cluster-0"    # adjust based on deployment_id
export CLUSTER_2="gke-cluster-1"
export APP_NAMESPACE="bank-of-anthos"

gcloud config set project "${PROJECT_ID}"
```

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `MC_Bank_GKE` module via the RAD UI. In the variable form, set:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `available_regions` | `["us-west1", "us-east1"]` | Regions for clusters |
| `cluster_size` | `2` | Number of clusters |
| `create_autopilot_cluster` | `true` | Autopilot (recommended) |
| `enable_cloud_service_mesh` | `true` | Fleet-wide managed Istio |
| `deploy_application` | `true` | Deploy Bank of Anthos |

Click **Deploy** and wait for provisioning to complete (approximately 40–60 minutes).

> **What this provisions:** One GKE Autopilot cluster per region, a shared VPC network,
> Cloud Service Mesh Fleet feature (MANAGEMENT_AUTOMATIC) on all clusters, Multi-Cluster
> Ingress and Multi-Cluster Services Fleet features, Bank of Anthos deployed to all clusters,
> and a global L7 load balancer with a single public IP.

### 4.2 Configure kubectl for Both Clusters

```bash
gcloud container clusters get-credentials "${CLUSTER_1}" \
  --region "${REGION_1}" \
  --project "${PROJECT_ID}"

gcloud container clusters get-credentials "${CLUSTER_2}" \
  --region "${REGION_2}" \
  --project "${PROJECT_ID}"

# Rename contexts for clarity
kubectl config rename-context \
  "gke_${PROJECT_ID}_${REGION_1}_${CLUSTER_1}" \
  "cluster-west"

kubectl config rename-context \
  "gke_${PROJECT_ID}_${REGION_2}_${CLUSTER_2}" \
  "cluster-east"

# Verify both contexts
kubectl config get-contexts
```

---

## Exercise 1 — Verify Multi-Cluster Infrastructure

### Objective

Confirm that all clusters are healthy, nodes are ready, and Bank of Anthos pods are running
with Envoy sidecars on every cluster.

### Step 1.1 — Verify Cluster Health

```bash
# Check cluster 1
kubectl --context=cluster-west get nodes

# Check cluster 2
kubectl --context=cluster-east get nodes
```

All nodes should show `STATUS=Ready`.

**gcloud:**
```bash
gcloud container clusters list \
  --project="${PROJECT_ID}" \
  --format="table(name, location, status, currentNodeCount)"
```

**REST API:**
```bash
curl -s \
  "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/-/clusters" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.clusters[] | {name, location, status, currentNodeCount}'
```

### Step 1.2 — Verify Application Pods on All Clusters

```bash
# Cluster 1
kubectl --context=cluster-west get pods -n "${APP_NAMESPACE}"

# Cluster 2
kubectl --context=cluster-east get pods -n "${APP_NAMESPACE}"
```

All pods should show `2/2 READY` (app + Envoy sidecar).

### Step 1.3 — Verify Sidecar Injection Labels

```bash
kubectl --context=cluster-west \
  get namespace "${APP_NAMESPACE}" --show-labels
# Should include: istio.io/rev=asm-managed

kubectl --context=cluster-east \
  get namespace "${APP_NAMESPACE}" --show-labels
```

---

## Exercise 2 — GKE Fleet Exploration

### Objective

Explore the GKE Fleet membership for all clusters and understand how the Fleet Hub provides
a single control plane across multiple clusters.

### Step 2.1 — List Fleet Memberships

**gcloud:**
```bash
gcloud container fleet memberships list --project="${PROJECT_ID}"
```

Expected output (one membership per cluster):
```
NAME           EXTERNAL_ID                            LOCATION
gke-cluster-0  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   global
gke-cluster-1  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   global
```

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.resources[] | {name, state: .state.code}'
```

### Step 2.2 — View Fleet Feature Status

```bash
gcloud container fleet features list --project="${PROJECT_ID}"
```

Expected features:
- `servicemesh` — Cloud Service Mesh (MANAGEMENT_AUTOMATIC on all clusters)
- `multiclusteringress` — Multi-Cluster Ingress
- `multiclusterservices` — Multi-Cluster Services

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/features" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.resources[] | {name, state: .state.state}'
```

### Step 2.3 — Inspect Fleet Hub Dashboard

```bash
echo "https://console.cloud.google.com/kubernetes/list/overview?project=${PROJECT_ID}"
```

The Fleet dashboard shows all clusters with:
- **Status** (healthy/degraded)
- **Node count** per cluster
- **Active alerts** per cluster
- **Workload summary** across the fleet

---

## Exercise 3 — Cloud Service Mesh (Fleet-Wide)

### Objective

Verify that Cloud Service Mesh is active and managing Envoy sidecars across all clusters,
and confirm mTLS is enforced fleet-wide.

### Step 3.1 — Check Mesh Feature Status on All Clusters

**gcloud:**
```bash
gcloud container fleet mesh describe --project="${PROJECT_ID}"
```

Expected:
```yaml
membershipStates:
  .../memberships/gke-cluster-0:
    servicemesh:
      controlPlaneManagement:
        state: ACTIVE
      dataPlaneManagement:
        state: ACTIVE
  .../memberships/gke-cluster-1:
    servicemesh:
      controlPlaneManagement:
        state: ACTIVE
      dataPlaneManagement:
        state: ACTIVE
```

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/features/servicemesh" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.membershipStates | to_entries[] | {
    cluster: .key,
    controlPlane: .value.servicemesh.controlPlaneManagement.state,
    dataPlane: .value.servicemesh.dataPlaneManagement.state
  }'
```

### Step 3.2 — Inspect Envoy Proxy on Each Cluster

```bash
# Cluster 1 - frontend pod
POD_WEST=$(kubectl --context=cluster-west \
  get pod -n "${APP_NAMESPACE}" -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl --context=cluster-west \
  exec "${POD_WEST}" -n "${APP_NAMESPACE}" -c istio-proxy -- \
  pilot-agent request GET server_info | jq '.version'

# Cluster 2 - frontend pod
POD_EAST=$(kubectl --context=cluster-east \
  get pod -n "${APP_NAMESPACE}" -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl --context=cluster-east \
  exec "${POD_EAST}" -n "${APP_NAMESPACE}" -c istio-proxy -- \
  pilot-agent request GET server_info | jq '.version'
```

### Step 3.3 — Verify mTLS Certificates (SPIFFE Identity)

```bash
kubectl --context=cluster-west \
  exec "${POD_WEST}" -n "${APP_NAMESPACE}" -c istio-proxy -- \
  cat /var/run/secrets/workload-spiffe-credentials/certificates.pem \
  | openssl x509 -noout -text \
  | grep -E "Subject Alternative Name|URI"

# Expected: URI:spiffe://<project-id>.svc.id.goog/ns/bank-of-anthos/sa/...
```

### Step 3.4 — Cloud Service Mesh Dashboard

```bash
echo "https://console.cloud.google.com/anthos/meshes?project=${PROJECT_ID}"
```

The CSM dashboard shows the combined service topology across all clusters, with per-cluster
and aggregate traffic metrics.

---

## Exercise 4 — Access the Application

### Objective

Access Bank of Anthos through the Multi-Cluster Ingress global IP and verify the application
is serving traffic across both clusters.

### Step 4.1 — Get the Global IP

```bash
kubectl --context=cluster-west \
  get multiclusteringress frontend-global-ingress \
  -n "${APP_NAMESPACE}" \
  -o jsonpath='{.status.VIP}'

# Or via gcloud
gcloud compute addresses list \
  --filter="name~bank" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/addresses" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | select(.name | test("bank")) | {name, address, status}'
```

### Step 4.2 — Access the Application

```bash
FRONTEND_IP=$(gcloud compute addresses list \
  --filter="name~bank" \
  --project="${PROJECT_ID}" \
  --format="value(address)")

echo "Application: http://${FRONTEND_IP}"
curl -s "http://${FRONTEND_IP}" | grep "<title>"
```

Navigate to `http://${FRONTEND_IP}` and log in with `testuser` / `password`.

### Step 4.3 — Identify Which Cluster Is Serving Traffic

Add a `server-id` header to trace which cluster serves each request:

```bash
for i in $(seq 1 10); do
  curl -s -I "http://${FRONTEND_IP}" \
    | grep -E "server|via|x-cluster"
done
```

Alternatively, the Global Load Balancer directs traffic based on the origin's geographic
proximity — users near `us-west1` land on cluster-west, users near `us-east1` on cluster-east.

---

## Exercise 5 — Multi-Cluster Ingress and Global Load Balancing

### Objective

Inspect the Multi-Cluster Ingress resources and understand how the global L7 load balancer
distributes traffic across regional backends.

### Step 5.1 — List MCI Resources

```bash
# MultiClusterIngress is a Fleet-level resource, managed from the config cluster
kubectl --context=cluster-west \
  get multiclusteringress -n "${APP_NAMESPACE}"

kubectl --context=cluster-west \
  describe multiclusteringress frontend-global-ingress \
  -n "${APP_NAMESPACE}"
```

### Step 5.2 — Inspect the Global Backends

**gcloud:**
```bash
gcloud compute backend-services list \
  --project="${PROJECT_ID}" \
  --global \
  --format="table(name, backends.group)"
```

**REST API:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/backendServices" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | {name, backends: [.backends[]?.group]}'
```

### Step 5.3 — Check Backend Health

**gcloud:**
```bash
gcloud compute backend-services get-health \
  "$(gcloud compute backend-services list --project="${PROJECT_ID}" --global --format="value(name)" | head -1)" \
  --global \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
BACKEND=$(curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/backendServices" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq -r '.items[0].name')

curl -s -X POST \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/backendServices/${BACKEND}/getHealth" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{"group": ""}' | jq '.healthStatus'
```

### Step 5.4 — View MultiClusterService Resources

Multi-Cluster Services (MCS) provides DNS-based cross-cluster service discovery:

```bash
kubectl --context=cluster-west \
  get multiclusterservice -n "${APP_NAMESPACE}"

kubectl --context=cluster-west \
  describe multiclusterservice frontend \
  -n "${APP_NAMESPACE}"
```

The `frontend.bank-of-anthos.svc.clusterset.local` DNS name resolves to the frontend service
across all clusters in the fleet.

---

## Exercise 6 — Resilience Testing: Regional Failover

### Objective

Simulate a regional failure by scaling down all deployments in one cluster and verify that
the Multi-Cluster Ingress routes all traffic to the remaining healthy cluster.

### Step 6.1 — Scale Down All Deployments in Cluster 2

```bash
# Scale all deployments to 0 in cluster-east
kubectl --context=cluster-east \
  get deployments -n "${APP_NAMESPACE}" \
  -o name | xargs -I{} kubectl --context=cluster-east \
  scale {} -n "${APP_NAMESPACE}" --replicas=0

# Verify all pods are gone
kubectl --context=cluster-east \
  get pods -n "${APP_NAMESPACE}"
# Expected: No resources found
```

### Step 6.2 — Verify Traffic Continues Serving from Cluster 1

```bash
# All requests should still succeed (served from cluster-west)
for i in $(seq 1 10); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${FRONTEND_IP}")
  echo "Request ${i}: HTTP ${HTTP_CODE}"
  sleep 2
done
```

The Global Load Balancer detects unhealthy backends in `us-east1` and routes all traffic
to `us-west1` — typically within 30–60 seconds.

### Step 6.3 — Monitor Failover in Cloud Logging

```bash
gcloud logging read \
  "resource.type=http_load_balancer \
   AND httpRequest.status>=500" \
  --project="${PROJECT_ID}" \
  --limit=10 \
  --format=json \
  | jq '.[] | {timestamp, status: .httpRequest.status, backendTargetProjectNumber: .jsonPayload.backendTargetProjectNumber}'
```

### Step 6.4 — Restore Cluster 2

```bash
# Scale all deployments back to their original replicas
kubectl --context=cluster-east \
  get deployments -n "${APP_NAMESPACE}" \
  -o name | xargs -I{} kubectl --context=cluster-east \
  scale {} -n "${APP_NAMESPACE}" --replicas=1

# Wait for pods to be ready
kubectl --context=cluster-east \
  get pods -n "${APP_NAMESPACE}" -w
```

---

## Exercise 7 — Observability Across Clusters

### Objective

Explore Cloud Logging, Cloud Monitoring, and Cloud Trace data aggregated across all clusters
in the fleet.

### Step 7.1 — Aggregate Logs Across Clusters

```bash
gcloud logging read \
  "resource.type=k8s_container \
   AND resource.labels.namespace_name=${APP_NAMESPACE} \
   AND resource.labels.container_name=frontend" \
  --project="${PROJECT_ID}" \
  --limit=20 \
  --format=json \
  | jq '.[] | {
    timestamp,
    cluster: .resource.labels.cluster_name,
    location: .resource.labels.location,
    message: .textPayload
  }'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_container resource.labels.namespace_name=${APP_NAMESPACE}\",
    \"orderBy\": \"timestamp desc\",
    \"pageSize\": 20
  }" | jq '.entries[] | {timestamp, cluster: .resource.labels.cluster_name}'
```

### Step 7.2 — Cross-Cluster Metrics in Cloud Monitoring

**REST API (request count per cluster):**
```bash
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "fetch istio_canonical_service::istio.io/service/server/request_count | within 1h | group_by [resource.cluster_name, resource.service_name], sum(val())"
  }' | jq '.timeSeriesData[] | {labels: .labelValues, count: .pointData[-1].values[0].int64Value}'
```

### Step 7.3 — Distributed Tracing Across Clusters

```bash
# Generate load to create traces
for i in $(seq 1 50); do
  curl -s -o /dev/null "http://${FRONTEND_IP}"
  sleep 0.2
done

# List traces
gcloud trace traces list \
  --project="${PROJECT_ID}" \
  --start-time="$(date -d '5 minutes ago' --utc +%Y-%m-%dT%H:%M:%SZ)" \
  --limit=10
```

Navigate to:
```bash
echo "https://console.cloud.google.com/traces/list?project=${PROJECT_ID}"
```

### Step 7.4 — Compare Pod Resource Usage Across Clusters

```bash
echo "=== Cluster West ==="
kubectl --context=cluster-west \
  top pods -n "${APP_NAMESPACE}" | sort -k3 -rn

echo "=== Cluster East ==="
kubectl --context=cluster-east \
  top pods -n "${APP_NAMESPACE}" | sort -k3 -rn
```

### Step 7.5 — Fleet-Level Security Dashboard

```bash
echo "https://console.cloud.google.com/kubernetes/security/dashboard?project=${PROJECT_ID}"
```

The Security Posture Dashboard aggregates vulnerability findings and misconfigurations across
all clusters in the fleet.

---

## Exercise 8 — Advanced Operations

### Objective

Explore advanced multi-cluster operations: cross-cluster traffic management with VirtualService,
Managed Prometheus across clusters, and Gateway API CRDs.

### Step 8.1 — Cross-Cluster VirtualService

With CSM running fleet-wide, VirtualServices can reference services across clusters via MCS:

```yaml
# vs-frontend-canary.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend
  namespace: bank-of-anthos
spec:
  hosts:
  - frontend
  http:
  - route:
    - destination:
        host: frontend
      weight: 100
    retries:
      attempts: 3
      perTryTimeout: 5s
      retryOn: "5xx,reset,connect-failure"
    timeout: 15s
```

```bash
kubectl --context=cluster-west apply -f vs-frontend-canary.yaml
kubectl --context=cluster-east apply -f vs-frontend-canary.yaml
```

### Step 8.2 — Managed Prometheus Across Clusters

```bash
# Query per-cluster CPU metrics
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"fetch k8s_container::kubernetes.io/container/cpu/limit_utilization | filter resource.namespace_name = '${APP_NAMESPACE}' | within 30m | group_by [resource.cluster_name, resource.container_name], mean(val())\"
  }" | jq '.timeSeriesData[] | {cluster: .labelValues[0].stringValue, container: .labelValues[1].stringValue, cpu: .pointData[-1].values[0].doubleValue}'
```

### Step 8.3 — GKE Gateway API CRDs

The module enables Gateway API CRDs on all clusters:

```bash
kubectl --context=cluster-west \
  get crds | grep -E "gateway|httproute|grpcroute"
```

### Step 8.4 — Cost Allocation Across Clusters

```bash
# View cost allocation by cluster and namespace labels
echo "https://console.cloud.google.com/billing?project=${PROJECT_ID}"
```

Navigate to **Billing** → **Reports** → group by `goog-k8s-cluster-name` label to see
per-cluster cost breakdown.

---

## 13. Cleanup

Return to the RAD UI and click **Undeploy** on the `MC_Bank_GKE` deployment. This removes
all clusters, VPC, Multi-Cluster Ingress, and Multi-Cluster Services resources.

> **Important:** The module's `mcs.tf` runs a cleanup provisioner to gracefully remove MCI
> and MCS resources before the load balancer deletion — this prevents orphaned Cloud resources.

### Manual Cleanup (if needed)

**gcloud:**
```bash
# Delete Fleet memberships for all clusters
gcloud container fleet memberships list \
  --project="${PROJECT_ID}" \
  --format="value(name)" \
  | xargs -I{} gcloud container fleet memberships delete {} \
    --project="${PROJECT_ID}" --quiet

# Delete GKE clusters
gcloud container clusters list \
  --project="${PROJECT_ID}" \
  --format="csv[no-heading](name,location)" \
  | while IFS=, read name location; do
    gcloud container clusters delete "${name}" \
      --region "${location}" \
      --project "${PROJECT_ID}" \
      --quiet
  done

# Release global static IP
gcloud compute addresses list \
  --filter="name~bank" --global \
  --project="${PROJECT_ID}" \
  --format="value(name)" \
  | xargs -I{} gcloud compute addresses delete {} \
    --global --project "${PROJECT_ID}" --quiet
```

**REST API — delete Fleet membership:**
```bash
for CLUSTER in gke-cluster-0 gke-cluster-1; do
  curl -s -X DELETE \
    "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER}" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"
done
```

**Clean up kubectl contexts:**
```bash
kubectl config delete-context cluster-west
kubectl config delete-context cluster-east
```

---

## 14. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `available_regions` | list(string) | `["us-west1", "us-east1"]` | Regions for cluster placement |
| `cluster_size` | number | `2` | Number of GKE clusters to create |
| `create_autopilot_cluster` | bool | `true` | Use GKE Autopilot for each cluster |
| `release_channel` | string | `REGULAR` | GKE release channel |
| `enable_cloud_service_mesh` | bool | `true` | Enable Fleet-wide managed Istio |
| `deploy_application` | bool | `true` | Deploy Bank of Anthos on all clusters |
| `create_network` | bool | `true` | Create shared VPC network |

### Fleet Features Activated

| Feature | API | Purpose |
|---|---|---|
| `servicemesh` | `gkehub.googleapis.com` | Fleet-wide Cloud Service Mesh |
| `multiclusteringress` | `gkehub.googleapis.com` | Global L7 load balancing |
| `multiclusterservices` | `gkehub.googleapis.com` | Cross-cluster DNS service discovery |

### GCP APIs Enabled

| API | Purpose |
|---|---|
| `container.googleapis.com` | GKE cluster management |
| `mesh.googleapis.com` | Cloud Service Mesh |
| `gkehub.googleapis.com` | Fleet Hub |
| `multiclusteringress.googleapis.com` | Multi-Cluster Ingress |
| `multiclusterservices.googleapis.com` | Multi-Cluster Services |
| `monitoring.googleapis.com` | Cloud Monitoring |
| `logging.googleapis.com` | Cloud Logging |
| `cloudtrace.googleapis.com` | Cloud Trace |

### Useful Commands Reference

```bash
# List fleet memberships
gcloud container fleet memberships list --project="${PROJECT_ID}"

# Fleet mesh status
gcloud container fleet mesh describe --project="${PROJECT_ID}"

# Get-credentials for each cluster
gcloud container clusters get-credentials <cluster-name> --region <region> --project="${PROJECT_ID}"

# Cross-cluster pod comparison
kubectl --context=cluster-west get pods -n bank-of-anthos
kubectl --context=cluster-east get pods -n bank-of-anthos

# Cross-cluster top pods
kubectl --context=cluster-west top pods -n bank-of-anthos
kubectl --context=cluster-east top pods -n bank-of-anthos

# Fleet ingress describe
gcloud container fleet ingress describe --project="${PROJECT_ID}"
```

### Further Reading

- [Multi-Cluster Ingress overview](https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-ingress)
- [Multi-Cluster Services overview](https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-services)
- [GKE Fleet overview](https://cloud.google.com/kubernetes-engine/docs/fleets-overview)
- [Cloud Service Mesh multi-cluster](https://cloud.google.com/service-mesh/docs/configure-managed-anthos-service-mesh-multicluster)
- [Bank of Anthos GitHub repository](https://github.com/GoogleCloudPlatform/bank-of-anthos)
- [Active-active geo-redundancy patterns](https://cloud.google.com/architecture/disaster-recovery/building-blocks-design-patterns)
