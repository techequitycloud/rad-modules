# Platform Engineering

This entire repository is a platform-engineering deliverable: a curated catalog of opinionated, self-service "golden paths" exposed through both a CLI and a web UI.

## A module catalog, not a kit

`modules/` contains five standalone modules. From `SKILLS.md` §1: *"There is no shared foundation module ... A module owns every resource it provisions and produces its own state."*

| Module | Golden path |
|---|---|
| `Istio_GKE` | Open-source Istio on GKE Standard with full observability |
| `Bank_GKE` | Cloud Service Mesh + Bank of Anthos on a single cluster |
| `MC_Bank_GKE` | Fleet-wide CSM + MCI/MCS across up to 4 GKE clusters |
| `AKS_GKE` | Azure AKS attached as a GKE Attached Cluster via Fleet |
| `EKS_GKE` | AWS EKS attached as a GKE Attached Cluster via Fleet |

The deeper technologies are catalogued under `docs/capabilities/` — [service-mesh](../capabilities/service-mesh.md), [kubernetes](../capabilities/kubernetes.md), [multicloud](../capabilities/multicloud.md), [hybrid-cloud-fleet](../capabilities/hybrid-cloud-fleet.md), and others.

## A single deployment lifecycle

Same four actions for every module — **create / update / delete / list** — through:

- The **RAD Lab Launcher** CLI (`rad-launcher/radlab.py`)
- The **RAD platform UI** invoking Cloud Build (`rad-ui/automation/`)

Both surfaces consume the same Terraform module source. See [cicd](./cicd.md) for the pipeline and [developer-productivity](./developer-productivity.md) for the user experience.

## UI-as-data via UIMeta annotations

Every variable carries a `{{UIMeta group=N order=M }}` annotation so the UI generates the deployment form by reading the variable file directly. The DSL and standard groups are documented in [infrastructure-as-code](../capabilities/infrastructure-as-code.md).

## Standardized scaffolding

The standard module layout, conventions, and invariants are documented in [infrastructure-as-code](../capabilities/infrastructure-as-code.md). Adding a new module is `cp -a modules/Istio_GKE modules/MyNewModule` and editing the domain-specific `.tf` files.

## Workflow surface for AI assistants

`AGENTS.md` defines workflow modes (`/global`, `/istio`, `/bank`, `/multicluster`, `/attached`, `/troubleshoot`, `/maintain`, `/security`) that prime an AI agent or new engineer with module-specific context. This is platform engineering applied to the AI-pair-programming surface itself.

## Versioning and release management

The platform catalog has no separate versioning layer — consumers pin to a Git commit SHA or branch when they supply `_MODULE_GIT_REPO_URL` to a Cloud Build pipeline. The recommended practice is to tag stable catalog states (e.g., `v1.2.0`) and reference tags rather than branches in production deployments, so that an upgrade is a deliberate change rather than a silent drift. A `CHANGELOG.md` at the repo root capturing per-module changes between tags is the minimum viable release-management artifact; GitHub Releases or Cloud Artifact Registry module packages are the natural next step for teams that need a formal promotion gate.

## Platform observability

The platform team should observe the platform's own health separately from the workloads it deploys. Key signals:

- **Cloud Build pipeline success rate and duration** — a rising `tofu apply` duration trend signals provider API latency or growing module complexity before it becomes a user-visible failure.
- **Purge frequency** — a rising number of purge pipeline invocations is a leading indicator of destroy reliability degrading.
- **Provider cache hit rate** — cache misses on every build indicate the GCS cache key is being invalidated more often than expected, adding avoidable build time.

A Cloud Monitoring dashboard querying Cloud Build log-based metrics covers the first two; the third can be tracked by adding a log entry in the cache-restore step.

## Contribution and validation guardrails

Adding a new module is documented as `cp -a modules/Istio_GKE modules/MyNewModule`. The following checks are the definition-of-ready before a new module enters the catalog:

1. `tofu validate` and `tofu fmt -check` pass with no warnings.
2. All required outputs (`deployment_id`, `project_id`, `cluster_credentials_cmd`) are declared.
3. `variables.tf` carries `credit_cost`, `require_credit_purchases`, and `enable_purge` with correct `{{UIMeta}}` annotations.
4. A `README.md` and a long-form `<Module_Name>.md` exist.
5. `provider-auth.tf` uses the impersonation pattern; no service account key files are referenced.

These checks are currently a manual checklist in `SKILLS.md`; encoding them as a Cloud Build validation pipeline triggered on PRs that touch `modules/` would make the contract machine-enforced.

## A tiered path from learning to production

- **Lab:** `scripts/gcp-istio-traffic/`, `scripts/gcp-istio-security/`, `scripts/gcp-cr-mesh/`, `scripts/gcp-m2c-vm/` for hands-on bash exercises (preview / create / delete modes).
- **Demo:** `modules/Istio_GKE`, `modules/Bank_GKE` for opinionated single-cluster reference deployments.
- **Multi-cluster reference:** `modules/MC_Bank_GKE` for fleet-wide CSM + MCI/MCS.
- **Multi-cloud:** `modules/AKS_GKE`, `modules/EKS_GKE` for fleet management of non-GCP clusters.
