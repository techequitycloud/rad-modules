# Application Modernization

Two assets in the repo support a "lift-and-modernize" path: the Bank of Anthos demo as a 12-factor reference application, and a guided Migrate-to-Containers lab.

## Bank of Anthos as a 12-factor reference

Bank of Anthos is a microservices banking app deployed by both `modules/Bank_GKE/` and `modules/MC_Bank_GKE/`. The deploy logic (`deploy.tf`) downloads the Bank of Anthos release tarball at apply time and applies the manifests:

- `modules/Bank_GKE/deploy.tf` — single cluster.
- `modules/MC_Bank_GKE/deploy.tf` — `for_each` over clusters; the database StatefulSets (`accounts-db`, `ledger-db`) deploy to `cluster1` (primary) only; non-primary clusters skip those manifests and reach the databases via Multi-Cluster Services.

The download is forced on every apply via `always_run = timestamp()`; the release URL is the only thing to change to upgrade the app version.

The application demonstrates how a modernized workload uses managed identity, mesh mTLS, multi-region routing, and observability — all the capabilities the rest of the repo documents.

## Migrate-to-Containers lab

`scripts/gcp-m2c-vm/gcp-m2c-vm.sh` is an interactive lab walking through Migrate-to-Containers for a Linux VM workload, with **preview / create / delete** modes. It is the on-ramp for teams whose modernization strategy includes lifting VM workloads onto a unified Kubernetes target.

## Cloud Run as a modernization target

`scripts/gcp-cr-mesh/gcp-cr-mesh.sh` shows the Cloud Run + mesh path — modernized workloads do not have to land on Kubernetes. See [serverless](./serverless.md).

## Patterns reused across modules

- `null_resource.deploy_*` with `always_run = timestamp()` for application deploys that need to refresh on each apply.
- Templates rendered by Terraform (`templates/*.yaml.tpl`) and applied via `kubernetes_manifest` or `kubectl apply`.
- Database StatefulSets confined to a primary cluster, accessed from others via MCS — a portable pattern for stateful workloads in a multi-region modernization.
