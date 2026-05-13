# gcp-istio-traffic.sh — Lab Guide

This guide walks through every step of the `gcp-istio-traffic.sh` lab: cluster
setup, Istio installation, Bookinfo deployment, and eight traffic-management
scenarios. Run menu options `1` → `8` once to build the environment, then use
option `9` to explore the scenarios interactively.

**Estimated time:** 45–60 minutes (includes ~15 minutes of background provisioning)

---

## Execution modes (option `0`)

Always press `0` first to set the mode and confirm the GCP project.

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands without running them. Use to review what each step will do before committing. |
| `n` | **Create** | Authenticates, applies all changes against your project and cluster. |
| `d` | **Delete** | Removes resources created by each step, in reverse order. |

In Create / Delete mode the script runs `gcloud auth login`, asks for the
project ID, creates a service account
`<project>@<project>.iam.gserviceaccount.com` with `roles/owner`, drops the
key at `./gcp-istio-traffic/.<project>.json`, and creates a
`gs://<project>` bucket for backing up `.env`. Delete the cached key file to
switch projects later.

> **Security note:** The service-account key at
> `./gcp-istio-traffic/.<project>.json` grants `roles/owner` on your project.
> Do not commit this file to source control. Delete it after the lab or when
> switching projects.

---

## Configuration (`.env`)

Created at `./gcp-istio-traffic/.env` when you first run Create mode. Edit
values before running the numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID |
| `GCP_REGION` | `us-central1` | Region for the GKE cluster |
| `GCP_CLUSTER` | `gke-cluster` | GKE cluster name |
| `ISTIO_VERSION` | `1.24.2` | Istio release downloaded by step 1 |
| `ISTIO_RELEASE_VERSION` | `1.24` | Branch used to fetch the addon manifests |

The application namespace and name are hardcoded to `bookinfo`.

`.env` is backed up to `gs://<GCP_PROJECT>/gcp-istio-traffic.sh.env`.

---

## Timing reference

| Step | Typical duration |
|------|-----------------|
| `(1)` Install tools | 1–2 minutes (depends on connection speed to GitHub) |
| `(2)` Enable APIs | 1–2 minutes |
| `(3)` Create cluster | 4–6 minutes |
| `(4)` Install Istio + addons | 3–5 minutes |
| `(5)` Configure namespace | < 1 minute |
| `(6)` Deploy services | Up to 10 minutes (waits for all pods ready) |
| `(7)` Configure gateway | < 1 minute |
| `(8)` Configure subsets | < 1 minute |
| `(9)` Full traffic demo | 15–25 minutes |

---

## Menu walkthrough

### `(1) Install tools`

**What it does:**
- **Create / Preview:** Downloads Istio `$ISTIO_VERSION` from GitHub and
  extracts it to `$HOME/istio-${ISTIO_VERSION}`, making `istioctl` and the
  Bookinfo sample manifests available locally.
- **Delete:** Removes the `$HOME/istio-${ISTIO_VERSION}` directory.

**Expected result:** Running `istioctl version --remote=false` returns
`$ISTIO_VERSION`. The directory `$HOME/istio-${ISTIO_VERSION}/samples/bookinfo`
exists and contains the Bookinfo manifests used by later steps.

> **If the download stalls:** The Istio release archive is ~50 MB. On slow
> connections, re-run option `1` — the script re-downloads if the directory is
> absent or incomplete.

---

### `(2) Enable APIs`

**What it does:**
- **Create:** Enables `cloudapis.googleapis.com` and
  `container.googleapis.com` on your project.
- **Delete:** No-op — API enablement is not reversed.

**Expected result:** Running
`gcloud services list --enabled --filter="name:container.googleapis.com"`
returns the GKE API as `ENABLED`.

---

### `(3) Create Kubernetes cluster`

**What it does:**
- **Create:** Creates `$GCP_CLUSTER` in `$GCP_REGION` with two
  `n1-standard-2` Spot nodes and the Gateway API enabled. Fetches credentials
  and grants your user `cluster-admin`.
- **Delete:** Deletes the cluster.

**Expected result:** `kubectl get nodes` returns two nodes in `Ready` state.
`kubectl cluster-info` resolves to the GKE control plane endpoint.

