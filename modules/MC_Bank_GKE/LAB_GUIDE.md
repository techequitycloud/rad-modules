# Multi-Cluster Bank of Anthos on GKE — Lab Guide

## Overview

This guide walks through the full Multi-Cluster Bank of Anthos on GKE lab using
the `MC_Bank_GKE` Terraform module. The module fully automates infrastructure
provisioning: GKE clusters, Fleet registration, Cloud Service Mesh, Multi-Cluster
Ingress, and the Bank of Anthos application itself. All exploration, verification,
and advanced feature exercises are performed manually after the automated deploy
completes.

**Estimated time:** 1.5–2 hours (includes ~45–60 minutes of background provisioning)

### Application: Bank of Anthos

Bank of Anthos is a sample multi-tier banking application demonstrating how to
build, deploy, and operate microservices on Google Kubernetes Engine. It consists
of ten loosely-coupled services communicating via gRPC and REST, backed by two
PostgreSQL databases:

| Service | Language | Role |
|---|---|---|
| `frontend` | Python | Single-page web UI; serves HTTP on port 8080 |
| `userservice` | Python | Handles user creation and JWT authentication |
| `contacts` | Python | Manages the user's contact list |
| `transactionhistory` | Java | Returns paginated transaction history |
| `balancereader` | Java | Returns current account balance |
| `ledgerwriter` | Java | Records new transactions in the ledger |
| `loadgenerator` | Python/Locust | Simulates user traffic against the frontend |
| `accounts-db` | PostgreSQL | Stores user accounts and contacts (**primary cluster only**) |
| `ledger-db` | PostgreSQL | Stores transaction ledger entries (**primary cluster only**) |

The databases are deployed exclusively to the **primary cluster** (cluster 1).
All other clusters connect to those databases via **Multi-Cluster Services (MCS)**,
allowing every cluster to serve live, consistent data without a replicated database
per cluster.

### What Terraform Automates

- Enabling ~30 required GCP APIs
- Creating the shared VPC, per-cluster subnets, Cloud Routers, and Cloud NAT gateways
- Reserving a global static IP for the load balancer
- Creating firewall rules (SSH, internal, GKE masters, health checks, webhooks)
- Creating GKE clusters (Autopilot or Standard) in up to four regions
- Registering all clusters to a GKE Fleet (Hub memberships)
- Enabling and configuring Cloud Service Mesh (Google-managed Istio) on every cluster
- Deploying Bank of Anthos v0.6.7 to all clusters
- Enabling the Multi-Cluster Ingress Fleet feature
- Applying the `MultiClusterIngress` and `MultiClusterService` CRDs to the config cluster

### What You Do Manually

- Retrieving cluster credentials and verifying the deployment
- Exploring the GKE Fleet dashboard and membership details
- Exploring Cloud Service Mesh topology, traffic metrics, and mTLS policies
- Accessing the Bank of Anthos web application
- Inspecting Multi-Cluster Ingress routing and the global load balancer
- Testing cross-cluster traffic and resilience
- Exploring Cloud Monitoring, Logging, and GKE Security Posture

---

## CLI and REST API Overview

Every action in this lab can be performed via either the `gcloud`/`kubectl` CLI or
the GCP REST APIs directly. API equivalents are shown after each relevant step.

**Key API base URLs:**

| Service | Base URL |
|---|---|
| GKE Fleet (Hub) | `https://gkehub.googleapis.com/v1` |
| GKE Container | `https://container.googleapis.com/v1` |
| Compute Engine | `https://compute.googleapis.com/compute/v1` |
| Kubernetes API | `https://<CLUSTER_ENDPOINT>/apis` |

**Set these shell variables once before running any API command:**

```bash
export TOKEN=$(gcloud auth print-access-token)
export PROJECT="your-project-id"
export REGION1="us-west1"
export REGION2="us-east1"
export CLUSTER1="gke-cluster-1"
export CLUSTER2="gke-cluster-2"
export NAMESPACE="bank-of-anthos"
export FLEET_BASE="https://gkehub.googleapis.com/v1/projects/${PROJECT}/locations/global"
export GKE_BASE="https://container.googleapis.com/v1/projects/${PROJECT}/locations"
export COMPUTE_BASE="https://compute.googleapis.com/compute/v1/projects/${PROJECT}"
```

**Refresh the token when it expires (tokens are valid for ~1 hour):**

```bash
export TOKEN=$(gcloud auth print-access-token)
```

**All mutating GCP operations return a long-running Operation. Poll for completion:**

```bash
curl -s "https://container.googleapis.com/v1/projects/${PROJECT}/locations/${REGION1}/operations/OPERATION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.status, .error'
```

