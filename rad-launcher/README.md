# RAD Lab Launcher

The RAD Lab Launcher is an interactive / scriptable CLI that walks you through
deploying, updating, listing, and deleting [RAD Lab](../modules) modules in
your Google Cloud environment. It wraps [OpenTofu](https://opentofu.org/)
(a drop-in replacement for Terraform) and manages remote state in a Google
Cloud Storage (GCS) bucket of your choice.

## What's in this directory

| File | Purpose |
| ---- | ------- |
| `radlab.py` | Main launcher. Guided & non-interactive deployment of RAD Lab modules. |
| `installer_prereq.py` | One-shot installer for all launcher prerequisites (Python deps, OpenTofu, Cloud SDK, kubectl). |
| `opentofu_installer.py` | Downloads and installs the latest OpenTofu release for your OS/arch. Invoked by `installer_prereq.py`. |
| `cloudsdk_kubectl_installer.py` | Installs the Google Cloud SDK and the `kubectl` component (skipped when running inside Cloud Shell). |
| `install.sh` | Optional helper that fetches and runs the official Google Cloud SDK installer. |
| `requirements.txt` | Python dependencies pulled in by `installer_prereq.py`. |

## Prerequisites

* **Python 3.7.3 or later** (tested with 3.9+).
* **`curl`** and **`bash`** — preinstalled on most Linux and macOS systems and in
  Google Cloud Shell. Windows users should run from `Command Prompt` or
  PowerShell *as Administrator*.
* **`gcloud`** CLI authenticated against the Google Cloud account that will
  deploy the modules. If `gcloud` is not present, `installer_prereq.py` will
  install it.

### IAM permissions

The identity running the launcher needs the following roles in addition to the
module-specific roles called out in each [module](../modules)'s `README.md`:

| Scope | Role |
| ----- | ---- |
| RAD Lab management project | `roles/storage.admin` |
| RAD Lab management project | `roles/serviceusage.serviceUsageConsumer` |
| Parent (organization / folder) | `roles/iam.organizationRoleViewer` (skip if deploying into a project with no parent) |

See [Manage access to other resources](https://cloud.google.com/iam/docs/manage-access-other-resources)
for how to grant roles.

Pass `--disable-perm-check` / `-dc` to skip the pre-flight IAM check. This
only disables the launcher's client-side check — the underlying OpenTofu
deployment will still fail if the required permissions are missing.

## Installation

1. Clone or download this repository onto the machine where you will run the
   launcher (your workstation or Google Cloud Shell):

   ```bash
   git clone <your-fork-url> rad-modules
   cd rad-modules/rad-launcher
   ```

2. Install the launcher prerequisites:

   ```bash
   python3 installer_prereq.py
   ```

   This will:

   * `pip3 install` the contents of `requirements.txt` (Google API client,
     `python-terraform` wrapper, `google-cloud-storage`, `colorama`, `art`,
     `requests`, `oauth2client`, `beautifulsoup4`).
   * Install **OpenTofu** by downloading the latest release from GitHub
     (Linux/macOS) or via Chocolatey (Windows). Installs to `/usr/local/bin`
     on Linux/macOS and may prompt for your `sudo` password.
   * Install the **Google Cloud SDK** and the **`kubectl`** component via
     `gcloud components install kubectl`. This step is skipped automatically
     when running inside Cloud Shell.

3. Verify the OpenTofu installation:

   ```bash
   tofu -version
   ```

   If you see `command not found`, re-run the installer or add the install
   location to your `PATH`.

## Launch preparation

Before running the launcher you will want to have ready:

* A **GCP project** designated as the "RAD Lab management project". This
  project owns the GCS bucket that stores OpenTofu state and configs for all
  module deployments.
* The **Organization ID** ([how to find it](https://cloud.google.com/resource-manager/docs/creating-managing-organization#retrieving_your_organization_id))
  of the org where you will deploy modules. This is optional if the target
  project has no parent organization; in that case disable the org policy
  resources in the target module (see its `orgpolicy.tf` / `variables.tf`).
* A **Billing Account ID** ([how to find it](https://cloud.google.com/billing/docs/how-to/manage-billing-account))
  to attach to resources the module creates.
* *(Optional)* A **Folder ID** ([how to find it](https://cloud.google.com/resource-manager/docs/creating-managing-folders#view))
  if you want the deployment placed under a specific folder.
* *(Optional)* An existing **GCS bucket** for remote state. The launcher can
  also create one for you during `create`.

## Running the launcher

From this directory:

```bash
python3 radlab.py
```

The launcher prints the `RADLAB` banner, then asks you to:

1. Confirm the active `gcloud` user (or re-authenticate with
   `gcloud auth application-default login`).
2. Pick the RAD Lab management GCP project.
3. Pick the module to deploy from the list of modules under `../modules`.
4. Choose an action:

   ```
   [1] Create New
   [2] Update
   [3] Delete
   [4] List
   [0] Exit
   ```

5. Select (or create) the GCS bucket that will hold OpenTofu state and
   configs.
6. Provide Organization ID / Folder ID / Billing Account ID as prompted (for
   `create`) or the existing **deployment ID** (for `update` / `delete`).

On a successful `create`, the launcher prints a 4-character **deployment ID**.
**Save it** — you need it to `update` or `delete` the deployment later. You
can also recover the list of active deployments with the `List` action.

Example output:

```
Outputs:

deployment_id = "ioi9"
notebooks-instance-names = "notebooks-instance-0"
project-radlab-ds-analytics-id = "radlab-ds-analytics-ioi9"
user-scripts-bucket-uri = "https://www.googleapis.com/storage/v1/b/user-scripts-notebooks-instance-ioi9"


GCS Bucket storing Tofu Configs: my-sample-bucket

TOFU DEPLOYMENT COMPLETED!!!
```

### Command-line arguments

All prompts can be skipped by supplying the corresponding flag:

| Flag | Long form | Purpose |
| ---- | --------- | ------- |
| `-p` | `--rad-project` | GCP Project ID used for RAD Lab management. |
| `-b` | `--rad-bucket` | GCS bucket that stores OpenTofu state & configs. |
| `-m` | `--module` | Module name (directory under `../modules`). |
| `-a` | `--action` | One of `create`, `update`, `delete`, `list`. |
| `-f` | `--varfile` | Path to a file containing `terraform.tfvars`-style `key = "value"` pairs to override module defaults. |
| `-dc` | `--disable-perm-check` | Skip the launcher's IAM pre-check. |

Example — fully non-interactive create:

```bash
python3 radlab.py \
  --module AKS_GKE \
  --action create \
  --rad-project my-mgmt-project \
  --rad-bucket my-mgmt-project-radlab-tfstate \
  --varfile /path/to/my.tfvars
```

Or with short flags:

```bash
python3 radlab.py -m AKS_GKE -a create -p my-mgmt-project -b my-mgmt-project-radlab-tfstate -f /path/to/my.tfvars
```

### Overriding module defaults (`--varfile`)

Any variable declared in a module's `variables.tf` can be overridden by
passing a file with `--varfile`. Typical contents:

```hcl
organization_id    = "123456789012"
billing_account_id = "ABCDEF-GHIJKL-MNOPQR"
folder_id          = "987654321098"
# deployment_id is optional; the launcher will generate a 4-char ID when absent.
# deployment_id   = "abcd"

# Module-specific overrides:
trusted_users = ["engineer@example.com"]
```

Notes:

* The launcher validates each key against the target module's `variables.tf`
  and aborts if an unknown key is present.
* `organization_id`, `billing_account_id`, `folder_id`, and `deployment_id`
  supplied in the file take precedence over interactive prompts.
* If `deployment_id` is supplied it must be exactly 4 alphanumeric characters.
* If no `--varfile` is supplied, module defaults from `variables.tf` apply.

## Cloud Shell one-click

The launcher works in Google Cloud Shell. Open a Cloud Shell session in your
fork of this repository and run:

```bash
cd rad-modules/rad-launcher
python3 installer_prereq.py
python3 radlab.py
```

Cloud SDK / kubectl installation is skipped automatically inside Cloud Shell
since those tools are already present.

## Concurrency & lock file

`radlab.py` creates `/tmp/radlab.lock` on start and removes it on exit so only
one launcher can run at a time. If a prior run was killed abruptly the lock
file can be left behind — delete it manually before re-running:

```bash
rm -f /tmp/radlab.lock
```

## Troubleshooting

* **`command not found: tofu`** — re-run `python3 installer_prereq.py`, or
  install OpenTofu manually from <https://opentofu.org/docs/intro/install/>.
* **Permission errors during pre-check** — review the [IAM table above](#iam-permissions)
  and grant the missing roles, or re-run with `-dc` to skip the check and let
  OpenTofu surface the real missing permission.
* **`Another instance is already running.`** — delete `/tmp/radlab.lock`.
* **Invalid bucket name or no access** — the supplied `--rad-bucket` must
  exist and be readable/writable by the current `gcloud` user in the
  management project.
* **`Deployment ID must be exactly 4 characters`** — `deployment_id` in your
  `--varfile` is the wrong length; it must be 4 alphanumeric characters.
* **Org policy errors on a no-parent project** — disable the org-policy
  toggles in the target module's `variables.tf` (e.g. set
  `set_shielded_vm_policy` and `set_vpc_peering_policy` defaults to `false`)
  or comment out `orgpolicy.tf`.
