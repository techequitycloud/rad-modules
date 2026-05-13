# gcp-istio-traffic.sh — Lab Guide

## Execution modes (option `0`)

When you select `0` the script asks how it should behave:

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints every command without running it. Safe for review. |
| `n` | **Create** | Authenticates, sets the project, and executes commands. |
| `d` | **Delete** | Tears down the resources created by each step. |

In Create or Delete mode the script will:

1. Run `gcloud auth login` if no service-account key is cached.
2. Prompt for the Google Cloud project ID to operate against.
3. Create a service account `<project>@<project>.iam.gserviceaccount.com`,
   grant it `roles/owner`, save its key to
   `./gcp-istio-traffic/.<project>.json`, and create a `gs://<project>` bucket
   for backing up `.env`.
4. Re-export the configuration to `./gcp-istio-traffic/.env`.

To change projects later, delete the cached key file and run option `0` again.

---

## Configuration (`.env`)

The script creates `./gcp-istio-traffic/.env` on first run. Edit values before
running the numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `GCP_REGION` | `us-central1` | Region for the GKE cluster. |
| `GCP_CLUSTER` | `gke-cluster` | GKE cluster name. |
| `ISTIO_VERSION` | `1.24.2` | Istio release downloaded by step 1. |
| `ISTIO_RELEASE_VERSION` | `1.24` | Branch used to fetch the addon manifests. |

The application namespace and name are hardcoded to `bookinfo`.

`.env` is backed up to `gs://<GCP_PROJECT>/gcp-istio-traffic.sh.env` so it can
be restored across Cloud Shell sessions.

---

## Menu walkthrough

Run `1` → `8` once to bring up the cluster, install Istio, and deploy Bookinfo.
Then use `9` to step through the traffic-management scenarios.

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

Creates the `bookinfo` namespace and labels it `istio-injection=enabled`.
Delete mode removes the namespace and label.

### `(6) Configure service and deployment`

Applies `samples/bookinfo/platform/kube/bookinfo.yaml`, deploying the four
Bookinfo microservices (`productpage`, `details`, `reviews` v1/v2/v3,
`ratings`). Waits up to 600 s for the deployments to become available. Delete
mode removes them.

### `(7) Configure gateway and virtualservice`

Applies `samples/bookinfo/networking/bookinfo-gateway.yaml`, exposing the
Bookinfo `productpage` through the Istio ingress gateway.

### `(8) Configure subsets`

Applies `samples/bookinfo/networking/destination-rule-all.yaml`, defining named
subsets per microservice version. Required for the routing scenarios in step 9.

### `(9) Explore Istio traffic management`

The interactive demo. In Create mode it generates continuous `curl` traffic to
the ingress IP and pauses between scenarios so you can observe behavior in
Grafana / Kiali / Jaeger:

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

---

## Working files

After running option `0` you'll have:

```
./gcp-istio-traffic/
├── .env                       # current configuration (edit to customise)
├── .<GCP_PROJECT>.json        # service-account key (delete to switch projects)
└── ingress.yaml               # IstioOperator written by step 4

$HOME/istio-<ISTIO_VERSION>/   # istioctl + samples/bookinfo manifests
```

---

## Cleanup

The cluster and addons are the cost drivers. To tear down:

1. Option `0` → `d` (delete mode).
2. Run option `9` in delete mode to revert any demo `VirtualService`s.
3. Run options `8`, `7`, `6`, `5` to remove subsets, gateway, deployments,
   and the namespace.
4. Run option `4` to uninstall Istio and the addons.
5. Run option `3` to delete the GKE cluster, then optionally `2` and `1`.
6. Delete `./gcp-istio-traffic/` and the service-account key file.