`status: "DONE"` with no `error` means the operation succeeded.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated, with `kubectl` component installed (`gcloud components install kubectl`) |
| GCP Project | Must already exist with billing enabled |
| Terraform provisioning service account | Must hold `roles/owner` on the target project |
| Caller permissions | The identity running `tofu apply` must hold `roles/iam.serviceAccountTokenCreator` on the provisioning service account |
| Available quota | 2× GKE clusters (Autopilot or Standard), 1 global static IP, regional CPU quota for node pools |

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/MC_Bank_GKE
```

Create a `terraform.tfvars` file. All values shown are module defaults — override
only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `existing_project_id` | *(required — no default)* | GCP project ID where all resources are created |
| `available_regions` | `["us-west1", "us-east1"]` | Regions for cluster assignment, cycled round-robin |
| `cluster_size` | `2` | Number of GKE clusters (2–4). Minimum 2 for meaningful multi-cluster demo |
| `create_autopilot_cluster` | `true` | `true` = Autopilot (fully managed nodes); `false` = Standard (manual node pools) |
| `release_channel` | `REGULAR` | GKE upgrade channel: `RAPID`, `REGULAR`, `STABLE`, or `NONE` |
| `create_network` | `true` | Creates a new shared VPC; set `false` to use an existing network |
| `network_name` | `vpc-network` | Name of the VPC (created or existing) |
| `subnet_name` | `vpc-subnet` | Base name for per-cluster subnets (`vpc-subnet-cluster1`, etc.) |
| `enable_cloud_service_mesh` | `true` | Installs Google-managed Cloud Service Mesh on all clusters |
| `cloud_service_mesh_version` | `1.23.4-asm.1` | ASM version. Must be compatible with the selected GKE release channel |
| `deploy_application` | `true` | Deploys Bank of Anthos v0.6.7 to all clusters after they are ready |
| `enable_services` | `true` | Enables required GCP APIs. Set `false` if APIs are already enabled |
| `resource_creator_identity` | *(platform default)* | Terraform service account email |
| `trusted_users` | `[]` | List of Google user emails granted `cluster-admin` on all clusters |
| `deployment_id` | *(auto-generated)* | Short suffix for unique resource naming; leave blank for auto |

Minimum `terraform.tfvars` example:

```hcl
existing_project_id = "your-project-id"
```

Full example with two clusters in separate regions:

```hcl
existing_project_id       = "your-project-id"
available_regions         = ["us-west1", "us-east1"]
cluster_size              = 2
create_autopilot_cluster  = true
release_channel           = "REGULAR"
enable_cloud_service_mesh = true
deploy_application        = true
```

### Step 1.2 — Initialise and Deploy

```bash
tofu init
tofu validate
tofu plan -out=plan.tfplan
tofu apply plan.tfplan
```

**Expected duration:**

| Resource | Typical time |
|---|---|
| API enablement | 2–3 minutes |
| VPC, subnets, Cloud Router, NAT | 2–3 minutes |
| GKE Autopilot clusters (×2) | 5–10 minutes |
| Fleet membership registration | 3–5 minutes per cluster |
| Cloud Service Mesh enablement | 10–15 minutes |
| Bank of Anthos deployment | 10–15 minutes |
| Multi-Cluster Ingress provisioning | 10–15 minutes (GLB setup continues after apply) |
| **Total** | **45–60 minutes** |

> The `tofu apply` returns once all resources are created. The Global Load
> Balancer provisioned by Multi-Cluster Ingress may take an additional
> 10–15 minutes to become healthy after apply completes.

### Step 1.3 — Record Terraform Outputs

When `apply` completes, note the project ID:

```bash
tofu output
```

The key information you need for the rest of the lab:

| Output | Used in |
|---|---|
| `project_id` | All `gcloud` and `kubectl` commands |
| `deployment_id` | Reference for resource names |

The cluster names, regions, and namespace are fixed by the module:

| Resource | Name |
|---|---|
| Primary cluster | `gke-cluster-1` in `us-west1` (default) |
| Secondary cluster | `gke-cluster-2` in `us-east1` (default) |
| Application namespace | `bank-of-anthos` |
| Global IP address name | `bank-of-anthos` |

---

## Phase 2 — Verify Cluster Setup and Access [MANUAL]

### Step 2.1 — Get Cluster Credentials

Set your project variable and retrieve credentials for both clusters:

```bash
export PROJECT=$(tofu output -raw project_id)
export CTX1="gke_${PROJECT}_${REGION1}_${CLUSTER1}"
export CTX2="gke_${PROJECT}_${REGION2}_${CLUSTER2}"

gcloud container clusters get-credentials $CLUSTER1 --region $REGION1 --project $PROJECT
gcloud container clusters get-credentials $CLUSTER2 --region $REGION2 --project $PROJECT
```

Confirm both contexts are available:

```bash
kubectl config get-contexts
```

**Expected result:** Both `gke_<project>_us-west1_gke-cluster-1` and
`gke_<project>_us-east1_gke-cluster-2` are listed.

> **REST API equivalent — list clusters:**
> ```bash
> # List all clusters in both regions
> for REGION in $REGION1 $REGION2; do
>   curl -s "${GKE_BASE}/${REGION}/clusters" \
>     -H "Authorization: Bearer $TOKEN" \
>     | jq '.clusters[] | {name, status, location}'
> done
> ```
> `status: "RUNNING"` confirms the cluster is operational.

### Step 2.2 — Verify Cluster Nodes

For an Autopilot cluster, nodes are provisioned on demand — they appear as
workloads are scheduled. For a Standard cluster, two spot `e2-standard-2` nodes
per cluster are pre-created:

```bash
# Cluster 1
kubectl get nodes --context=$CTX1 -o wide

# Cluster 2
kubectl get nodes --context=$CTX2 -o wide
```

```bash
# gcloud equivalent — describe node pool for Standard clusters
gcloud container node-pools list \
  --cluster=$CLUSTER1 \
  --region=$REGION1 \
  --project=$PROJECT
```

**Expected result (Autopilot):** Nodes appear after pods are scheduled; the
cluster itself is visible and healthy. **Expected result (Standard):** Two nodes
per cluster in `Ready` state across multiple zones.

> **REST API equivalent — list node pools:**
> ```bash
> curl -s "${GKE_BASE}/${REGION1}/clusters/${CLUSTER1}/nodePools" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.nodePools[] | {name, status, initialNodeCount}'
> ```

### Step 2.3 — Verify Application Pods

```bash
# Check pods on the primary cluster (includes databases)
kubectl get pods -n $NAMESPACE --context=$CTX1 -o wide

# Check pods on the secondary cluster (no database pods)
kubectl get pods -n $NAMESPACE --context=$CTX2 -o wide
```

**Expected result:** All pods in `Running` state. Cluster 1 includes
`accounts-db-0` and `ledger-db-0` StatefulSets; cluster 2 does not — it
connects to those databases through Multi-Cluster Services.

```bash
# Confirm no database StatefulSets on cluster 2
kubectl get statefulsets -n $NAMESPACE --context=$CTX2
```

**Expected result:** `No resources found in bank-of-anthos namespace.`

### Step 2.4 — Verify Services

```bash
kubectl get services -n $NAMESPACE --context=$CTX1
```

```bash
# gcloud equivalent — list all workloads in the namespace
gcloud container clusters describe $CLUSTER1 \
  --region=$REGION1 \
  --project=$PROJECT \
  --format='value(name, status, currentNodeCount)'
```

**Expected result:** Services including `frontend`, `userservice`, `contacts`,
`transactionhistory`, `balancereader`, `ledgerwriter`, `accounts-db`, and
`ledger-db`. The `frontend` service is of type `ClusterIP` — external access
is through the Multi-Cluster Ingress global load balancer.

### Step 2.5 — Verify the Namespace ASM Label

Cloud Service Mesh uses the `istio.io/rev` label on the namespace to enable
automatic sidecar injection:

```bash
kubectl get namespace $NAMESPACE --context=$CTX1 \
  -o jsonpath='{.metadata.labels}' | jq .
