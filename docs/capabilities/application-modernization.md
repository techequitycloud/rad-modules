# Application Modernization

Two assets in the repo support a "lift-and-modernize" path: the Bank of Anthos demo as a 12-factor reference application, and a guided Migrate-to-Containers lab.

## Bank of Anthos as a 12-factor reference

Bank of Anthos is a microservices banking app deployed by both `modules/Bank_GKE/` and `modules/MC_Bank_GKE/`. The deploy logic (`deploy.tf`) downloads the Bank of Anthos release tarball at apply time and applies the manifests:

- `modules/Bank_GKE/deploy.tf` — single cluster.
- `modules/MC_Bank_GKE/deploy.tf` — `for_each` over clusters; the database StatefulSets (`accounts-db`, `ledger-db`) deploy to `cluster1` (primary) only; non-primary clusters skip those manifests and reach the databases via Multi-Cluster Services.

The download is forced on every apply via `always_run = timestamp()`; the release URL is the only thing to change to upgrade the app version.

The application demonstrates how a modernized workload uses managed identity, mesh mTLS, multi-region routing, and observability — all the capabilities the rest of the repo documents.

## Stateful workloads in a multi-region topology

The database placement pattern in `MC_Bank_GKE` is worth understanding explicitly:

1. `accounts-db` and `ledger-db` are Kubernetes `StatefulSet` resources deployed **only to `cluster1`** (the primary region).
2. Application pods on `cluster2`–`cluster4` reach these databases through **Multi-Cluster Services** — a fleet-level DNS name that routes to the primary cluster's endpoints over the mesh.
3. This preserves data consistency (no distributed database) while allowing stateless application tiers to be globally distributed.

This is a portable pattern for any stateful workload that cannot or should not be replicated: deploy state to one cluster, expose it via MCS, let stateless tiers scale freely.

## Post-migration lifecycle: GitOps

The Migrate-to-Containers lab lands workloads on Kubernetes, but the repo does not currently prescribe a GitOps workflow for ongoing delivery. The natural next step after migration is enabling **Anthos Config Management** (Config Sync) on the target cluster so that application manifests are sourced from Git rather than applied imperatively. See [hybrid-cloud-fleet](./hybrid-cloud-fleet.md) for the ACM/Config Sync model.

## Migrate-to-Containers lab

`scripts/gcp-m2c-vm/gcp-m2c-vm.sh` is an interactive lab walking through Migrate-to-Containers for a Linux VM workload, with **preview / create / delete** modes. It is the on-ramp for teams whose modernization strategy includes lifting VM workloads onto a unified Kubernetes target.

## Cloud Run as a modernization target

`scripts/gcp-cr-mesh/gcp-cr-mesh.sh` shows the Cloud Run + mesh path — modernized workloads do not have to land on Kubernetes. See [serverless](./serverless.md).

## Patterns reused across modules

- `null_resource.deploy_*` with `always_run = timestamp()` for application deploys that need to refresh on each apply.
- Templates rendered by Terraform (`templates/*.yaml.tpl`) and applied via `kubernetes_manifest` or `kubectl apply`.
- Database StatefulSets confined to a primary cluster, accessed from others via MCS — a portable pattern for stateful workloads in a multi-region modernization.
