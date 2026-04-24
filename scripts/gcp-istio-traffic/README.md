# gcp-istio-traffic.sh — Explore Istio traffic management on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio with the Prometheus / Grafana / Jaeger / Kiali addons, deploys the
`bookinfo` sample, and walks you through Istio's traffic-management primitives:
request routing, weighted splits, fault injection, header-based routing,
sidecar egress, port-level load balancing, timeouts, and retries.

## Prerequisites

- Google Cloud project with billing enabled and quota for a 2-node
  `n1-standard-2` GKE cluster (Spot VMs by default).
- `gcloud` CLI authenticated as a project Owner or Editor.
- `kubectl` available locally (or installed via `gcloud components`).
- Internet egress to download Istio releases from `github.com/istio/istio` and
  pull container images from Docker Hub / `gcr.io`.
- The script installs `pv` automatically with `sudo apt-get`. Install it
  manually on non-Debian systems first.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-istio-traffic.sh
```

A menu loops until you press `Q`. **Always start each session by pressing `0`**
to choose an execution mode and confirm the GCP project.

## Execution modes (option `0`)

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands without running them. |
| `n` | **Create** | Authenticates, applies all changes against your project/cluster. |
| `d` | **Delete** | Removes resources created by each step. |

In Create / Delete mode the script runs `gcloud auth login`, asks for the
project ID, creates a service account
`<project>@<project>.iam.gserviceaccount.com` with `roles/owner`, drops the
key at `./gcp-istio-traffic/.<project>.json`, and creates a
`gs://<project>` bucket for backing up `.env`. Delete the cached key file to
switch projects later.

## Configuration (`.env`)

Created at `./gcp-istio-traffic/.env`. Edit values before running the
numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `GCP_REGION` | `us-central1` | Region for the GKE cluster. |
| `GCP_CLUSTER` | `gke-cluster` | GKE cluster name. |
| `ISTIO_VERSION` | `1.24.2` | Istio release downloaded by step 1. |
| `ISTIO_RELEASE_VERSION` | `1.24` | Branch used to fetch the addon manifests. |

The application namespace and name are hardcoded to `bookinfo`.

## Menu walkthrough

Run `1` → `8` once to bring up the cluster, install Istio, and deploy
Bookinfo. Then use `9` to step through the traffic-management scenarios.

### `(1) Install tools`
Downloads Istio `$ISTIO_VERSION` from GitHub and extracts it to
`$HOME/istio-${ISTIO_VERSION}` so `istioctl` and the Bookinfo sample manifests
are available locally. Delete mode removes the directory.

### `(2) Enable APIs`
Enables `cloudapis.googleapis.com` and `container.googleapis.com`.

### `(3) Create Kubernetes cluster`
Creates `$GCP_CLUSTER` in `$GCP_REGION` with two `n1-standard-2` Spot nodes
and the Gateway API enabled. Fetches credentials and grants your user
`cluster-admin`. Delete mode deletes the cluster.

### `(4) Install Istio`
Runs `istioctl install --set profile=default -y`, then deploys an Istio
`IngressGateway` into the application namespace via a generated
`ingress.yaml` IstioOperator. Also installs four observability addons from
`raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}`:
**Prometheus**, **Jaeger**, **Grafana**, and **Kiali**.

### `(5) Configure namespace for automatic sidecar injection`
Creates the `bookinfo` namespace and labels it
`istio-injection=enabled`. Delete mode removes the namespace and label.

### `(6) Configure service and deployment`
Applies `samples/bookinfo/platform/kube/bookinfo.yaml`, deploying the four
Bookinfo microservices (`productpage`, `details`, `reviews` v1/v2/v3,
`ratings`). Waits up to 600 s for the deployments to become available. Delete
mode removes them.

### `(7) Configure gateway and virtualservice`
Applies `samples/bookinfo/networking/bookinfo-gateway.yaml`, exposing the
Bookinfo `productpage` through the Istio ingress gateway.

### `(8) Configure subsets`
Applies `samples/bookinfo/networking/destination-rule-all.yaml`, defining
named subsets per microservice version. Required for the routing scenarios
in step 9.

### `(9) Explore Istio traffic management`
The interactive demo. In Create mode it generates continuous `curl` traffic
to the ingress IP and pauses between scenarios so you can observe the
behavior in Grafana / Kiali / Jaeger:

- Route 100% to `reviews` v1.
- Route user `jason` to v2 while everyone else stays on v1.
- 50/50 weighted split between v1 and v3.
- Fault injection: delay on `ratings` for `jason`, then HTTP 500 abort.
- Header-based routing variations.
- Sidecar egress restrictions.
- Port-level load-balancing policy.
- Request timeouts and retry policies.

Press Enter at each pause to advance. Delete mode reverts the demo
`VirtualService`s back to the default routing.

To reach Bookinfo from outside the cluster:

```bash
export INGRESS_HOST=$(kubectl -n bookinfo get svc istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://${INGRESS_HOST}/productpage
```

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — launch the bundled Cloud Shell tutorial (Cloud Shell only).
- `Q` — quit.

## Working files

```
./gcp-istio-traffic/
├── .env                       # current configuration
├── .<GCP_PROJECT>.json        # service-account key
└── ingress.yaml               # IstioOperator written by step 4

$HOME/istio-<ISTIO_VERSION>/   # istioctl + samples/bookinfo manifests
```

`.env` is backed up to `gs://<GCP_PROJECT>/gcp-istio-traffic.sh.env`.

## Cleanup

The cluster and the addons are the cost drivers. To tear down:

1. Option `0` → `d` (delete mode).
2. Run option `9` in delete mode to revert any demo `VirtualService`s.
3. Run options `8`, `7`, `6`, `5` to remove subsets, gateway, deployments,
   and the namespace.
4. Run option `4` to uninstall Istio and the addons.
5. Run option `3` to delete the GKE cluster, then optionally `2` and `1`.
6. Delete `./gcp-istio-traffic/` and the service-account key file.
