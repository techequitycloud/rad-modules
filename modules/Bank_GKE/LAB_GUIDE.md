# Bank of Anthos on GKE — Lab Guide

## Overview

This guide walks through the full Bank of Anthos on GKE lab using the
`Bank_GKE` Terraform module. The module automates the Google Cloud
infrastructure setup including the GKE cluster, Cloud Service Mesh, Fleet
registration, and application deployment. All exploration and configuration
tasks are performed manually after deployment.

**Estimated time:** 2–3 hours

### What Terraform Automates

- Enabling required GCP APIs (GKE, Mesh, Anthos, IAM, Artifact Registry, etc.)
- Creating the VPC network, subnet, and secondary IP ranges (pods and services)
- Configuring Cloud Router and NAT gateway for egress
- Creating VPC firewall rules (load balancer health checks, IAP SSH, intra-VPC, HTTP/HTTPS)
- Provisioning the GKE cluster (Autopilot or Standard) with Workload Identity,
  Managed Prometheus, Gateway API, and security posture scanning
- Creating a node pool and service account (Standard clusters only)
- Registering the cluster with GKE Fleet
- Installing and verifying Cloud Service Mesh (Google-managed Istio control plane)
- Creating Cloud Monitoring services and CPU-utilisation SLOs for all nine microservices
- Reserving a global static IP for the load balancer
- Deploying Bank of Anthos v0.6.7 (JWT secret + all Kubernetes manifests)

### What You Do Manually

- Fetching cluster credentials and verifying pod readiness
- Accessing the Bank of Anthos application in a browser
- Exploring the microservices topology in the Cloud Console
- Inspecting Cloud Service Mesh traffic flows and mTLS security
- Applying traffic management policies (VirtualServices, fault injection)
- Exploring Cloud Monitoring dashboards, Managed Prometheus, and SLOs
- Reviewing GKE security posture and vulnerability findings
- Exploring GKE Fleet membership and fleet-level feature status
- (Optional) Verifying Anthos Config Management GitOps sync behaviour
- Scaling workloads, triggering rolling updates, and reviewing audit logs

---

## gcloud / kubectl / REST API Overview

Every action in this lab can be performed via `gcloud`, `kubectl`, the GKE
REST API, or the Fleet Hub API as an alternative to the Cloud Console UI.
Equivalent commands are shown after each relevant step.

**Set these shell variables once before running any command:**

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export CLUSTER_NAME="gke-cluster"
export NAMESPACE="bank-of-anthos"
```

**Authenticate and fetch cluster credentials:**

```bash
gcloud container clusters get-credentials $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID
```

**GKE REST API base URL:** `https://container.googleapis.com/v1`

**Fleet Hub API base URL:** `https://gkehub.googleapis.com/v1`

**All REST API calls require a bearer token:**

```bash
export TOKEN=$(gcloud auth print-access-token)
```

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| GCP Project | Must already exist with billing enabled |
| Terraform resource provisioning Service Account | Must hold `roles/owner` on the target project |
| Caller permissions | The identity running `tofu apply` must hold `roles/iam.serviceAccountTokenCreator` on the service account above |
| `kubectl` | Installed and available in PATH |
| `curl` + `jq` | For REST API examples |

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/Bank_GKE
```

Create a `terraform.tfvars` file. All values shown are the module defaults —
override only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `existing_project_id` | *(required — no default)* | GCP project ID where all resources are created |
| `gcp_region` | `us-central1` | Region for the GKE cluster, VPC, and all resources |
| `create_autopilot_cluster` | `true` | `true` = GKE Autopilot (fully managed nodes); `false` = Standard cluster with manually configured node pool |
| `gke_cluster` | `gke-cluster` | Name given to the GKE cluster |
| `release_channel` | `REGULAR` | GKE upgrade channel: `RAPID`, `REGULAR`, `STABLE`, or `NONE` |
| `create_network` | `true` | `true` = creates new VPC; `false` = uses existing network identified by `network_name` |
| `network_name` | `vpc-network` | Name of the VPC network |
| `subnet_name` | `vpc-subnet` | Name of the subnet |
| `ip_cidr_ranges` | `["10.132.0.0/16", "192.168.1.0/24"]` | Primary node CIDR and additional secondary ranges |
| `pod_cidr_block` | `10.62.128.0/17` | IPv4 CIDR for pod IPs (supports up to 32,768 pod IPs) |
| `service_cidr_block` | `10.64.128.0/20` | IPv4 CIDR for Kubernetes service IPs |
| `enable_cloud_service_mesh` | `true` | Installs Google-managed Cloud Service Mesh (ASM) |
| `enable_monitoring` | `true` | Creates Cloud Monitoring services and SLOs for each Bank of Anthos microservice |
| `deploy_application` | `true` | Downloads and deploys Bank of Anthos v0.6.7 manifests |
| `enable_config_management` | `false` | Enables Anthos Config Management (ACM) — set to `true` to explore Phase 9 |
| `resource_creator_identity` | *(platform default)* | Terraform service account for resource creation |

Minimum `terraform.tfvars` example:

```hcl
existing_project_id = "your-project-id"
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
| API enablement | 1–2 minutes |
| VPC network, subnet, firewall rules | 1–2 minutes |
| GKE Autopilot cluster creation | 5–10 minutes |
| GKE node pool (Standard only) | 3–5 minutes |
| Fleet membership registration | 2–3 minutes |
| Cloud Service Mesh feature activation | 5–10 minutes |
| ASM control plane provisioning | 10–15 minutes |
| Bank of Anthos download and deployment | 5–10 minutes |
| Cloud Monitoring SLOs | 1–2 minutes |

> Allow up to 45 minutes for the full `tofu apply` to complete. The ASM
> provisioning steps include built-in wait loops that poll the control plane
> until it reports `ACTIVE` before the application is deployed. This ensures
> Envoy sidecars are correctly injected from the first deployment.

### Step 1.3 — Review Terraform Outputs

When `apply` completes, review the outputs:

```bash
tofu output
```

| Output | Used in |
|---|---|
| `project_id` | All subsequent `gcloud` and `kubectl` commands |
| `deployment_id` | Appended to resource names for uniqueness |

---

## Phase 2 — Access the Bank of Anthos Application [MANUAL]

### Step 2.1 — Fetch Cluster Credentials

Open Cloud Shell or a local terminal and run:

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export CLUSTER_NAME="gke-cluster"

