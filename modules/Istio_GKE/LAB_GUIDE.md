# Istio on GKE — Lab Guide

## Overview

This guide walks through the full Istio on GKE lab using the `Istio_GKE`
Terraform module. The module automates all GCP infrastructure setup, installs
open-source Istio via `istioctl`, and optionally deploys the Bookinfo sample
application. Exploration of traffic management, observability, and security
features is performed manually.

**Estimated time:** 45–75 minutes (includes ~15–20 minutes of background
provisioning)

### What Terraform Automates

- Enabling required GCP APIs (container.googleapis.com and others)
- Creating a VPC network, subnet, Cloud Router, and NAT gateway
- Creating firewall rules (IAP SSH, intra-VPC, load balancer health checks)
- Provisioning a GKE Standard cluster with a preemptible node pool
- Creating a dedicated GKE service account with the required IAM roles
- Installing open-source Istio via `istioctl` in either **sidecar** or
  **ambient** mode
- Installing the Istio observability stack: Prometheus, Grafana, Jaeger,
  and Kiali
- Optionally deploying the Istio **Bookinfo** sample application
- Retrieving the Istio ingress gateway external IP

### What You Do Manually

- Configuring `kubectl` to reach the GKE cluster
- Exploring the Bookinfo application via the ingress gateway
- Exploring traffic management: routing rules, retries, fault injection,
  traffic shifting
- Exploring observability: Kiali service graph, Grafana dashboards, Jaeger
  traces, Prometheus metrics
- Exploring security: mutual TLS (mTLS) enforcement, authorization policies
- Exploring ambient mode: waypoint proxies, ztunnel traffic capture
- Tearing down all resources with `tofu destroy`

---

## REST API Overview

Most actions in this lab use `kubectl` and `istioctl`. Some GCP-level actions
can also be performed via the Google Cloud API (`container.googleapis.com`).

**Set these shell variables once before running any command:**

```bash
export PROJECT="your-project-id"
export REGION="us-central1"
export CLUSTER="gke-cluster"
export TOKEN=$(gcloud auth print-access-token)
```

**Get cluster credentials:**

```bash
gcloud container clusters get-credentials $CLUSTER \
  --region $REGION \
  --project $PROJECT
```

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 0.13 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| GCP Project | Must already exist with billing enabled |
| Terraform resource provisioning Service Account | Must hold `roles/owner` on the target project |
| Caller permissions | The identity running `tofu apply` must hold `roles/iam.serviceAccountTokenCreator` on the service account above |

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/Istio_GKE
```

Create a `terraform.tfvars` file. All values shown are module defaults —
override only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `project_id` | *(required — no default)* | GCP project ID where all resources are created |
| `gcp_region` | `us-central1` | Region for the GKE cluster and VPC |
| `istio_version` | `1.24.2` | Open-source Istio version to install |
| `install_ambient_mesh` | `false` | Set to `true` for ambient mode; `false` for sidecar mode |
| `deploy_application` | `true` | Set to `true` to deploy the Bookinfo sample application |
| `gke_cluster` | `gke-cluster` | Name for the GKE cluster |
| `release_channel` | `REGULAR` | GKE release channel |

Minimum `terraform.tfvars` example:

```hcl
project_id = "your-project-id"
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
| VPC and firewall rules | 1–2 minutes |
| GKE cluster | 8–12 minutes |
| Istio installation | 3–5 minutes |
| Bookinfo deployment (if enabled) | 1–2 minutes |

### Step 1.3 — Record Terraform Outputs

When `apply` completes, note the following outputs:

```bash
tofu output
```

| Output | Used in |
|---|---|
| `cluster_credentials_cmd` | Phase 2 — configure kubectl |
| `external_ip` | Phase 3 — access the Bookinfo application |
| `project_id` | Reference throughout |
| `deployment_id` | Reference throughout |

---

## Phase 2 — Configure kubectl Access [MANUAL]

### Step 2.1 — Fetch Cluster Credentials

Run the command from the `cluster_credentials_cmd` output, or use:

```bash
gcloud container clusters get-credentials gke-cluster \
  --region us-central1 \
  --project your-project-id
```

### Step 2.2 — Verify Cluster Access

