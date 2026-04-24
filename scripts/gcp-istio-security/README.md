# gcp-istio-security.sh — Explore Istio security on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio, and walks you through Istio's security primitives — mutual TLS,
`PeerAuthentication`, `RequestAuthentication` (JWT), and `AuthorizationPolicy` —
plus traffic mirroring and circuit breaking demonstrations on the way.

## Prerequisites

- Google Cloud project with billing enabled and quota for a 3-node
  `n1-standard-2` GKE cluster (Spot VMs by default).
- `gcloud` CLI authenticated as a project Owner or Editor.
- `kubectl` available locally (or installed via `gcloud components`).
- Internet egress to download Istio releases from
  `github.com/istio/istio/releases` and pull container images from Docker Hub.
- The script installs `pv` automatically with `sudo apt-get`. Install it
  manually on non-Debian systems first.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-istio-security.sh
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
project ID, creates a service account
`<project>@<project>.iam.gserviceaccount.com` with `roles/owner`, drops the
key at `./gcp-istio-security/.<project>.json`, and creates a
`gs://<project>` bucket for backing up `.env`. Delete the cached key file to
switch projects later.

## Configuration (`.env`)

Created at `./gcp-istio-security/.env`. Edit values before running the
numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `GCP_REGION` | `us-central1` | Region for the GKE cluster. |
| `GCP_CLUSTER` | `gke-cluster` | GKE cluster name. |
| `ISTIO_VERSION` | `1.24.2` | Istio release downloaded by step 1. |
| `APPLICATION_NAMESPACE` | `httpbin` | Namespace for the demo workloads. |
| `APPLICATION_NAME` | `httpbin` | Demo application name. |

## Menu walkthrough

Run options `1` → `5` once to set up the cluster and mesh, then explore `6`,
`7`, and `8` in any order.

### `(1) Install tools`
Downloads Istio `$ISTIO_VERSION` from GitHub and extracts it to
`$HOME/istio-${ISTIO_VERSION}`. The `istioctl` binary and `samples/` directory
are used by later steps. Delete mode removes the directory.

### `(2) Enable APIs`
Enables `cloudapis.googleapis.com` and `container.googleapis.com`. Delete mode
disables them.

### `(3) Create Kubernetes cluster`
Creates `$GCP_CLUSTER` in `$GCP_REGION` with three `n1-standard-2` Spot nodes,
50 GB disks, and the Gateway API enabled. Fetches credentials with
`gcloud container clusters get-credentials` and grants your user
`cluster-admin`. Delete mode deletes the cluster.

### `(4) Install Istio`
Runs `istioctl install --set profile=default -y`. Delete mode runs
`istioctl uninstall --purge` and deletes the `istio-system` namespace.

### `(5) Configure namespace for automatic sidecar injection`
Creates `$APPLICATION_NAMESPACE` and labels it `istio-injection=enabled` so
new pods receive an Envoy sidecar automatically. Delete mode removes the
label and namespace.

### `(6) Explore traffic mirroring`
Deploys `httpbin` v1 and v2 plus a Fortio load-test pod, then applies a
`DestinationRule` defining `v1`/`v2` subsets and a `VirtualService` that sends
100% of live traffic to v1 while *mirroring* it to v2. Use the printed Fortio
commands to generate load and inspect logs from both versions to confirm the
mirror.

### `(7) Explore circuit breaking`
Applies a `DestinationRule` with connection-pool limits and outlier detection,
then drives the service with concurrent Fortio requests to trigger the
breaker. The script prints the Envoy stats command to view rejected requests
(`upstream_rq_pending_overflow`).

### `(8) Explore security`
The largest scenario. Creates `foo`, `bar`, and `legacy` namespaces, deploys
`httpbin` and `sleep` clients into each, and demonstrates:

- **mTLS modes** — `PeerAuthentication` set to `PERMISSIVE` (default), then
  `STRICT` mesh-wide, then per-namespace overrides; `curl` from the `legacy`
  (non-injected) namespace shows when plaintext is rejected.
- **JWT authentication** — applies a `RequestAuthentication` that validates a
  JWT against Istio's sample JWKS, and tests with the bundled `demo.jwt`
  (200 vs. 401/403).
- **AuthorizationPolicy** — applies allow/deny rules keyed on principals,
  namespaces, HTTP methods, and paths, exercising each with `curl` from the
  sleep pods.

Delete mode removes the namespaces and bundled policies.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — launch the bundled Cloud Shell tutorial (Cloud Shell only).
- `Q` — quit.

## Working files

```
./gcp-istio-security/
├── .env                       # current configuration
└── .<GCP_PROJECT>.json        # service-account key

$HOME/istio-<ISTIO_VERSION>/   # istioctl binary + samples used by steps 6–8
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-istio-security.sh.env`.

## Cleanup

The cluster is the dominant cost. To tear everything down:

1. Option `0` → `d` (delete mode).
2. Run options `8`, `7`, `6` in delete mode to drop the demo namespaces.
3. Run `5`, `4`, `3` to remove the application namespace, uninstall Istio, and
   delete the GKE cluster.
4. Optionally `2` to disable the APIs and `1` to remove Istio binaries.
5. Delete `./gcp-istio-security/` and the service-account key file.