```

**Expected result:**

```json
{
  "istio.io/rev": "asm-managed"
}
```

This label triggers injection of the Envoy sidecar proxy into every pod
scheduled in the namespace.

### Step 2.6 — Verify Sidecar Injection

Confirm that application pods have two containers — the application container
plus the injected Envoy sidecar (`istio-proxy`):

```bash
kubectl get pods -n $NAMESPACE --context=$CTX1 \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'
```

**Expected result:** Each pod row lists two containers — the application
container (e.g. `frontend`) and `istio-proxy`.

---

## Phase 3 — Explore GKE Fleet [MANUAL]

GKE Fleet (formerly Anthos) provides a unified control plane for managing multiple
clusters. The module registered all clusters with the Fleet and enabled the
Service Mesh and Multi-Cluster Ingress features.

### Step 3.1 — List Fleet Memberships

```bash
gcloud container fleet memberships list --project=$PROJECT
```

**Expected result:** Both `gke-cluster-1` and `gke-cluster-2` listed with
`state: READY`.

```bash
# Describe a specific membership
gcloud container fleet memberships describe gke-cluster-1 \
  --location=global --project=$PROJECT
```

> **REST API equivalent — list Fleet memberships:**
> ```bash
> curl -s "${FLEET_BASE}/memberships" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.resources[] | {name, state: .state.code}'
> ```
> `state.code: "READY"` confirms the cluster is successfully registered.

> **REST API equivalent — describe a membership:**
> ```bash
> curl -s "${FLEET_BASE}/memberships/gke-cluster-1" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '{name, state: .state.code, endpoint: .endpoint.gkeCluster.resourceLink}'
> ```

**Expected result:** Both memberships show `state.code: "READY"`.

### Step 3.2 — View Fleet Memberships in the Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Fleet**.
2. Click the **Clusters** tab.
3. Confirm both `gke-cluster-1` and `gke-cluster-2` are listed as registered
   members.
4. Click on `gke-cluster-1` to view its Fleet membership details, including
   the enabled features (Service Mesh, Multi-Cluster Ingress).

**Expected result:** Both clusters appear as Fleet members with a green
**Registered** status indicator.

### Step 3.3 — View Enabled Fleet Features

```bash
gcloud container fleet features list --project=$PROJECT
```

**Expected result:** The following features are listed as `ACTIVE`:

| Feature | Description |
|---|---|
| `servicemesh` | Cloud Service Mesh — mTLS, traffic management, observability |
| `multiclusteringress` | Multi-Cluster Ingress — global load balancing across clusters |
| `multiclusterservicediscovery` | Multi-Cluster Services — cross-cluster service discovery |

> **REST API equivalent — list Fleet features:**
> ```bash
> curl -s "${FLEET_BASE}/features" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.resources[] | {name, state: .state.state}'
> ```

### Step 3.4 — Inspect Service Mesh Feature State

```bash
gcloud container fleet mesh describe --project=$PROJECT
```

> **REST API equivalent — describe the Service Mesh feature:**
> ```bash
> curl -s "${FLEET_BASE}/features/servicemesh" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.membershipStates | to_entries[] | {
>       cluster: .key,
>       controlPlane: .value.servicemesh.controlPlaneManagement.state,
>       dataPlane: .value.servicemesh.dataPlaneManagement.state
>     }'
> ```

**Expected result:** `membershipStates` entries for each cluster showing
`controlPlaneManagement.state: "ACTIVE"` or `"PROVISIONED"`, confirming that
the managed control plane is running on each cluster.

### Step 3.5 — View Fleet Features in the Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Fleet**.
2. Click the **Features** tab.
3. Review the enabled features: **Service Mesh**, **Multi-cluster Ingress**,
   and **Multi-cluster Services Discovery**.
4. Click **Service Mesh** to open the Anthos Service Mesh dashboard.

**Expected result:** All three features show as enabled with no error
indicators.

---

## Phase 4 — Explore Cloud Service Mesh [MANUAL]

Cloud Service Mesh (ASM) is Google-managed Istio deployed across all clusters.
It provides mTLS encryption between every service, cross-cluster traffic
management, and unified observability through the ASM dashboard.

### Step 4.1 — Open the ASM Dashboard

1. In the Google Cloud console, navigate to **Kubernetes Engine > Service Mesh**.
2. Click the **Services** tab.
3. You will see all Bank of Anthos services listed from both clusters.

**Expected result:** All microservices appear in the topology view with
active traffic flowing between them. The load generator continuously sends
synthetic traffic, so metrics are populated immediately.

### Step 4.2 — Explore the Service Topology

1. In the Service Mesh dashboard, click **Topology**.
2. The topology graph shows all services as nodes with directed edges
   representing active traffic flows.
3. Click on the `frontend` service node to see its inbound and outbound
   connections.

**Expected result:** The topology shows `frontend` receiving external traffic
from the ingress gateway and calling `userservice`, `contacts`,
`transactionhistory`, `balancereader`, and `ledgerwriter`.

### Step 4.3 — Inspect Service SLOs and Traffic Metrics

1. In the Service Mesh dashboard, click **Services**.
2. Click on `frontend` to open its detail page.
3. Review the **Traffic** section — request rate, error rate, and latency (P50, P95, P99).
4. Click the **Health** tab to review the SLO configuration.

**Expected result:** The frontend service shows continuous traffic from the
load generator with a low error rate and latency in the low-millisecond range.

### Step 4.4 — Verify mTLS Policy

ASM enforces mutual TLS (mTLS) for all service-to-service communication. Verify
the mesh-wide mTLS policy:

```bash
# Check for PeerAuthentication policies in the application namespace
kubectl get peerauthentication -n $NAMESPACE --context=$CTX1

# Check for mesh-level PeerAuthentication in istio-system
kubectl get peerauthentication -n istio-system --context=$CTX1 -o yaml
```

```bash
# gcloud equivalent — check ASM mesh status
gcloud container fleet mesh describe --project=$PROJECT \
  --format='json' | jq '.membershipStates | to_entries[] | 
  {cluster: .key, state: .value.servicemesh.controlPlaneManagement.state}'
