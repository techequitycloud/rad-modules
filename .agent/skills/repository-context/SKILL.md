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
│   ├── Container_Migration/ # Migrate-to-Containers: source VMs → GKE
│   ├── Istio_GKE/      # GKE + open-source Istio (sidecar or ambient)
│   ├── MC_Bank_GKE/    # Bank of Anthos across multiple GKE clusters (MCI/MCS)
│   ├── Migration_Center/   # Migration Center discovery over GCE + AWS source VMs
│   └── VMware_Engine/  # Google Cloud VMware Engine private cloud + jump host
├── docs/
│   ├── labs/           # Per-module hands-on lab guides (one per module)
│   └── modules/        # Per-module long-form technical deep dives (one per module)
├── scripts/            # check_conventions.py, validate_all_modules.sh, standalone shell/Python demos
├── rad-launcher/       # Python CLI that drives `tofu` + GCS state for modules
└── rad-ui/
    └── automation/     # Cloud Build YAMLs invoked by the RAD platform UI
        ├── check_step_arg_limits.py  # lints the 10k step-arg cap + volume reuse rule
        └── scripts/    # step logic extracted out of the YAML to stay under that cap
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
| `Istio_GKE` | GKE Standard + open-source Istio (sidecar or ambient); Bookinfo is deployed manually per the lab guide | `google`, `google-beta`, `kubernetes`, `null` |
| `Container_Migration` | Source VMs + Migrate-to-Containers CLI VM + GKE target cluster | `google`, `random`, `null` |
| `Migration_Center` | Migration Center discovery over Linux/Windows GCE VMs plus AWS source VMs | `google`, `aws`, `random`, `null`, `tls` |
| `VMware_Engine` | GCVE private cloud + network peering/policy + jump host | `google`, `random`, `null`, `external` |

### Shared Module Patterns

Two broad families exist:

1.  **GKE Attached Cluster modules** (`AKS_GKE`, `EKS_GKE`) — provision a Kubernetes cluster in Azure or AWS, install the GKE Connect bootstrap manifests via a `modules/attached-install-manifest` submodule, then create a `google_container_attached_cluster` to register the cluster in a GKE Fleet. See the `attached-cluster-modules` skill.

2.  **Native GKE + workload modules** (`Bank_GKE`, `MC_Bank_GKE`, `Istio_GKE`) — provision GKE cluster(s), enable a service mesh (Cloud Service Mesh or open-source Istio), and — for `Bank_GKE` and `MC_Bank_GKE` — deploy Bank of Anthos via `null_resource` + `kubectl`/`helm` scripts. `Istio_GKE` deploys **no** application: its `deploy_application` variable is dead code and no Bookinfo install step exists, so the mesh comes up with an empty (but pre-labelled) `default` namespace. See the `gke-application-modules` skill.

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

| File | Trigger | Timeout |
|---|---|---|
| `cloudbuild_deployment_create.yaml` | First deploy of a module | 3600s |
| `cloudbuild_deployment_update.yaml` | Re-apply with new inputs | 3600s |
| `cloudbuild_deployment_destroy.yaml` | `tofu destroy` | 3600s |
| `cloudbuild_deployment_purge.yaml` | Administrative force-cleanup | 600s |

Steps too large for Cloud Build's 10,000-character per-step-arg cap are extracted to `rad-ui/automation/scripts/` (`apply_infrastructure.sh`, `apply_infrastructure_update.sh`, `prepare_destroy.sh`, `handle_plan_cycle.sh`) and staged onto a shared `pipeline-scripts` volume. `check_step_arg_limits.py` enforces the cap and Cloud Build's rule that a named volume be used by two or more steps; `.github/workflows/cloudbuild-lint.yml` runs it in CI.

The create, update, and destroy pipelines cache downloaded Terraform provider binaries in GCS at `gs://${_DEPLOYMENT_BUCKET_ID}/terraform-provider-cache/${_MODULE_NAME}/providers.tar.gz` using `TF_PLUGIN_CACHE_DIR`. The cache is restored before `tofu init` and saved back after a successful init; a missing cache is non-fatal.

The UI reads variable metadata (grouping, ordering, whether update-safe) from the `{{UIMeta ...}}` tags in each module's `variables.tf`. These tags are load-bearing — see the `module-conventions` skill.

## Governance

- **Naming**: Module directory names are `PascalCase` with underscores separating clouds/scenarios (e.g. `AKS_GKE`, `MC_Bank_GKE`). TF file names are lowercase (`gke.tf`, `network.tf`, `provider-auth.tf`).
- **License headers**: Nearly every `.tf` file begins with an Apache 2.0 block-comment header referencing Google LLC and the year. Three `versions.tf` files (`Bank_GKE`, `Migration_Center`, `VMware_Engine`) currently lack one, which is why `scripts/check_conventions.py` treats a missing header as WARN rather than FAIL.
- **State**: State is never stored in the repo. The launcher and `rad-ui` automation put it in GCS.
- **No shared code**: Modules do **not** symlink to each other. If two modules need the same behavior, each has its own copy. The `modules/<Name>/modules/` subdirectories are module-local helpers (e.g. `attached-install-manifest`, `attached-install-mesh`) and do not cross module boundaries.
- **Documentation**: Each module has a short `README.md` inside the module directory (summary, usage, inputs/outputs tables) plus two repo-root files — a long educational deep dive at `docs/modules/<Module_Name>.md` and a hands-on lab guide at `docs/labs/<Module_Name>.md`. The README links out to them with a `../../docs/...` path. All three are kept in sync with `variables.tf`.

## Where to Look for Specific Concerns

| Concern | Skill |
|---|---|
| Adding a new TF file, ordering variables, UIMeta, provider auth | `module-conventions` |
| AKS/EKS cluster creation, GKE Attached, OIDC federation | `attached-cluster-modules` |
| GKE cluster creation, CSM/Istio, Bank of Anthos/Bookinfo deploy | `gke-application-modules` |
| Running locally, `rad-launcher` flags, varfiles, state buckets | `rad-launcher/README.md` |
| UI-driven deployment pipelines | `rad-ui/automation/*.yaml` |
