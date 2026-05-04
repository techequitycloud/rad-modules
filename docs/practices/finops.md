# FinOps Adoption

Cost-awareness is encoded in platform deployment: every module declares its credit cost, supports gated purchasing, and ships with destroy / purge automation so demo workloads do not silently run forever.

## Credit-based cost gating

Every module's `variables.tf` declares the cost of a deployment in platform credits and (optionally) requires the user to hold a balance:

```hcl
variable "credit_cost" {
  description = "... defaults to 100. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "... {{UIMeta group=0 order=104 }}"
  type        = bool
}
```

Present in all five modules. Setting `require_credit_purchases = true` prevents a deployment from starting without pre-purchased budget — a hard FinOps control at the platform layer.

## Purge to recover stuck spend

`enable_purge` (`{{UIMeta group=0 order=106 }}`) is the kill-switch wired into `cloudbuild_deployment_purge.yaml` (600s timeout) — for the case where ordinary `tofu destroy` cannot finish. Without it, a failed destroy on a multi-cluster deployment leaves four GKE clusters running until someone notices the bill. See [cicd](./cicd.md).

## Cost-shape choices for compute

Spot VMs in the lab scripts (`scripts/gcp-istio-security/`, `scripts/gcp-istio-traffic/`) cut node costs by up to 60–90% versus on-demand pricing, in exchange for the possibility of preemption with a 30-second eviction notice. This trade-off is acceptable for short-lived lab exercises but not for the persistent module deployments — none of the `modules/` use Spot nodes by default. The Autopilot option in `modules/Bank_GKE/gke.tf` is the recommended cost-efficient path for demo modules: billing is per-Pod rather than per-node, idle capacity is not charged, and node management overhead is eliminated. See [kubernetes](../capabilities/kubernetes.md).

## Destroy-first hygiene

The "I'll clean it up later" failure mode is the largest source of lab spend. Repo invariants — destroy provisioners using `set +e`, `--ignore-not-found`, `|| true`, and dependency-ordered teardown — make destroy reliable even when the underlying cluster is partly broken. See [infrastructure-as-code](../capabilities/infrastructure-as-code.md).

## API-disable safety

Every module sets `disable_on_destroy = false` on `google_project_service`, so a destroy on one module never disables APIs that another deployment in the same project still depends on — preventing cascading apply failures that would otherwise force costly re-creates. See [infrastructure-as-code](../capabilities/infrastructure-as-code.md).

## State as a chargeback signal

Remote state in GCS plus the `deployment_id` output give an inventory key that ties Terraform state to platform credit consumption. The `radlab.py list` action enumerates active deployments.

## Cost attribution via labels

The `deployment_id` output is a natural billing label key — adding it as a resource label on GKE clusters and node pools ties every cloud cost line item to the specific deployment that incurred it. This enables per-deployment chargeback from the standard Cloud Billing export without any additional tooling. Extending `variables.tf` with a `labels` map variable (passed through to GKE and GCS resources) is the recommended pattern for teams that need finer-grained cost attribution.

## What is not here

Native Cloud Billing budget alerts, Recommender-based rightsizing, and Cloud Asset Inventory exports are not currently included. Natural next steps for a FinOps-mature deployment:

- **Budget alerts:** `google_billing_budget` resources scoped to the management project, with Pub/Sub notification to trigger a purge pipeline when spend exceeds a threshold.
- **Rightsizing:** Vertical Pod Autoscaler (VPA) in recommendation mode surfaces over-provisioned resource requests without changing anything; pairing VPA recommendations with GKE node autoscaling reduces wasted capacity.
- **Namespace quotas:** `ResourceQuota` objects per namespace prevent a single workload from consuming disproportionate cluster resources, providing a soft chargeback boundary within a shared cluster.
- **CAI exports:** Exporting Cloud Asset Inventory to BigQuery enables cross-project inventory queries that correlate deployed resources with their credit consumption and deployment lifecycle state.
