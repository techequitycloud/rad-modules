# gcp-istio-traffic.sh — Explore Istio traffic management on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio in either sidecar or ambient mode with the Prometheus / Grafana / Jaeger /
Kiali addons, deploys the `bookinfo` sample behind a Kubernetes Gateway API
ingress, and walks you through Istio's traffic-management primitives: request
routing, weighted splits, fault injection, header-based routing, sidecar egress,
port-level load balancing, timeouts, and retries.

For the full step-by-step walkthrough see **[Istio_GKE.md](../../docs/labs/Istio_GKE.md)**.

## Prerequisites

| Requirement | Detail |
|---|---|
| GCP project | Billing enabled; quota for a 2-node `n1-standard-2` GKE cluster |
| `gcloud` CLI | Authenticated as a project Owner or Editor |
| `kubectl` | Available locally or via `gcloud components install kubectl` |
| Internet egress | Required to download Istio from `github.com/istio/istio` and pull images |
| `pv` | Installed automatically via `sudo apt-get`; install manually on non-Debian systems first |

## Quick Start

```bash
cd /path/where/you/want/working/files
./gcp-istio-traffic.sh
```

A menu loops until you press `Q`. **Always start each session by pressing `0`**
to choose an execution mode and confirm the GCP project, then run options
`1` → `3`, `4A` or `4B`, then `5` → `8` in order to provision the cluster and
deploy Bookinfo. Use option `9` to step through the interactive
traffic-management scenarios.

`4A` installs Istio's `default` profile (sidecar injection); `4B` installs the
`ambient` profile (ztunnel, no sidecars). Whichever you pick is recorded as
`ISTIO_MODE` in `.env` and read by every later step — option `5` labels
`$APPLICATION_NAMESPACE` accordingly (`istio-injection=enabled` for sidecar,
`istio.io/dataplane-mode=ambient` plus a deployed waypoint proxy for ambient),
and option `9`'s traffic-management rules are enforced by that waypoint when
running in ambient mode. Option `7` configures ingress with the Kubernetes
Gateway API (`Gateway`/`HTTPRoute`) rather than Istio's legacy
`networking.istio.io` `Gateway`/`VirtualService` — the proxy Deployment/Service
is auto-provisioned by the `Gateway` resource itself.

See [Istio_GKE.md](../../docs/labs/Istio_GKE.md) for a full description of every menu option,
expected results, timing estimates, and cleanup instructions. **Note:** that
guide predates this script's `4A`/`4B` split and Gateway API ingress and has not
yet been updated to match.
