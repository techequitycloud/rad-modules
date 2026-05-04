# Enhanced Developer Productivity

The repository pulls a developer from "I want to learn Istio" or "I need a multi-cluster mesh" to a working environment in a single command. It does this by pre-packaging the cluster, mesh, observability stack, sample app, and operator runbook into one self-contained module.

## One command from zero to a running mesh

```bash
cd modules/Istio_GKE
tofu init
tofu apply -var="existing_project_id=my-gcp-project"
```

That single apply provisions a GKE Standard cluster, a VPC with private nodes, Cloud NAT, an Istio control plane (sidecar **or** ambient via `var.install_ambient_mesh`), Prometheus, Grafana, Jaeger, Kiali, and optionally the Bookinfo sample app — all defined under `modules/Istio_GKE/`. There is no separate "now configure the mesh" step.

## Self-service via the launcher

`rad-launcher/radlab.py` is a Python CLI that walks a developer through:

1. Confirming the active `gcloud` user
2. Picking the management project
3. Picking a module from `modules/`
4. Picking an action (`create` / `update` / `delete` / `list`)
5. Picking or creating the GCS state bucket
6. Supplying the org / billing / folder IDs

`rad-launcher/installer_prereq.py` installs OpenTofu, the Cloud SDK, `kubectl`, and all Python deps in one shot, including auto-detecting Cloud Shell to skip what's already there.

## Self-service via the platform UI

The same modules deploy through the RAD platform UI without a developer ever opening a terminal. Every variable in `variables.tf` carries a `{{UIMeta group=N order=M }}` annotation:

```hcl
variable "existing_project_id" {
  description = "GCP project ID ... {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
}
```

(`SKILLS.md` §3.4). The UI uses these annotations to render a grouped, ordered deployment form, so a new module gets a UI for free as soon as its variables are annotated correctly. The `updatesafe` tag tells the UI which fields can be edited on an in-place re-apply versus those that force a rebuild.

## Sane defaults, every time

Every module exposes the same outputs, so any tool — a Slack bot, a runbook, a follow-on script — can rely on them (`SKILLS.md` §3.5):

```hcl
output "deployment_id"
output "project_id"
output "cluster_credentials_cmd"   # a copy-pastable gcloud command
output "external_ip"               # LoadBalancer IP, with fileexists() fallback
```

`cluster_credentials_cmd` is the highest-impact one: a developer gets a one-line `gcloud container clusters get-credentials ...` they can paste into any shell to attach `kubectl` to the cluster they just created.

## On-demand tooling

Provisioner scripts install missing CLIs themselves. `modules/Istio_GKE/istiosidecar.tf` installs `kubectl` and `istioctl` into `$HOME/.local/bin` if not present, so the apply succeeds on a fresh workstation without a separate "set up your tools" step.

## Documentation that explains *why*

Each module ships two markdown files (`SKILLS.md` §4):

- A short `README.md` (~90 lines) for fast onboarding — usage, requirements, providers, resources, inputs, outputs.
- A long `<Module_Name>.md` (~1,100–2,600 lines) covering architecture, secondary IP ranges, sidecar-vs-ambient trade-offs, multi-cluster routing, security model, and operational guidance. It is teaching material, not just reference.

`AGENTS.md` adds **Workflow Modes** (`/istio`, `/bank`, `/multicluster`, `/attached`, `/troubleshoot`, `/maintain`, `/security`) — context briefs an AI assistant or a new engineer can switch into to focus on a single module's idioms.

## Ready-to-run hands-on labs

`scripts/gcp-istio-traffic/`, `scripts/gcp-istio-security/`, `scripts/gcp-cr-mesh/`, and `scripts/gcp-m2c-vm/` are interactive bash scripts with **preview / create / delete** modes. Developers can step through Istio traffic management, Istio security, Cloud Run mesh, or VM migration without writing any YAML or Terraform first.

## Shared helper scaffolding

`SKILLS.md` §5 gives a copy-this-folder recipe for new modules:

```bash
cp -a modules/Istio_GKE modules/MyNewModule
```

All scaffolding — provider impersonation, API enablement loop, `random_id` deployment suffix, output set, destroy-safety patterns — comes for free.