```bash
kubectl get nodes
kubectl get namespaces
```

**Expected result:** Cluster nodes are listed with status `Ready`. The
`istio-system` namespace is present alongside the default Kubernetes
namespaces.

### Step 2.3 — Verify Istio Installation

```bash
kubectl get pods -n istio-system
```

**Expected result:** Pods for `istiod`, `istio-ingressgateway`, `prometheus`,
`grafana`, `jaeger`, and `kiali` are all in `Running` state.

Check the installed Istio version:

```bash
istioctl version
```

---

## Phase 3 — Explore the Bookinfo Application [MANUAL]

The Bookinfo application is a polyglot microservices demo composed of four
services: `productpage` (Python), `details` (Ruby), `reviews` (Java, three
versions), and `ratings` (Node.js). Traffic flows through the Istio ingress
gateway into the mesh.

### Step 3.1 — Access the Bookinfo Application

1. Get the external IP from the Terraform output:

```bash
tofu output external_ip
```

2. Open a browser and navigate to:

```
http://<external_ip>/productpage
```

**Expected result:** The Bookinfo product page loads, showing book details and
reviews. Refreshing the page cycles through the three versions of the reviews
service — no stars (v1), black stars (v2), and red stars (v3) — because no
routing rules are applied yet.

### Step 3.2 — Inspect the Bookinfo Resources

```bash
kubectl get pods -n default
kubectl get services -n default
kubectl get gateway -n default
kubectl get virtualservice -n default
```

**Expected result:** Pods for all four Bookinfo services are running. An Istio
`Gateway` and `VirtualService` expose the `productpage` service through the
ingress gateway.

In sidecar mode, each pod has two containers — the application container and
the injected Envoy sidecar:

```bash
kubectl describe pod -l app=productpage -n default
```

---

## Phase 4 — Traffic Management [MANUAL]

Istio's traffic management layer uses `VirtualService` and
`DestinationRule` resources to control how traffic is routed within the mesh.

### Step 4.1 — Pin Traffic to a Single Reviews Version

Apply a destination rule that defines the three subsets of the `reviews`
service, then a virtual service that routes all traffic to `v1`:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
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
EOF

kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
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
EOF
```

Refresh the Bookinfo product page several times.

**Expected result:** The reviews section always shows no stars (v1). Traffic is
fully pinned to the first version of the reviews service.

### Step 4.2 — Traffic Shifting (Canary)

Gradually shift traffic from v1 to v3 using weighted routing:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
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
EOF
```

Refresh the Bookinfo product page 10 times.

**Expected result:** Approximately 20% of requests show red stars (v3), and
80% show no stars (v1). This simulates a canary release without any application
code changes.

### Step 4.3 — Fault Injection

Inject a 7-second delay for the `ratings` service to test application
resilience:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
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
        port:
          number: 9080
EOF
```

Open the Bookinfo product page and observe the delay before the ratings
section loads.

**Expected result:** The page takes approximately 7 seconds to fully render,
demonstrating how a downstream service timeout affects the end user experience.

Clean up the fault injection:

```bash
kubectl delete virtualservice ratings
```

### Step 4.4 — Retries

Configure automatic retries for the `details` service:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
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
        port:
          number: 9080
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: gateway-error,connect-failure,retriable-4xx
EOF
```

**Expected result:** The VirtualService is applied. The Envoy sidecar now
automatically retries failed requests to the details service up to 3 times,
improving reliability without any changes to the application code.

Clean up routing rules when done:

```bash
kubectl delete virtualservice reviews details
kubectl delete destinationrule reviews
```

---

## Phase 5 — Observability [MANUAL]

Istio automatically collects telemetry — metrics, traces, and access logs —
from all services in the mesh without any application code instrumentation.

### Step 5.1 — Access Kiali (Service Graph)

Forward the Kiali port to your local machine:

```bash
kubectl port-forward svc/kiali 20001:20001 -n istio-system
```

Open `http://localhost:20001` in your browser.

1. Click **Graph** in the left navigation.
2. Select the `default` namespace from the namespace dropdown.
3. Generate some traffic by refreshing the Bookinfo product page several
   times.
4. Click **Refresh** in the Kiali UI.

