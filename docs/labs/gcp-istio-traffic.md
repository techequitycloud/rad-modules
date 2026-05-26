# GCP Istio Traffic Management — Lab Guide

This lab guide walks through the full Istio traffic management lab using the `gcp-istio-traffic.sh`
script. The script automates cluster provisioning, Istio installation, and the Bookinfo deployment.
The traffic-management scenarios in Phase 3 are interactive — you observe each change live in
Grafana, Kiali, and Jaeger.

**Estimated time:** 45–60 minutes (includes approximately 10 minutes of cluster and Istio
provisioning in steps 1–4)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Quick Start](#3-quick-start)
4. [Execution Modes](#4-execution-modes-option-0)
5. [Configuration](#5-configuration-env)
6. [Phase 1 — Provision the Environment (options 1–4)](#6-phase-1--provision-the-environment-options-14)
7. [Phase 2 — Deploy Bookinfo (options 5–8)](#7-phase-2--deploy-bookinfo-options-58)
8. [Phase 3 — Explore Istio Traffic Management (option 9)](#8-phase-3--explore-istio-traffic-management-option-9)
9. [Working Files](#9-working-files)
10. [Tips and Troubleshooting](#10-tips-and-troubleshooting)
11. [Cleanup](#11-cleanup)

---

## 1. Overview

### What the Script Automates

- Downloading and extracting the Istio release (`istioctl` + sample manifests)
- Enabling required GCP APIs
- Creating the GKE cluster with Gateway API enabled
- Installing Istio (default profile) and all four observability addons
- Labelling the `bookinfo` namespace for automatic sidecar injection
- Deploying the Bookinfo microservices and waiting for readiness
- Applying the Istio gateway, VirtualService, and DestinationRules
- Generating continuous `curl` traffic during the demo scenarios

### What You Do

- Choose execution mode and confirm the GCP project (option `0`)
- Review and adjust `.env` variables before running numbered steps
- Observe traffic behaviour in Grafana / Kiali / Jaeger and press Enter
  to advance through each scenario
- Clean up resources when the lab is complete

---

## 2. Prerequisites

| Requirement | Detail |
|---|---|
| GCP project | Billing enabled; quota for a 2-node `n1-standard-2` GKE cluster |
| `gcloud` CLI | Authenticated as a project Owner or Editor |
| `kubectl` | Available locally or via `gcloud components install kubectl` |
| Internet egress | Required to download Istio from `github.com/istio/istio` and pull images from Docker Hub / `gcr.io` |
| `pv` | Installed automatically via `sudo apt-get`; install manually first on non-Debian systems |

---

## 3. Quick Start

```bash
cd /path/where/you/want/working/files
./gcp-istio-traffic.sh
```

A menu loops until you press `Q`. **Always start each session by pressing `0`** to choose an
execution mode and confirm the GCP project.

---

## 4. Execution Modes (option `0`)

| Reply | Mode | Behaviour |
|-------|------|-----------|
| `y` (default) | **Preview** | Prints commands without running them — safe to explore. |
| `n` | **Create** | Authenticates and applies all changes against your project/cluster. |
| `d` | **Delete** | Removes resources created by each step. |

In Create / Delete mode the script runs `gcloud auth login`, asks for the project ID, creates a
service account `<project>@<project>.iam.gserviceaccount.com` with `roles/owner`, saves the key at
`./gcp-istio-traffic/.<project>.json`, and creates a `gs://<project>` bucket for backing up `.env`.
Delete the cached key file to switch projects.

---

## 5. Configuration (`.env`)

Created at `./gcp-istio-traffic/.env`. Edit values before running the numbered steps.

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID |
| `GCP_REGION` | `us-central1` | Region for the GKE cluster |
| `GCP_CLUSTER` | `gke-cluster` | GKE cluster name |
| `ISTIO_VERSION` | `1.24.2` | Istio release downloaded by step 1 |
| `ISTIO_RELEASE_VERSION` | `1.24` | Branch used to fetch addon manifests |

The application namespace and name are hardcoded to `bookinfo`.

---

## 6. Phase 1 — Provision the Environment (options `1`–`4`)

Run options `1` through `4` in order once per lab. These steps are idempotent — re-running them in
Create mode is safe.

### Step `(1)` — Install Tools

Downloads Istio `$ISTIO_VERSION` from GitHub and extracts it to `$HOME/istio-${ISTIO_VERSION}`,
making `istioctl` and the Bookinfo sample manifests available locally.

**Expected result:** The directory `$HOME/istio-${ISTIO_VERSION}/` exists and `istioctl version`
prints the expected version. Delete mode removes the directory.

**Estimated time:** 1–2 minutes (depends on download speed).

### Step `(2)` — Enable APIs

**What it does:**

- **Create:** Enables `cloudapis.googleapis.com` and `container.googleapis.com` on your project.
- **Delete:** No-op — API enablement is not reversed.

**Expected result:** Running
`gcloud services list --enabled --filter="name:container.googleapis.com"` returns the GKE API as
`ENABLED`. Both APIs show as enabled in the Google Cloud console under
**APIs & Services > Enabled APIs**. No action needed if they are already enabled.

### Step `(3)` — Create Kubernetes Cluster

Creates `$GCP_CLUSTER` in `$GCP_REGION` with two `n1-standard-2` Spot nodes and the Gateway API
enabled. Fetches credentials and grants your user `cluster-admin`.

**Expected result:** `kubectl get nodes` returns two nodes in `Ready` state. Delete mode deletes
the cluster.

**Estimated time:** 4–7 minutes.

> **Cost note:** The cluster runs on Spot VMs to minimise cost, but GKE management fees and node
> uptime still incur charges. Run option `3` in Delete mode as soon as the lab is complete.

### Step `(4)` — Install Istio

Runs `istioctl install --set profile=default -y`, then deploys an Istio `IngressGateway` into the
`bookinfo` namespace via a generated `ingress.yaml` IstioOperator. Also installs four observability
addons from `raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}`:
**Prometheus**, **Jaeger**, **Grafana**, and **Kiali**.

**Expected result:** `kubectl get pods -n istio-system` shows all control plane pods and addon pods
in `Running` state.

**Estimated time:** 2–4 minutes.

---

## 7. Phase 2 — Deploy Bookinfo (options `5`–`8`)

### Step `(5)` — Configure Namespace for Automatic Sidecar Injection

Creates the `bookinfo` namespace and labels it `istio-injection=enabled` so that every pod
deployed into it automatically gets an Envoy sidecar.

**Expected result:** `kubectl get ns bookinfo --show-labels` shows the label
`istio-injection=enabled`. Delete mode removes the namespace and the label.

### Step `(6)` — Configure Service and Deployment

Applies `samples/bookinfo/platform/kube/bookinfo.yaml`, deploying the four Bookinfo microservices:

| Service | Versions |
|---------|---------|
| `productpage` | v1 |
| `details` | v1 |
| `reviews` | v1, v2, v3 |
| `ratings` | v1 |

The script waits up to 600 seconds for all deployments to become available.

**Expected result:** `kubectl get pods -n bookinfo` shows all pods in `Running` state, each with
`2/2` containers (app + Envoy sidecar). Delete mode removes the deployments and services.

**Estimated time:** 2–4 minutes.

### Step `(7)` — Configure Gateway and VirtualService

Applies `samples/bookinfo/networking/bookinfo-gateway.yaml`, exposing the Bookinfo `productpage`
through the Istio ingress gateway.

**Expected result:** Navigating to `http://<INGRESS_IP>/productpage` in a browser loads the
Bookinfo product page. Retrieve the ingress IP with:

```bash
kubectl -n bookinfo get svc istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Step `(8)` — Configure Subsets

Applies `samples/bookinfo/networking/destination-rule-all.yaml`, defining named subsets (`v1`,
`v2`, `v3`) per microservice version. These subset labels are required before any weighted or
header-based routing rules in step 9 will take effect.

**Expected result:** `kubectl get destinationrules -n bookinfo` lists rules for `productpage`,
`details`, `reviews`, and `ratings`.

---

## 8. Phase 3 — Explore Istio Traffic Management (option `9`)

> **Before starting:** Open the Kiali, Grafana, and Jaeger dashboards in separate browser tabs so
> you can observe each scenario live. Use `istioctl dashboard kiali` (or `grafana` / `jaeger`) to
> open them via a local port-forward.

In Create mode, the script generates continuous `curl` traffic to the ingress IP and pauses between
scenarios. **Press Enter at each pause to advance.** Delete mode reverts all demo VirtualServices
back to default routing.

### Scenario 1 — Route 100% to `reviews` v1

All traffic to `reviews` is directed to v1 (no star ratings shown).

**What to observe:** In Kiali's graph view, all `productpage → reviews` traffic flows only to the
`v1` workload. No traffic reaches `v2` or `v3`.

### Scenario 2 — Header-Based Routing for User `jason`

User `jason` (identified by a cookie set at login) is routed to `reviews` v2 (black star ratings);
all other users remain on v1.

**What to observe:** Log in as `jason` in the Bookinfo UI — black stars appear. Log out — stars
disappear. In Kiali, both `v1` and `v2` receive traffic, with `v2` carrying only the `jason`
sessions.

### Scenario 3 — Weighted 50 / 50 Split (v1 / v3)

Traffic to `reviews` is split evenly between v1 (no stars) and v3 (red stars).

**What to observe:** Refreshing the product page alternates between no-star and red-star layouts.
In Grafana, the request rate to `v1` and `v3` converges toward 50% each over time.

### Scenario 4 — Fault Injection: Delay for `jason`

A 7-second delay is injected on the `ratings` service for user `jason`, simulating a slow upstream
dependency.

**What to observe:** Log in as `jason` — the product page takes 7 seconds to load. Other users are
unaffected. In Jaeger, traces for `jason`'s requests show a long span on `ratings`.

> **Learning point:** This demonstrates how a slow dependency surfaces in distributed traces and
> how Istio fault injection lets you test timeout handling without modifying application code.

### Scenario 5 — Fault Injection: HTTP 500 Abort for `jason`

The `ratings` service returns an HTTP 500 error for user `jason`.

**What to observe:** The product page shows "Ratings service is currently unavailable" for `jason`.
In Kiali, the `ratings` service shows a red error indicator. Traces in Jaeger show the 500
response on the `ratings` span.

### Scenario 6 — Additional Header-Based Routing Variations

Further VirtualService rules demonstrating routing based on custom request headers and user-agent
patterns.

**What to observe:** Change request headers using a browser extension or `curl -H` and see traffic
directed to different subset versions accordingly.

### Scenario 7 — Sidecar Egress Restrictions

An Istio `Sidecar` resource limits outbound traffic from the `productpage` pod to only the
services it legitimately needs.

**What to observe:** Attempts to reach external hosts or other cluster services from `productpage`
are blocked by Envoy. Legitimate internal calls continue unaffected.

### Scenario 8 — Port-Level Load-Balancing Policy

A `DestinationRule` applies a `ROUND_ROBIN` load-balancing policy at the port level for a specific
service.

**What to observe:** In Kiali, request distribution across service instances becomes more uniform
compared to the default `RANDOM` policy.

### Scenario 9 — Request Timeouts

A 0.5-second timeout is set on requests from `reviews` to `ratings`. A 2-second delay is
simultaneously injected on `ratings` to trigger the timeout.

**What to observe:** The product page shows "Sorry, product reviews are not available" because
`reviews` times out waiting for `ratings`. In Jaeger, the trace shows the timeout on the `ratings`
call.

> **Learning point:** Timeouts are applied at the client-proxy level (the `reviews` sidecar) with
> no changes to either service's code.

### Scenario 10 — Retry Policy

An automatic retry policy (up to 3 attempts, 1-second per-try timeout) is configured on the
`productpage → reviews` route.

**What to observe:** Transient errors on `reviews` are silently retried by the Envoy proxy. In
Jaeger, you can see multiple spans for a single logical request when a retry occurs.

---

## 9. Working Files

```
./gcp-istio-traffic/
├── .env                       # current configuration
├── .<GCP_PROJECT>.json        # service-account key (do not commit)
└── ingress.yaml               # IstioOperator written by step 4

$HOME/istio-<ISTIO_VERSION>/   # istioctl + samples/bookinfo manifests
```

`.env` is backed up to `gs://<GCP_PROJECT>/gcp-istio-traffic.sh.env`.

---

## 10. Tips and Troubleshooting

- **Pods stuck in `Pending`:** Check node capacity with `kubectl describe nodes`. Spot VMs can be
  preempted — if both nodes are gone, delete and recreate the cluster (option `3` delete then
  create).
- **Ingress IP not assigned:** The `LoadBalancer` service can take 2–3 minutes to get an external
  IP after the cluster is ready. Re-run the `kubectl get svc` command after waiting.
- **`istioctl` not found:** Confirm step 1 completed and that
  `$HOME/istio-${ISTIO_VERSION}/bin` is on your `$PATH`, or use the full path.
- **Kiali shows no graph traffic:** The graph requires at least a few minutes of live traffic.
  Leave the script running through a scenario and wait for Prometheus to scrape the metrics.
- **Wrong project after first run:** Delete `./gcp-istio-traffic/.<project>.json` and re-run
  option `0`.
- **Re-running step 9 after partial demo:** Run option `9` in Delete mode first to revert all
  VirtualServices, then re-run in Create mode for a clean start.

---

## 11. Cleanup

The GKE cluster is the primary cost driver. Tear down in this order to avoid IAM permission
errors:

1. Option `0` → `d` (switch to Delete mode).
2. Option `9` — revert demo VirtualServices.
3. Options `8`, `7`, `6`, `5` — remove subsets, gateway, deployments, and the namespace.
4. Option `4` — uninstall Istio and the observability addons.
5. Option `3` — delete the GKE cluster.
6. Options `2` and `1` (optional) — disable APIs and remove the Istio directory.
7. Delete `./gcp-istio-traffic/` and the cached service-account key file.

**Expected result:** `gcloud container clusters list` shows no clusters in the project. Cloud
Billing shows no ongoing GKE or load-balancer charges.