```

**Expected result:** mTLS is enforced in `STRICT` or `PERMISSIVE` mode
(managed automatically by ASM). All inter-service traffic in the mesh is
encrypted with mutual TLS certificates that rotate automatically.

### Step 4.5 — View Distributed Traces

1. In the Google Cloud console, navigate to **Trace > Trace List**.
2. In the **Service** filter, select `frontend`.
3. Click on any trace to view the full end-to-end request chain through the
   microservices.

```bash
# gcloud equivalent — list recent traces for the frontend service
gcloud trace traces list \
  --project=$PROJECT \
  --filter="rootSpans.name:frontend" \
  --limit=5
```

**Expected result:** A distributed trace shows a single user request flowing
from `frontend` through `balancereader`, `transactionhistory`, and other
downstream services, with latency attributed to each hop.

### Step 4.6 — Confirm Managed Control Plane

With Google-managed ASM, the Istiod control plane runs in Google's
infrastructure — not as pods in your cluster. Verify this:

```bash
# There is no istiod deployment in the cluster (it's managed externally)
kubectl get deployment -n istio-system --context=$CTX1

# The ASM ConfigMap configures the managed channel
kubectl get configmap -n istio-system --context=$CTX1
```

```bash
# gcloud equivalent — view ASM management configuration
gcloud container fleet mesh describe --project=$PROJECT \
  --format='json' | jq '.membershipStates[].servicemesh'
```

**Expected result:** No `istiod` Deployment exists. The `asm-options`
ConfigMap configures the managed channel. The control plane SLA, upgrades,
and scaling are handled by Google.

---

## Phase 5 — Explore the Bank of Anthos Application [MANUAL]

### Step 5.1 — Get the Application URL

The application is exposed via Multi-Cluster Ingress. Retrieve the global
IP address assigned by the load balancer:

```bash
# Get the reserved global IP address
gcloud compute addresses describe bank-of-anthos \
  --global --project=$PROJECT --format='value(address)'
```

```bash
# Alternatively, get the VIP from the MultiClusterIngress resource
kubectl get multiclusteringress bank-of-anthos-mci \
  -n $NAMESPACE --context=$CTX1 \
  -o jsonpath='{.status.VIP}{"\n"}'
```

> **REST API equivalent — get the global static IP address:**
> ```bash
> curl -s "${COMPUTE_BASE}/global/addresses/bank-of-anthos" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '{name, address, status}'
> ```
> `status: "IN_USE"` confirms the address is assigned to the load balancer.

**Expected result:** A public IP address in the format `X.X.X.X`. Note: the
MultiClusterIngress `status.VIP` field is populated once the Google Cloud Load
Balancer finishes provisioning — this may take 10–15 minutes after `tofu apply`
completes.

### Step 5.2 — Access the Application in a Browser

1. Open a browser and navigate to `http://<VIP>` using the IP from Step 5.1.
2. The Bank of Anthos login page loads.

> **Note:** If the load balancer is still provisioning, you may see a 404 or
> connection refused error. Wait a few minutes and retry. You can check the
> backend health in the console at **Network Services > Load Balancing**.

**Expected result:** The Bank of Anthos web application loads showing a login
form with a **Sign In** and **Sign Up** option.

### Step 5.3 — Create a User Account

1. Click **Sign Up** on the login page.
2. Fill in the registration form:
   - **First Name:** Test
   - **Last Name:** User
   - **Username:** `testuser`
   - **Password:** `password123`
   - **Password Confirmation:** `password123`
   - **Account Currency:** USD
3. Click **Create Account**.
4. You are automatically logged in and the account dashboard is displayed.

**Expected result:** The dashboard shows a new account with an initial
balance pre-loaded from the database seed data.

### Step 5.4 — Explore the Application Features

1. **View transaction history:** Click on the account balance to see the
   paginated transaction list served by the `transactionhistory` service.
2. **Send a payment:**
   - Click **Send Payment**.
   - In the **To Account** field, enter account number `1011226111`.
   - Enter an amount (e.g. `10.00`).
   - Click **Send Payment**.
   - Confirm the updated balance is reflected immediately — this demonstrates
     the `ledgerwriter` service writing a new transaction and `balancereader`
     returning the updated balance.
3. **View contacts:** Click **Contacts** to see the pre-seeded contact list,
   served by the `contacts` service.

**Expected result:** All application features work end-to-end, with data
persisted in the `accounts-db` and `ledger-db` databases on the primary cluster
and read by services running on either cluster.

### Step 5.5 — Identify Which Cluster Served the Request

The Multi-Cluster Ingress routes each request to the nearest healthy backend.
Monitor the frontend logs on both clusters to see which one is serving your
browser traffic:

```bash
# Watch frontend logs on cluster 1
kubectl logs -n $NAMESPACE --context=$CTX1 \
  -l app=frontend --tail=10 -f &

# Watch frontend logs on cluster 2
kubectl logs -n $NAMESPACE --context=$CTX2 \
  -l app=frontend --tail=10 -f
```

**Expected result:** Both clusters show incoming requests from the load
generator. If you are geographically closer to `us-west1`, most browser
requests are routed to cluster 1; users closer to `us-east1` are routed
to cluster 2.

---

## Phase 6 — Explore Multi-Cluster Ingress [MANUAL]

Multi-Cluster Ingress (MCI) provides a single, Google-managed global load
balancer VIP that routes HTTP traffic to backend pods across all registered
clusters. It is implemented through two custom resource definitions:
`MultiClusterIngress` and `MultiClusterService`.

### Step 6.1 — Inspect the MultiClusterIngress Resource

MCI resources are applied to the **config cluster** (cluster 1) only. The Fleet
controller reads them and provisions the underlying Google Cloud load balancer:

```bash
kubectl get multiclusteringress -n $NAMESPACE --context=$CTX1 -o yaml
```

```bash
# gcloud equivalent — list all MCI resources in the Fleet
gcloud container fleet ingress describe --project=$PROJECT
```

> **REST API equivalent — describe the Multi-Cluster Ingress Fleet feature:**
> ```bash
> curl -s "${FLEET_BASE}/features/multiclusteringress" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '{state: .state.state, configMembership: .spec.multiclusteringress.configMembership}'
> ```

