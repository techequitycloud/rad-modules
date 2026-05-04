# Site Reliability Engineering

This repository supports SRE practices through built-in observability, SLO instrumentation, traffic-management primitives, and explicit destroy/troubleshooting playbooks for every module.

## SLOs and service-level monitoring

`modules/Bank_GKE/monitoring.tf` defines `google_monitoring_slo` resources for the Bank of Anthos services. SLOs are coupled to the deployment so the four-nines or three-nines budget moves with the workload, not in a separate console click-trail. The Bank_GKE workflow in `AGENTS.md` documents how to add a new SLO by appending a `google_monitoring_slo` block referencing the existing service resource.

## Out-of-the-box observability stack

`modules/Istio_GKE/istiosidecar.tf` and `modules/Istio_GKE/istioambient.tf` install the canonical Istio observability add-ons — **Prometheus**, **Grafana**, **Jaeger**, and **Kiali** — automatically as part of the mesh installation. An operator gets metrics, traces, dashboards, and a service-graph view with no extra configuration step.

For Cloud Service Mesh (managed Istio) deployments, `modules/Bank_GKE/asm.tf` and `modules/MC_Bank_GKE/asm.tf` enable the GKE Hub `service_mesh` feature, which routes telemetry into Cloud Monitoring and Cloud Trace via the managed control plane.

## Traffic management for reliable rollouts

`scripts/gcp-istio-traffic/gcp-istio-traffic.sh` is a hands-on lab covering the traffic-management primitives SREs use to limit blast radius:

- Weighted traffic splits (canary / blue-green)
- Header-based routing
- Fault injection (chaos experiments)
- Timeouts and retries
- Port-level load balancing
- Sidecar egress controls

These are the same primitives applied at scale by `modules/MC_Bank_GKE`, which uses Multi-Cluster Ingress and Multi-Cluster Services to route around regional failures (`modules/MC_Bank_GKE/glb.tf`, `modules/MC_Bank_GKE/mcs.tf`).

## Operational runbooks

`AGENTS.md` includes a dedicated Troubleshooting workflow keyed by symptom: provisioner failures, mesh pods stuck Pending, MCI never receiving a VIP, attached clusters missing from the GCP Console, destroy hangs, and APIs disabled after destroy. Each entry pairs the symptom with a one-command diagnostic and the file:line of the related source.

`AGENTS.md` also lists standard diagnostic commands — `gcloud container fleet mesh describe`, `istioctl verify-install`, `istioctl proxy-status`, `kubectl get mci -n bank-of-anthos` — keeping the on-call workflow close to the code that produced the resource.

## Destroy safety as a first-class invariant

`SKILLS.md` §6 mandates that every `null_resource` create-time effect has a matching `when = destroy` provisioner using `set +e`, `--ignore-not-found` on `kubectl delete`, and `|| true` to be best-effort. Examples:

- `modules/Istio_GKE/istiosidecar.tf` — sidecar mode teardown
- `modules/MC_Bank_GKE/mcs.tf` — pre-destroy MCI/MCS cleanup so the fleet feature can be removed
- `modules/Bank_GKE/hub.tf` — depends-on chain ordering ASM removal before Hub deregistration

This makes failed deploys recoverable without orphaned cloud resources — a recurring SRE pain point.

## API protection

Every module sets `disable_on_destroy = false` and `disable_dependent_services = false` on `google_project_service` (see `SKILLS.md` §6, enforced in each module's `main.tf`). Tearing down one deployment cannot disable APIs that other production deployments depend on.
