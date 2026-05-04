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

## A tiered path from learning to production

- **Lab:** `scripts/gcp-istio-traffic/`, `scripts/gcp-istio-security/`, `scripts/gcp-cr-mesh/`, `scripts/gcp-m2c-vm/` for hands-on bash exercises (preview / create / delete modes).
- **Demo:** `modules/Istio_GKE`, `modules/Bank_GKE` for opinionated single-cluster reference deployments.
- **Multi-cluster reference:** `modules/MC_Bank_GKE` for fleet-wide CSM + MCI/MCS.
- **Multi-cloud:** `modules/AKS_GKE`, `modules/EKS_GKE` for fleet management of non-GCP clusters.