**Expected result:**

```yaml
apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: bank-of-anthos-mci
  namespace: bank-of-anthos
spec:
  template:
    spec:
      backend:
        serviceName: bank-of-anthos-mcs
        servicePort: 80
status:
  VIP: "X.X.X.X"
```

### Step 6.2 — Inspect the MultiClusterService Resource

The `MultiClusterService` defines which clusters contribute backend pods to
the load balancer:

```bash
kubectl get multiclusterservice -n $NAMESPACE --context=$CTX1 -o yaml
```

**Expected result:** The `spec.clusters` field lists both cluster links
(`us-west1/gke-cluster-1` and `us-east1/gke-cluster-2`). The service
selector targets pods with `app: frontend` on port 8080.

### Step 6.3 — Inspect the Derived NodePort Services

MCI creates a **derived service** in each member cluster — a `NodePort` service
that connects the frontend pods to the load balancer backends:

```bash
# Cluster 1
kubectl get service frontend-nodeport \
  -n $NAMESPACE --context=$CTX1 -o yaml

# Cluster 2
kubectl get service frontend-nodeport \
  -n $NAMESPACE --context=$CTX2 -o yaml
```

**Expected result:** A `NodePort` service named `frontend-nodeport` exists on
each cluster, created automatically by the MCI controller.

### Step 6.4 — View the Global Load Balancer in the Console

1. In the Google Cloud console, navigate to **Network Services > Load Balancing**.
2. Click on the load balancer with the `mci-` prefix to open its details.
3. Click the **Backend Services** tab to see the two backend services — one for
   each cluster.
4. Check the **Health** column — both backends should show healthy instances.

```bash
# gcloud equivalent — list global backend services
gcloud compute backend-services list \
  --global \
  --project=$PROJECT \
  --filter="name~^mci-"
```

> **REST API equivalent — list global backend services:**
> ```bash
> curl -s "${COMPUTE_BASE}/global/backendServices" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.items[] | select(.name | startswith("mci-")) | 
>   {name, loadBalancingScheme, protocol}'
> ```

**Expected result:** Two backend services (one per cluster) are shown,
each with at least one healthy instance. The global anycast VIP routes
traffic to the geographically nearest healthy backend.

### Step 6.5 — View the BackendConfig

The `BackendConfig` custom resource configures health check parameters for
the load balancer backend:

```bash
kubectl get backendconfig bank-of-anthos \
  -n $NAMESPACE --context=$CTX1 -o yaml
```

```bash
# gcloud equivalent — list health checks associated with the load balancer
gcloud compute health-checks list \
  --project=$PROJECT \
  --filter="name~^mci-"
```

> **REST API equivalent — list global health checks:**
> ```bash
> curl -s "${COMPUTE_BASE}/global/healthChecks" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.items[] | select(.name | startswith("mci-")) |
>   {name, type, checkIntervalSec, timeoutSec}'
> ```

**Expected result:** The BackendConfig specifies an HTTP health check against
path `/` with a 2-second interval, 1-second timeout, and a threshold of 10
consecutive failures before marking unhealthy.

### Step 6.6 — Understand the Multi-Cluster Architecture

The diagram below summarises how traffic reaches the application:

```
Client Request
      │
      ▼
Global Anycast VIP (Cloud Load Balancer)
      │
      ├── Backend: gke-cluster-1 (us-west1) → frontend pods
      │                │
      │                └── accounts-db, ledger-db (via ClusterIP)
      │
      └── Backend: gke-cluster-2 (us-east1) → frontend pods
                       │
                       └── accounts-db, ledger-db (via MCS cross-cluster)
```

Services on cluster 2 that need to reach the databases (on cluster 1) do so
via the Multi-Cluster Service discovery mechanism — the service FQDN
resolves to the remote cluster's pods transparently.

---

## Phase 7 — Test Resilience and Traffic Failover [MANUAL]

### Step 7.1 — Observe Load Generator Traffic

Both clusters run a `loadgenerator` pod that generates synthetic traffic.
This ensures that MCI backend health checks pass on both clusters:

```bash
# View load generator logs on cluster 1
kubectl logs -n $NAMESPACE --context=$CTX1 \
  -l app=loadgenerator --tail=20
```

**Expected result:** Continuous log output showing HTTP requests to the
frontend at `http://frontend:80` with 200 status responses.

### Step 7.2 — Simulate Pod Failure on Cluster 1

Scale the `frontend` deployment to zero on cluster 1, simulating a cluster
or application failure:

```bash
kubectl scale deployment frontend --replicas=0 \
  -n $NAMESPACE --context=$CTX1

# Confirm no frontend pods remain
kubectl get pods -n $NAMESPACE --context=$CTX1 -l app=frontend
```

Wait 30–60 seconds for the health check threshold (10 consecutive failures)
to be reached and for the load balancer to update backend health status.

> **REST API equivalent — check backend health:**
> ```bash
> # List backend services and get their health
> BACKEND=$(curl -s "${COMPUTE_BASE}/global/backendServices" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq -r '.items[] | select(.name | startswith("mci-")) | .name' | head -1)
>
> curl -s -X POST "${COMPUTE_BASE}/global/backendServices/${BACKEND}/getHealth" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{}' | jq '.healthStatus'
> ```

### Step 7.3 — Verify Traffic Failover to Cluster 2

After the health check threshold is reached, the load balancer stops routing
traffic to cluster 1:

```bash
# Check frontend pods still running on cluster 2
kubectl get pods -n $NAMESPACE --context=$CTX2 -l app=frontend
```

1. In a browser, navigate to `http://<VIP>` and confirm the application
   still loads — all traffic is now being served by cluster 2.
2. In the console at **Network Services > Load Balancing**, observe that
   the cluster 1 backend now shows 0 healthy instances.

**Expected result:** The application remains available. The global
load balancer automatically redirects traffic to cluster 2 when cluster 1's
backend becomes unhealthy.

### Step 7.4 — Restore Cluster 1

Scale the frontend back up:

```bash
kubectl scale deployment frontend --replicas=1 \
  -n $NAMESPACE --context=$CTX1

# Watch the pod come back up
kubectl get pods -n $NAMESPACE --context=$CTX1 -l app=frontend -w
```

