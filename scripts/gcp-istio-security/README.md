# gcp-istio-security.sh — Explore Istio security on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio in either sidecar or ambient mode, and walks you through Istio's security
primitives — mutual TLS, `PeerAuthentication`, `RequestAuthentication` (JWT),
and `AuthorizationPolicy` — plus traffic mirroring (via the Kubernetes Gateway
API) and circuit breaking demonstrations on the way.

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
project ID, and creates a `gs://<project>` bucket for backing up `.env`. Just
run option `0` again with a different project ID to switch projects later.

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
| `ISTIO_MODE` | `sidecar` | Set by step `4A`/`4B`; read by every later step. |

## Menu walkthrough

Run options `1` → `3`, `4A` or `4B`, then `5` once to set up the cluster and
mesh, then explore `6`, `7`, `8`, and `9` in any order.

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

### `(4A) Install Istio - sidecar mode` / `(4B) Install Istio - ambient mode`
`4A` runs `istioctl install --set profile=default -y`. `4B` runs
`istioctl install --set profile=ambient ...` (ztunnel + `istio-cni`, no
sidecars) and verifies ztunnel came up. Whichever you pick is recorded as
`ISTIO_MODE` in `.env` and read by every later step. Delete mode (either
option) runs `istioctl uninstall --purge` and deletes the `istio-system`
namespace.

### `(5) Configure namespace for mesh dataplane (sidecar or ambient)`
Creates `$APPLICATION_NAMESPACE` and, based on `ISTIO_MODE`, either labels it
`istio-injection=enabled` (sidecar) or labels it
`istio.io/dataplane-mode=ambient` and deploys a waypoint proxy with
`istioctl waypoint apply` (ambient) — the waypoint is what lets steps `6`-`9`'s
L7 features (mirroring, circuit breaking, `AuthorizationPolicy`) keep working
without sidecars. Delete mode tears down the waypoint (ambient) or removes the
label (sidecar), then deletes the namespace.

### `(6) Explore traffic mirroring (Gateway API)`
Deploys `httpbin` v1 and v2 behind three Services (a shared `httpbin` plus
per-version `httpbin-v1`/`httpbin-v2`) and a Fortio-adjacent `sleep` client,
then applies an `HTTPRoute` — attached directly to the `httpbin` Service via
`parentRefs`, no ingress `Gateway` needed — that sends 100% of live traffic to
`httpbin-v1` while *mirroring* it to `httpbin-v2` with a `RequestMirror`
filter. Inspect logs from both versions to confirm the mirror. **This step
resets `$APPLICATION_NAMESPACE` at the end** (delete + recreate) to hand step
`7` a clean namespace — the reset re-applies whichever `ISTIO_MODE` is active,
including redeploying the waypoint under ambient.

### `(7) Explore circuit breaking`
Applies a `DestinationRule` with connection-pool limits and outlier detection,
then drives the service with concurrent Fortio requests to trigger the
breaker. The script prints the Envoy stats command to view rejected requests
(`upstream_rq_pending_overflow`).

### `(8) Explore security`
The largest scenario. Creates `foo`, `bar`, and `legacy` namespaces (always
sidecar-injected, independent of `ISTIO_MODE` — `legacy` specifically tests
mTLS rejection from an unlabeled namespace, a sidecar-era concept), deploys
`httpbin` and `sleep` clients into each, and demonstrates:

- **mTLS modes** — `PeerAuthentication` set to `PERMISSIVE` (default), then
  `STRICT` mesh-wide, then per-namespace overrides; `curl` from the `legacy`
  (non-injected) namespace shows when plaintext is rejected.
- **JWT authentication** — applies a `RequestAuthentication` that validates a
  JWT against Istio's sample JWKS, and tests with the bundled `demo.jwt`
  (200 vs. 401/403).
- **AuthorizationPolicy** — applies allow/deny rules keyed on principals,
  namespaces, HTTP methods, and paths, exercising each with `curl` from the
  sleep pods. These all use workload `selector` — correct for this step's
  sidecar-only `foo`/`bar`/`legacy` namespaces, but see step `9` for why that
  doesn't carry over to ambient mode.

Delete mode removes the namespaces and bundled policies. **This step also
resets `$APPLICATION_NAMESPACE`** at the end, the same way step `6` does.

### `(9) Explore ambient L7 policy attachment (Gateway API)`
Deploys a fresh `httpbin`/`sleep` pair (step `8`'s reset wiped step `7`'s
copy), then applies the *same* `AuthorizationPolicy` rule (`ALLOW` GET
`/ip`) twice: first attached with `selector` — step `8`'s idiom — then
attached with `targetRefs` pointing at the `httpbin` Service. Under sidecar
mode both forms behave identically. Under ambient mode, the `selector` form
fails **closed** (ztunnel can't evaluate L7 rules attached that way, so it
denies everything) while the `targetRefs` form works, because it's the
Gateway-API-style attachment ambient's waypoint actually enforces. Run this
after `4B`/`5` to see the failure and the fix live; run it after `4A`/`5` to
see both forms behave the same. Delete mode removes this step's policy and
workloads.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — launch the bundled Cloud Shell tutorial (Cloud Shell only).
- `Q` — quit.

## Working files

```
./gcp-istio-security/
└── .env                       # current configuration

$HOME/istio-<ISTIO_VERSION>/   # istioctl binary + samples used by steps 6–9
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-istio-security.sh.env`.

## Cleanup

The cluster is the dominant cost. To tear everything down:

1. Option `0` → `d` (delete mode).
2. Run options `9`, `8`, `7`, `6` in delete mode to drop the demo namespaces.
3. Run `5`, `4A` (or `4B`), `3` to remove the application namespace, uninstall
   Istio, and delete the GKE cluster.
4. Optionally `2` to disable the APIs and `1` to remove Istio binaries.
5. Delete `./gcp-istio-security/`.