**Expected result:** A live service graph shows the Bookinfo microservices,
the traffic flow between them, and per-edge request rates. Edges are coloured
by error rate. Click any service node to view its health, traffic metrics, and
configuration.

### Step 5.2 — Access Grafana (Metrics Dashboards)

Forward the Grafana port:

```bash
kubectl port-forward svc/grafana 3000:3000 -n istio-system
```

Open `http://localhost:3000` in your browser (no login required by default).

1. Click **Dashboards** in the left navigation.
2. Open the **Istio Service Dashboard**.
3. Select the `productpage.default.svc.cluster.local` service from the
   **Service** dropdown.

**Expected result:** Real-time metrics are displayed including request volume,
error rate (%), P50/P90/P99 request latency, and TCP connection counts.
Switch to the **Istio Workload Dashboard** to view the same metrics scoped to
individual pods rather than services.

### Step 5.3 — Access Jaeger (Distributed Tracing)

Forward the Jaeger port:

```bash
kubectl port-forward svc/tracing 16686:80 -n istio-system
```

Open `http://localhost:16686` in your browser.

1. In the **Service** dropdown, select `productpage.default`.
2. Click **Find Traces**.
3. Click any trace to open the waterfall view.

**Expected result:** Each trace shows the full end-to-end request path through
all Bookinfo microservices, including per-service latency, upstream calls, and
any errors. This is Istio-generated distributed tracing with no instrumentation
required in the application code.

### Step 5.4 — Query Prometheus Metrics

Forward the Prometheus port:

```bash
kubectl port-forward svc/prometheus 9090:9090 -n istio-system
```

Open `http://localhost:9090` in your browser and run the following query:

```
istio_requests_total{destination_service="productpage.default.svc.cluster.local"}
```

**Expected result:** A table of request counters labelled by source, destination,
response code, and reporter (source vs. destination sidecar). This is the raw
metric that Grafana and Kiali use for their dashboards.

---

## Phase 6 — Security [MANUAL]

Istio enforces security at the network level using mutual TLS (mTLS) and
authorization policies, independent of application code.

### Step 6.1 — Verify mTLS is Enabled

Check the peer authentication policy applied by Istio:

```bash
kubectl get peerauthentication -n istio-system
kubectl get peerauthentication -n default
```

In sidecar mode, the Istio sidecar proxies handle mTLS automatically.
Verify that traffic between services is encrypted:

```bash
istioctl authn tls-check productpage-v1-<pod-id>.default \
  details.default.svc.cluster.local
```

Replace `<pod-id>` with the suffix from `kubectl get pods -n default`.

**Expected result:** Output shows `STATUS: OK` and `SERVER: mTLS`. All
service-to-service traffic is automatically encrypted and mutually
authenticated by the Envoy sidecars.

### Step 6.2 — Apply an Authorization Policy