**Expected result:** The frontend pod on cluster 1 returns to `Running` and
the load balancer resumes sending traffic to both backends within 30–60
seconds as health checks begin passing.

### Step 7.5 — Verify Cross-Cluster Database Connectivity

Confirm that the frontend on cluster 2 can successfully read data from the
databases running on cluster 1:

```bash
# Check service endpoints on cluster 2 — DB endpoints resolve cross-cluster
kubectl get endpoints -n $NAMESPACE --context=$CTX2 | grep -E "accounts-db|ledger-db"
```

**Expected result:** Endpoint entries are populated for `accounts-db` and
`ledger-db`, resolving to the pods on cluster 1 via the MCS mechanism.
If you log in to the application (served by cluster 2) and transactions are
visible, cross-cluster connectivity is working correctly.

---

## Phase 8 — Observability and Security [MANUAL]

### Step 8.1 — Explore Cloud Monitoring

1. In the Google Cloud console, navigate to **Monitoring > Dashboards**.
2. Find and open the **GKE** or **Kubernetes** pre-built dashboard.
3. Filter by cluster name (`gke-cluster-1` or `gke-cluster-2`).
4. Review CPU utilisation, memory usage, and network throughput for the
   Bank of Anthos pods.

```bash
# gcloud equivalent — list monitoring dashboards
gcloud monitoring dashboards list --project=$PROJECT
```

> **REST API equivalent — list Monitoring dashboards:**
> ```bash
> curl -s "https://monitoring.googleapis.com/v1/projects/${PROJECT}/dashboards" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.dashboards[] | {name: .displayName}'
> ```

**Expected result:** Metrics are collected automatically from both GKE system
components and the Envoy sidecar proxies injected by ASM.

### Step 8.2 — Create a Metrics Explorer Query

1. In the Google Cloud console, navigate to **Monitoring > Metrics Explorer**.
2. Under **Select a metric**, search for `kubernetes.io/container/cpu/request_utilization`.
3. Filter by **namespace_name = bank-of-anthos**.
4. Group by **container_name** to see per-service CPU metrics.

```bash
# gcloud equivalent — query time series data
gcloud monitoring time-series list \
  --project=$PROJECT \
  --filter='metric.type="kubernetes.io/container/cpu/request_utilization" AND resource.labels.namespace_name="bank-of-anthos"' \
  --interval-start-time="$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --interval-end-time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**Expected result:** A time-series chart shows CPU utilization for each Bank
of Anthos microservice, with the `loadgenerator` driving steady traffic.

### Step 8.3 — Explore Cloud Logging

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query editor, enter:

```
resource.type="k8s_container"
resource.labels.namespace_name="bank-of-anthos"
resource.labels.cluster_name="gke-cluster-1"
```

3. Press **Run Query**.
4. Expand a log entry from the `frontend` container to see structured log
   output.

```bash
# gcloud equivalent — tail logs from the frontend container
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.namespace_name="bank-of-anthos" AND resource.labels.container_name="frontend"' \
  --project=$PROJECT \
  --limit=20 \
  --format='value(textPayload)'
```

> **REST API equivalent — list log entries:**
> ```bash
> curl -s -X POST "https://logging.googleapis.com/v2/entries:list" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d "{
>     \"resourceNames\": [\"projects/${PROJECT}\"],
>     \"filter\": \"resource.type=k8s_container resource.labels.namespace_name=bank-of-anthos\",
>     \"orderBy\": \"timestamp desc\",
>     \"pageSize\": 10
>   }" | jq '.entries[] | {timestamp, message: .textPayload}'
> ```

**Expected result:** Application logs from all Bank of Anthos services are
streamed to Cloud Logging automatically with structured fields.

### Step 8.4 — Explore GKE Security Posture

The clusters are configured with `BASIC` security posture mode and
`VULNERABILITY_BASIC` vulnerability scanning enabled.

1. In the Google Cloud console, navigate to **Kubernetes Engine > Security**.
2. Click the **Concerns** tab to view active security findings.
3. Review workload configuration concerns such as containers not setting
   resource limits or containers running as root.

```bash
# gcloud equivalent — describe security posture configuration
gcloud container clusters describe $CLUSTER1 \
  --region=$REGION1 \
  --project=$PROJECT \
  --format='value(securityPostureConfig)'
```

> **REST API equivalent — get cluster security posture config:**
> ```bash
> curl -s "${GKE_BASE}/${REGION1}/clusters/${CLUSTER1}" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.securityPostureConfig'
> ```

**Expected result:** The cluster security posture configuration shows
`mode: BASIC` and `vulnerabilityMode: VULNERABILITY_BASIC`.

### Step 8.5 — Explore Security Command Center

1. In the Google Cloud console, navigate to **Security > Security Command Center**.
2. Click **Findings** and filter by **Resource type = k8s_cluster**.
3. Review findings related to the GKE clusters — such as public endpoint
   access or missing binary authorisation.

```bash
# gcloud equivalent — list Security Command Center findings
gcloud scc findings list \
  --project=$PROJECT \
  --filter="resource.type=\"google.container.Cluster\""
```

> **REST API equivalent — list SCC findings:**
> ```bash
> curl -s "https://securitycenter.googleapis.com/v1/projects/${PROJECT}/sources/-/findings" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.findings[] | {name, category, severity, state}'
> ```

**Expected result:** Security Command Center displays findings for the GKE
clusters, providing visibility into the security posture without additional
configuration.

### Step 8.6 — Review Audit Logs for Kubernetes Operations

Every `kubectl apply` and Fleet feature operation generates an entry in Cloud
Audit Logs:

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query editor, enter:

```
resource.type="k8s_cluster"
protoPayload.serviceName="container.googleapis.com"
protoPayload.methodName=~".*deployments.*"
```

3. Press **Run Query**.

```bash
# gcloud equivalent — read audit logs for Kubernetes deployments
gcloud logging read \
  'resource.type="k8s_cluster" protoPayload.serviceName="container.googleapis.com"' \
  --project=$PROJECT \
  --limit=10 \
  --format='table(timestamp, protoPayload.methodName, protoPayload.authenticationInfo.principalEmail)'
