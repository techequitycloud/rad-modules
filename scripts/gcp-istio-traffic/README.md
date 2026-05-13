# gcp-istio-traffic.sh — Explore Istio traffic management on GKE

Interactive bash script that provisions a GKE cluster, installs open-source
Istio with the Prometheus / Grafana / Jaeger / Kiali addons, deploys the
`bookinfo` sample, and walks you through Istio's traffic-management primitives:
request routing, weighted splits, fault injection, header-based routing,
sidecar egress, port-level load balancing, timeouts, and retries.

## Prerequisites

| Requirement | Detail |
|---|---|
| GCP project | Billing enabled; quota for 2× `n1-standard-2` Spot nodes |
| `gcloud` CLI | Authenticated as Owner or Editor (`gcloud auth login`) |
| `kubectl` | Available locally or via `gcloud components install kubectl` |
| Internet egress | Required to pull Istio from `github.com/istio/istio` and images from Docker Hub / `gcr.io` |
| `pv` (pipe viewer) | Auto-installed via `apt-get` on Debian/Ubuntu; install manually on other distros |

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-istio-traffic.sh
```

A menu loops until you press `Q`. **Always start each session by pressing `0`**
to choose an execution mode and confirm the GCP project.

For step-by-step instructions, configuration reference, timing estimates,
observability dashboard access, and traffic-management scenario walkthroughs,
see the [Lab Guide](LAB_GUIDE.md).