gcloud container clusters get-credentials $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID
```

**Expected result:** `kubectl` is configured to communicate with your GKE cluster.
The context name will be `gke_<PROJECT_ID>_<REGION>_<CLUSTER_NAME>`.

### Step 2.2 — Verify All Pods Are Running

Confirm the Bank of Anthos application deployed successfully:

```bash
kubectl get pods -n bank-of-anthos
```

**Expected result:** All pods show a `Running` status with `2/2` containers
ready. On an Autopilot cluster, pods that are `Pending` are waiting for
Autopilot to provision node capacity — wait 2–3 minutes and re-run.

```
NAME                                   READY   STATUS    RESTARTS   AGE
accounts-db-0                          2/2     Running   0          10m
balancereader-xxx-yyy                  2/2     Running   0          10m
contacts-xxx-yyy                       2/2     Running   0          10m
frontend-xxx-yyy                       2/2     Running   0          10m
ledger-db-0                            2/2     Running   0          10m
ledgerwriter-xxx-yyy                   2/2     Running   0          10m
loadgenerator-xxx-yyy                  2/2     Running   0          10m
transactionhistory-xxx-yyy             2/2     Running   0          10m
userservice-xxx-yyy                    2/2     Running   0          10m
```

> **Note:** The `2/2` ready count is the key indicator — it confirms that the
> ASM Envoy proxy sidecar was automatically injected into every pod. The
> `bank-of-anthos` namespace was labelled `istio.io/rev=asm-managed` by
> Terraform, which triggers automatic injection for all new pods.

> **gcloud equivalent — check cluster status and node count:**
> ```bash
> gcloud container clusters describe $CLUSTER_NAME \
>   --region=$REGION \
>   --project=$PROJECT_ID \
>   --format="table(name,status,currentNodeCount,autopilot.enabled)"
> ```
>
> **kubectl JSON equivalent — list pods with readiness detail:**
> ```bash
> kubectl get pods -n bank-of-anthos -o json | \
>   jq '.items[] | {name: .metadata.name, ready: (.status.containerStatuses | map(.ready) | all), phase: .status.phase}'
> ```

### Step 2.3 — Get the Application URL

Retrieve the external IP address of the frontend service:

```bash
kubectl get service frontend -n bank-of-anthos
```

**Expected result:** The `EXTERNAL-IP` column shows a public IP address. If
it shows `<pending>`, wait 1–2 minutes for the Google Cloud Load Balancer
to finish provisioning.

```
NAME       TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
frontend   LoadBalancer   10.64.128.xx    34.xxx.xxx.xxx   80:31xxx/TCP   12m
```

Save the IP for later steps:

```bash
export FRONTEND_IP=$(kubectl get service frontend -n bank-of-anthos \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Bank of Anthos URL: http://$FRONTEND_IP"
```

### Step 2.4 — Log In to the Application

1. Open a browser and navigate to `http://<EXTERNAL-IP>`.
2. The Bank of Anthos login page appears.
3. Log in with the default test credentials:
   - **Username:** `testuser`
   - **Password:** `password`

**Expected result:** The Bank of Anthos dashboard loads, showing the account
overview with a pre-seeded balance and recent transactions.

> If the login fails, wait 1–2 minutes and retry — the `userservice` may
> still be completing its initial database connection to `accounts-db`.

### Step 2.5 — Create Accounts and Transactions

1. Click **+ New Account** to create a savings account.
2. In the **Send Payment** section, enter an amount and send a payment to a default contact.
3. Click **Deposit Funds** and deposit funds into the new account.
4. Click **Transaction History** to view all transactions for the account.

**Expected result:** Transactions are recorded and balances update in real
time, confirming end-to-end connectivity across all eight application
microservices.

> **Background:** The `loadgenerator` service runs continuously inside the
> cluster, generating synthetic transactions to simulate production-level
> traffic. This ensures the service mesh topology is always populated with
> live call graph data.

---

## Phase 3 — Explore the Microservices Architecture [MANUAL]

### Step 3.1 — Review the Service Inventory

Bank of Anthos is composed of nine microservices:

| Service | Language | Role |
|---|---|---|
| `frontend` | Python (Flask) | Web UI and API gateway — the only externally accessible service |
| `userservice` | Python | User account creation and authentication (REST) |
| `contacts` | Python | Contact list management (REST) |
| `accounts-db` | PostgreSQL | Persistent storage for user accounts and contacts (StatefulSet) |
| `ledgerwriter` | Java | Validates and writes transactions to the ledger (gRPC) |
| `balancereader` | Java | Reads current account balances from the ledger cache (gRPC) |
| `transactionhistory` | Java | Reads historical transaction records (gRPC) |
| `ledger-db` | PostgreSQL | Persistent ledger storage (StatefulSet) |
| `loadgenerator` | Python (Locust) | Continuous synthetic load generation against the frontend |

View all Kubernetes resources in the namespace:

```bash
kubectl get all -n bank-of-anthos
```

**Expected result:** Pods, Deployments, Services, and StatefulSets are all
listed. Note that `accounts-db` and `ledger-db` are StatefulSets (because
they require stable network identities and persistent storage), while all
application services are Deployments.

### Step 3.2 — Inspect the Frontend Deployment

```bash
kubectl describe deployment frontend -n bank-of-anthos
```

Review:
- **Replicas:** Number of running instances
- **Image:** Container image and version tag
- **Environment variables:** Service discovery configuration — the frontend
  discovers other services via Kubernetes DNS names (e.g. `USERSERVICE_ADDR`,
  `CONTACTS_ADDR`, `BALANCEREADER_ADDR`)
- **Resource requests and limits:** CPU and memory allocations. Autopilot
  enforces these to provision correctly sized nodes.

**Expected result:** The frontend deployment references all downstream services
by their Kubernetes DNS names (`<service>.bank-of-anthos.svc.cluster.local`),
using no hard-coded IPs. This is the Kubernetes-native service discovery pattern.

### Step 3.3 — View Services and Their Types

```bash
kubectl get services -n bank-of-anthos
```

Note the service types:
- `frontend`: `LoadBalancer` — exposes a Google Cloud HTTP load balancer and assigns an external IP
- All others: `ClusterIP` — internal-only, reachable only within the cluster

**Expected result:** Only `frontend` has an `EXTERNAL-IP`. All backend
services use `ClusterIP`, meaning they are not directly exposed to the internet.
The service mesh enforces mTLS on all ClusterIP-to-ClusterIP communication.

> **gcloud equivalent — list load balancer forwarding rules (shows the frontend external IP):**
> ```bash
> gcloud compute forwarding-rules list \
>   --project=$PROJECT_ID \
>   --format="table(name,IPAddress,IPProtocol,target)"
> ```
>
> **kubectl JSON equivalent — list services with type and IP:**
> ```bash
> kubectl get services -n bank-of-anthos -o json | \
>   jq '.items[] | {name: .metadata.name, type: .spec.type, clusterIP: .spec.clusterIP}'
> ```

### Step 3.4 — Explore the GKE Cluster in the Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**.
2. Click the cluster name **gke-cluster**.
3. Review the cluster overview, noting:
   - **Type:** Autopilot (or Standard if overridden)
   - **Release channel:** REGULAR
   - **Security posture:** BASIC
   - **Workload vulnerability scanning:** BASIC
4. Click the **Workloads** tab — all nine Bank of Anthos workloads are visible.
5. Click the **Services & Ingress** tab — the frontend LoadBalancer and all
   ClusterIP services are listed.

**Expected result:** All workloads are in a `Running` state. The cluster
overview confirms security features and Workload Identity are active.

> **gcloud equivalent — describe cluster summary:**
> ```bash
> gcloud container clusters describe $CLUSTER_NAME \
>   --region=$REGION \
>   --project=$PROJECT_ID \
>   --format="table(name,status,currentNodeCount,currentMasterVersion,releaseChannel.channel,autopilot.enabled)"
> ```

---

## Phase 4 — Explore Cloud Service Mesh [MANUAL]

Cloud Service Mesh (ASM) is the Google-managed distribution of Istio. It
provides automatic mTLS encryption, traffic management, and deep observability
for all service-to-service communication without any application code changes.

### Step 4.1 — Verify the ASM Control Plane

ASM uses a Google-managed control plane — no Istio control plane pods run
in your cluster. Verify the managed control plane is active:

```bash
gcloud container hub features describe servicemesh \
  --project=$PROJECT_ID \
  --format="yaml(resourceState, membershipStates)"
```

Look for:
- `resourceState.state: ACTIVE` — the servicemesh fleet feature is active
- `membershipStates[<cluster-path>].servicemesh.controlPlaneManagement.state: ACTIVE` — the managed control plane is provisioned
- `membershipStates[<cluster-path>].state.code: OK` — the cluster is correctly enrolled

**Expected result:** Both the feature state and the per-cluster control plane
state are `ACTIVE`. If the control plane shows `PROVISIONING`, wait a few
minutes — it can take up to 15 minutes after cluster creation.

> **REST API equivalent:**
> ```bash
> curl -s \
>   "https://gkehub.googleapis.com/v1/projects/$PROJECT_ID/locations/global/features/servicemesh" \
>   -H "Authorization: Bearer $TOKEN" | jq '.resourceState, .membershipStates'
> ```

### Step 4.2 — Inspect Envoy Sidecar Injection

Every pod in the `bank-of-anthos` namespace contains two containers: the
application container and the ASM Envoy proxy sidecar. Inspect a running pod:

```bash
FRONTEND_POD=$(kubectl get pod -n bank-of-anthos -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

# List both containers
kubectl get pod $FRONTEND_POD -n bank-of-anthos \
  -o jsonpath='{.spec.containers[*].name}'
```

**Expected result:** Two names are returned — `frontend` (the application
container) and `istio-proxy` (the Envoy sidecar).

Verify the namespace sidecar injection label that Terraform applied:

```bash
kubectl get namespace bank-of-anthos -o jsonpath='{.metadata.labels}'
```

**Expected result:** The label `istio.io/rev=asm-managed` is present. This
label instructs the ASM mutating webhook to inject a sidecar into every new
pod created in this namespace.

### Step 4.3 — Verify mTLS Encryption Between Services

Cloud Service Mesh automatically encrypts all service-to-service traffic
with mutual TLS. Check the mesh-wide authentication policy:

```bash
# Check for PeerAuthentication policies in the namespace
kubectl get peerauthentication -n bank-of-anthos

# Check for mesh-wide policy in istio-system
kubectl get peerauthentication -n istio-system
```

If no explicit policy exists, the fleet default is `PERMISSIVE` (accepts both
plaintext and mTLS), transitioning automatically to `STRICT` once all services
in the namespace have sidecars injected.

Apply a `STRICT` mTLS policy to prevent any plaintext traffic in the namespace:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: bank-of-anthos
spec:
  mtls:
    mode: STRICT
EOF
```

**Expected result:** All service-to-service calls in `bank-of-anthos` now
require valid mTLS certificates. Any attempt to call a service without a
sidecar (i.e. from outside the mesh) will be rejected.

Verify the policy was applied:

```bash
kubectl get peerauthentication -n bank-of-anthos
```

### Step 4.4 — View Service Mesh Topology in the Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Service Mesh**.
2. Select the cluster **gke-cluster**.
3. Click the **Service Topology** tab.
4. The topology graph shows each Bank of Anthos service as a node, with
   directed edges representing live traffic flows between services.

Explore the topology:
- Click on **frontend** — observe inbound traffic from `loadgenerator` and
  outbound calls to `userservice`, `contacts`, `balancereader`,
  `transactionhistory`, and `ledgerwriter`.
- Click on **ledgerwriter** — observe it receiving writes from `frontend`
  and forwarding reads to `ledger-db`.
- Click on **balancereader** — observe it receiving read requests from
  `frontend` and reading from `ledger-db`.

**Expected result:** The full call graph is visible and continuously updated
by the synthetic traffic from `loadgenerator`. The topology confirms the
correct service communication pattern for the banking application.

### Step 4.5 — Explore Service Mesh Golden Signal Metrics

1. In the Service Mesh console, click on the **frontend** service node.
2. Select the **Metrics** tab.
3. Review the four golden signals:
   - **Request rate (RPS):** Requests per second hitting the frontend
   - **Error rate:** Percentage of requests returning HTTP 5xx
   - **Latency (p50 / p95 / p99):** Response time percentiles
   - **Saturation:** Resource utilisation relative to capacity

4. Click on **ledgerwriter** and compare its gRPC metrics with the
   frontend's HTTP metrics.

**Expected result:** All golden signal metrics are populated from the
`loadgenerator` synthetic traffic, showing healthy request rates with
near-zero error rates and low latency.

> **gcloud equivalent — list available ASM metrics:**
> ```bash
> gcloud monitoring metrics list \
>   --filter="metric.type:istio.io" \
>   --project=$PROJECT_ID | head -30
> ```
>
> **REST API equivalent:**
> ```bash
> curl -s \
>   "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/metricDescriptors?filter=metric.type%3Dstarts_with(%22istio.io%22)" \
>   -H "Authorization: Bearer $TOKEN" | jq '.metricDescriptors[].type' | head -30
> ```

---

## Phase 5 — Traffic Management with Service Mesh [MANUAL]

Istio traffic management resources (`VirtualService` and `DestinationRule`)
allow fine-grained control over how traffic flows between services without
changing any application code.

### Step 5.1 — Apply a VirtualService with Timeout and Retry

Apply a VirtualService that adds a 10-second timeout and automatic retries
on transient failures for requests to the `frontend` service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
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
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: "5xx,reset,connect-failure,retriable-4xx"
EOF
```

Verify it was applied:

```bash
kubectl get virtualservice frontend -n bank-of-anthos
kubectl describe virtualservice frontend -n bank-of-anthos
```

**Expected result:** Requests to `frontend` that do not complete within 10
seconds will be failed fast, and transient 5xx errors will be retried up
to 3 times before propagating to the caller.

### Step 5.2 — Inject a Latency Fault into balancereader

Fault injection tests application resilience under degraded conditions.
Inject a 5-second delay for 50% of requests to the `balancereader` service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: balancereader-fault
  namespace: bank-of-anthos
spec:
  hosts:
  - balancereader
  http:
  - fault:
      delay:
        percentage:
          value: 50
        fixedDelay: 5s
    route:
    - destination:
        host: balancereader
EOF
```

1. Reload the Bank of Anthos application in your browser (`http://$FRONTEND_IP`).
2. Click **Refresh** several times on the account summary page.
3. Some page loads will take noticeably longer due to the injected delay.

**Expected result:** Intermittent latency spikes are observable — roughly
every other balance lookup takes 5 seconds extra. The application remains
functional because the `frontend` VirtualService configured in Step 5.1
handles the retries. Observe the p99 latency spike for `balancereader` in
the Service Mesh Metrics console.

Remove the fault injection:

```bash
kubectl delete virtualservice balancereader-fault -n bank-of-anthos
```

### Step 5.3 — Inject an Abort Fault to Simulate a Service Failure

Test what happens when the `contacts` service returns errors for all requests:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: contacts-fault
  namespace: bank-of-anthos
spec:
  hosts:
  - contacts
  http:
  - fault:
      abort:
        percentage:
          value: 100
        httpStatus: 503
    route:
    - destination:
        host: contacts
EOF
```

1. In the Bank of Anthos application, navigate to the **Pay a Contact** section.
2. The contact list will fail to load — the `contacts` service is returning 503 for every call.

**Expected result:** The contacts feature is unavailable. Observe the error
rate spike on the `contacts` service node in the Service Mesh topology graph.
All other application features (balance display, transaction history, payments)
continue to work because `contacts` is only used for the contact list feature.

Clean up all traffic management resources:

```bash
kubectl delete virtualservice contacts-fault -n bank-of-anthos
kubectl delete virtualservice frontend -n bank-of-anthos
```

### Step 5.4 — Apply a Circuit Breaker with DestinationRule

A circuit breaker automatically removes unhealthy endpoints from the load
balancing pool before they cause cascading failures. Apply one to `ledgerwriter`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ledgerwriter
  namespace: bank-of-anthos
spec:
  host: ledgerwriter
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
EOF
```

**Expected result:** Any `ledgerwriter` pod that returns 5 consecutive 5xx
errors within a 10-second window is ejected from the load balancing pool
for 30 seconds. This prevents a single unhealthy pod from degrading
transaction write performance.

View the circuit breaker policy:

```bash
kubectl get destinationrule ledgerwriter -n bank-of-anthos -o yaml
```

Clean up:

```bash
kubectl delete destinationrule ledgerwriter -n bank-of-anthos
```

---

## Phase 6 — Cloud Monitoring and SLOs [MANUAL]

### Step 6.1 — View the Pre-Configured Monitoring Services

Terraform created Cloud Monitoring service resources and SLOs for all nine
Bank of Anthos microservices. View them in the console:

1. Navigate to **Monitoring > Services**.
2. The following nine services are listed (created by `monitoring.tf`):
   - `accounts-db`, `balancereader`, `contacts`, `frontend`, `ledger-db`,
     `ledgerwriter`, `loadgenerator`, `transactionhistory`, `userservice`
3. Click **frontend** to view its SLO configuration.

**Expected result:** Each service has an SLO targeting 95% of 5-minute windows
per calendar day where the container CPU limit utilisation stays at or below
100%.

> **gcloud equivalent — list monitoring services:**
> ```bash
> gcloud monitoring services list \
>   --project=$PROJECT_ID \
>   --filter="basic_service.service_type=GKE_SERVICE"
> ```
>
> **REST API equivalent:**
> ```bash
> curl -s \
>   "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/services?filter=basic_service.service_type%3DGKE_SERVICE" \
>   -H "Authorization: Bearer $TOKEN" | jq '.services[] | {name, displayName}'
> ```

### Step 6.2 — Explore the SLO Dashboard

1. Click the **frontend** monitoring service.
2. Click the SLO named **95.0% - CPU Limit Utilization Metric - Calendar day**.
3. Review:
   - **SLO target:** 95% — the goal is that CPU utilisation stays within limits for 95% of measurement windows each day
   - **Current compliance:** The percentage of windows meeting the target today
   - **Error budget remaining:** The remaining headroom before breaching the SLO
   - **Error budget burn rate:** How quickly the error budget is being consumed

4. Click **View SLO history** to see compliance over recent days.

**Expected result:** The SLO dashboard shows live compliance data. The
`loadgenerator` keeps all services under sustained load, making this a
meaningful real-time indicator.

> **gcloud equivalent — list SLOs for a monitoring service:**
> ```bash
> gcloud monitoring services list \
>   --project=$PROJECT_ID \
>   --filter="basic_service.service_type=GKE_SERVICE" \
>   --format="value(name)" | while read SVC; do
>     echo "=== $SVC ==="; \
>     gcloud monitoring services service-level-objectives list "$SVC" \
>       --project=$PROJECT_ID \
>       --format="table(name,displayName,goal)"; \
>   done
> ```
>
> **REST API equivalent — list SLOs for the frontend service:**
> ```bash
> curl -s \
>   "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/services/frontend/serviceLevelObjectives" \
>   -H "Authorization: Bearer $TOKEN" | jq '.serviceLevelObjectives[] | {name, displayName, goal}'
> ```

### Step 6.3 — Query CPU Metrics in Metrics Explorer

1. Navigate to **Monitoring > Metrics Explorer**.
2. In the **Select a metric** field, type `kubernetes.io/container/cpu`.
3. Select **kubernetes.io/container/cpu/limit_utilization**.
4. Under **Filter**, add: `namespace_name = bank-of-anthos`.
5. Under **Group By**, select `container_name` and aggregation **Mean**.
6. Click **Apply**.

**Expected result:** A time-series chart shows CPU limit utilisation per
container. The `loadgenerator` drives sustained utilisation across
`frontend`, `ledgerwriter`, and the balance reader services.

> **gcloud equivalent — list available Kubernetes CPU metrics:**
> ```bash
> gcloud monitoring metrics list \
>   --filter="metric.type:kubernetes.io/container/cpu" \
>   --project=$PROJECT_ID
> ```
>
> **REST API equivalent:**
> ```bash
> curl -s \
>   "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/metricDescriptors?filter=metric.type%3Dstarts_with(%22kubernetes.io%2Fcontainer%2Fcpu%22)" \
>   -H "Authorization: Bearer $TOKEN" | jq '.metricDescriptors[] | {type, description}'
> ```

### Step 6.4 — View the Managed Prometheus Endpoint

GKE Managed Service for Prometheus was enabled on the cluster via the
`monitoring_config.managed_prometheus.enabled = true` setting in `gke.tf`.
This scrapes all Kubernetes and Istio metrics automatically.

Verify the Prometheus operator is running:

```bash
kubectl get pods -n gmp-system
```

**Expected result:** Pods in the `gmp-system` namespace manage the scraping
and forwarding of metrics to Google Cloud Managed Service for Prometheus.

In the console:
1. Navigate to **Monitoring > Managed Prometheus**.
2. The **Target status** page shows all active scrape targets.
3. Click on **kube-state-metrics** or **node-exporter** to see scrape health.

### Step 6.5 — Create an Alert Policy for Error Rate

Create an alert to notify when the `ledgerwriter` service starts returning
errors at a rate above a defined threshold:

1. Navigate to **Monitoring > Alerting**.
2. Click **Create Policy**.
3. Click **Select a metric**.
4. Search for `istio.io/service/server/request_count`.
5. Under **Filter**, add:
   - `destination_service_name = ledgerwriter`
   - `response_code_class = 5xx`
6. Under **Transform**, set:
   - **Rolling window:** 5 minutes
   - **Rolling window function:** Rate
7. Set the threshold condition: **above 0.1** (triggers if > 0.1 error/second)
8. Click **Next**, configure a notification channel (email address), name the
   policy `ledgerwriter-error-rate`, and click **Save**.

**Expected result:** The alert policy is created and shows `No incident`
under normal load. The policy will fire if a fault injection or real failure
causes sustained write errors.

> **gcloud equivalent — list existing alert policies:**
> ```bash
> gcloud alpha monitoring policies list \
>   --project=$PROJECT_ID \
>   --format="table(name,displayName,enabled)"
> ```
>
> **REST API equivalent — list alert policies:**
> ```bash
> curl -s \
>   "https://monitoring.googleapis.com/v3/projects/$PROJECT_ID/alertPolicies" \
>   -H "Authorization: Bearer $TOKEN" | jq '.alertPolicies[] | {name, displayName, enabled}'
> ```

---

## Phase 7 — GKE Security Features [MANUAL]

### Step 7.1 — Explore the Security Posture Dashboard

The GKE cluster was created with `security_posture_config.mode = BASIC` and
`vulnerability_mode = VULNERABILITY_BASIC`, enabling continuous security
scanning of workload configurations and container images.

1. Navigate to **Kubernetes Engine > Security Posture**.
2. The dashboard shows:
   - **Workload misconfigurations:** Kubernetes security issues such as
     missing resource limits, containers running as root, or missing
     read-only root filesystems
   - **Vulnerability findings:** Known CVEs in the container images
     deployed in the cluster

3. Click the **Vulnerabilities** tab and review findings for the
   `bank-of-anthos` namespace.
4. Click on any finding to see:
   - The CVE identifier and CVSS severity score
   - The affected container image and package version
   - Remediation guidance and available fixed versions

**Expected result:** The security posture dashboard displays findings for
the deployed workloads. For this demo application, findings are informational.
In a production environment these findings would drive a container image
update or policy enforcement process.

> **gcloud equivalent — check security posture configuration on the cluster:**
> ```bash
> gcloud container clusters describe $CLUSTER_NAME \
>   --region=$REGION \
>   --project=$PROJECT_ID \
>   --format="yaml(securityPostureConfig)"
> ```
>
> **REST API equivalent — retrieve cluster security posture settings:**
> ```bash
> curl -s \
>   "https://container.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters/$CLUSTER_NAME" \
>   -H "Authorization: Bearer $TOKEN" | jq '.securityPostureConfig'
> ```

### Step 7.2 — Verify Workload Identity Is Active

Workload Identity allows Kubernetes service accounts to impersonate GCP
service accounts without key files. It is configured via `workload_pool`
in `gke.tf`.

```bash
gcloud container clusters describe $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="value(workloadIdentityConfig.workloadPool)"
```

**Expected result:** Returns `<PROJECT_ID>.svc.id.goog`, confirming the
Workload Identity Pool is active.

> **Why this matters:** In a production Bank of Anthos deployment, services
> that access Google Cloud APIs (Cloud SQL, Secret Manager, Pub/Sub) would
> bind a Kubernetes service account to a GCP service account via Workload
> Identity, eliminating the need for service account key files mounted in pods.

Verify the workload pool is configured on the node pool (Standard clusters only):

```bash
gcloud container node-pools list \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID
```

> **REST API equivalent — get cluster workload identity config:**
> ```bash
> curl -s \
>   "https://container.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters/$CLUSTER_NAME" \
>   -H "Authorization: Bearer $TOKEN" | jq '.workloadIdentityConfig'
> ```

### Step 7.3 — Inspect Sidecar Injection and Namespace Configuration

Verify the namespace configuration that drives automatic sidecar injection:

```bash
kubectl get namespace bank-of-anthos -o yaml
```

Review:
- The `istio.io/rev: asm-managed` label triggers the ASM mutating admission
  webhook to inject an Envoy proxy sidecar into every new pod.
- The `lifecycle.ignore_changes` setting in Terraform ensures manual label
  additions are not reverted by subsequent `tofu apply` runs.

**Expected result:** The namespace has the ASM revision label. All nine pods
in the namespace have `2/2` containers running, confirming 100% sidecar
injection coverage.

### Step 7.4 — Review All GKE Security Settings

```bash
gcloud container clusters describe $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="yaml(securityPostureConfig,workloadIdentityConfig,addonsConfig,gatewayApiConfig,monitoringConfig)"
```

Review each section:
- `securityPostureConfig.mode: BASIC` — basic workload misconfiguration scanning
- `securityPostureConfig.vulnerabilityMode: VULNERABILITY_BASIC` — basic image CVE scanning
- `workloadIdentityConfig.workloadPool` — Workload Identity active
- `addonsConfig.httpLoadBalancing.disabled: false` — HTTP load balancing enabled (required for LoadBalancer services)
- `addonsConfig.horizontalPodAutoscaling.disabled: false` — HPA available
- `addonsConfig.gcsFuseCsiDriverConfig.enabled: true` — GCS FUSE CSI driver active
- `gatewayApiConfig.channel: CHANNEL_STANDARD` — Kubernetes Gateway API CRDs installed
- `monitoringConfig.managedPrometheus.enabled: true` — Managed Prometheus active

**Expected result:** All security and observability features are confirmed active.

> **REST API equivalent — get full cluster configuration:**
> ```bash
> curl -s \
>   "https://container.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters/$CLUSTER_NAME" \
>   -H "Authorization: Bearer $TOKEN" | jq '{securityPostureConfig, workloadIdentityConfig, addonsConfig, gatewayApiConfig, monitoringConfig}'
> ```

---

## Phase 8 — GKE Fleet Management [MANUAL]

GKE Fleet provides a unified management plane for one or more GKE clusters.
The `Bank_GKE` module registers the cluster with the project's fleet and
enables the Service Mesh fleet feature, which controls ASM installation and
configuration.

### Step 8.1 — View the Fleet in the Console

1. Navigate to **Kubernetes Engine > Fleets**.
2. The fleet overview shows all registered clusters.
3. Click the cluster **gke-cluster** to view its membership details.

Review:
- **Membership ID:** `gke-cluster` (set by `hub.tf`)
- **Location:** global
- **Features:** servicemesh (and configmanagement if enabled)
- **State:** READY

**Expected result:** The cluster is registered and all enabled fleet features
show a healthy state.

### Step 8.2 — View Fleet Membership via CLI

```bash
gcloud container hub memberships list \
  --project=$PROJECT_ID

gcloud container hub memberships describe $CLUSTER_NAME \
  --project=$PROJECT_ID
```

Look for:
- `state.code: READY`
- `authority.issuer` — points to the GKE cluster's OIDC issuer
- `endpoint.gkeCluster.resourceLink` — the full resource path of the cluster

**Expected result:** The membership is healthy and its authority issuer matches
the GKE cluster.

> **gcloud equivalent — shown in the main step above.**
>
> **REST API equivalent — describe fleet membership:**
> ```bash
> curl -s \
>   "https://gkehub.googleapis.com/v1/projects/$PROJECT_ID/locations/global/memberships/$CLUSTER_NAME" \
>   -H "Authorization: Bearer $TOKEN" | jq '{name, state: .state.code, authority: .authority.issuer}'
> ```

### Step 8.3 — View Fleet-Level Feature Status

```bash
gcloud container hub features list \
  --project=$PROJECT_ID
```

**Expected result:** The `servicemesh` feature is listed with state `ACTIVE`.
If `enable_config_management = true` was set, `configmanagement` also appears.

Fleet features are managed at the project level and apply configuration
consistently across all enrolled clusters — this is the mechanism that allows
a single `gcloud container hub features` command to control ASM across dozens
of clusters simultaneously.

> **gcloud equivalent — shown in the main step above.**
>
> **REST API equivalent — list fleet features:**
> ```bash
> curl -s \
>   "https://gkehub.googleapis.com/v1/projects/$PROJECT_ID/locations/global/features" \
>   -H "Authorization: Bearer $TOKEN" | jq '.resources[] | {name, state: .resourceState.state}'
> ```

---

## Phase 9 — Anthos Config Management (Optional) [MANUAL]

> **This phase requires `enable_config_management = true` to have been set**
> **in `terraform.tfvars` before running `tofu apply`.**
> **If it was not set, re-run `tofu apply` with the variable added, or skip to Phase 10.**

Anthos Config Management (ACM) implements a GitOps model — Kubernetes
configuration is declared in a Git repository and Config Sync automatically
applies changes to the cluster within seconds of a Git commit, without manual
`kubectl apply` commands.

### Step 9.1 — Verify ACM Installation

```bash
gcloud container hub config-management status \
  --project=$PROJECT_ID
```

**Expected result:** The output shows the cluster as `SYNCED`, meaning Config
Sync has successfully pulled configuration from the Git repository specified
by `config_sync_repo` and applied it to the cluster.

> **REST API equivalent — get ACM feature status:**
> ```bash
> curl -s \
>   "https://gkehub.googleapis.com/v1/projects/$PROJECT_ID/locations/global/features/configmanagement" \
>   -H "Authorization: Bearer $TOKEN" | jq '.membershipStates | to_entries[] | {cluster: .key, syncState: .value.configSync.syncState}'
> ```

### Step 9.2 — View Config Sync Reconciler Pods

```bash
kubectl get pods -n config-management-system
```

**Expected result:** The `root-reconciler-*` pod is running. This pod monitors
the configured Git repository every 15 seconds (default) and applies any new
commits automatically.

### Step 9.3 — Explore Config Sync Status in the Console

1. Navigate to **Kubernetes Engine > Config**.
2. Click the **Config Sync** tab to see:
   - The sync source repository URL
   - The last successfully synced Git commit hash
   - The sync status (`Synced` or `Error`)
3. Click the **Policy Controller** tab to see admission control policies
   installed by ACM.

**Expected result:** Config Sync is actively syncing from the
`anthos-config-management-samples` repository. The last sync commit is recent.

### Step 9.4 — Understand GitOps Drift Prevention

Config Sync enforces the declared state from Git. If a resource managed by
Config Sync is modified manually, Config Sync reverts it on the next sync.

Test this behaviour:

```bash
# Inspect the root sync configuration
kubectl get rootsync -n config-management-system -o yaml

# Attempt to add a label that Config Sync does not manage
kubectl label namespace default test-label=manual-edit --overwrite

# Watch whether it gets reverted
sleep 20 && kubectl get namespace default --show-labels | grep test-label
```

**Expected result:** If the `default` namespace is managed by Config Sync,
the `test-label` label is reverted within 15–30 seconds of the next sync
cycle.

> **Note:** The default `config_sync_repo` points to the Google Cloud Platform
> `anthos-config-management-samples` repository. In a real deployment, you
> would point this to your own organisation's configuration repository and
> control access via a Git read credential.

---

## Phase 10 — Advanced Operations [MANUAL]

### Step 10.1 — Scale a Deployment

Scale the `frontend` deployment to 3 replicas:

```bash
kubectl scale deployment frontend --replicas=3 -n bank-of-anthos
kubectl rollout status deployment/frontend -n bank-of-anthos
kubectl get pods -n bank-of-anthos -l app=frontend
```

**Expected result:** Three `frontend` pods are running, each showing `2/2`
(application + Envoy sidecar). On an Autopilot cluster, Autopilot
automatically provisions additional node capacity if needed. ASM's Envoy
webhook injects the sidecar into each new pod automatically.

Scale back to a single replica:

```bash
kubectl scale deployment frontend --replicas=1 -n bank-of-anthos
```

> **kubectl alternative — patch replicas directly:**
> ```bash
> kubectl patch deployment frontend -n bank-of-anthos \
>   -p '{"spec":{"replicas":3}}'
> ```
>
> **REST API equivalent — patch deployment via Kubernetes API:**
> ```bash
> curl -s -X PATCH \
>   "https://$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')/apis/apps/v1/namespaces/bank-of-anthos/deployments/frontend" \
>   -H "Authorization: Bearer $(gcloud auth print-access-token)" \
>   -H "Content-Type: application/merge-patch+json" \
>   -d '{"spec":{"replicas":3}}' | jq '.spec.replicas'
> ```

### Step 10.2 — Trigger a Rolling Update

Trigger a rolling restart of the `frontend` deployment (simulating a new
image deployment):

```bash
kubectl rollout restart deployment/frontend -n bank-of-anthos
kubectl rollout status deployment/frontend -n bank-of-anthos
```

**Expected result:** The rolling update proceeds pod-by-pod. New pods are
created and reach `Running` state before old pods are terminated, ensuring
zero-downtime deployment. The Envoy sidecar is injected into each new pod.

View the rollout history:

```bash
kubectl rollout history deployment/frontend -n bank-of-anthos
```

Roll back if needed:

```bash
kubectl rollout undo deployment/frontend -n bank-of-anthos
```

### Step 10.3 — Inspect the Load Generator

The `loadgenerator` service uses Locust to simulate a continuous stream of
user transactions against the `frontend`. Inspect its activity:

```bash
kubectl describe deployment loadgenerator -n bank-of-anthos
kubectl logs deployment/loadgenerator -n bank-of-anthos --tail=30
```

**Expected result:** Logs show Locust generating a steady stream of requests
including GET requests (account summary, transaction history) and POST requests
(deposits, payments). This traffic is what keeps the Service Mesh topology
graph populated with live call graph data.

### Step 10.4 — Explore Gateway API CRDs

The cluster was created with `gateway_api_config.channel = CHANNEL_STANDARD`,
which installs the Kubernetes Gateway API Custom Resource Definitions.

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

**Expected result:** Gateway API CRDs are present:
- `gateways.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`
- `grpcroutes.gateway.networking.k8s.io`
- `gatewayclasses.gateway.networking.k8s.io`

> **Note:** Bank of Anthos currently uses a classic Kubernetes `LoadBalancer`
> service for the frontend. The Gateway API CRDs are available for advanced
> use cases such as path-based routing, header-based routing, traffic splitting
> by percentage, and HTTPS termination — all managed declaratively as
> Kubernetes objects.

### Step 10.5 — Verify Cost Allocation is Active

The cluster has `cost_management_config.enabled = true`, which tags Kubernetes
resource usage with namespace and label dimensions for cost attribution.

1. Navigate to **Billing > Cost breakdown** in the Google Cloud console.
2. Under **Service**, click **Kubernetes Engine**.
3. Expand the cost breakdown to see namespace-level attribution.

Alternatively, view cluster-level cost allocation:

1. Navigate to **Kubernetes Engine > Clusters > gke-cluster**.
2. Click the **Cost** tab to see a breakdown of compute costs by namespace.

**Expected result:** Costs for the `bank-of-anthos` namespace are tracked
separately from `kube-system` and other namespaces, enabling per-team or
per-application cost attribution.

### Step 10.6 — Review Kubernetes Audit Logs

Every `kubectl` command and API operation generates an entry in Cloud Audit
Logs, providing a complete compliance trail.

1. Navigate to **Logging > Logs Explorer**.
2. Enter the following query:

```
resource.type="k8s_cluster"
resource.labels.cluster_name="gke-cluster"
protoPayload.methodName=~"(create|delete|patch|update)"
protoPayload.authenticationInfo.principalEmail!=""
```

3. Click **Run Query**.
4. Expand individual entries to see:
   - The Kubernetes resource type and name modified
   - The caller identity (service account email or user)
   - The operation method (`apps.deployments.patch`, `core.pods.create`, etc.)
   - Timestamp and response status code

**Expected result:** Audit log entries are visible for all `kubectl scale`,
`kubectl apply`, and `kubectl rollout restart` operations performed during
this lab.

> **gcloud equivalent — query audit logs:**
> ```bash
> gcloud logging read \
>   'resource.type="k8s_cluster" AND protoPayload.methodName=~"(create|delete|patch)"' \
>   --project=$PROJECT_ID \
>   --limit=10 \
>   --format="json" | jq '.[].protoPayload | {method: .methodName, caller: .authenticationInfo.principalEmail}'
> ```
>
> **REST API equivalent:**
> ```bash
> curl -s -X POST \
>   "https://logging.googleapis.com/v2/entries:list" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d "{
>     \"resourceNames\": [\"projects/$PROJECT_ID\"],
>     \"filter\": \"resource.type=k8s_cluster AND protoPayload.methodName=~\\\"(create|delete|patch)\\\"\",
>     \"pageSize\": 10
>   }" | jq '.entries[] | .protoPayload | {method: .methodName, caller: .authenticationInfo.principalEmail}'
> ```

---

## Phase 11 — Explore Additional Cloud Console Features [MANUAL]

### Step 11.1 — View Application Logs in Cloud Logging

1. Navigate to **Logging > Logs Explorer**.
2. Set the resource filter to **Kubernetes Container**.
3. Under **Cluster**, select **gke-cluster**.
4. Under **Namespace**, select **bank-of-anthos**.
5. Browse logs from individual services — for example, filter by
   `resource.labels.container_name="frontend"` to see HTTP access logs.

**Expected result:** Structured JSON logs from all Bank of Anthos services
are visible, showing HTTP requests, gRPC calls, and database connection events.
All logs are automatically collected because the cluster has `WORKLOADS`
component logging enabled in `logging_config`.

> **gcloud equivalent — tail application logs from Cloud Logging:**
> ```bash
> gcloud logging read \
>   'resource.type="k8s_container" AND resource.labels.cluster_name="gke-cluster" AND resource.labels.namespace_name="bank-of-anthos"' \
>   --project=$PROJECT_ID \
>   --limit=20 \
>   --format="json" | jq '.[] | {timestamp: .timestamp, container: .resource.labels.container_name, message: (.textPayload // (.jsonPayload | tostring))}'
> ```
>
> **REST API equivalent:**
> ```bash
> curl -s -X POST \
>   "https://logging.googleapis.com/v2/entries:list" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d "{
>     \"resourceNames\": [\"projects/$PROJECT_ID\"],
>     \"filter\": \"resource.type=k8s_container AND resource.labels.cluster_name=gke-cluster AND resource.labels.namespace_name=bank-of-anthos\",
>     \"pageSize\": 20,
>     \"orderBy\": \"timestamp desc\"
>   }" | jq '.entries[] | {timestamp: .timestamp, container: .resource.labels.container_name, message: (.textPayload // (.jsonPayload | tostring))}'
> ```

### Step 11.2 — View Workload Logs from GKE Console

1. Navigate to **Kubernetes Engine > Workloads**.
2. Click on **ledgerwriter**.
3. Click the **Logs** tab on the workload details page.

**Expected result:** The `ledgerwriter` application logs are displayed inline,
showing gRPC transaction write events. The logs tab provides a quick way to
access service logs without navigating to the Logs Explorer separately.

### Step 11.3 — Review the VPC Network and Firewall Rules

1. Navigate to **VPC Network > VPC Networks** and click **vpc-network**.
2. Review the subnet CIDR assignments:
   - **Node subnet:** `10.132.0.0/16`
   - **Pod secondary range:** `10.62.128.0/17`
   - **Service secondary range:** `10.64.128.0/20`
3. Navigate to **VPC Network > Firewall** and review the rules created by Terraform:
   - `fw-allow-lb-hc`: Allows Google load balancer health check probes (TCP 80)
   - `fw-allow-nfs-hc`: Allows NFS health check probes (TCP 2049)
   - `fw-allow-iap-ssh`: Allows IAP tunnel SSH access (TCP 22, source `35.235.240.0/20`)
   - `fw-allow-intra-vpc`: Allows all pod-to-pod traffic within the pod CIDR
   - `fw-allow-http-tcp`: Allows HTTP/HTTPS access (TCP 80, 443) for tagged instances

**Expected result:** The VPC is correctly configured with non-overlapping CIDR
ranges and the minimum firewall rules required for GKE and load balancing.

> **gcloud equivalent — list subnets and secondary ranges:**
> ```bash
> gcloud compute networks subnets list \
>   --filter="network~vpc-network" \
>   --project=$PROJECT_ID \
>   --format="table(name,region,ipCidrRange,secondaryIpRanges.rangeName,secondaryIpRanges.ipCidrRange)"
> ```
>
> **gcloud equivalent — list firewall rules for the VPC:**
> ```bash
> gcloud compute firewall-rules list \
>   --filter="network~vpc-network" \
>   --project=$PROJECT_ID \
>   --format="table(name,direction,allowed[].map().firewall_rule().list():label=ALLOW,sourceRanges.list():label=SRC_RANGES)"
> ```
>
> **REST API equivalent — list subnets:**
> ```bash
> curl -s \
>   "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/regions/$REGION/subnetworks?filter=network+eq+.*vpc-network" \
>   -H "Authorization: Bearer $TOKEN" | jq '.items[] | {name, ipCidrRange, secondaryIpRanges}'
> ```
>
> **REST API equivalent — list firewall rules:**
> ```bash
> curl -s \
>   "https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/global/firewalls?filter=network+eq+.*vpc-network" \
>   -H "Authorization: Bearer $TOKEN" | jq '.items[] | {name, direction, allowed, sourceRanges}'
> ```

### Step 11.4 — Explore Cloud Trace

The cluster has `cloudtrace.googleapis.com` enabled in the project APIs. ASM
automatically generates distributed traces for all mesh-enrolled services.

1. Navigate to **Trace > Trace Explorer** in the Google Cloud console.
2. Select a time range and click **Find Traces**.
3. Click on a trace for a `frontend` request to see the distributed trace
   waterfall across `frontend`, `balancereader`, `userservice`, and
   `transactionhistory`.

**Expected result:** Distributed trace spans are visible showing the complete
call chain for a single end-user request, including the latency contribution
of each microservice.

> **REST API equivalent — list recent traces:**
> ```bash
> curl -s \
>   "https://cloudtrace.googleapis.com/v1/projects/$PROJECT_ID/traces?pageSize=5&orderBy=start+desc" \
>   -H "Authorization: Bearer $TOKEN" | jq '.traces[] | {traceId, spans: [.spans[] | {name, startTime, endTime}]}'
> ```

---

## Summary

The table below recaps every action in the lab, its phase, and whether it
is automated by the `Bank_GKE` Terraform module or performed manually.

| Action | Phase | Automated |
|---|---|---|
| Enable GCP APIs (GKE, Mesh, Anthos, IAM, Trace, etc.) | 1 | Yes — `main.tf` |
| Create VPC network and subnet with secondary ranges | 1 | Yes — `network.tf` |
| Configure Cloud Router and NAT gateway | 1 | Yes — `network.tf` |
| Create VPC firewall rules | 1 | Yes — `network.tf` |
| Provision GKE Autopilot or Standard cluster | 1 | Yes — `gke.tf` |
| Create GKE node pool and service account (Standard only) | 1 | Yes — `gke.tf` |
| Grant IAM roles to GKE node service account | 1 | Yes — `gke.tf` |
| Register cluster with GKE Fleet | 1 | Yes — `hub.tf` |
| Wait for Fleet API propagation and IAM consistency | 1 | Yes — `hub.tf` (wait loops) |
| Enable Service Mesh fleet feature | 1 | Yes — `asm.tf` |
| Wait for ASM control plane activation | 1 | Yes — `asm.tf` (wait loops) |
| Create Cloud Monitoring services and SLOs for all microservices | 1 | Yes — `monitoring.tf` |
| Reserve global static IP for load balancer | 1 | Yes — `glb.tf` |
| Download and extract Bank of Anthos v0.6.7 manifests | 1 | Yes — `deploy.tf` |
| Create `bank-of-anthos` namespace with ASM injection label | 1 | Yes — `deploy.tf` |
| Apply JWT secret and all Kubernetes manifests | 1 | Yes — `deploy.tf` |
| Fetch GKE cluster credentials | 2 | No — `gcloud container clusters get-credentials` |
| Verify pod readiness and sidecar injection | 2 | No — `kubectl get pods` |
| Retrieve frontend external IP | 2 | No — `kubectl get service` |
| Log in to Bank of Anthos in browser | 2 | No — browser session |
| Create accounts and make transactions | 2 | No — browser session |
| View all Kubernetes resources in namespace | 3 | No — `kubectl get all` |
| Inspect deployment configuration and environment variables | 3 | No — `kubectl describe deployment` |
| Review service types and cluster-internal DNS | 3 | No — `kubectl get services` |
| Explore cluster workloads and services in GKE console | 3 | No — GKE console |
| Verify ASM control plane state via Hub API | 4 | No — `gcloud container hub features describe` |
| Inspect Envoy sidecar containers in pods | 4 | No — `kubectl get pod` |
| Apply STRICT mTLS PeerAuthentication policy | 4 | No — `kubectl apply` |
| View Service Mesh topology graph | 4 | No — Service Mesh console |
| Explore golden signal metrics per service | 4 | No — Service Mesh console |
| Apply VirtualService with timeout and retry | 5 | No — `kubectl apply` |
| Inject latency fault into `balancereader` | 5 | No — `kubectl apply` |
| Inject abort fault into `contacts` | 5 | No — `kubectl apply` |
| Apply circuit breaker DestinationRule to `ledgerwriter` | 5 | No — `kubectl apply` |
| Observe fault injection impact in topology console | 5 | No — Service Mesh console |
| View pre-configured Cloud Monitoring services | 6 | No — Monitoring console |
| Explore SLO compliance and error budget dashboard | 6 | No — Monitoring console |
| Query CPU limit utilisation in Metrics Explorer | 6 | No — Monitoring console |
| View Managed Prometheus scrape targets | 6 | No — Monitoring console |
| Create alert policy for `ledgerwriter` error rate | 6 | No — Monitoring console |
| Review security posture workload findings | 7 | No — Security Posture console |
| Review container vulnerability scan findings | 7 | No — Security Posture console |
| Verify Workload Identity pool configuration | 7 | No — `gcloud` command |
| Inspect ASM sidecar injection namespace label | 7 | No — `kubectl get namespace` |
| Review all GKE cluster security and feature settings | 7 | No — `gcloud` command |
| View fleet membership in console | 8 | No — Fleet console |
| Inspect fleet membership details via CLI | 8 | No — `gcloud container hub memberships` |
| View fleet-level feature status | 8 | No — `gcloud container hub features list` |
| Verify ACM Config Sync status | 9 | No — optional (requires `enable_config_management = true`) |
| Inspect Config Sync reconciler pods | 9 | No — optional |
| Explore GitOps drift prevention behaviour | 9 | No — optional |
| Scale `frontend` deployment and observe HPA | 10 | No — `kubectl scale` |
| Trigger rolling update and verify zero-downtime | 10 | No — `kubectl rollout restart` |
| Inspect `loadgenerator` synthetic traffic logs | 10 | No — `kubectl logs` |
| Explore Gateway API CRD availability | 10 | No — `kubectl get crd` |
| View namespace-level cost allocation | 10 | No — Billing console |
| Query Kubernetes audit logs for lab operations | 10 | No — Cloud Logging |
| Browse application logs by container in Logs Explorer | 11 | No — Cloud Logging |
| View workload logs inline in GKE console | 11 | No — GKE console |
| Review VPC subnet CIDRs and firewall rules | 11 | No — VPC console |
| Explore distributed traces in Cloud Trace | 11 | No — Cloud Trace console |