```

> **REST API equivalent — list audit log entries:**
> ```bash
> curl -s -X POST "https://logging.googleapis.com/v2/entries:list" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d "{
>     \"resourceNames\": [\"projects/${PROJECT}\"],
>     \"filter\": \"protoPayload.serviceName=container.googleapis.com logName=~cloudaudit\",
>     \"pageSize\": 10
>   }" | jq '.entries[] | {
>     timestamp,
>     method: .protoPayload.methodName,
>     caller: .protoPayload.authenticationInfo.principalEmail
>   }'
> ```

**Expected result:** Audit log entries are visible for Kubernetes resource
operations performed during the Terraform apply.

---

## Phase 9 — Advanced Features [MANUAL]

### Step 9.1 — Explore Workload Identity

The Standard cluster node pool service account (`gke-standard-sa`) is granted
minimum required IAM roles. Review the assigned roles:

```bash
gcloud projects get-iam-policy $PROJECT \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:gke-standard-sa@${PROJECT}.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

> **REST API equivalent — get IAM policy:**
> ```bash
> curl -s -X POST \
>   "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{}' | jq '.bindings[] | select(.members[] | contains("gke-standard-sa")) | .role'
> ```

**Expected result (Standard cluster):** Roles including
`roles/monitoring.metricWriter`, `roles/logging.logWriter`,
`roles/artifactregistry.reader`, and `roles/container.defaultNodeServiceAccount`
are listed — the minimum required set for GKE node operation.

### Step 9.2 — Explore Cost Management

GKE cost allocation is enabled on all clusters, allowing per-namespace and
per-label cost attribution in Cloud Billing:

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**.
2. Click on `gke-cluster-1` and scroll to the **Features** section.
3. Confirm **Cost management** is shown as enabled.

```bash
# gcloud equivalent — confirm cost management is enabled
gcloud container clusters describe $CLUSTER1 \
  --region=$REGION1 \
  --project=$PROJECT \
  --format='value(costManagementConfig)'
```

> **REST API equivalent — check cost management config:**
> ```bash
> curl -s "${GKE_BASE}/${REGION1}/clusters/${CLUSTER1}" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.costManagementConfig'
> ```

**Expected result:** `enabled: true` — cost allocation data is available in
Cloud Billing broken down by Kubernetes namespace and label.

### Step 9.3 — Explore Managed Prometheus

All clusters have Managed Prometheus enabled, allowing you to query application
metrics using PromQL without running your own Prometheus infrastructure:

1. In the Google Cloud console, navigate to **Monitoring > Managed Prometheus**.
2. Use the **Query** interface to run a PromQL query:

```promql
sum by (container) (rate(container_cpu_usage_seconds_total{namespace="bank-of-anthos"}[5m]))
```

```bash
# gcloud equivalent — confirm Managed Prometheus is enabled
gcloud container clusters describe $CLUSTER1 \
  --region=$REGION1 \
  --project=$PROJECT \
  --format='value(monitoringConfig)'
```

> **REST API equivalent — check monitoring config:**
> ```bash
> curl -s "${GKE_BASE}/${REGION1}/clusters/${CLUSTER1}" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.monitoringConfig | {enableComponents, managedPrometheusConfig}'
> ```

**Expected result:** CPU usage rate per container is returned in the PromQL
query. The monitoring config shows `managedPrometheusConfig.enabled: true`.

### Step 9.4 — Explore the Gateway API Configuration

The clusters are configured with the `CHANNEL_STANDARD` Gateway API channel:

```bash
kubectl get gatewayclasses --context=$CTX1
```

```bash
# gcloud equivalent — view Gateway API channel configuration
gcloud container clusters describe $CLUSTER1 \
  --region=$REGION1 \
  --project=$PROJECT \
  --format='value(networkConfig.gatewayApiConfig)'
```

> **REST API equivalent — check Gateway API config:**
> ```bash
> curl -s "${GKE_BASE}/${REGION1}/clusters/${CLUSTER1}" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.networkConfig.gatewayApiConfig'
> ```

**Expected result:** GatewayClass resources are listed including
`gke-l7-global-external-managed`. The API response shows
`channel: CHANNEL_STANDARD`.

### Step 9.5 — Scale the Deployment

Scale Bank of Anthos services independently on each cluster to demonstrate
Autopilot or Standard horizontal scaling:

```bash
# Scale frontend to 3 replicas on cluster 1
kubectl scale deployment frontend --replicas=3 \
  -n $NAMESPACE --context=$CTX1

# Watch pods come up
kubectl get pods -n $NAMESPACE --context=$CTX1 \
  -l app=frontend -w
```

**Expected result (Autopilot):** New nodes are provisioned within 2–3 minutes
and the frontend pods move to `Running`. **Expected result (Standard):**
Pods are scheduled on existing nodes if sufficient capacity is available.

### Step 9.6 — Add a Trusted User (cluster-admin)

Additional users can be granted `cluster-admin` access by updating the
`trusted_users` variable and re-running `tofu apply`:

```hcl
trusted_users = ["colleague@example.com"]
```

```bash
tofu apply
```

```bash
# Verify the ClusterRoleBinding was created
kubectl get clusterrolebindings --context=$CTX1 | grep trusted
```

**Expected result:** The specified user can run `kubectl` commands against
all clusters. A `ClusterRoleBinding` is created binding them to
`cluster-admin`.

### Step 9.7 — Deploy a Third Cluster

Increase the cluster count to 3 and add a third region to see round-robin
cluster assignment in action:

```hcl
cluster_size      = 3
available_regions = ["us-west1", "us-east1", "us-central1"]
```

```bash
tofu apply
```

```bash
# Verify the third cluster is Fleet-registered
gcloud container fleet memberships list --project=$PROJECT
```

> **REST API equivalent — verify new membership:**
> ```bash
> curl -s "${FLEET_BASE}/memberships/gke-cluster-3" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '{name, state: .state.code}'
> ```

**Expected result:** A third cluster (`gke-cluster-3`) is created in
`us-central1`, registered with the Fleet, ASM-enabled, and the Bank of
Anthos application deployed to it. The `MultiClusterService` is updated
to include the new cluster as a backend, and the global load balancer
gains a third regional backend pool.

---

## Phase 10 — Clean Up [AUTOMATED]

### Step 10.1 — Destroy All Resources

