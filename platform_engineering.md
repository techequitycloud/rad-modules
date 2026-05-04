# Platform Engineering

This entire repository is a platform-engineering deliverable: a curated catalog of opinionated, self-service "golden paths" for GKE, multi-cluster mesh, and multi-cloud Kubernetes, exposed through both a CLI and a web UI.

## A module catalog, not a kit

`modules/` contains five **standalone, self-contained** modules. From `SKILLS.md` §1: *"There is no shared foundation module, no symlink pattern, and no cross-module Terraform dependency. A module owns every resource it provisions and produces its own state."* This is a deliberate platform choice — every offering can be reasoned about, audited, deployed, destroyed, and upgraded in isolation.

| Module | Golden path |
|---|---|
| `Istio_GKE` | Open-source Istio (sidecar / ambient) on GKE Standard with full observability |
| `Bank_GKE` | Cloud Service Mesh + Bank of Anthos demo on a single cluster |
| `MC_Bank_GKE` | Fleet-wide CSM + MCI/MCS across up to 4 GKE clusters |
| `AKS_GKE` | Azure AKS attached as a GKE Attached Cluster via Fleet |
| `EKS_GKE` | AWS EKS attached as a GKE Attached Cluster via Fleet |

## A single deployment lifecycle

The platform exposes the same four actions for every module — **create / update / delete / list** — through:

- The **RAD Lab Launcher** CLI (`rad-launcher/radlab.py`, documented in `rad-launcher/README.md`)
- The **RAD platform UI** invoking Cloud Build (`rad-ui/automation/cloudbuild_deployment_{create,destroy,purge,update}.yaml`)

Both surfaces consume the same Terraform module source. There is no UI-specific fork of the infrastructure code.

## UI-as-data via UIMeta annotations

Platform engineering's classic problem — "how do we make Terraform self-service without writing a custom UI for every module?" — is solved here by annotating every variable with rendering hints (`SKILLS.md` §3.4):

```hcl
variable "existing_project_id" {
  description = "GCP project ID ... {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
}
```

Standard groups codify a consistent form layout across the catalog:

| Group | Section |
|---|---|
| 0 | Provider / Metadata (cost, purge, trusted users, SA identity) |
| 1 | Main (project, region) |
| 2 | Network |
| 3 | Cluster (GKE / AKS / EKS) |
| 4 | Features (mesh, version flags) |
| 6 | Application |

The UI generates the deployment form by reading these annotations directly, so a new module gets a UI for free as soon as its variables are annotated. The `updatesafe` tag tells the UI which fields can be edited in place vs. those that force a rebuild.

## Standardized scaffolding

Every module follows the layout documented in `SKILLS.md` §2:

```
main.tf            # project bootstrap, API enablement, random_id
provider-auth.tf   # impersonation pattern (or provider.tf for attached clusters)
versions.tf        # required_providers + required_version
variables.tf       # UIMeta-annotated inputs
outputs.tf         # deployment_id, project_id, cluster_credentials_cmd, external_ip
network.tf         # VPC, subnet, firewall, Cloud Router + NAT
gke.tf             # cluster, node pool, cluster SA, IAM
<feature>.tf       # null_resource installing workloads
manifests/         # raw YAML
templates/         # rendered YAML
```

The standard output set means downstream tools (the launcher, dashboards, runbooks) can rely on `deployment_id`, `project_id`, `cluster_credentials_cmd`, and `external_ip` being present for every GKE-based module.

## Versioned guardrails

`SKILLS.md` §6 documents the platform's invariants — file naming (`snake_case` `.tf`, `PascalCase` directories), license headers, API enablement flags, destroy-safety, no secrets in defaults, and impersonation gating. These are checked by `tofu validate && tofu fmt -check` (`SKILLS.md` §5) before merge.

## A workflow surface for AI assistants

`AGENTS.md` defines workflow modes (`/global`, `/istio`, `/bank`, `/multicluster`, `/attached`, `/troubleshoot`, `/maintain`, `/security`) that prime an AI agent or a new engineer with the exact context they need to operate inside a single module without breaking the platform's invariants. This is platform engineering applied to the AI-pair-programming surface itself.

## A path from learning to production

The catalog is intentionally tiered:

- **Lab:** `scripts/gcp-istio-traffic/`, `scripts/gcp-istio-security/`, `scripts/gcp-cr-mesh/`, `scripts/gcp-m2c-vm/` for hands-on bash exercises (preview / create / delete modes).
- **Demo:** `modules/Istio_GKE`, `modules/Bank_GKE` for opinionated single-cluster reference deployments.
- **Multi-cluster reference:** `modules/MC_Bank_GKE` for fleet-wide CSM + MCI/MCS.
- **Multi-cloud:** `modules/AKS_GKE`, `modules/EKS_GKE` for fleet management of non-GCP clusters.

A platform team can adopt a module by copying it (`SKILLS.md` §5 — `cp -a modules/Istio_GKE modules/MyNewModule`) and tailoring it, while keeping the conventions that make every module deployable through the same UI and CLI.
