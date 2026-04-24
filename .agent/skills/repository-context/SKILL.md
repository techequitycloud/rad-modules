---
name: repository-context
description: Overall structure of rad-modules — the RAD Lab OpenTofu modules, the rad-launcher CLI that deploys them, and the rad-ui platform integration.
---

# Repository Context

`rad-modules` is the module catalog for **RAD Lab** — a collection of OpenTofu/Terraform modules that deploy educational Google Cloud and multi-cloud Kubernetes reference architectures. Each module is standalone and runnable through the interactive `rad-launcher` CLI or through the RAD platform's Cloud Build automation in `rad-ui/automation/`.

## Top-Level Layout

```
rad-modules/
├── modules/            # Deployable OpenTofu modules (one per RAD Lab scenario)
│   ├── AKS_GKE/        # Azure AKS registered as a GKE Attached Cluster
│   ├── Bank_GKE/       # Bank of Anthos on a single GKE cluster
│   ├── EKS_GKE/        # AWS EKS registered as a GKE Attached Cluster
│   ├── Istio_GKE/      # GKE + open-source Istio (sidecar or ambient)
│   └── MC_Bank_GKE/    # Bank of Anthos across multiple GKE clusters (MCI/MCS)
├── rad-launcher/       # Python CLI that drives `tofu` + GCS state for modules
└── rad-ui/
    └── automation/     # Cloud Build YAMLs invoked by the RAD platform UI
```

The root `README.md`, `CHANGELOG.md`, and `LICENSE` come from the OpenTofu project and are not module-specific.

## Module Catalog

Each top-level `modules/<Name>/` directory is an independent OpenTofu root module. There is no shared foundation module and no symlinks between modules — everything is self-contained. Differences are in which cloud providers they target and whether they install Kubernetes workloads.

| Module | Purpose | Key Providers |
|---|---|---|
| `AKS_GKE` | Create AKS in Azure, attach to a GKE Fleet | `azurerm`, `google`, `helm` |
| `EKS_GKE` | Create EKS in AWS, attach to a GKE Fleet | `aws`, `google`, `helm` |
| `Bank_GKE` | GKE (Autopilot/Standard) + Cloud Service Mesh + Bank of Anthos | `google`, `google-beta`, `kubernetes`, `null` |
| `MC_Bank_GKE` | Multi-cluster GKE + fleet-wide CSM + MCI/MCS + Bank of Anthos | `google`, `google-beta`, `kubernetes` (per-cluster aliases), `null` |
| `Istio_GKE` | GKE Standard + open-source Istio (sidecar or ambient) + Bookinfo | `google`, `null` |

### Shared Module Patterns

Two broad families exist:

1.  **GKE Attached Cluster modules** (`AKS_GKE`, `EKS_GKE`) — provision a Kubernetes cluster in Azure or AWS, install the GKE Connect bootstrap manifests via a `modules/attached-install-manifest` submodule, then create a `google_container_attached_cluster` to register the cluster in a GKE Fleet. See the `attached-cluster-modules` skill.

2.  **Native GKE + workload modules** (`Bank_GKE`, `MC_Bank_GKE`, `Istio_GKE`) — provision GKE cluster(s), enable a service mesh (Cloud Service Mesh or open-source Istio), and deploy a demo application (Bank of Anthos or Bookinfo) via `null_resource` + `kubectl`/`helm` scripts. See the `gke-application-modules` skill.

All modules share the same conventions for TF file organization, variables, provider authentication, and the UI metadata format. See the `module-conventions` skill for the binding rules.

## rad-launcher

`rad-launcher/` is a Python CLI (`radlab.py`) that:

- Discovers modules from `../modules/` and presents a selection menu.
- Stores OpenTofu state and `.tfvars` in a user-provided GCS bucket in a "RAD Lab management project".
- Supports `create`, `update`, `delete`, and `list` actions, each producing or consuming a 4-character **deployment ID**.
- Validates user-supplied `--varfile` contents against each module's `variables.tf` before invoking `tofu`.
- Installs its own prerequisites (`installer_prereq.py` → OpenTofu + Cloud SDK + kubectl + Python deps).

The launcher is the **primary** way modules are consumed outside the UI. Any new module must work when invoked this way — meaning its `variables.tf` must declare everything the launcher will pass and must not require interactive inputs beyond what the launcher provides.

Non-interactive example:
```bash
python3 rad-launcher/radlab.py \
  -m AKS_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

## rad-ui Automation

`rad-ui/automation/` contains the Cloud Build pipelines the RAD platform UI uses to deploy modules without the launcher:

| File | Trigger |
|---|---|
| `cloudbuild_deployment_create.yaml` | First deploy of a module |
| `cloudbuild_deployment_update.yaml` | Re-apply with new inputs |
| `cloudbuild_deployment_destroy.yaml` | `tofu destroy` |
| `cloudbuild_deployment_purge.yaml` | Administrative force-cleanup |

The UI reads variable metadata (grouping, ordering, whether update-safe) from the `{{UIMeta ...}}` tags in each module's `variables.tf`. These tags are load-bearing — see the `module-conventions` skill.

## Governance

- **Naming**: Module directory names are `PascalCase` with underscores separating clouds/scenarios (e.g. `AKS_GKE`, `MC_Bank_GKE`). TF file names are lowercase (`gke.tf`, `network.tf`, `provider-auth.tf`).
- **License headers**: Every `.tf` file begins with an Apache 2.0 block-comment header referencing Google LLC and the year.
- **State**: State is never stored in the repo. The launcher and `rad-ui` automation put it in GCS.
- **No shared code**: Modules do **not** symlink to each other. If two modules need the same behavior, each has its own copy. The `modules/<Name>/modules/` subdirectories are module-local helpers (e.g. `attached-install-manifest`, `attached-install-mesh`) and do not cross module boundaries.
- **Documentation**: Each module has both a short `README.md` (summary, usage, inputs/outputs tables) and a long `<MODULE_NAME>.md` (educational deep dive). Both are kept in sync with `variables.tf`.

## Where to Look for Specific Concerns

| Concern | Skill |
|---|---|
| Adding a new TF file, ordering variables, UIMeta, provider auth | `module-conventions` |
| AKS/EKS cluster creation, GKE Attached, OIDC federation | `attached-cluster-modules` |
| GKE cluster creation, CSM/Istio, Bank of Anthos/Bookinfo deploy | `gke-application-modules` |
| Running locally, `rad-launcher` flags, varfiles, state buckets | `rad-launcher/README.md` |
| UI-driven deployment pipelines | `rad-ui/automation/*.yaml` |
