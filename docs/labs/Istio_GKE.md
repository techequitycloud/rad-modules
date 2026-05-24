# Istio Service Mesh on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Istio_GKE)**

This lab guide walks you through the full lifecycle of deploying, configuring, and observing a
service mesh on Google Kubernetes Engine using **open-source Istio** — installed via `istioctl`
on a GKE Standard cluster. You will use the **Istio_GKE** module to provision the platform, then
explore traffic management, security, and observability capabilities hands-on. The module supports
both **sidecar mode** (Envoy per-pod) and **ambient mode** (ztunnel per-node).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Verify the Istio Installation](#exercise-1--verify-the-istio-installation)
6. [Exercise 2 — Explore the Bookinfo Application](#exercise-2--explore-the-bookinfo-application)
7. [Exercise 3 — Traffic Management (Canary and Weighted Routing)](#exercise-3--traffic-management-canary-and-weighted-routing)
8. [Exercise 4 — Fault Injection and Resilience](#exercise-4--fault-injection-and-resilience)
9. [Exercise 5 — Mutual TLS and PeerAuthentication](#exercise-5--mutual-tls-and-peerauthentication)
10. [Exercise 6 — Authorization Policies (L7 Access Control)](#exercise-6--authorization-policies-l7-access-control)
11. [Exercise 7 — Observability: Kiali, Grafana, Jaeger, and Prometheus](#exercise-7--observability-kiali-grafana-jaeger-and-prometheus)
12. [Exercise 8 — Ambient Mode (ztunnel and Waypoint Proxies)](#exercise-8--ambient-mode-ztunnel-and-waypoint-proxies)
13. [Cleanup](#13-cleanup)
14. [Reference](#14-reference)

---

## 1. Overview

### What Is Istio?

Istio is an open-source **service mesh** that adds a transparent layer of infrastructure to
distributed applications. It manages service-to-service communication in Kubernetes clusters
without requiring changes to application code.

Key capabilities:

| Capability | What It Enables |
|---|---|
| **Traffic Management** | Canary releases, A/B testing, circuit breaking, fault injection, retries |
| **Security** | Mutual TLS (mTLS) between all services, L7 authorization policies, JWT validation |
| **Observability** | Automatic telemetry: request metrics, distributed traces, service topology |
| **Resilience** | Timeouts, health-aware load balancing, outlier detection |

### Sidecar Mode vs Ambient Mode

The `Istio_GKE` module supports two data plane architectures:

| Mode | Data Plane | Resource Overhead | L7 Features |
|---|---|---|---|
| **Sidecar** | Envoy proxy injected into every pod | ~30–50% additional CPU/memory per pod | Full (built-in) |
| **Ambient** | ztunnel DaemonSet on each node + optional waypoint proxy per namespace | ~5% overhead at node level | Requires waypoint proxy |

Set `install_ambient_mesh = false` (default) for sidecar mode or `install_ambient_mesh = true`
for ambient mode.

### Observability Stack

The module installs four open-source observability tools automatically:

| Tool | Port | Purpose |
|---|---|---|
| **Kiali** | 20001 | Service topology graph, traffic flow visualization |
| **Grafana** | 3000 | Istio metrics dashboards (RED metrics per service) |
| **Jaeger** | 16686 | Distributed tracing |
| **Prometheus** | 9090 | Metrics storage and querying |

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  GKE Standard Cluster (Istio_GKE module)                           │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  istio-system namespace                                        │ │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌─────────┐ │ │
│  │  │  istiod    │  │  Ingress   │  │  Kiali     │  │Grafana/ │ │ │
│  │  │ (control   │  │  Gateway   │  │  (topology)│  │Jaeger/  │ │ │
│  │  │  plane)    │  │  (L7 LB)   │  │            │  │Prom     │ │ │
│  │  └────────────┘  └────────────┘  └────────────┘  └─────────┘ │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  default namespace (label: istio-injection=enabled)            │ │
│  │                                                                │ │
│  │  ┌──────────────────────┐   ┌──────────────────────┐          │ │
│  │  │  productpage pod     │   │  reviews pod         │          │ │
│  │  │  [app + envoy proxy] │◄──►  [app + envoy proxy] │          │ │
│  │  └──────────────────────┘   └──────────────────────┘          │ │
│  │  ┌──────────────────────┐   ┌──────────────────────┐          │ │
│  │  │  details pod         │   │  ratings pod         │          │ │
│  │  │  [app + envoy proxy] │   │  [app + envoy proxy] │          │ │
│  │  └──────────────────────┘   └──────────────────────┘          │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  Istio_GKE
    install_ambient_mesh = false  →  Sidecar mode (Envoy per-pod)
    install_ambient_mesh = true   →  Ambient mode (ztunnel per-node)
    deploy_application   = true   →  Bookinfo sample app in default namespace
    istio_version        = "1.24.2"
```

### Bookinfo Application Architecture

The Bookinfo sample application is a four-microservice polyglot app used throughout this lab:

```
Browser → Ingress Gateway → productpage (Python)
                               ├── details (Ruby)
                               └── reviews (Java) [v1/v2/v3]
                                      └── ratings (Node.js)
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

**Access to the RAD UI** with permission to deploy the `Istio_GKE` module in the target GCP project.

### GCP Permissions

```
roles/owner                        # or the following fine-grained set:
roles/container.admin
roles/compute.networkAdmin
roles/iam.serviceAccountAdmin
```

### Environment Variables

Set these once; all commands in this lab reference them:

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export CLUSTER_NAME="istio-gke-cluster"   # matches gke_cluster variable
export ISTIO_VERSION="1.24.2"

gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${REGION}"
```

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `Istio_GKE` module via the RAD UI. In the variable form, set the following key
variables:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `region` | `us-central1` | GCP region |
| `istio_version` | `1.24.2` | Istio release to install |
| `install_ambient_mesh` | `false` | Use `true` for ambient mode |
| `deploy_application` | `true` | Deploy Bookinfo sample app |
| `gke_cluster` | `istio-gke-cluster` | GKE cluster name |

Click **Deploy** and wait for provisioning to complete (approximately 15–20 minutes).

> **What this provisions:** A GKE Standard cluster with two preemptible e2-standard-2 nodes,
> VPC network, Istio installed via `istioctl` with the default or ambient profile, the Bookinfo
> sample application in the `default` namespace, and the full observability stack (Prometheus,
> Grafana, Jaeger, Kiali) in `istio-system`.

### 4.2 Configure kubectl

```bash
gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}"

kubectl cluster-info
kubectl get nodes
```

---

## Exercise 1 — Verify the Istio Installation

### Objective

Confirm that Istio is running correctly, the control plane is healthy, and the observability
components are deployed.

### Step 1.1 — Check Istio Control Plane

```bash
# Verify istiod (Istio control plane) is running
kubectl get pods -n istio-system

# Expected pods (sidecar mode):
# istiod-xxxxxxx-xxxxx          1/1  Running
# istio-ingressgateway-xxxxx    1/1  Running
# prometheus-xxxxx              2/2  Running
# grafana-xxxxx                 1/1  Running
# jaeger-xxxxx                  1/1  Running
# kiali-xxxxx                   1/1  Running
```

### Step 1.2 — Check Istio Version

```bash
istioctl version

# Expected output:
# client version: 1.24.2
# control plane version: 1.24.2
# data plane version: 1.24.2 (X proxies)
```

### Step 1.3 — Verify Sidecar Injection Webhook

```bash
kubectl get mutatingwebhookconfigurations | grep istio
# Should show: istio-sidecar-injector

kubectl get namespace default --show-labels
# Should include: istio-injection=enabled
```

### Step 1.4 — Analyse Mesh Configuration

```bash
istioctl analyze

# Lists any configuration issues in the mesh.
# A healthy installation returns: ✔ No validation issues found.
```

### Step 1.5 — Check Proxy Status

```bash
istioctl proxy-status

# Lists all sidecar proxies synced to the control plane:
# NAME                    CLUSTER  CDS  LDS  EDS  RDS  ECDS  ISTIOD
# details-v1-xxx.default  ...      SYNCED SYNCED SYNCED SYNCED ...
```

---

## Exercise 2 — Explore the Bookinfo Application

### Objective

Access the Bookinfo sample application through the Istio Ingress Gateway and understand its
multi-version microservice architecture.

### Step 2.1 — Get the Ingress Gateway IP

```bash
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Ingress Gateway IP: ${INGRESS_IP}"
```

### Step 2.2 — Access Bookinfo

```bash
# Test the product page
curl -s "http://${INGRESS_IP}/productpage" | grep "<title>"
# Expected: <title>Simple Bookstore App</title>

# Open in browser
echo "http://${INGRESS_IP}/productpage"
```

Refresh the page multiple times — the **Book Reviews** section cycles through three versions:
- **v1**: No stars (no call to ratings service)
- **v2**: Black stars
- **v3**: Red stars

### Step 2.3 — Inspect the Mesh Resources

```bash
# View all Bookinfo pods (each should show 2/2 READY in sidecar mode)
kubectl get pods -o wide

# View the Istio Gateway resource
kubectl get gateway
kubectl describe gateway bookinfo-gateway

# View the VirtualService routing to productpage
kubectl get virtualservice
kubectl describe virtualservice bookinfo
```

### Step 2.4 — Inspect the Envoy Sidecar

```bash
POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

# Containers in the pod (should show: productpage, istio-proxy)
kubectl get pod "${POD}" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n'

# Envoy proxy version
kubectl exec "${POD}" -c istio-proxy -- \
  pilot-agent request GET server_info | jq '.version'

# Active listeners (what traffic the sidecar intercepts)
kubectl exec "${POD}" -c istio-proxy -- \
  pilot-agent request GET listeners | jq '.[].name'
```

### Step 2.5 — View Full Proxy Configuration

```bash
# Full Envoy config for the productpage sidecar
istioctl proxy-config all "${POD}"

# Only clusters (upstream services this sidecar knows about)
istioctl proxy-config cluster "${POD}"

# Active routes
istioctl proxy-config route "${POD}"
```

---

## Exercise 3 — Traffic Management (Canary and Weighted Routing)

### Objective

Use Istio `VirtualService` and `DestinationRule` resources to control traffic between the three
versions of the `reviews` service.

### Background: Istio Traffic Management Resources

| Resource | Purpose |
|---|---|
| `DestinationRule` | Defines named subsets of a service (v1, v2, v3) and load balancing policy |
| `VirtualService` | Attaches routing rules to a Kubernetes Service — weight, headers, retry, timeout |

### Step 3.1 — Create a DestinationRule for All Services

```yaml
# destination-rules-all.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: productpage
spec:
  host: productpage
  subsets:
  - name: v1
    labels:
      version: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ratings
spec:
  host: ratings
  subsets:
  - name: v1
    labels:
      version: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: details
spec:
  host: details
  subsets:
  - name: v1
    labels:
      version: v1
```

```bash
kubectl apply -f destination-rules-all.yaml
kubectl get destinationrules
```

### Step 3.2 — Pin All Traffic to reviews v1

```yaml
# virtual-service-all-v1.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
```

```bash
kubectl apply -f virtual-service-all-v1.yaml
```

Refresh `http://${INGRESS_IP}/productpage` multiple times — you should only see v1 (no stars).

### Step 3.3 — Canary: 80% v1 / 20% v3

```yaml
# virtual-service-reviews-80-20.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 80
    - destination:
        host: reviews
        subset: v3
      weight: 20
```

```bash
kubectl apply -f virtual-service-reviews-80-20.yaml

# Generate load to observe the split
for i in $(seq 1 50); do
  curl -s -o /dev/null "http://${INGRESS_IP}/productpage"
done
```

### Step 3.4 — Header-Based Routing (Test User)

Route a specific test user always to v2 (black stars) while everyone else sees v1:

```yaml
# virtual-service-reviews-user-v2.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

```bash
kubectl apply -f virtual-service-reviews-user-v2.yaml
```

Log into the Bookinfo UI as `jason` (any password) — you should see black stars (v2). Log out
and you see no stars (v1).

### Step 3.5 — Promote to 100% v3

```bash
kubectl patch virtualservice reviews \
  --type='merge' \
  -p '{
    "spec": {
      "http": [{
        "route": [{
          "destination": {"host": "reviews", "subset": "v3"},
          "weight": 100
        }]
      }]
    }
  }'
```

---

## Exercise 4 — Fault Injection and Resilience

### Objective

Use Istio's fault injection to simulate network failures and test the application's resilience.

### Step 4.1 — Inject a 7-Second Delay on Ratings

```yaml
# virtual-service-ratings-delay.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percentage:
          value: 100.0
        fixedDelay: 7s
    route:
    - destination:
        host: ratings
        subset: v1
```

```bash
kubectl apply -f virtual-service-ratings-delay.yaml
```

Access the product page — you will notice a timeout after ~6 seconds (the reviews service has
a 6s timeout to ratings). This demonstrates how latency in one service propagates to the
client even without an error code.

### Step 4.2 — Inject HTTP Abort Faults

```yaml
# virtual-service-ratings-abort.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      abort:
        percentage:
          value: 100.0
        httpStatus: 500
    route:
    - destination:
        host: ratings
        subset: v1
```

```bash
kubectl apply -f virtual-service-ratings-abort.yaml
# The reviews section shows "Ratings service is currently unavailable"
```

### Step 4.3 — Add Retries to details Service

```yaml
# virtual-service-details-retry.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: details
spec:
  hosts:
  - details
  http:
  - route:
    - destination:
        host: details
        subset: v1
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "5xx,reset,connect-failure,retriable-4xx"
    timeout: 10s
```

```bash
kubectl apply -f virtual-service-details-retry.yaml
```

### Step 4.4 — Remove Fault Injection

```bash
kubectl delete virtualservice ratings
# Or re-apply a clean VirtualService without the fault block
```

---

## Exercise 5 — Mutual TLS and PeerAuthentication

### Objective

Enforce strict mutual TLS (mTLS) between all services in the default namespace and verify
encrypted communication using Envoy proxy stats.

### Background

Istio issues X.509 certificates to each workload sidecar using the SPIFFE standard. mTLS is
negotiated transparently by Envoy sidecars — application code has no awareness of encryption.

```
Service A Pod                     Service B Pod
┌─────────────────────┐           ┌─────────────────────┐
│  App container      │           │  App container      │
│  (plain HTTP)       │           │  (plain HTTP)       │
├─────────────────────┤           ├─────────────────────┤
│  Envoy sidecar      │◄─mTLS────►│  Envoy sidecar      │
│  (cert: spiffe://   │           │  (cert: spiffe://   │
│   cluster.local/...) │           │   cluster.local/...) │
└─────────────────────┘           └─────────────────────┘
```

### Step 5.1 — Check Default mTLS Mode

```bash
POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

# Check current auth policy
istioctl x authz check "${POD}"

# Inspect the workload certificate
kubectl exec "${POD}" -c istio-proxy -- \
  cat /var/run/secrets/workload-spiffe-credentials/certificates.pem \
  | openssl x509 -noout -text \
  | grep -E "Subject Alternative Name|URI"
# Expected: URI:spiffe://cluster.local/ns/default/sa/bookinfo-productpage
```

### Step 5.2 — Apply Strict PeerAuthentication

```yaml
# peer-auth-strict.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f peer-auth-strict.yaml
kubectl get peerauthentication
```

### Step 5.3 — Test mTLS Enforcement

```bash
# This should FAIL — plain HTTP from a pod without a sidecar
kubectl run plain-test \
  --image=curlimages/curl:latest \
  --restart=Never \
  --rm -it \
  -n kube-system \
  -- curl -v --max-time 5 http://productpage.default.svc.cluster.local:9080

# This should SUCCEED — sidecar-equipped pod in the mesh
kubectl run mesh-test \
  --image=curlimages/curl:latest \
  --restart=Never \
  --rm -it \
  -- curl -s http://productpage:9080/productpage | head -5
```

### Step 5.4 — View mTLS Stats

```bash
POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

kubectl exec "${POD}" -c istio-proxy -- \
  pilot-agent request GET stats \
  | grep -E "ssl\.(handshake|connection_error|fail)"
```

---

## Exercise 6 — Authorization Policies (L7 Access Control)

### Objective

Use Istio `AuthorizationPolicy` resources to enforce fine-grained, per-route access control
between services — without touching application code.

### Step 6.1 — Deny All Traffic by Default

```yaml
# deny-all.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}   # empty spec = deny all
```

```bash
kubectl apply -f deny-all.yaml

# All requests should now return 403
curl -s -o /dev/null -w "%{http_code}" "http://${INGRESS_IP}/productpage"
# Expected: 403
```

### Step 6.2 — Allow Ingress Gateway to productpage

```yaml
# allow-productpage.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ingress-productpage
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"
    to:
    - operation:
        methods: ["GET"]
```

```bash
kubectl apply -f allow-productpage.yaml
```

### Step 6.3 — Allow productpage to Call details and reviews

```yaml
# allow-services.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-productpage-details
  namespace: default
spec:
  selector:
    matchLabels:
      app: details
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/default/sa/bookinfo-productpage"
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-productpage-reviews
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/default/sa/bookinfo-productpage"
```

```bash
kubectl apply -f allow-services.yaml
```

### Step 6.4 — Allow reviews to Call ratings Only

```yaml
# allow-reviews-ratings.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-reviews-ratings
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/default/sa/bookinfo-reviews"
    to:
    - operation:
        methods: ["GET"]
```

```bash
kubectl apply -f allow-reviews-ratings.yaml

# Verify policy decisions
kubectl exec "$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')" \
  -c istio-proxy -- \
  pilot-agent request GET stats \
  | grep -E "rbac\.(allowed|denied)"
```

### Step 6.5 — Cleanup Authorization Policies

```bash
kubectl delete authorizationpolicies --all
```

---

## Exercise 7 — Observability: Kiali, Grafana, Jaeger, and Prometheus

### Objective

Explore the four open-source observability tools installed by the `Istio_GKE` module and
understand how they provide complementary views of service mesh behaviour.

### Step 7.1 — Generate Load for Telemetry

Before opening dashboards, generate traffic to populate metrics and traces:

```bash
for i in $(seq 1 200); do
  curl -s -o /dev/null "http://${INGRESS_IP}/productpage"
  sleep 0.2
done
```

Or use fortio for sustained load:

```bash
kubectl run fortio \
  --image=fortio/fortio:latest \
  --restart=Never \
  --rm -it \
  -- load -c 5 -qps 10 -t 120s "http://${INGRESS_IP}/productpage"
```

### Step 7.2 — Kiali: Service Topology Graph

```bash
# Port-forward to Kiali
kubectl port-forward svc/kiali 20001:20001 -n istio-system &

# Open: http://localhost:20001
```

In Kiali:
1. Navigate to **Graph** → select the `default` namespace
2. Observe the service dependency graph with live traffic flow
3. Click any edge to see request rate, error rate, and latency
4. Toggle **Traffic Animation** to see request flow in real time
5. Navigate to **Workloads** to inspect individual pod health

### Step 7.3 — Grafana: RED Metrics Dashboards

```bash
kubectl port-forward svc/grafana 3000:3000 -n istio-system &

# Open: http://localhost:3000
```

In Grafana:
1. Navigate to **Dashboards** → **Istio** folder
2. Open **Istio Service Dashboard** — select the `reviews` service
   - **Request Volume**: requests per second
   - **Success Rate**: percentage of non-5xx responses
   - **Request Duration**: P50, P90, P99 latency percentiles
3. Open **Istio Workload Dashboard** to compare individual pod metrics

### Step 7.4 — Jaeger: Distributed Tracing

```bash
kubectl port-forward svc/tracing 16686:80 -n istio-system &

# Open: http://localhost:16686
```

In Jaeger:
1. Select service `productpage.default` from the dropdown
2. Click **Find Traces**
3. Click a trace to expand the span waterfall
4. Identify which service contributes the most latency
5. Trace IDs are propagated via the `x-b3-traceid` header automatically by Envoy

### Step 7.5 — Prometheus: Raw Metrics

```bash
kubectl port-forward svc/prometheus 9090:9090 -n istio-system &

# Open: http://localhost:9090
```

Sample PromQL queries:

```promql
# Total requests per service
sum(istio_requests_total) by (destination_service_name)

# Request rate over 5 minutes
rate(istio_requests_total[5m])

# 99th percentile latency per service
histogram_quantile(0.99,
  sum(rate(istio_request_duration_milliseconds_bucket[5m]))
  by (destination_service_name, le)
)

# Error rate (5xx responses)
sum(rate(istio_requests_total{response_code=~"5.*"}[5m]))
  by (destination_service_name)
  /
sum(rate(istio_requests_total[5m]))
  by (destination_service_name)
```

### Step 7.6 — Envoy Admin Interface

```bash
POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward "${POD}" 15000:15000 &

# Query Envoy stats directly
curl -s http://localhost:15000/stats/prometheus \
  | grep -E "istio_requests_total|upstream_rq"

# View Envoy configuration
curl -s http://localhost:15000/config_dump | jq '.configs | length'
```

---

## Exercise 8 — Ambient Mode (ztunnel and Waypoint Proxies)

### Objective

If `install_ambient_mesh = true` was set during deployment, explore how ambient mode provides
L4 mTLS and L7 policies without per-pod Envoy sidecars.

> **Note:** If you deployed with `install_ambient_mesh = false` (the default), skip to
> [Cleanup](#13-cleanup). Ambient mode requires a fresh deployment with the flag enabled.

### Step 8.1 — Verify ztunnel DaemonSet

```bash
# ztunnel runs on every node (one pod per node)
kubectl get daemonset ztunnel -n istio-system
kubectl get pods -n istio-system -l app=ztunnel -o wide

# Verify no sidecars in application pods (1/1 READY, not 2/2)
kubectl get pods
```

### Step 8.2 — Confirm Ambient Mode Label

```bash
kubectl get namespace default --show-labels
# Should include: istio.io/dataplane-mode=ambient
```

### Step 8.3 — Verify Waypoint Proxy

```bash
# The module deploys a waypoint proxy for the default namespace
kubectl get gateway -n default

# Check waypoint proxy status
istioctl waypoint status
```

### Step 8.4 — mTLS in Ambient Mode

With ambient mode, ztunnel handles L4 mTLS transparently. Verify:

```bash
# Check ztunnel logs for CONNECT tunnels (mTLS)
kubectl logs -n istio-system -l app=ztunnel --tail=20 \
  | grep -E "CONNECT|tls"

# Proxy status shows ztunnel-managed workloads
istioctl proxy-status
```

### Step 8.5 — L7 Policy via Waypoint Proxy

Authorization policies require the waypoint proxy for L7 enforcement in ambient mode:

```yaml
# ambient-authz.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-reviews-only
  namespace: default
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: waypoint
  selector:
    matchLabels:
      app: ratings
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/default/sa/bookinfo-reviews"
```

```bash
kubectl apply -f ambient-authz.yaml
```

---

## 13. Cleanup

Return to the RAD UI, navigate to your `Istio_GKE` deployment, and click **Undeploy** (or
**Delete**). This removes the GKE cluster, VPC network, and all Istio components.

### Manual Cleanup (if needed)

```bash
# Delete GKE cluster
gcloud container clusters delete "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --quiet

# Release reserved static IPs
gcloud compute addresses list \
  --filter="name~istio" \
  --project="${PROJECT_ID}"
```

Kill port-forward processes:

```bash
pkill -f "kubectl port-forward"
```

---

## 14. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `region` | string | `us-central1` | GCP region for all resources |
| `gke_cluster` | string | `gke-cluster` | GKE cluster name |
| `istio_version` | string | `1.24.2` | Open-source Istio version to install |
| `install_ambient_mesh` | bool | `false` | `true` for ambient mode, `false` for sidecar |
| `deploy_application` | bool | `true` | Deploy Bookinfo sample application |
| `create_network` | bool | `true` | Create a new VPC; set `false` to use existing |
| `create_cluster` | bool | `true` | Create a new GKE cluster; set `false` to use existing |

### Istio Resource Reference

| Resource | API Group | Purpose |
|---|---|---|
| `VirtualService` | `networking.istio.io/v1beta1` | Traffic routing rules (weight, headers, fault injection) |
| `DestinationRule` | `networking.istio.io/v1beta1` | Subsets, load balancing, circuit breaking |
| `Gateway` | `networking.istio.io/v1beta1` | Inbound/outbound traffic at mesh boundary |
| `PeerAuthentication` | `security.istio.io/v1beta1` | mTLS mode per namespace or workload |
| `AuthorizationPolicy` | `security.istio.io/v1beta1` | L7 allow/deny based on identity, path, method |
| `RequestAuthentication` | `security.istio.io/v1beta1` | JWT issuer validation |

### Useful Commands Reference

```bash
# Istio status
istioctl version
istioctl proxy-status
istioctl analyze

# Proxy config for a pod
istioctl proxy-config cluster <pod-name>
istioctl proxy-config route <pod-name>
istioctl proxy-config listener <pod-name>

# Check auth policy for a pod
istioctl x authz check <pod-name>

# Tail Envoy access logs
kubectl logs <pod> -c istio-proxy -f

# Port-forward observability tools
kubectl port-forward svc/kiali 20001:20001 -n istio-system
kubectl port-forward svc/grafana 3000:3000 -n istio-system
kubectl port-forward svc/tracing 16686:80 -n istio-system
kubectl port-forward svc/prometheus 9090:9090 -n istio-system
```

### Further Reading

- [Istio traffic management concepts](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio security concepts (mTLS, AuthorizationPolicy)](https://istio.io/latest/docs/concepts/security/)
- [Istio ambient mode overview](https://istio.io/latest/docs/ops/ambient/)
- [Bookinfo sample application](https://istio.io/latest/docs/examples/bookinfo/)
- [Kiali documentation](https://kiali.io/docs/)
- [GKE with open-source Istio](https://cloud.google.com/kubernetes-engine/docs/tutorials/installing-istio)
