# Bank of Anthos on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Bank_GKE)**

This lab guide walks you through deploying, exploring, and operating the **Bank of Anthos**
reference application on Google Kubernetes Engine with **Cloud Service Mesh (CSM)** using the
**Bank_GKE** module. You will explore a production-grade microservices architecture representing
a PCI-DSS-relevant financial services workload, including service mesh security, traffic
management, observability, and GitOps-driven configuration management.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Access the Application](#exercise-1--access-the-application)
6. [Exercise 2 — Explore the Microservices Architecture](#exercise-2--explore-the-microservices-architecture)
7. [Exercise 3 — Cloud Service Mesh Exploration](#exercise-3--cloud-service-mesh-exploration)
8. [Exercise 4 — Traffic Management](#exercise-4--traffic-management)
9. [Exercise 5 — Cloud Monitoring and SLOs](#exercise-5--cloud-monitoring-and-slos)
10. [Exercise 6 — GKE Security Posture](#exercise-6--gke-security-posture)
11. [Exercise 7 — GKE Fleet Management](#exercise-7--gke-fleet-management)
12. [Exercise 8 — Anthos Config Management (Optional)](#exercise-8--anthos-config-management-optional)
13. [Exercise 9 — Advanced Operations](#exercise-9--advanced-operations)
14. [Cleanup](#14-cleanup)
15. [Reference](#15-reference)

---

## 1. Overview

### What Is Bank of Anthos?

Bank of Anthos is an open-source **reference banking application** from Google that demonstrates
a production-like polyglot microservices architecture. It implements a simplified retail bank
with account management, ledger transactions, and a web frontend. The `Bank_GKE` module deploys
version **v0.6.7** on GKE with Cloud Service Mesh enabled.

### Key Capabilities Demonstrated

| Capability | What It Demonstrates |
|---|---|
| **PCI-DSS Patterns** | mTLS encryption, L7 auth policies, Workload Identity, vulnerability scanning |
| **GitOps** | Anthos Config Management (ACM) for declarative, drift-preventing config management |
| **SLOs** | Pre-built Cloud Monitoring SLOs for CPU utilisation per microservice |
| **Service Mesh** | Cloud Service Mesh (managed Istio) with Envoy sidecars, mTLS, traffic topology |
| **Observability** | Managed Prometheus, distributed tracing, structured logging |
| **Autopilot** | GKE Autopilot cluster with automatic node provisioning and security hardening |

### What the Module Automates

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

## 2. Architecture

### Microservices Map

```
Browser
  │
  ▼
frontend (Python/Flask)
  │          │
  ▼          ▼
userservice  contacts        ← Account management (Python + PostgreSQL)
  │
  ├── accounts-db (PostgreSQL)
  │
  ├── ledgerwriter (Java/Spring Boot)
  │      └── ledger-db (PostgreSQL)
  │
  └── balancereader (Java)   ← Reads from ledger-db
       transactionhistory    ← Reads from ledger-db

loadgenerator               ← Synthetic traffic for telemetry
```

### Infrastructure

```
┌──────────────────────────────────────────────────────────────────────┐
│  Google Cloud                                                        │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  GKE Autopilot Cluster (or Standard)                           │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │  bank-of-anthos namespace                                │  │  │
│  │  │  (label: istio.io/rev=asm-managed)                       │  │  │
│  │  │                                                          │  │  │
│  │  │  All 9 pods: 2/2 READY (app + Envoy sidecar)            │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌─────────────────┐  │  │
│  │  │  Cloud Service │  │  GKE Fleet Hub │  │  Global L4 LB   │  │  │
│  │  │  Mesh (managed │  │  (membership)  │  │  (frontend IP)  │  │  │
│  │  │  istiod)       │  │                │  │                 │  │  │
│  │  └────────────────┘  └────────────────┘  └─────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────┐  ┌───────────────────┐  ┌───────────────────┐ │
│  │  Cloud Logging   │  │  Cloud Monitoring │  │  Cloud Trace      │ │
│  │  (structured     │  │  (Managed         │  │  (auto-sampled    │ │
│  │   workload logs) │  │   Prometheus SLOs)│  │   traces)         │ │
│  └──────────────────┘  └───────────────────┘  └───────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  Bank_GKE
    create_autopilot_cluster    = true  →  GKE Autopilot cluster
    enable_cloud_service_mesh   = true  →  Fleet Hub CSM, MANAGEMENT_AUTOMATIC
    deploy_application          = true  →  Bank of Anthos v0.6.7
    enable_monitoring           = true  →  Cloud Monitoring services and SLOs
    enable_config_management    = false →  Set true for GitOps via ACM
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
roles/monitoring.admin
roles/logging.admin
```

### Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export CLUSTER_NAME="gke-cluster"    # matches gke_cluster variable
export APP_NAMESPACE="bank-of-anthos"

gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${REGION}"
```

### REST API Authentication

Every action in this lab can also be performed via the GKE REST API or Fleet Hub API as an
alternative to the Cloud Console UI. Equivalent REST API commands are shown after each relevant
step. All REST API calls require a bearer token:

```bash
export TOKEN=$(gcloud auth print-access-token)
```

**GKE REST API base URL:** `https://container.googleapis.com/v1`

**Fleet Hub API base URL:** `https://gkehub.googleapis.com/v1`

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `Bank_GKE` module via the RAD UI. In the variable form, set:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `region` | `us-central1` | GCP region |
| `gke_cluster` | `gke-cluster` | Cluster name |
| `create_autopilot_cluster` | `true` | Autopilot (recommended) or Standard |
| `enable_cloud_service_mesh` | `true` | Enable managed Istio |
| `deploy_application` | `true` | Deploy Bank of Anthos v0.6.7 |
| `enable_monitoring` | `true` | Enable Cloud Monitoring and SLOs |
| `enable_config_management` | `false` | Set `true` for Exercise 8 |

Click **Deploy** and wait for provisioning to complete (approximately 30–45 minutes).

> **What this provisions:** GKE Autopilot cluster, VPC with secondary IP ranges for pods and
> services, Cloud Service Mesh (managed Istio with MANAGEMENT_AUTOMATIC), Bank of Anthos
> application in the `bank-of-anthos` namespace with Envoy sidecars, Cloud Monitoring services
> and SLOs, and optionally Anthos Config Management for GitOps.

### 4.2 Configure kubectl

```bash
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}"

kubectl cluster-info
kubectl get nodes
```

---

## Exercise 1 — Access the Application

### Objective

Retrieve the Bank of Anthos frontend IP and explore the application as an end user.

### Step 1.1 — Get the Frontend IP

**kubectl:**
```bash
kubectl get service frontend -n "${APP_NAMESPACE}"

FRONTEND_IP=$(kubectl get service frontend -n "${APP_NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Frontend: http://${FRONTEND_IP}"
```

**gcloud (via static IP):**
```bash
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

### Step 1.2 — Log In and Explore

Navigate to `http://${FRONTEND_IP}` in your browser.

Default test credentials: `testuser` / `password`

Explore the application:
1. Log in with the test user
2. View the account balance and transaction history
3. Deposit funds (send from the external account)
4. Transfer funds between accounts
5. View the updated transaction history and balance

> If the login fails, wait 1–2 minutes and retry — the `userservice` may still be completing
> its initial database connection to `accounts-db`.

### Step 1.3 — Create Accounts and Transactions

1. Click **+ New Account** to create a savings account.
2. In the **Send Payment** section, enter an amount and send a payment to a default contact.
3. Click **Deposit Funds** and deposit funds into the new account.
4. Click **Transaction History** to view all transactions for the account.

Transactions are recorded and balances update in real time, confirming end-to-end connectivity
across all eight application microservices.

> **Background:** The `loadgenerator` service runs continuously inside the cluster, generating
> synthetic transactions to simulate production-level traffic. This ensures the service mesh
> topology is always populated with live call graph data.

### Step 1.4 — Verify All Pods Are Running

```bash
kubectl get pods -n "${APP_NAMESPACE}"

# All pods should show 2/2 READY (app container + Envoy sidecar)
```

Expected pods:
```
NAME                                  READY   STATUS
accounts-db-xxx                       2/2     Running
balancereader-xxx                     2/2     Running
contacts-xxx                          2/2     Running
frontend-xxx                          2/2     Running
ledger-db-xxx                         2/2     Running
ledgerwriter-xxx                      2/2     Running
loadgenerator-xxx                     2/2     Running
transactionhistory-xxx                2/2     Running
userservice-xxx                       2/2     Running
```

---

## Exercise 2 — Explore the Microservices Architecture

### Objective

Understand the nine-microservice polyglot architecture and how the services communicate.

### Step 2.1 — List Services

```bash
kubectl get services -n "${APP_NAMESPACE}"
```

| Service | Type | Port | Technology |
|---|---|---|---|
| `frontend` | LoadBalancer | 80 | Python/Flask |
| `userservice` | ClusterIP | 8080 | Python |
| `contacts` | ClusterIP | 8080 | Python |
| `ledgerwriter` | ClusterIP | 8080 | Java/Spring Boot |
| `balancereader` | ClusterIP | 8080 | Java |
| `transactionhistory` | ClusterIP | 8080 | Java |
| `accounts-db` | ClusterIP | 5432 | PostgreSQL |
| `ledger-db` | ClusterIP | 5432 | PostgreSQL |

### Step 2.2 — Inspect a Deployment

```bash
kubectl describe deployment frontend -n "${APP_NAMESPACE}"

# Note:
# - Image: gcr.io/bank-of-anthos-ci/frontend:v0.6.7
# - Env vars: TRANSACTIONS_API_ADDR, USERSERVICE_API_ADDR
# - Resource requests and limits
```

### Step 2.3 — View Service Account Annotations (Workload Identity)

```bash
kubectl get serviceaccounts -n "${APP_NAMESPACE}" -o yaml \
  | grep -A2 "annotations:"
```

Workload Identity binds each Kubernetes service account to a GCP service account, enabling
fine-grained IAM access to GCP resources (Cloud SQL, Secret Manager, etc.) without keys.

### Step 2.4 — Explore the Load Generator

The `loadgenerator` service uses Locust to simulate a continuous stream of user transactions
against the `frontend`, exercising all code paths and generating telemetry:

```bash
kubectl logs -n "${APP_NAMESPACE}" \
  "$(kubectl get pod -n "${APP_NAMESPACE}" -l app=loadgenerator \
     -o jsonpath='{.items[0].metadata.name}')" \
  --tail=20
```

Logs show Locust generating a steady stream of requests including GET requests (account summary,
transaction history) and POST requests (deposits, payments). This traffic keeps the Service Mesh
topology graph populated with live call graph data.

### Step 2.5 — Examine a Java Service Pod

```bash
LEDGER_POD=$(kubectl get pod -n "${APP_NAMESPACE}" -l app=ledgerwriter \
  -o jsonpath='{.items[0].metadata.name}')

# Containers: ledgerwriter + istio-proxy
kubectl get pod "${LEDGER_POD}" -n "${APP_NAMESPACE}" \
  -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n'

# View JVM startup logs
kubectl logs "${LEDGER_POD}" -n "${APP_NAMESPACE}" -c ledgerwriter --tail=30
```

### Step 2.6 — Explore the GKE Cluster in the Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**.
2. Click the cluster name **gke-cluster**.
3. Review the cluster overview, noting:
   - **Type:** Autopilot (or Standard if overridden)
   - **Release channel:** REGULAR
   - **Security posture:** BASIC
   - **Workload vulnerability scanning:** BASIC
4. Click the **Workloads** tab — all nine Bank of Anthos workloads are visible.
5. Click the **Services & Ingress** tab — the frontend LoadBalancer and all ClusterIP services
   are listed. Only `frontend` has an `EXTERNAL-IP`; all backend services use `ClusterIP`,
   meaning they are not directly exposed to the internet.

```bash
# gcloud equivalent — describe cluster summary
gcloud container clusters describe "${CLUSTER_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="table(name,status,currentNodeCount,currentMasterVersion,releaseChannel.channel,autopilot.enabled)"
```

---

## Exercise 3 — Cloud Service Mesh Exploration

### Objective

Explore the Cloud Service Mesh (CSM) control plane, verify Envoy sidecar injection, inspect
the service topology, and verify mTLS encryption between services.

### Step 3.1 — Verify Fleet Hub CSM Feature

**gcloud:**
```bash
gcloud container fleet mesh describe --project="${PROJECT_ID}"
```

Expected:
```yaml
membershipStates:
  .../memberships/gke-cluster:
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
  | jq '{state: .state.state}'
```

### Step 3.2 — Verify Namespace Label (Sidecar Injection Trigger)

```bash
kubectl get namespace "${APP_NAMESPACE}" --show-labels

# Should include: istio.io/rev=asm-managed
```

### Step 3.3 — Inspect an Envoy Sidecar

```bash
POD=$(kubectl get pod -n "${APP_NAMESPACE}" -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

# Check Envoy version
kubectl exec "${POD}" -n "${APP_NAMESPACE}" -c istio-proxy -- \
  pilot-agent request GET server_info | jq '.version'

# List all clusters (upstream services this sidecar knows about)
istioctl proxy-config cluster "${POD}" -n "${APP_NAMESPACE}"

# Active routes
istioctl proxy-config route "${POD}" -n "${APP_NAMESPACE}"
```

### Step 3.4 — Verify mTLS Between Services

```bash
# Check the workload certificate (SPIFFE identity)
kubectl exec "${POD}" -n "${APP_NAMESPACE}" -c istio-proxy -- \
  cat /var/run/secrets/workload-spiffe-credentials/certificates.pem \
  | openssl x509 -noout -text \
  | grep -E "Subject Alternative Name|URI"

# Expected: URI:spiffe://<project-id>.svc.id.goog/ns/bank-of-anthos/sa/...

# View mTLS stats
kubectl exec "${POD}" -n "${APP_NAMESPACE}" -c istio-proxy -- \
  pilot-agent request GET stats \
  | grep -E "ssl\.(handshake|connection_error)"
```

Check existing PeerAuthentication policies:

```bash
# Check for PeerAuthentication policies in the namespace
kubectl get peerauthentication -n "${APP_NAMESPACE}"

# Check for mesh-wide policy in istio-system
kubectl get peerauthentication -n istio-system
```

If no explicit policy exists, the fleet default is `PERMISSIVE` (accepts both plaintext and
mTLS), transitioning automatically to `STRICT` once all services in the namespace have sidecars
injected.

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

All service-to-service calls in `bank-of-anthos` now require valid mTLS certificates. Any
attempt to call a service without a sidecar (i.e. from outside the mesh) will be rejected.

Verify the policy was applied:

```bash
kubectl get peerauthentication -n "${APP_NAMESPACE}"
```

### Step 3.5 — View Service Mesh Topology in the Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Service Mesh**.
2. Select the cluster **gke-cluster**.
3. Click the **Service Topology** tab.
4. The topology graph shows each Bank of Anthos service as a node, with directed edges
   representing live traffic flows between services.

Explore the topology:
- Click on **frontend** — observe inbound traffic from `loadgenerator` and outbound calls to
  `userservice`, `contacts`, `balancereader`, `transactionhistory`, and `ledgerwriter`.
- Click on **ledgerwriter** — observe it receiving writes from `frontend` and forwarding reads
  to `ledger-db`.
- Click on **balancereader** — observe it receiving read requests from `frontend` and reading
  from `ledger-db`.

The full call graph is continuously updated by the synthetic traffic from `loadgenerator`,
confirming the correct service communication pattern for the banking application.

### Step 3.6 — Explore Service Mesh Golden Signal Metrics

1. In the Service Mesh console, click on the **frontend** service node.
2. Select the **Metrics** tab.
3. Review the four golden signals:
   - **Request rate (RPS):** Requests per second hitting the frontend
   - **Error rate:** Percentage of requests returning HTTP 5xx
   - **Latency (p50 / p95 / p99):** Response time percentiles
   - **Saturation:** Resource utilisation relative to capacity
4. Click on **ledgerwriter** and compare its gRPC metrics with the frontend's HTTP metrics.

```bash
# gcloud equivalent — list available ASM metrics
gcloud monitoring metrics list \
  --filter="metric.type:istio.io" \
  --project="${PROJECT_ID}" | head -30
```

```bash
# REST API equivalent
curl -s \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/metricDescriptors?filter=metric.type%3Dstarts_with(%22istio.io%22)" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '.metricDescriptors[].type' | head -30
```

### Step 3.7 — Open the Cloud Service Mesh Dashboard

```bash
echo "https://console.cloud.google.com/anthos/meshes?project=${PROJECT_ID}"
```

Explore:
- **Service topology** — visual graph of which services communicate with which
- **Goldilocks metrics** — request rate, error rate, P99 latency per service
- **SLO windows** — current error budget for each microservice

---

## Exercise 4 — Traffic Management

### Objective

Use Istio VirtualService and DestinationRule resources to control traffic flow between Bank of
Anthos services — demonstrating timeouts, retries, and fault injection.

### Step 4.1 — Apply a Timeout to userservice Calls

```yaml
# vs-userservice-timeout.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: userservice
  namespace: bank-of-anthos
spec:
  hosts:
  - userservice
  http:
  - route:
    - destination:
        host: userservice
    timeout: 2s
    retries:
      attempts: 3
      perTryTimeout: 1s
      retryOn: "5xx,reset,connect-failure"
```

```bash
kubectl apply -f vs-userservice-timeout.yaml

kubectl get virtualservice -n "${APP_NAMESPACE}"
```

### Step 4.2 — Inject a Latency Fault on balancereader

Simulate slow responses from balancereader to observe the application's behaviour:

```yaml
# vs-balancereader-delay.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: balancereader
  namespace: bank-of-anthos
spec:
  hosts:
  - balancereader
  http:
  - fault:
      delay:
        percentage:
          value: 50.0
        fixedDelay: 3s
    route:
    - destination:
        host: balancereader
```

```bash
kubectl apply -f vs-balancereader-delay.yaml

# Navigate to the Bank of Anthos UI — balance may load slowly or show "unavailable"
# Check the CSM dashboard for increased latency on balancereader
```

### Step 4.3 — Inject an Abort Fault to Simulate a Service Failure

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

Navigate to the **Pay a Contact** section in the Bank of Anthos UI — the contact list will fail
to load because `contacts` is returning 503 for every call. All other application features
(balance display, transaction history, payments) continue to work because `contacts` is only
used for the contact list feature.

Observe the error rate spike on the `contacts` service node in the Service Mesh topology graph,
then remove the fault:

```bash
kubectl delete virtualservice contacts-fault -n "${APP_NAMESPACE}"
```

### Step 4.4 — Circuit Breaker on ledgerwriter

```yaml
# dr-ledgerwriter-circuit-breaker.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ledgerwriter
  namespace: bank-of-anthos
spec:
  host: ledgerwriter
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    connectionPool:
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
```

```bash
kubectl apply -f dr-ledgerwriter-circuit-breaker.yaml
```

### Step 4.5 — Remove Traffic Rules

```bash
kubectl delete virtualservice userservice balancereader -n "${APP_NAMESPACE}" --ignore-not-found
kubectl delete destinationrule ledgerwriter -n "${APP_NAMESPACE}" --ignore-not-found
```

---

## Exercise 5 — Cloud Monitoring and SLOs

### Objective

Explore the pre-built Cloud Monitoring services and SLOs that the `Bank_GKE` module creates
for each Bank of Anthos microservice.

### Step 5.1 — View Services in Cloud Monitoring

```bash
echo "https://console.cloud.google.com/monitoring/services?project=${PROJECT_ID}"
```

Each microservice appears as a monitored service with auto-detected SLIs (Service Level
Indicators).

### Step 5.2 — View Pre-built SLOs

The module creates a CPU utilisation SLO for each service (95% of requests must be served
with CPU below limit):

**gcloud:**
```bash
gcloud alpha monitoring services list \
  --project="${PROJECT_ID}" \
  --format="table(name, displayName)"
```

**REST API:**
```bash
curl -s \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/services" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.services[] | {name, displayName}'
```

### Step 5.3 — Query Request Metrics

**gcloud (MQL — request count per service):**
```bash
gcloud monitoring metrics list \
  --filter="metric.type:istio" \
  --project="${PROJECT_ID}" \
  | grep -E "request_count|request_duration"
```

**REST API — request count for frontend:**
```bash
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "fetch istio_canonical_service::istio.io/service/server/request_count | within 1h | filter resource.service_name = \"frontend\" | group_by [], sum(val())"
  }' | jq '.timeSeriesData[].pointData[-1].values'
```

### Step 5.4 — Explore the SLO Dashboard

1. Navigate to **Monitoring > Services** and click the **frontend** monitoring service.
2. Click the SLO named **95.0% - CPU Limit Utilization Metric - Calendar day**.
3. Review:
   - **SLO target:** 95% — the goal is that CPU utilisation stays within limits for 95% of
     measurement windows each day
   - **Current compliance:** The percentage of windows meeting the target today
   - **Error budget remaining:** The remaining headroom before breaching the SLO
   - **Error budget burn rate:** How quickly the error budget is being consumed
4. Click **View SLO history** to see compliance over recent days.

```bash
# gcloud equivalent — list SLOs for a monitoring service
gcloud monitoring services list \
  --project="${PROJECT_ID}" \
  --filter="basic_service.service_type=GKE_SERVICE" \
  --format="value(name)" | while read SVC; do
    echo "=== $SVC ==="; \
    gcloud monitoring services service-level-objectives list "$SVC" \
      --project="${PROJECT_ID}" \
      --format="table(name,displayName,goal)"; \
  done
```

```bash
# REST API equivalent — list SLOs for the frontend service
curl -s \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/services/frontend/serviceLevelObjectives" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '.serviceLevelObjectives[] | {name, displayName, goal}'
```

### Step 5.5 — View the Managed Prometheus Endpoint

GKE Managed Service for Prometheus was enabled on the cluster (`monitoring_config.managed_prometheus.enabled = true`).
This scrapes all Kubernetes and Istio metrics automatically.

Verify the Prometheus operator is running:

```bash
kubectl get pods -n gmp-system
```

Pods in the `gmp-system` namespace manage the scraping and forwarding of metrics to Google Cloud
Managed Service for Prometheus.

In the console:
1. Navigate to **Monitoring > Managed Prometheus**.
2. The **Target status** page shows all active scrape targets.
3. Click on **kube-state-metrics** or **node-exporter** to see scrape health.

```bash
# Query CPU utilisation via Cloud Monitoring REST API
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "fetch k8s_container::kubernetes.io/container/cpu/limit_utilization | filter resource.namespace_name = \"bank-of-anthos\" | within 30m | group_by [resource.container_name], mean(val())"
  }' | jq '.timeSeriesData[] | {container: .labelValues[0].stringValue, utilisation: .pointData[-1].values[0].doubleValue}'
```

### Step 5.6 — Create an Alert Policy

**gcloud:**
```bash
gcloud alpha monitoring policies create \
  --display-name="Bank of Anthos - Error Rate Alert" \
  --notification-channels="" \
  --condition-filter="metric.type=\"istio.io/service/server/request_count\" metric.label.\"response_code\"=~\"5..\" resource.label.\"namespace_name\"=\"bank-of-anthos\"" \
  --condition-threshold-value=5 \
  --condition-threshold-duration=60s \
  --condition-threshold-comparison=COMPARISON_GT \
  --project="${PROJECT_ID}"
```

---

## Exercise 6 — GKE Security Posture

### Objective

Explore GKE's built-in security features: the Security Posture Dashboard, vulnerability
scanning, and Workload Identity verification.

### Step 6.1 — Security Posture Dashboard

```bash
echo "https://console.cloud.google.com/kubernetes/security/dashboard?project=${PROJECT_ID}"
```

The dashboard shows:
- **Vulnerability findings** — CVEs in container images (updated periodically)
- **Misconfigurations** — Kubernetes resource configuration issues
- **Concerns** — Policy violations per namespace and workload

### Step 6.2 — Container Image Vulnerability Scanning

The cluster is configured with `VULNERABILITY_BASIC` security mode. View scan results:

**gcloud:**
```bash
gcloud artifacts vulnerabilities list \
  --project="${PROJECT_ID}" \
  --format="table(name, severity, cveId, description)"
```

**REST API:**
```bash
curl -s \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/occurrences?filter=kind%3D%22VULNERABILITY%22" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.occurrences[] | {name, severity: .vulnerability.severity, cve: .vulnerability.shortDescription}' \
  | head -20
```

### Step 6.3 — Verify Workload Identity

Workload Identity allows Kubernetes service accounts to impersonate GCP service accounts without
key files. It is configured via `workload_pool` in the cluster.

```bash
# Confirm the Workload Identity Pool is active
gcloud container clusters describe "${CLUSTER_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="value(workloadIdentityConfig.workloadPool)"
# Expected: <PROJECT_ID>.svc.id.goog
```

```bash
# List service accounts in bank-of-anthos namespace
kubectl get serviceaccounts -n "${APP_NAMESPACE}"

# Check GCP SA binding annotation
kubectl get serviceaccount frontend -n "${APP_NAMESPACE}" -o yaml \
  | grep -A3 "annotations:"

# Verify IAM binding for Workload Identity
gcloud iam service-accounts list \
  --filter="email~bank-of-anthos OR email~gke" \
  --project="${PROJECT_ID}"
```

> **Why this matters:** In a production Bank of Anthos deployment, services that access Google
> Cloud APIs (Cloud SQL, Secret Manager, Pub/Sub) bind a Kubernetes service account to a GCP
> service account via Workload Identity, eliminating the need for service account key files
> mounted in pods.

```bash
# REST API equivalent — get cluster workload identity config
curl -s \
  "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER_NAME}" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '.workloadIdentityConfig'
```

### Step 6.4 — Review All GKE Security Settings

```bash
gcloud container clusters describe "${CLUSTER_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(securityPostureConfig,workloadIdentityConfig,addonsConfig,gatewayApiConfig,monitoringConfig)"
```

Review each section:
- `securityPostureConfig.mode: BASIC` — basic workload misconfiguration scanning
- `securityPostureConfig.vulnerabilityMode: VULNERABILITY_BASIC` — basic image CVE scanning
- `workloadIdentityConfig.workloadPool` — Workload Identity active
- `addonsConfig.httpLoadBalancing.disabled: false` — HTTP load balancing enabled
- `addonsConfig.horizontalPodAutoscaling.disabled: false` — HPA available
- `addonsConfig.gcsFuseCsiDriverConfig.enabled: true` — GCS FUSE CSI driver active
- `gatewayApiConfig.channel: CHANNEL_STANDARD` — Kubernetes Gateway API CRDs installed
- `monitoringConfig.managedPrometheus.enabled: true` — Managed Prometheus active

```bash
# REST API equivalent — get full cluster configuration
curl -s \
  "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER_NAME}" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '{securityPostureConfig, workloadIdentityConfig, addonsConfig, gatewayApiConfig, monitoringConfig}'
```

### Step 6.5 — Review Audit Logs

Every `kubectl` command and API operation generates an entry in Cloud Audit Logs, providing
a complete compliance trail.

In the console, navigate to **Logging > Logs Explorer** and run this query:

```
resource.type="k8s_cluster"
resource.labels.cluster_name="gke-cluster"
protoPayload.methodName=~"(create|delete|patch|update)"
protoPayload.authenticationInfo.principalEmail!=""
```

Expand individual entries to see:
- The Kubernetes resource type and name modified
- The caller identity (service account email or user)
- The operation method (`apps.deployments.patch`, `core.pods.create`, etc.)
- Timestamp and response status code

```bash
# gcloud equivalent
gcloud logging read \
  "protoPayload.serviceName=container.googleapis.com \
   AND protoPayload.methodName=~\"google.container\" \
   AND protoPayload.request.cluster.name=${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" \
  --limit=10 \
  --format=json \
  | jq '.[] | {
    timestamp,
    method: .protoPayload.methodName,
    caller: .protoPayload.authenticationInfo.principalEmail
  }'
```

```bash
# REST API equivalent
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_cluster AND protoPayload.methodName=~\\\"(create|delete|patch)\\\"\",
    \"pageSize\": 10
  }" | jq '.entries[] | .protoPayload | {method: .methodName, caller: .authenticationInfo.principalEmail}'
```

---

## Exercise 7 — GKE Fleet Management

### Objective

Explore GKE Fleet Hub membership and the Cloud Service Mesh Fleet feature that coordinates
the managed Istio control plane.

### Step 7.1 — View the Fleet in the Console

1. Navigate to **Kubernetes Engine > Fleets**.
2. The fleet overview shows all registered clusters.
3. Click the cluster **gke-cluster** to view its membership details.

Review:
- **Membership ID:** `gke-cluster`
- **Location:** global
- **Features:** servicemesh (and configmanagement if enabled)
- **State:** READY

### Step 7.2 — List Fleet Memberships

**gcloud:**
```bash
gcloud container fleet memberships list --project="${PROJECT_ID}"

gcloud container fleet memberships describe "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}"
```

Look for:
- `state.code: READY`
- `authority.issuer` — points to the GKE cluster's OIDC issuer
- `endpoint.gkeCluster.resourceLink` — the full resource path of the cluster

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.resources[] | {name, state: .state.code}'
```

```bash
# REST API — describe individual membership
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/memberships/${CLUSTER_NAME}" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '{name, state: .state.code, authority: .authority.issuer}'
```

### Step 7.3 — Fleet Features

```bash
gcloud container fleet features list --project="${PROJECT_ID}"
```

The `Bank_GKE` module activates the `servicemesh` Fleet feature with `MANAGEMENT_AUTOMATIC`.
This instructs Google to manage the Istio control plane lifecycle (installation, upgrades,
certificate rotation).

Fleet features are managed at the project level and apply configuration consistently across all
enrolled clusters — this is the mechanism that allows a single `gcloud container fleet features`
command to control ASM across dozens of clusters simultaneously.

```bash
# REST API equivalent — list fleet features
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/features" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '.resources[] | {name, state: .resourceState.state}'
```

### Step 7.4 — Inspect the Servicemesh Feature

**gcloud:**
```bash
gcloud container fleet mesh describe --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://gkehub.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/features/servicemesh" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{
    state: .state.state,
    membershipSpecs: (.membershipSpecs | keys),
    dataPlane: (.membershipStates | to_entries[0].value.servicemesh.dataPlaneManagement.state)
  }'
```

---

## Exercise 8 — Anthos Config Management (Optional)

### Objective

If `enable_config_management = true` was set during deployment, explore how Anthos Config
Management (ACM) provides GitOps-driven Kubernetes configuration with drift prevention.

> **Note:** If you deployed with `enable_config_management = false` (the default), you can
> update the deployment via the RAD UI to enable it, or skip to Exercise 9.

### Step 8.1 — Verify Config Management Installation

```bash
gcloud container fleet config-management status \
  --project="${PROJECT_ID}"
```

Expected:
```
Name      Status   Last_Synced_Token  Sync_Branch  Last_Synced_Time
gke-cluster  SYNCED  xxxxxxxx          main         2024-xx-xx
```

### Step 8.2 — Check Config Sync Reconciler

```bash
kubectl get pods -n config-management-system

# config-sync-operator-xxx        1/1  Running
# reconciler-manager-xxx          2/2  Running
# root-reconciler-xxx             4/4  Running
```

### Step 8.3 — View Sync Status

```bash
kubectl get rootsync -n config-management-system
kubectl describe rootsync root-sync -n config-management-system
```

### Step 8.4 — Test Drift Prevention

```bash
# Manually change a label (ACM will revert it)
kubectl label namespace bank-of-anthos test-label=manual-change

# Wait ~30 seconds, then check if the label was reverted
sleep 30
kubectl get namespace bank-of-anthos --show-labels | grep test-label
# Expected: not present (ACM reverted the drift)
```

---

## Exercise 9 — Advanced Operations

### Objective

Explore advanced cluster operations: scaling deployments, rolling updates, cost allocation,
and distributed tracing.

### Step 9.1 — Scale a Deployment

```bash
# Scale balancereader to 3 replicas
kubectl scale deployment balancereader \
  --replicas=3 \
  -n "${APP_NAMESPACE}"

kubectl get pods -n "${APP_NAMESPACE}" -l app=balancereader -w
```

### Step 9.2 — Rolling Update

```bash
# Trigger a rolling update by updating an environment variable
kubectl set env deployment/frontend \
  APP_VERSION=v0.6.7-lab \
  -n "${APP_NAMESPACE}"

# Watch the rolling update
kubectl rollout status deployment/frontend -n "${APP_NAMESPACE}"

# Rollback if needed
kubectl rollout undo deployment/frontend -n "${APP_NAMESPACE}"
```

### Step 9.3 — Cost Allocation Labels

GKE Autopilot reports per-namespace costs via the `goog-k8s-cluster-name` and
`goog-k8s-namespace` labels. View cost allocation:

```bash
echo "https://console.cloud.google.com/billing?project=${PROJECT_ID}"
```

Navigate to **Billing** → **Reports** → filter by label `goog-k8s-namespace=bank-of-anthos`.

### Step 9.4 — Inspect the Load Generator

```bash
kubectl describe deployment loadgenerator -n "${APP_NAMESPACE}"
kubectl logs deployment/loadgenerator -n "${APP_NAMESPACE}" --tail=30
```

Logs show Locust generating a steady stream of requests including GET requests (account summary,
transaction history) and POST requests (deposits, payments). This traffic keeps the Service Mesh
topology graph populated with live call graph data and the SLO compliance dashboard current.

### Step 9.5 — Distributed Tracing with Cloud Trace

CSM auto-instruments traces via the W3C `traceparent` header:

1. Navigate to **Trace > Trace Explorer** in the Google Cloud console.
2. Select a time range and click **Find Traces**.
3. Click on a trace for a `frontend` request to see the distributed trace waterfall across
   `frontend`, `balancereader`, `userservice`, and `transactionhistory`.

Distributed trace spans show the complete call chain for a single end-user request, including
the latency contribution of each microservice.

**gcloud:**
```bash
gcloud trace traces list \
  --project="${PROJECT_ID}" \
  --start-time="$(date -d '1 hour ago' --utc +%Y-%m-%dT%H:%M:%SZ)" \
  --limit=10
```

**REST API:**
```bash
START=$(date -d '1 hour ago' --utc +%Y-%m-%dT%H:%M:%SZ)
curl -s \
  "https://cloudtrace.googleapis.com/v1/projects/${PROJECT_ID}/traces?startTime=${START}&pageSize=5" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.traces[] | {traceId, spans: [.spans[] | {name, startTime, endTime}]}'
```

Navigate to:
```bash
echo "https://console.cloud.google.com/traces/list?project=${PROJECT_ID}"
```

### Step 9.6 — Review VPC Network and Firewall Rules

1. Navigate to **VPC Network > VPC Networks** and click **vpc-network**.
2. Review the subnet CIDR assignments:
   - **Node subnet:** `10.132.0.0/16`
   - **Pod secondary range:** `10.62.128.0/17`
   - **Service secondary range:** `10.64.128.0/20`
3. Navigate to **VPC Network > Firewall** and review the rules created by the module:
   - `fw-allow-lb-hc` — allows Google load balancer health check probes (TCP 80)
   - `fw-allow-nfs-hc` — allows NFS health check probes (TCP 2049)
   - `fw-allow-iap-ssh` — allows IAP tunnel SSH access (TCP 22, source `35.235.240.0/20`)
   - `fw-allow-intra-vpc` — allows all pod-to-pod traffic within the pod CIDR
   - `fw-allow-http-tcp` — allows HTTP/HTTPS access (TCP 80, 443) for tagged instances

```bash
# List subnets and secondary ranges
gcloud compute networks subnets list \
  --filter="network~vpc-network" \
  --project="${PROJECT_ID}" \
  --format="table(name,region,ipCidrRange,secondaryIpRanges.rangeName,secondaryIpRanges.ipCidrRange)"

# List firewall rules
gcloud compute firewall-rules list \
  --filter="network~vpc-network" \
  --project="${PROJECT_ID}" \
  --format="table(name,direction,allowed[].map().firewall_rule().list():label=ALLOW,sourceRanges.list():label=SRC_RANGES)"
```

```bash
# REST API — list subnets
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/regions/${REGION}/subnetworks?filter=network+eq+.*vpc-network" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | {name, ipCidrRange, secondaryIpRanges}'

# REST API — list firewall rules
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/firewalls?filter=network+eq+.*vpc-network" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | {name, direction, allowed, sourceRanges}'
```

### Step 9.7 — View Workload Logs in the GKE Console

1. Navigate to **Kubernetes Engine > Workloads**.
2. Click on **ledgerwriter**.
3. Click the **Logs** tab on the workload details page.

The `ledgerwriter` application logs are displayed inline, showing gRPC transaction write events.
The logs tab provides a quick way to access service logs without navigating to the Logs Explorer
separately.

You can also query logs for any container via Logs Explorer:

1. Navigate to **Logging > Logs Explorer**.
2. Set the resource filter to **Kubernetes Container**.
3. Under **Cluster**, select **gke-cluster**, and under **Namespace**, select **bank-of-anthos**.
4. Filter by a specific container: `resource.labels.container_name="frontend"` to see HTTP
   access logs.

```bash
# gcloud equivalent — tail application logs
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.cluster_name="gke-cluster" AND resource.labels.namespace_name="bank-of-anthos"' \
  --project="${PROJECT_ID}" \
  --limit=20 \
  --format=json \
  | jq '.[] | {
      timestamp: .timestamp,
      container: .resource.labels.container_name,
      message: (.textPayload // (.jsonPayload | tostring))
    }'
```

```bash
# REST API equivalent
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=k8s_container AND resource.labels.cluster_name=gke-cluster AND resource.labels.namespace_name=bank-of-anthos\",
    \"pageSize\": 20,
    \"orderBy\": \"timestamp desc\"
  }" | jq '.entries[] | {timestamp: .timestamp, container: .resource.labels.container_name, message: (.textPayload // (.jsonPayload | tostring))}'
```

---

## 14. Cleanup

Return to the RAD UI and click **Undeploy** on the `Bank_GKE` deployment. This removes the
GKE cluster, VPC, Cloud Service Mesh Fleet feature, and all application resources.

### Manual Cleanup (if needed)

**gcloud:**
```bash
# Delete Fleet membership
gcloud container fleet memberships delete "${CLUSTER_NAME}" \
  --project="${PROJECT_ID}" --quiet

# Delete GKE cluster
gcloud container clusters delete "${CLUSTER_NAME}" \
  --region "${REGION}" --project "${PROJECT_ID}" --quiet

# Delete static IP
gcloud compute addresses list \
  --filter="name~bank" --project="${PROJECT_ID}"
gcloud compute addresses delete <address-name> \
  --global --project "${PROJECT_ID}" --quiet
```

**REST API — delete GKE cluster:**
```bash
curl -s -X DELETE \
  "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

---

## 15. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `region` | string | `us-central1` | GCP region for all resources |
| `gke_cluster` | string | `gke-cluster` | GKE cluster name |
| `create_autopilot_cluster` | bool | `true` | Autopilot cluster (recommended) or Standard |
| `release_channel` | string | `REGULAR` | GKE release channel (`RAPID`/`REGULAR`/`STABLE`) |
| `enable_cloud_service_mesh` | bool | `true` | Enable Fleet Hub CSM feature |
| `cloud_service_mesh_version` | string | `1.23.4-asm.1` | ASM version |
| `deploy_application` | bool | `true` | Deploy Bank of Anthos v0.6.7 |
| `enable_monitoring` | bool | `true` | Enable Cloud Monitoring services and SLOs |
| `enable_config_management` | bool | `false` | Enable Anthos Config Management (ACM) |
| `config_sync_repo` | string | — | Git repository URL for ACM config sync |

### Microservice Summary

| Service | Language | Port | Role |
|---|---|---|---|
| `frontend` | Python/Flask | 80/8080 | Web UI, API gateway |
| `userservice` | Python | 8080 | User authentication and accounts |
| `contacts` | Python | 8080 | Contact list management |
| `ledgerwriter` | Java/Spring | 8080 | Write transactions to ledger |
| `balancereader` | Java | 8080 | Read account balances |
| `transactionhistory` | Java | 8080 | Read transaction history |
| `accounts-db` | PostgreSQL | 5432 | User and account data |
| `ledger-db` | PostgreSQL | 5432 | Ledger transaction data |
| `loadgenerator` | Python/Locust | — | Synthetic load for telemetry |

### Useful Commands Reference

```bash
# Get frontend IP
kubectl get service frontend -n bank-of-anthos

# Check pod health
kubectl get pods -n bank-of-anthos

# View mesh status
gcloud container fleet mesh describe --project="${PROJECT_ID}"

# Proxy status for all sidecars
istioctl proxy-status

# View Cloud Trace
gcloud trace traces list --project="${PROJECT_ID}" --limit=10

# Scale a deployment
kubectl scale deployment <name> --replicas=<n> -n bank-of-anthos

# Rollout status
kubectl rollout status deployment/<name> -n bank-of-anthos

# Tail Envoy logs
kubectl logs <pod> -n bank-of-anthos -c istio-proxy -f
```

### Further Reading

- [Bank of Anthos GitHub repository](https://github.com/GoogleCloudPlatform/bank-of-anthos)
- [Cloud Service Mesh documentation](https://cloud.google.com/service-mesh/docs)
- [Anthos Config Management](https://cloud.google.com/anthos-config-management/docs)
- [GKE Autopilot overview](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Cloud Monitoring for GKE](https://cloud.google.com/stackdriver/docs/solutions/gke)
- [GKE Security Posture](https://cloud.google.com/kubernetes-engine/docs/concepts/security-posture-dashboard)
