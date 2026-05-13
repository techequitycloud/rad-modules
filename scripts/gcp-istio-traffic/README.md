# gcp-istio-traffic.sh — Explore Istio traffic management on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio with the Prometheus / Grafana / Jaeger / Kiali addons, deploys the
`bookinfo` sample, and walks you through Istio's traffic-management primitives:
request routing, weighted splits, fault injection, header-based routing,
sidecar egress, port-level load balancing, timeouts, and retries.

## Prerequisites

| Requirement | Detail |
|---|---|
| GCP project | Billing enabled; quota for a 2-node `n1-standard-2` GKE cluster (Spot VMs by default) |
| `gcloud` CLI | Authenticated as a project Owner or Editor |
| `kubectl` | Available locally, or install via `gcloud components install kubectl` |
| Internet egress | Required to download Istio releases from `github.com/istio/istio` and pull images from Docker Hub / `gcr.io` |
| `pv` | Installed automatically on Debian/Ubuntu via `sudo apt-get`; install manually on other systems |

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-istio-traffic.sh
```

A menu loops until you press `Q`. **Always start each session by pressing `0`**
to choose an execution mode and confirm the GCP project.

See [LAB_GUIDE.md](LAB_GUIDE.md) for the full walkthrough: execution modes,
configuration variables, step-by-step menu guide, and cleanup instructions.
