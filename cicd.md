# Continuous Integration and Continuous Delivery

The repository delivers infrastructure as a product: every module is shipped through a managed pipeline of Cloud Build YAMLs, with a Python CLI that automates local apply-cycles and an explicit lifecycle of `create` / `update` / `destroy` / `purge`.

## Cloud Build pipelines

`rad-ui/automation/` contains four Cloud Build configurations that the RAD platform UI invokes for any module deployment:

| File | Purpose | Timeout |
|---|---|---|
| `cloudbuild_deployment_create.yaml` | Initial `tofu apply` of a module | 3600s |
| `cloudbuild_deployment_update.yaml` | Re-apply with changed variables | 3600s |
| `cloudbuild_deployment_destroy.yaml` | `tofu destroy` | 3600s |
| `cloudbuild_deployment_purge.yaml` | Destroy plus post-cleanup of stuck resources | 600s |

Each pipeline pulls module source from a Git repository (configurable via `_MODULE_GIT_REPO_URL` / `_GIT_REPO_URL` substitutions), records the deployed commit SHA into `commit_hash.txt`, and writes `repo_url.txt` for traceability across the deployment lifecycle (`cloudbuild_deployment_create.yaml:71-79`).

## Provider caching for fast builds

The create / update / destroy pipelines cache OpenTofu provider binaries in GCS between builds (documented in `SKILLS.md` §7):

```
gs://${_DEPLOYMENT_BUCKET_ID}/terraform-provider-cache/${_MODULE_NAME}/providers.tar.gz
```

Restored into `/workspace/.terraform-plugin-cache/` via `TF_PLUGIN_CACHE_DIR` before each `tofu init` and saved back after a successful init. A missing cache is non-fatal — providers are downloaded fresh on the first run for a given module. This keeps subsequent builds on the order of seconds for `init` instead of minutes.

## Local pipeline parity

`rad-launcher/radlab.py` is the same flow, runnable from a workstation or Cloud Shell. It supports the same four actions:

```
[1] Create New
[2] Update
[3] Delete
[4] List
```

A non-interactive command-line form lets it run inside any external CI tool:

```bash
python3 radlab.py -m AKS_GKE -a create -p my-mgmt-project \
  -b my-mgmt-project-radlab-tfstate -f /path/to/my.tfvars
```

(`rad-launcher/README.md` "Command-line arguments" section).

## Reproducible deployments

Every module has a 4-character `deployment_id` (`outputs.tf` in each module), generated automatically via `random_id` if not supplied, or accepted from the user via `var.deployment_id`. The same ID is used to update or destroy that deployment later. The launcher's `List` action enumerates active deployments by reading state buckets directly.

## Validation gates

`SKILLS.md` §5 documents the validation steps that run before any apply:

```bash
tofu init
tofu validate
tofu fmt -check
tofu plan -var="existing_project_id=my-test-project"
```

These are also the contract for adding a new module: they are the definition of "ready to merge" stated in `SKILLS.md`.

## GKE release-channel managed updates

`modules/Bank_GKE/gke.tf`, `modules/Istio_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf` set `release_channel`, allowing GKE control-plane upgrades to be delivered continuously by Google. The Maintenance workflow in `AGENTS.md` documents promoting a deployment between channels (`REGULAR` → `STABLE`) and how to preview the resulting GKE version diff via `tofu plan`.

## Git-driven workflow

`AGENTS.md` and `SKILLS.md` are themselves CI artifacts: they instruct an automated agent or a new contributor exactly which validation commands to run and which invariants to preserve before opening a pull request, so contributions remain consistent across modules.
