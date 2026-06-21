# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

`rad-modules` is a catalog of standalone OpenTofu/Terraform modules that deploy educational Google Cloud and multi-cloud Kubernetes reference architectures ("RAD Lab"). Modules are deployed via the interactive `rad-launcher` CLI or via Cloud Build pipelines driven by the RAD platform UI.

## Common Commands

All Terraform commands run from **within a module directory** (e.g. `cd modules/Istio_GKE`):

```bash
# Validate and format-check a module
tofu init -backend=false
tofu validate
tofu fmt -check

# Run module-level tests (uses mock providers, no GCP credentials needed)
tofu test

# Plan/apply with a real project
tofu plan  -var="project_id=my-gcp-project"
tofu apply -var="project_id=my-gcp-project"
tofu destroy -var="project_id=my-gcp-project"
```

Lint all modules from the repo root:
```bash
# Format check (CI uses terraform, but tofu also works)
terraform fmt -check -recursive modules/

# tflint (run from within a module directory)
tflint --init --config ../../.tflint.hcl
tflint --config ../../.tflint.hcl --format compact
```

Run the interactive launcher:
```bash
cd rad-launcher
python3 installer_prereq.py   # install prerequisites once
python3 radlab.py             # interactive module deploy/destroy
```

Non-interactive launcher:
```bash
python3 rad-launcher/radlab.py \
  -m Istio_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

## Architecture

### Module Families

Six independent modules under `modules/`. No shared foundation module, no symlinks, no cross-module Terraform dependency — each owns every resource it provisions and its own state.

| Module | What it deploys |
|---|---|
| `Istio_GKE` | GKE Standard + open-source Istio (sidecar **or** ambient) + Prometheus/Jaeger/Grafana/Kiali + optional Bookinfo |
| `Bank_GKE` | GKE (Autopilot/Standard) + Cloud Service Mesh + Bank of Anthos + optional ACM + Cloud Monitoring SLOs |
| `MC_Bank_GKE` | Multi-cluster GKE across regions + fleet-wide CSM + Multi-Cluster Ingress/Services + Bank of Anthos |
| `AKS_GKE` | Azure AKS registered in a GKE Fleet as a GKE Attached Cluster via Helm |
| `EKS_GKE` | AWS EKS registered in a GKE Fleet as a GKE Attached Cluster via Helm |
| `VMware_Engine` | GCVE private cloud + VPC peering + Windows jump host + vCenter credential reset |

### Standard Module File Layout

```
modules/<Module_Name>/
├── main.tf              # data.google_project, random_id, google_project_service API enablement
├── provider-auth.tf     # google provider with SA impersonation (GKE modules)
├── versions.tf          # required_providers + required_version
├── variables.tf         # UIMeta-annotated inputs
├── outputs.tf           # deployment_id, project_id, cluster_credentials_cmd, external_ip
├── network.tf           # VPC, subnets, Cloud Router + NAT
├── gke.tf               # GKE cluster, node pool, cluster SA, IAM
├── <feature>.tf         # e.g. istiosidecar.tf, istioambient.tf, asm.tf, deploy.tf, hub.tf
├── manifests/           # Raw Kubernetes manifests
├── templates/           # Kubernetes manifests rendered via templatefile()
├── tests/               # *.tftest.hcl using mock providers
├── README.md            # Short overview + inputs/outputs tables
└── <Module_Name>.md     # Long-form educational deep dive
```

Lab guides live at `docs/labs/<Module_Name>.md`, **not** inside the module directory.

### Two Provider Auth Patterns

**Impersonation (`provider-auth.tf`)** — used by `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`, `VMware_Engine`. Fetches a short-lived access token for `var.resource_creator_identity` (a service account) when that variable is non-empty; otherwise falls back to ADC.

**Direct (`provider.tf`)** — used by `AKS_GKE`, `EKS_GKE`. Configures `azurerm`/`aws`/`helm` providers directly. Azure credentials via `ARM_*` env vars; AWS credentials via `AWS_*` env vars — never hardcode these as defaults.

### Post-Provisioning via `null_resource`

Anything that can't be expressed as a Terraform resource (installing Istio via `istioctl`, applying Bank of Anthos manifests, waiting for a LoadBalancer IP) uses `null_resource` + `local-exec`:

- **Triggers** must capture every variable the destroy provisioner needs (only `self.triggers.*` is available at destroy time).
- **Create provisioner**: `set -eo pipefail`, installs missing CLIs into `$HOME/.local/bin`, runs `gcloud container clusters get-credentials --impersonate-service-account=...`, then does the actual install.
- **Destroy provisioner**: `set +e`, uses `--ignore-not-found` and `|| echo "Warning:..."` — must be best-effort so destroy never blocks on missing resources.

### UIMeta Variable Annotations

Every `variable` description ends with a `{{UIMeta group=N order=M }}` tag that drives the RAD platform UI. Groups follow this convention: 0=Provider/Metadata, 1=Main, 2=Network, 3=GKE, 4=Features, 6=Application. The `updatesafe` flag marks variables that can change without forcing resource replacement. `enable_services` always lives in group 0 order 109.

### API Enablement Invariant

Every `google_project_service` resource must have both:
```hcl
disable_dependent_services = false
disable_on_destroy         = false
```
Multiple independent modules may share the same GCP project — a destroy of one module must never disable APIs that other modules depend on. Do **not** use `lifecycle { prevent_destroy = true }` on these resources (it causes the destroy pipeline to fail with "Instance cannot be destroyed").

## Key Conventions

- Every `.tf` file begins with the Apache 2.0 license header (Google LLC).
- File names: `snake_case` for `.tf` files; module directories are `PascalCase_WithUnderscores`.
- All modules use `project_id` (not `existing_project_id`) and `region` (not `gcp_region`) for GCP inputs.
- `MC_Bank_GKE` uses four static `kubernetes` provider aliases (`cluster1`–`cluster4`); provider configurations must be static in Terraform — they cannot be generated with `for_each`.
- The `Istio_GKE` sidecar installer pipes a custom `IstioOperator` YAML into `istioctl install -y -f -` to set `hpaSpec.scaleTargetRef.name = istio-ingressgateway` — do not remove this block (it prevents known HPA naming conflicts).
- `external_ip` output reads from a file written by post-provisioning `null_resource` and falls back to `"IP not available"` via `fileexists()`.
- State is never stored in the repo — the launcher and `rad-ui` pipelines store it in GCS.

## CI Pipeline

The GitHub Actions workflow (`.github/workflows/terraform-ci.yml`) runs on changes to `modules/**`:

1. **format** — `terraform fmt -check -recursive modules/`
2. **validate** — `terraform init -backend=false && terraform validate` per changed module
3. **tflint** — Google ruleset via `.tflint.hcl`
4. **test** — `terraform test` per module (mock providers, no GCP credentials)
5. **security** — Trivy config scan (HIGH/CRITICAL, non-blocking)

CI uses `terraform` (Terraform ~1.9) not `tofu`, but they are interchangeable for `init`/`validate`/`fmt`/`test`.

## Agent Workflows

`AGENTS.md` defines slash-command workflows to context-switch into specific module modes: `/istio`, `/bank`, `/multicluster`, `/attached`, `/troubleshoot`, `/maintain`, `/security`. Read `SKILLS.md` for the detailed implementation guide before making structural changes to any module.
