# Continuous Integration and Continuous Delivery

Infrastructure is delivered as a product through a managed pipeline of Cloud Build YAMLs and a Python CLI that automates local apply-cycles.

## Cloud Build pipelines

`rad-ui/automation/` contains four Cloud Build configurations invoked by the RAD platform UI:

| File | Purpose | Timeout |
|---|---|---|
| `cloudbuild_deployment_create.yaml` | Initial `tofu apply` | 3600s |
| `cloudbuild_deployment_update.yaml` | Re-apply with changed variables | 3600s |
| `cloudbuild_deployment_destroy.yaml` | `tofu destroy` | 3600s |
| `cloudbuild_deployment_purge.yaml` | Destroy plus post-cleanup of stuck resources | 600s |

Each pipeline pulls module source from a Git repository (configurable via `_MODULE_GIT_REPO_URL` / `_GIT_REPO_URL`), records the deployed commit SHA into `commit_hash.txt`, and writes `repo_url.txt` for traceability across the deployment lifecycle (`cloudbuild_deployment_create.yaml:71-79`).

Cloud Build is itself a serverless build platform — see [serverless](../capabilities/serverless.md).

## Provider caching for fast builds

Create / update / destroy pipelines cache OpenTofu provider binaries in GCS between builds at `gs://${_DEPLOYMENT_BUCKET_ID}/terraform-provider-cache/${_MODULE_NAME}/providers.tar.gz`, restored into `/workspace/.terraform-plugin-cache/` via `TF_PLUGIN_CACHE_DIR` before each `tofu init` and saved back after success. A missing cache is non-fatal (`SKILLS.md` §7).

## Local pipeline parity

`rad-launcher/radlab.py` is the same flow runnable from a workstation or Cloud Shell, with a non-interactive command-line form for external CI integration:

```bash
python3 radlab.py -m AKS_GKE -a create -p my-mgmt-project \
  -b my-mgmt-project-radlab-tfstate -f /path/to/my.tfvars
```

(`rad-launcher/README.md`).

## Reproducible deployments

Every module has a 4-character `deployment_id` generated via `random_id` (or supplied by the user). The same ID identifies that deployment for `update` or `delete` later. The launcher's `List` action enumerates active deployments by reading state buckets directly.

## Validation gates

`SKILLS.md` §5 documents the validation contract:

```bash
tofu init && tofu validate && tofu fmt -check
tofu plan -var="existing_project_id=my-test-project"
```

These are the definition-of-ready for any module change. See [infrastructure-as-code](../capabilities/infrastructure-as-code.md) for the conventions they enforce.

## Managed Kubernetes upgrades

GKE `release_channel` lets the control plane be upgraded continuously by Google. The `/maintain` workflow in `AGENTS.md` covers promoting a deployment between channels. See [kubernetes](../capabilities/kubernetes.md).