> **If node provisioning times out:** Spot VMs can occasionally be unavailable
> in a region. Change `GCP_REGION` in `.env` and re-run option `3`.

---

### `(4) Install Istio`

**What it does:**
- **Create:** Runs `istioctl install --set profile=default -y`, then deploys
  an Istio `IngressGateway` into the `bookinfo` namespace via a generated
  `ingress.yaml` IstioOperator. Installs four observability addons from
  `raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}`:
  **Prometheus**, **Jaeger**, **Grafana**, and **Kiali**.
- **Delete:** Uninstalls Istio and removes the addon deployments.

**Why the `IngressGateway` goes into the application namespace:** Placing the
gateway alongside the application pods (rather than `istio-system`) scopes its
lifecycle to the `bookinfo` namespace and avoids cross-namespace RBAC
complexity in single-app demos.

**Expected result:** `kubectl get pods -n istio-system` shows `istiod` and
all four addon pods (`prometheus`, `grafana`, `jaeger`, `kiali`) in `Running`
state. `kubectl get pods -n bookinfo` shows the `istio-ingressgateway` pod
running.

> **If Kiali or Grafana pods stay in `Pending`:** The cluster may lack
> resources. Verify node count with `kubectl get nodes` — both nodes must be
> `Ready` before Istio addons can schedule.

---

### `(5) Configure namespace for automatic sidecar injection`

**What it does:**
- **Create:** Creates the `bookinfo` namespace (if it does not already exist)
  and applies the label `istio-injection=enabled`.
- **Delete:** Removes the namespace and its label.

**Why this label matters:** Istio's data plane relies on a
`MutatingAdmissionWebhook` that intercepts pod creation. When the namespace
carries `istio-injection=enabled`, the webhook automatically injects an Envoy
sidecar proxy container into every new pod. Without this label, pods run
without a proxy and are invisible to the mesh — traffic-management rules will
have no effect.

**Expected result:** `kubectl get namespace bookinfo --show-labels` shows
`istio-injection=enabled` in the labels column.

---

### `(6) Configure service and deployment`

**What it does:**
- **Create:** Applies
  `samples/bookinfo/platform/kube/bookinfo.yaml`, deploying the four Bookinfo
  microservices: `productpage`, `details`, `reviews` (v1, v2, v3), and
  `ratings`. Waits up to 600 s for all deployments to become available.
- **Delete:** Removes all Bookinfo deployments and services.

**Expected result:** `kubectl get pods -n bookinfo` shows one pod per
microservice version, all in `Running` state with `2/2` containers ready
(application container + Envoy sidecar). `kubectl get svc -n bookinfo` lists
`productpage`, `details`, `reviews`, and `ratings`.

> **If pods stay in `Pending` or `Init` state past 5 minutes:** Check
> `kubectl describe pod <pod-name> -n bookinfo` for resource or image-pull
> errors. Most image-pull failures resolve on retry — re-run option `6`.

---

### `(7) Configure gateway and virtualservice`

**What it does:**
- **Create:** Applies
  `samples/bookinfo/networking/bookinfo-gateway.yaml`, creating an Istio
  `Gateway` and a `VirtualService` that expose the Bookinfo `productpage`
  through the ingress gateway.
- **Delete:** Removes the `Gateway` and `VirtualService`.

**Expected result:** The ingress gateway service has an external IP assigned.
Retrieve it and confirm the app is reachable:

```bash
export INGRESS_HOST=$(kubectl -n bookinfo get svc istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://${INGRESS_HOST}/productpage | grep -o "<title>.*</title>"
# Expected: <title>Simple Bookstore App</title>
```

> **If `INGRESS_HOST` is empty:** LoadBalancer provisioning can take 2–3
> minutes. Re-run the `kubectl get svc` command until an external IP appears.

---

### `(8) Configure subsets`

**What it does:**
- **Create:** Applies
  `samples/bookinfo/networking/destination-rule-all.yaml`, defining named
  subsets (`v1`, `v2`, `v3`) per microservice version using pod label
  selectors. These subsets are required for all routing scenarios in step 9.
- **Delete:** Removes the `DestinationRule` resources.

**Why subsets are needed:** A `VirtualService` can only route to named subsets
defined in a `DestinationRule`. Without subsets, Istio treats all `reviews`
pods as a single pool and cannot distinguish between v1, v2, and v3.