Restrict access to the `ratings` service so that only the `reviews` service
can call it:

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ratings-allow-reviews
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/bookinfo-reviews
EOF
```

Open the Bookinfo product page. Refresh a few times.

**Expected result:** The ratings section is still visible when accessed via
the `reviews` service, because its service account identity is explicitly
allowed. If you attempt to call `ratings` directly from a pod without the
permitted identity, the request is denied with `403 Forbidden`.

Clean up the authorization policy:

```bash
kubectl delete authorizationpolicy ratings-allow-reviews -n default
```

---

## Phase 7 — Ambient Mode (if enabled) [MANUAL]

If the module was deployed with `install_ambient_mesh = true`, the cluster
uses Istio ambient mode instead of sidecar injection. In ambient mode, a
per-node `ztunnel` proxy handles L4 mTLS transparently, and optional
`waypoint` proxies provide L7 traffic management per service account.

### Step 7.1 — Verify Ambient Mode Components

```bash
kubectl get pods -n istio-system -l app=ztunnel
kubectl get pods -n istio-system -l app=istio-cni
```

**Expected result:** A `ztunnel` pod runs on every node in the cluster. The
`istio-cni` DaemonSet redirects traffic through ztunnel without requiring
Envoy sidecars in application pods.

### Step 7.2 — Verify No Sidecars in Application Pods

```bash
kubectl get pods -n default
kubectl describe pod -l app=productpage -n default
```

**Expected result:** Each pod has only **one** container — the application
itself. There is no injected sidecar. Istio captures traffic at the node
level instead.

### Step 7.3 — Enrol a Namespace in the Ambient Mesh

```bash
kubectl label namespace default istio.io/dataplane-mode=ambient
```

Verify the label and check that existing pods are captured by ztunnel:

```bash
kubectl get namespace default --show-labels
kubectl exec -it deploy/sleep -n default -- curl -s http://productpage:9080/productpage | head -5
```

**Expected result:** The namespace is enrolled. Traffic between services in
the namespace is now captured by ztunnel and encrypted with mTLS — visible
in the Kiali graph as secured edges.

### Step 7.4 — Deploy a Waypoint Proxy for L7 Features

To use L7 traffic management features (routing, retries, fault injection) in
ambient mode, deploy a waypoint proxy for the desired service account:

```bash
istioctl waypoint apply --service-account bookinfo-productpage
kubectl wait -n default --for=condition=Ready pod -l istio.io/waypoint
```

**Expected result:** A waypoint pod is running and the `productpage` service
account's traffic now passes through both ztunnel (L4) and the waypoint (L7).
Traffic management rules from Phase 4 can now be applied to this service.

---

## Phase 8 — Clean Up [MANUAL]

### Step 8.1 — Tear Down with Terraform

```bash
tofu destroy
```

**Expected duration:** 5–10 minutes. The GKE cluster deletion is the longest
step.

**Expected result:** All GCP resources are deleted — the GKE cluster, VPC
network, firewall rules, Cloud Router, NAT gateway, and IAM resources. Verify
in the Google Cloud console that no orphaned resources remain.

---

## Summary

The table below recaps every action in the lab, its phase, and whether it is
automated by the `Istio_GKE` Terraform module or performed manually.

| Action | Phase | Automated |
|---|---|---|
| Enable GCP APIs | 1 | Yes — `main.tf` |
| Create VPC, subnet, Cloud Router, NAT gateway | 1 | Yes — `network.tf` |
| Create firewall rules | 1 | Yes — `network.tf` |
| Provision GKE Standard cluster and node pool | 1 | Yes — `gke.tf` |
| Create GKE service account with IAM roles | 1 | Yes — `gke.tf` |
| Install Istio via istioctl (sidecar mode) | 1 | Yes — `istiosidecar.tf` |
| Install Istio via istioctl (ambient mode) | 1 | Yes — `istioambient.tf` |
| Install Prometheus, Grafana, Jaeger, Kiali | 1 | Yes — Istio addons |
| Deploy Bookinfo sample application | 1 | Yes — `istiosidecar.tf` / `istioambient.tf` |
| Configure kubectl credentials | 2 | No — run `cluster_credentials_cmd` output |
| Verify cluster nodes and Istio pods | 2 | No — `kubectl` commands |
| Access Bookinfo via ingress gateway | 3 | No — browser |
| Inspect Bookinfo pods and Istio resources | 3 | No — `kubectl` commands |
| Pin traffic to reviews v1 with VirtualService | 4 | No — `kubectl apply` |
| Traffic shifting (canary 80/20) | 4 | No — `kubectl apply` |
| Fault injection (7 s delay) | 4 | No — `kubectl apply` |
| Retry policy configuration | 4 | No — `kubectl apply` |
| Explore Kiali service graph | 5 | No — browser via port-forward |
| Explore Grafana dashboards | 5 | No — browser via port-forward |
| Explore Jaeger distributed traces | 5 | No — browser via port-forward |
| Query Prometheus metrics | 5 | No — browser via port-forward |
| Verify mTLS encryption between services | 6 | No — `istioctl authn tls-check` |
| Apply AuthorizationPolicy for ratings | 6 | No — `kubectl apply` |
| Verify ambient mode ztunnel DaemonSet | 7 | No — `kubectl` commands |
| Confirm no sidecars in ambient mode pods | 7 | No — `kubectl describe` |
| Enrol namespace in ambient mesh | 7 | No — `kubectl label` |
| Deploy waypoint proxy for L7 features | 7 | No — `istioctl waypoint apply` |
| Tear down all resources | 8 | No — `tofu destroy` |
