# Infrastructure as Code

The OpenTofu/Terraform conventions and invariants that make every module in this repo behave consistently. Documented in `SKILLS.md`; this page is the orientation map.

## OpenTofu, not Terraform

`SKILLS.md` §5: validation runs on `tofu init && tofu validate && tofu fmt -check`. OpenTofu is a drop-in replacement for Terraform; the repo standardizes on OpenTofu via the `rad-launcher`'s installer.

## Module layout

```
modules/<Name>/
├── main.tf              # project bootstrap, API enablement, random_id
├── provider-auth.tf     # impersonation pattern (or provider.tf for attached clusters)
├── versions.tf          # required_providers + required_version
├── variables.tf         # UIMeta-annotated inputs
├── outputs.tf           # deployment_id, project_id, cluster_credentials_cmd, external_ip
├── network.tf           # VPC, subnet, firewall, Cloud Router + NAT
├── gke.tf               # cluster, node pool, cluster SA, IAM
├── <feature>.tf         # null_resource installing workloads
├── manifests/           # raw YAML
├── templates/           # rendered YAML
├── README.md
└── <Module_Name>.md
```

(`SKILLS.md` §2). Adding a new module is `cp -a modules/Istio_GKE modules/MyNewModule` and editing the domain-specific files.

## Provider authentication patterns

Two patterns documented in `SKILLS.md` §3.2:

- **Impersonation** (`provider-auth.tf`) — `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`. The provider mints a short-lived access token for `var.resource_creator_identity` when set, falling back to ADC.
- **Direct** (`provider.tf`) — `AKS_GKE`, `EKS_GKE`. Configures `azurerm` / `aws` / `helm` providers directly without GCP impersonation wrapping.

## UIMeta annotations

Every variable description ends with `{{UIMeta group=N order=M [updatesafe] }}` (`SKILLS.md` §3.4). The platform UI reads these to render a grouped, ordered deployment form. Standard groups:

| Group | Section |
|---|---|
| 0 | Provider / Metadata |
| 1 | Main (project, region) |
| 2 | Network |
| 3 | Cluster |
| 4 | Features |
| 6 | Application |

`updatesafe` marks fields editable on an in-place re-apply.

## Standard outputs

Every GKE-based module exposes the same four outputs (`SKILLS.md` §3.5): `deployment_id`, `project_id`, `cluster_credentials_cmd`, `external_ip`. Downstream tools rely on this contract.

## Destroy safety

Every `null_resource` with a create-time effect has a matching `when = destroy` provisioner that uses:

- `set +e` (not `set -e`)
- `--ignore-not-found` on `kubectl delete`
- `|| echo "Warning: ..."` or `|| true` on each step

(`SKILLS.md` §6, observed in `modules/Istio_GKE/istiosidecar.tf`, `modules/MC_Bank_GKE/mcs.tf`, `modules/Bank_GKE/hub.tf`).

## API enablement invariant

Every `google_project_service` resource sets:

```hcl
disable_dependent_services = false
disable_on_destroy         = false
```

So a destroy never disables APIs another deployment may depend on (`SKILLS.md` §6).

## No secrets in defaults

Inputs like `client_secret` (AKS_GKE) and `aws_secret_key` (EKS_GKE) have no defaults. Callers source them from environment variables or a secret store at apply time.

## Validation gates

`SKILLS.md` §5:

```bash
tofu init
tofu validate
tofu fmt -check
tofu plan -var="existing_project_id=my-test-project"
```

These are the definition of "ready to merge" for any module change.

## State

Remote state in GCS with versioning and object-level encryption. Bucket IAM is not publicly readable. `.terraform/` is in `.gitignore`. See [devsecops](../practices/devsecops.md).
