# FinOps Adoption

The repository encodes cost-awareness into platform deployment: every module declares its credit cost, supports gated purchasing, and ships with destroy / purge automation so demo workloads do not silently run forever.

## Credit-based cost gating

Every module's `variables.tf` declares the cost of a deployment in platform credits and (optionally) requires the user to hold a balance before deploying:

```hcl
variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require_credit_purchases is true, users must have sufficient credit balance before deploying. Defaults to 100. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require users to hold a credit balance before deploying this module. {{UIMeta group=0 order=104 }}"
  type        = bool
}
```

(present in `modules/Istio_GKE/variables.tf`, `modules/Bank_GKE/variables.tf`, `modules/MC_Bank_GKE/variables.tf`, `modules/AKS_GKE/variables.tf`, `modules/EKS_GKE/variables.tf`).

Platform admins can set `require_credit_purchases = true` to prevent a deployment from starting if the requesting user has not pre-purchased the budget for it — a hard FinOps control at the platform layer.

## Purge to recover stuck spend

`enable_purge` (`{{UIMeta group=0 order=106 }}`) is the kill-switch that lets platform administrators force-delete a deployment that ordinary `tofu destroy` cannot remove. It is wired into the `cloudbuild_deployment_purge.yaml` pipeline (`rad-ui/automation/cloudbuild_deployment_purge.yaml`, 600s timeout) — much shorter than `destroy` because purge is for the worst case, not the happy path.

This is critical for FinOps: a failed destroy on a multi-cluster Bank_GKE deployment would otherwise leave four GKE clusters running until someone notices the bill.

## Spot VMs for lab modules

Both hands-on lab scripts default to GKE node pools backed by Spot VMs:

- `scripts/gcp-istio-security/README.md` — "3-node `n1-standard-2` GKE cluster (Spot VMs by default)"
- `scripts/gcp-istio-traffic/README.md` — "2-node `n1-standard-2` GKE cluster (Spot VMs by default)"

Spot pricing trades availability (~70% cheaper) for interruption tolerance, which is appropriate for ephemeral training environments.

## Autopilot option for managed cost shape

`modules/Bank_GKE/gke.tf` exposes both **Autopilot** and **Standard** GKE cluster modes via a feature flag. Autopilot bills per-pod-second and removes node-pool sizing decisions, which typically reduces cost on bursty / dev workloads. Engineers can switch from Standard to Autopilot by toggling a single variable.

## Destroy-first hygiene

`SKILLS.md` §6 invariant: every `null_resource` with a side effect has a matching destroy provisioner that uses `set +e`, `--ignore-not-found`, and `|| true` so cleanup is best-effort and never blocks. This makes destroy reliable even when the underlying cluster is partly broken — preventing the "I'll clean it up later" scenario that drives lab spend.

`modules/MC_Bank_GKE/mcs.tf` is the canonical example: it deletes Multi-Cluster Ingress and Multi-Cluster Service objects across all clusters before Terraform removes the fleet feature, so the destroy graph cannot stall mid-way and leave running compute.

## API-disable safety

Every module sets `disable_on_destroy = false` on `google_project_service` (`SKILLS.md` §6, enforced in each `main.tf`). A destroy on one module never disables APIs that another deployment in the same project still depends on — preventing cascading apply failures that would otherwise force a costly re-create.

## State stored where it can be inspected

Remote state in GCS (`SKILLS.md` §6) makes the deployed footprint of every module discoverable for reporting and chargeback. The `radlab.py` `List` action and the `deployment_id` output give an inventory key that ties Terraform state to platform credit consumption.

## What is *not* here

The repo does not currently include native Cloud Billing budget alerts, Recommender-based rightsizing, or Cloud Asset Inventory exports. These would be natural next steps for a FinOps-mature deployment and could be added to `monitoring.tf` per module.
