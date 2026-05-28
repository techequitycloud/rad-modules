# gcp-istio-traffic.sh — Explore Istio traffic management on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio with the Prometheus / Grafana / Jaeger / Kiali addons, deploys the
`bookinfo` sample, and walks you through Istio's traffic-management primitives:
request routing, weighted splits, fault injection, header-based routing,
sidecar egress, port-level load balancing, timeouts, and retries.

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
`1` → `8` in order to provision the cluster and deploy Bookinfo. Use option
`9` to step through the interactive traffic-management scenarios.

See [Istio_GKE.md](../../docs/labs/Istio_GKE.md) for a full description of every menu option,
expected results, timing estimates, and cleanup instructions.
