# Site Reliability Engineering

How this repository supports SRE practices: error budgets, safe rollouts, incident response, and reliable destroy.

## Service-level objectives

`modules/Bank_GKE/monitoring.tf` defines `google_monitoring_slo` resources for the Bank of Anthos services, attached to the same deployment that provisions the workload. The Bank_GKE workflow in `AGENTS.md` documents how to add a new SLO.

For the metrics and traces feeding those SLOs, see [observability](../capabilities/observability.md).

## Safe rollouts

Traffic-management primitives (canary splits, fault injection, timeouts, retries) are the SRE control surface for limiting blast radius. The canonical reference is [service-mesh](../capabilities/service-mesh.md); the lab in `scripts/gcp-istio-traffic/` walks through them on a live cluster.

## Multi-region availability

`modules/MC_Bank_GKE/` deploys Bank of Anthos across up to four GKE clusters behind a global HTTPS load balancer with Multi-Cluster Ingress and Multi-Cluster Services. See [multicloud](../capabilities/multicloud.md) for the cluster-fleet model and [service-mesh](../capabilities/service-mesh.md) for the cross-cluster traffic story.

## Operational runbooks

`AGENTS.md` defines a `/troubleshoot` workflow keyed by symptom: provisioner failures, mesh pods stuck `Pending`, MCI never receiving a VIP, attached clusters missing from the GCP Console, destroy hangs, APIs disabled after destroy. Each entry pairs the symptom with a one-command diagnostic and a file:line reference. The maintenance counterpart is `/maintain`.

## Destroy as a first-class operation

A failed `tofu destroy` is an SRE problem — it leaves orphaned cloud resources accruing risk. The repo's destroy-safety invariants (`set +e`, `--ignore-not-found`, `|| true`, dependency-ordered teardown) are documented in [infrastructure-as-code](../capabilities/infrastructure-as-code.md) and applied in every `null_resource` create-time effect.
