# gcp-istio-traffic.sh — Explore Istio traffic management on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio in either sidecar or ambient mode with the Prometheus / Grafana / Jaeger /
Kiali addons, deploys the `bookinfo` sample behind a Kubernetes Gateway API
ingress, and walks you through Istio's traffic-management primitives: request
routing, weighted splits, fault injection, header-based routing, sidecar egress,
port-level load balancing, timeouts, and retries.

This script is a standalone, hands-on companion to the `Istio_GKE` Terraform
module — it is not invoked by the module and does not share its lifecycle. For
the module's own RAD-platform lab guide (Deploy/Update/Delete via the
platform UI) see [Istio_GKE.md](../../docs/labs/Istio_GKE.md); it does not
document this script's menu.

## Prerequisites

| Requirement | Detail |
|---|---|
| GCP project | Billing enabled; quota for a 2-node `n1-standard-2` GKE cluster |
| `gcloud` CLI | Authenticated as a project Owner or Editor |
| `kubectl` | Available locally or via `gcloud components install kubectl` |
| Internet egress | Required to download Istio from `github.com/istio/istio` and pull images |
| `pv` | Installed automatically via `sudo apt-get`; install manually on non-Debian systems first |

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-istio-traffic.sh
```

A menu appears that loops until you press `Q`. **Always start each session by
pressing `0`** to choose an execution mode and confirm the GCP project.

## Execution modes (option `0`)

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands without running them. |
| `n` | **Create** | Authenticates, applies all changes against your project/cluster. |
| `d` | **Delete** | Removes resources created by each step. |

In Create / Delete mode the script runs `gcloud auth login`, asks for the
project ID, and creates a `gs://<project>` bucket for backing up `.env`. Just
run option `0` again with a different project ID to switch projects later.

## Configuration (`.env`)

Created at `./gcp-istio-traffic/.env`. Edit values before running the
numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `GCP_CLUSTER` | `gke-cluster` | GKE cluster name. |
| `ISTIO_VERSION` | `1.30.3` | Istio release downloaded by step 1. |
| `ISTIO_RELEASE_VERSION` | `1.30` | Minor-version branch used for addon manifest URLs. |
| `GCP_REGION` | `us-central1` | Region for the GKE cluster. |
| `ISTIO_MODE` | `sidecar` | Set by step `4A`/`4B`; read by every later step. |

`APPLICATION_NAMESPACE`/`APPLICATION_NAME` are hardcoded to `bookinfo` (not
configurable via `.env`).

## Menu walkthrough

Run options `1` → `3`, `4A` or `4B`, then `5` → `8` in order to provision the
cluster and deploy Bookinfo. Use option `9` to step through the interactive
traffic-management scenarios.

### `(1) Install tools`
Downloads Istio `$ISTIO_VERSION` from GitHub and extracts it to
`$HOME/istio-${ISTIO_VERSION}`. The `istioctl` binary and `samples/` directory
are used by later steps. Delete mode removes the directory.

### `(2) Enable APIs`
Enables `cloudapis.googleapis.com` and `container.googleapis.com`. Delete mode
does nothing — the APIs are deliberately left enabled.

### `(3) Create Kubernetes cluster`
Creates `$GCP_CLUSTER` in `$GCP_REGION` with two `n1-standard-2` Spot nodes and
the Gateway API enabled (`--gateway-api=standard`). Fetches credentials with
`gcloud container clusters get-credentials` and grants your user
`cluster-admin`. Delete mode deletes the cluster.

### `(4A) Install Istio - sidecar mode` / `(4B) Install Istio - ambient mode`
`4A` runs `istioctl install --set profile=default -y`, then creates the
`bookinfo` namespace and installs the Prometheus/Grafana/Jaeger/Kiali addons.
`4B` runs `istioctl install --set profile=ambient ...` (ztunnel + `istio-cni`,
no sidecars), verifies ztunnel came up, then does the same namespace/addon
setup. Whichever you pick is recorded as `ISTIO_MODE` in `.env` and read by
every later step. Delete mode (either option) runs
`istioctl uninstall --purge` and removes the addons and `istio-system`.

### `(5) Configure namespace for mesh dataplane (sidecar or ambient)`
Based on `ISTIO_MODE`, either labels `bookinfo` with
`istio-injection=enabled` (sidecar) or with `istio.io/dataplane-mode=ambient`
plus deploys a waypoint proxy with `istioctl waypoint apply` (ambient) — the
waypoint is what lets step `9`'s traffic-management rules (all L7: routing,
fault injection, timeouts, retries) keep working without sidecars. Delete
mode tears down the waypoint (ambient) or removes the label (sidecar), then
deletes the namespace.

### `(6) Configure service and deployment`
Deploys the Bookinfo sample (`productpage`, `details`, `reviews` v1/v2/v3,
`ratings`) from the downloaded Istio release's `samples/bookinfo/`.

### `(7) Configure Gateway API ingress`
Applies a Kubernetes Gateway API `Gateway` (`gatewayClassName: istio`) and
`HTTPRoute` routing `/productpage`, `/static`, `/login`, `/logout`, and
`/api/v1/products*` to the `productpage` Service — replacing the legacy
`networking.istio.io` `Gateway`/`VirtualService` sample. The proxy
Deployment/Service is auto-provisioned by the `Gateway` resource itself; the
script reads the assigned address from `gateway.status.addresses`, not from a
Service lookup. Delete mode removes the `Gateway`/`HTTPRoute` pair, which
cascades removal of the auto-provisioned proxy.

### `(8) Configure subsets`
Applies `destination-rule-all.yaml`, defining `v1`/`v2`/`v3` subsets on
`reviews` (and matching subsets on the other services) via `DestinationRule`
— the foundation for the version-based routing scenarios in step `9`.

### `(9) Explore Istio traffic management`
Steps through request routing (all traffic to `v1`), user-based routing,
weighted splits, fault injection (delay/abort), header-based routing,
`Sidecar` egress restriction, port-level `DestinationRule` load balancing,
`VirtualService` timeouts, and retries — all expressed as legacy
`VirtualService`/`DestinationRule`/`Sidecar` resources, since Gateway API has
no equivalent for subset routing or fault injection. Under ambient mode these
are enforced by the waypoint deployed in step `5`.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — runs `cloudshell launch-tutorial .tutorial.md` (Cloud Shell only).
  No `.tutorial.md` ships here, so this fails unless you add one yourself.
- `Q` — quit.

## Working files

```
./gcp-istio-traffic/
└── .env                       # current configuration

$HOME/istio-<ISTIO_VERSION>/   # istioctl binary + samples used by steps 6, 9
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-istio-traffic.sh.env`.

## Cleanup

The cluster is the dominant cost. To tear everything down:

1. Option `0` → `d` (delete mode).
2. Run options `8`, `7`, `6` in delete mode to drop the Bookinfo resources.
3. Run `5`, `4A` (or `4B`), `3` to remove the application namespace, uninstall
   Istio, and delete the GKE cluster.
4. Optionally `2` to disable the APIs and `1` to remove Istio binaries.
5. Delete `./gcp-istio-traffic/`.

See [SKILLS.md](../../SKILLS.md) (§10, Standalone Lab Scripts) for the
`.env`/`MODE`/`ISTIO_MODE` conventions shared by this script and
`gcp-istio-security.sh`.
