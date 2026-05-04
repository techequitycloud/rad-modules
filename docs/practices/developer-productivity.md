# Enhanced Developer Productivity

The repository pulls a developer from "I want to learn Istio" or "I need a multi-cluster mesh" to a working environment in a single command.

## One command from zero to a running mesh

```bash
cd modules/Istio_GKE
tofu init
tofu apply -var="existing_project_id=my-gcp-project"
```

That single apply provisions a GKE cluster, VPC with private nodes, Cloud NAT, an Istio control plane, the full observability stack, and optionally the Bookinfo sample. There is no separate "now configure the mesh" step. See [service-mesh](../capabilities/service-mesh.md) and [observability](../capabilities/observability.md).

## Self-service via the launcher

`rad-launcher/radlab.py` walks through project / module / action / bucket selection. `rad-launcher/installer_prereq.py` installs OpenTofu, the Cloud SDK, `kubectl`, and Python deps in one shot, including auto-detecting Cloud Shell to skip what's already there.

## Self-service via the platform UI

The same modules deploy through the RAD platform UI without opening a terminal. The UI is generated from each module's variables file via UIMeta — see [infrastructure-as-code](../capabilities/infrastructure-as-code.md).

## Sane defaults, every time

Every module exposes the same outputs (`SKILLS.md` §3.5):

```hcl
output "deployment_id"
output "project_id"
output "cluster_credentials_cmd"   # copy-pastable gcloud command
output "external_ip"               # LoadBalancer IP, with fileexists() fallback
```

`cluster_credentials_cmd` is the highest-impact one: a one-line `gcloud` command that attaches `kubectl` to the cluster.

## On-demand tooling

`modules/Istio_GKE/istiosidecar.tf` installs `kubectl` and `istioctl` into `$HOME/.local/bin` if missing, so apply succeeds on a fresh workstation without a separate "set up your tools" step.

## Documentation that explains *why*

Each module ships two markdown files (`SKILLS.md` §4):

- A short `README.md` for fast onboarding — usage, requirements, providers, resources, inputs, outputs.
- A long `<Module_Name>.md` (~1,100–2,600 lines) covering architecture, networking, mesh trade-offs, and operational guidance — teaching material, not just reference.

`AGENTS.md` adds workflow modes that prime a new engineer or AI assistant with the right context for a single module.

## Hands-on labs

`scripts/gcp-istio-traffic/`, `scripts/gcp-istio-security/`, `scripts/gcp-cr-mesh/`, `scripts/gcp-m2c-vm/` are interactive bash scripts with **preview / create / delete** modes. See [application-modernization](../capabilities/application-modernization.md) and [serverless](../capabilities/serverless.md) for what each one teaches.