```bash
tofu destroy
```

The destroy sequence:

1. Removes MultiClusterIngress and MultiClusterService resources from all clusters
2. Disables the Multi-Cluster Ingress Fleet feature
3. Disables ASM on each cluster membership and at the Fleet level
4. Deletes GKE Hub memberships for all clusters
5. Deletes GKE clusters (including all node pools and workloads)
6. Deletes subnets, Cloud Routers, NAT gateways, and firewall rules
7. Deletes the VPC network
8. Releases the global static IP address

> **Note:** Terraform provisioners handle graceful cleanup of Fleet features
> and ASM before cluster deletion to avoid orphaned resources. The destroy
> may take 10–20 minutes.

**Expected result:** All resources are deleted. Only the GCP project itself
remains.

---

## Summary

The table below recaps every action in the lab, its phase, and whether it is
automated by the `MC_Bank_GKE` Terraform module or performed manually.

| Action | Phase | Automated |
|---|---|---|
| Enable ~30 GCP APIs | 1 | Yes — `main.tf` |
| Create shared VPC network | 1 | Yes — `network.tf` |
| Create per-cluster subnets | 1 | Yes — `network.tf` |
| Create Cloud Routers and NAT gateways | 1 | Yes — `network.tf` |
| Reserve global static IP | 1 | Yes — `glb.tf` |
| Create firewall rules (SSH, internal, health checks, webhooks) | 1 | Yes — `network.tf` |
| Create GKE clusters (Autopilot or Standard) | 1 | Yes — `gke.tf` |
| Create Standard node pools | 1 | Yes — `gke.tf` (Standard only) |
| Register clusters to GKE Fleet | 1 | Yes — `hub.tf` |
| Enable Cloud Service Mesh Fleet feature | 1 | Yes — `asm.tf` |
| Enable ASM managed control plane on each cluster | 1 | Yes — `hub.tf` |
| Download Bank of Anthos v0.6.7 release | 1 | Yes — `deploy.tf` |
| Create `bank-of-anthos` namespace with ASM injection label | 1 | Yes — `deploy.tf` |
| Deploy Bank of Anthos app (primary cluster — all services + DBs) | 1 | Yes — `deploy.tf` |
| Deploy Bank of Anthos app (non-primary clusters — no DBs) | 1 | Yes — `deploy.tf` |
| Enable Multi-Cluster Ingress Fleet feature | 1 | Yes — `deploy.tf` |
| Apply MultiClusterIngress and MultiClusterService CRDs | 1 | Yes — `deploy.tf` |
| Apply BackendConfig, FrontendConfig, NodePort service | 1 | Yes — `deploy.tf` |
| Get cluster credentials | 2 | No — `gcloud container clusters get-credentials` |
| Verify nodes | 2 | No — `kubectl get nodes` / `gcloud container node-pools list` |
| Verify pods and services | 2 | No — `kubectl get pods/services` |
| Confirm ASM sidecar injection label on namespace | 2 | No — `kubectl get namespace` |
| Verify sidecar (istio-proxy) injected into pods | 2 | No — `kubectl get pods` |
| List Fleet memberships | 3 | No — `gcloud container fleet memberships list` / REST API |
| View Fleet features (ASM, MCI, MCS) | 3 | No — `gcloud container fleet features list` / REST API |
| Inspect Service Mesh feature state | 3 | No — `gcloud container fleet mesh describe` / REST API |
| Open ASM dashboard in console | 4 | No — console navigation |
| Explore service topology | 4 | No — ASM console |
| Inspect traffic metrics (rate, error, latency) | 4 | No — ASM console |
| Verify mTLS policy | 4 | No — `kubectl get peerauthentication` |
| View distributed traces | 4 | No — Cloud Trace console / `gcloud trace` |
| Confirm no istiod deployment (managed control plane) | 4 | No — `kubectl get deployment` / REST API |
| Get application VIP | 5 | No — `gcloud compute addresses describe` / REST API |
| Access Bank of Anthos in browser | 5 | No — browser |
| Create user account and send payment | 5 | No — browser interaction |
| Observe which cluster serves requests via logs | 5 | No — `kubectl logs` |
| Inspect MultiClusterIngress resource | 6 | No — `kubectl get multiclusteringress` / REST API |
| Inspect MultiClusterService resource | 6 | No — `kubectl get multiclusterservice` |
| Inspect derived NodePort services on each cluster | 6 | No — `kubectl get service` |
| View global load balancer and backend health | 6 | No — console / `gcloud compute backend-services list` / REST API |
| View BackendConfig health check settings | 6 | No — `kubectl get backendconfig` / REST API |
| Scale frontend to zero on cluster 1 (simulate failure) | 7 | No — `kubectl scale` |
| Check backend health via REST API | 7 | No — REST API |
| Verify traffic failover to cluster 2 | 7 | No — browser + console |
| Restore cluster 1 frontend | 7 | No — `kubectl scale` |
| Verify cross-cluster DB connectivity via MCS | 7 | No — `kubectl get endpoints` |
| Explore Cloud Monitoring GKE dashboard | 8 | No — console navigation |
| Create Metrics Explorer query | 8 | No — `gcloud monitoring` / console |
| Query Cloud Logging for application logs | 8 | No — `gcloud logging read` / REST API |
| Explore GKE Security Posture findings | 8 | No — `gcloud container clusters describe` / REST API |
| Explore Security Command Center | 8 | No — `gcloud scc findings list` / REST API |
| Review Kubernetes audit logs | 8 | No — `gcloud logging read` / REST API |
| Review node pool IAM roles | 9 | No — `gcloud projects get-iam-policy` / REST API |
| Explore cost management | 9 | No — `gcloud container clusters describe` / REST API |
| Query Managed Prometheus with PromQL | 9 | No — Managed Prometheus UI / REST API |
| Inspect Gateway API GatewayClasses | 9 | No — `kubectl get gatewayclasses` / REST API |
| Scale frontend deployment to 3 replicas | 9 | No — `kubectl scale` |
| Add trusted user via `trusted_users` variable | 9 | No — `tofu apply` |
| Deploy third cluster via `cluster_size = 3` | 9 | No — `tofu apply` / REST API verification |
| Destroy all resources | 10 | Yes — `tofu destroy` |
