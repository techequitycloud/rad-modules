# Site Reliability Engineering

How this repository supports SRE practices: error budgets, safe rollouts, incident response, and reliable destroy.

## Service-level objectives

`modules/Bank_GKE/monitoring.tf` defines `google_monitoring_slo` resources for the Bank of Anthos services, attached to the same deployment that provisions the workload. The Bank_GKE workflow in `AGENTS.md` documents how to add a new SLO.

SLO targets should be explicit in the Terraform resource. A reasonable starting point for a demo banking workload:

- **Availability SLO:** 99.5% of requests succeed (HTTP 2xx) over a 28-day rolling window.
- **Latency SLO:** 95% of requests complete in under 500 ms over the same window.

These targets set an error budget of ~3.6 hours/month for availability. The targets are deliberately achievable on a single-cluster demo deployment; `MC_Bank_GKE` can justify tighter targets given its multi-region redundancy.

For the metrics and traces feeding those SLOs, see [observability](../capabilities/observability.md).

## Alerting policies

SLOs without alerting do not page anyone. `modules/Bank_GKE/monitoring.tf` should pair each SLO with a `google_monitoring_alert_policy` using a burn-rate condition: alert when the error budget is being consumed at 14× the sustainable rate over a 1-hour window (fast-burn), and at 6× over a 6-hour window (slow-burn). This two-window pattern minimizes both false positives and missed incidents. If alerting resources are not yet present in `monitoring.tf`, adding them is the highest-priority SRE gap in the current codebase.

## Safe rollouts

Traffic-management primitives (canary splits, fault injection, timeouts, retries) are the SRE control surface for limiting blast radius. The canonical reference is [service-mesh](../capabilities/service-mesh.md); the lab in `scripts/gcp-istio-traffic/` walks through them on a live cluster.

## Multi-region availability

`modules/MC_Bank_GKE/` deploys Bank of Anthos across up to four GKE clusters behind a global HTTPS load balancer with Multi-Cluster Ingress and Multi-Cluster Services. See [multicloud](../capabilities/multicloud.md) for the cluster-fleet model and [service-mesh](../capabilities/service-mesh.md) for the cross-cluster traffic story.

## Operational runbooks

`AGENTS.md` defines a `/troubleshoot` workflow keyed by symptom: provisioner failures, mesh pods stuck `Pending`, MCI never receiving a VIP, attached clusters missing from the GCP Console, destroy hangs, APIs disabled after destroy. Each entry pairs the symptom with a one-command diagnostic and a file:line reference. The maintenance counterpart is `/maintain`.

## Capacity planning

GKE cluster sizing is currently set via static `variables.tf` defaults (node count, machine type). For demo and lab workloads this is sufficient, but for the multi-cluster `MC_Bank_GKE` module a brief capacity model is needed:

- Enable **node autoscaling** on each cluster with a `min_node_count` that keeps the mesh control plane healthy and a `max_node_count` that caps spend.
- Size the initial node pool to the steady-state load, not the peak load — autoscaling handles spikes; over-provisioning static nodes wastes budget.
- `Bank_GKE`'s Autopilot option eliminates explicit node sizing entirely by billing per-Pod.

For the cost implications of node sizing choices, see [finops](./finops.md).

## Destroy as a first-class operation

A failed `tofu destroy` is simultaneously an SRE problem (orphaned resources accruing risk) and a FinOps problem (uncontrolled spend from abandoned GKE clusters). The repo's destroy-safety invariants (`set +e`, `--ignore-not-found`, `|| true`, dependency-ordered teardown) are documented in [infrastructure-as-code](../capabilities/infrastructure-as-code.md) and applied in every `null_resource` create-time effect. The `enable_purge` kill-switch in [finops](./finops.md) is the last resort when these invariants are not enough.