**Expected result:** `kubectl get destinationrules -n bookinfo` lists rules
for `productpage`, `details`, `reviews`, and `ratings`, each with v1/v2/v3
subsets where applicable.

---

### `(9) Explore Istio traffic management`

The interactive demo. In Create mode the script generates continuous `curl`
traffic to the ingress IP and pauses between scenarios so you can observe
behavior in the observability dashboards. Press **Enter** at each pause to
advance to the next scenario. Delete mode reverts all demo `VirtualService`s
back to default round-robin routing.

#### Opening the observability dashboards

Run each command in a separate terminal before starting option `9`:

```bash
# Kiali — service mesh topology and traffic flow
istioctl dashboard kiali

# Grafana — metrics and dashboards
istioctl dashboard grafana

# Jaeger — distributed tracing
istioctl dashboard jaeger
```

Each command opens a browser tab via `kubectl port-forward`. Leave all three
open during the demo to observe each scenario from multiple angles.

#### Traffic-management scenarios

| Scenario | Istio feature | What to observe |
|---|---|---|
| Route 100% to `reviews` v1 | `VirtualService` subset routing | Kiali graph shows all traffic flowing only to v1 (no star ratings on productpage) |
| Route user `jason` to v2, everyone else to v1 | Match on `end-user` header | Log in as `jason` in the productpage — black stars appear; other users see no stars |
| 50/50 weighted split between v1 and v3 | Traffic weights | Kiali graph shows roughly equal flow to v1 and v3; productpage alternates between no stars and red stars on refresh |
| Fault injection — 7 s delay on `ratings` for `jason` | `fault.delay` | Logged in as `jason`, productpage takes ~7 s to load; Jaeger traces show the delay on the `ratings` span |
| Fault injection — HTTP 500 abort on `ratings` for `jason` | `fault.abort` | Logged in as `jason`, productpage shows "Ratings service is currently unavailable" |
| Header-based routing variations | `VirtualService` header match | Demonstrates arbitrary header conditions beyond end-user identity |
| Sidecar egress restrictions | `Sidecar` resource | Limits which services each pod can reach; Kiali graph shows reduced connectivity |
| Port-level load-balancing policy | `DestinationRule` `trafficPolicy` | Applies a `LEAST_CONN` load-balancing algorithm at port level |
| Request timeouts | `timeout` field on `VirtualService` | Productpage returns a timeout error when the upstream exceeds the configured limit |
| Retry policies | `retries` field on `VirtualService` | Istio transparently retries failed requests; Jaeger traces show retry spans |

---

## Working files

```
./gcp-istio-traffic/
├── .env                       # current configuration
├── .<GCP_PROJECT>.json        # service-account key (do not commit)
└── ingress.yaml               # IstioOperator written by step 4

$HOME/istio-<ISTIO_VERSION>/   # istioctl + samples/bookinfo manifests
```

---

## Cleanup

The GKE cluster and Istio addons are the primary cost drivers. Tear down in
this order to avoid dependency errors:

1. Option `0` → `d` (switch to delete mode).
2. Run option `9` to revert all demo `VirtualService`s.
3. Run options `8`, `7`, `6`, `5` to remove subsets, gateway, deployments,
   and the namespace.
4. Run option `4` to uninstall Istio and the addons.
5. Run option `3` to delete the GKE cluster, then optionally `2` and `1`.
6. Delete `./gcp-istio-traffic/` and the service-account key file.

---

## What you learned

| Concept | Istio resource | Step |
|---|---|---|
| Subset-based routing | `VirtualService` + `DestinationRule` | 8, 9 |
| Header-match routing | `VirtualService` match conditions | 9 |
| Canary / weighted traffic splits | `VirtualService` weights | 9 |
| Fault injection (delay + abort) | `VirtualService` fault | 9 |
| Sidecar egress control | `Sidecar` resource | 9 |
| Port-level load balancing | `DestinationRule` trafficPolicy | 9 |
| Timeout enforcement | `VirtualService` timeout | 9 |
| Automatic retries | `VirtualService` retries | 9 |
| Automatic sidecar injection | Namespace label + MutatingAdmissionWebhook | 5 |
| Mesh observability | Prometheus / Grafana / Jaeger / Kiali | 4, 9 |
