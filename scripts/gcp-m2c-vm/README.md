# gcp-m2c-vm.sh — Migrate a Compute Engine VM to a container

Interactive bash script that automates Google Cloud's
[Migrate to Containers](https://cloud.google.com/migrate/containers) workflow
for a Linux Compute Engine VM. It analyzes the source VM with `mcdc`, syncs
its filesystem with `m2c`, generates a Dockerfile and Kubernetes / Cloud Run
deployment specs, and finally builds and deploys the container with
`skaffold`.

## Prerequisites

- Google Cloud project with billing enabled.
- An existing **Linux** Compute Engine VM you want to migrate. You'll need to
  know its instance name; the script will discover the zone automatically.
- `gcloud` CLI authenticated as a project Owner or Editor, with SSH/IAP access
  to the VM.
- `gsutil` and `kubectl` (bundled with `gcloud`).
- [`skaffold`](https://skaffold.dev/) installed locally for the deploy step.
- `rsync` installed locally and on the source VM (the script installs it on
  the VM via `apt`).
- Disk space for the synced VM filesystem — easily 10 GB+ depending on the
  source. The `filesystem/` copy is deleted after artifact generation.
- The script installs `pv` automatically with `sudo apt-get`. Install it
  manually on non-Debian systems first.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-m2c-vm.sh
```

A menu loops until you press `Q`. **Always start each session by pressing `0`**
to choose an execution mode, confirm the GCP project, and supply the source
VM name.

## Execution modes (option `0`)

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands without running them. |
| `n` | **Create** | Runs the analyze → generate → deploy pipeline for real. |
| `d` | **Delete** | Tears down resources created by each step. |

In Create / Delete mode the script runs `gcloud auth login`, asks for the
project ID, the source VM name and the container name, and creates a
`gs://<project>` bucket for backing up `.env`. The VM zone (and, in step 4,
the region) are derived from `gcloud compute instances list` at the start of
each numbered step, not here. Just run option `0` again with a different project ID to
switch projects.

## Configuration (`.env`)

Created at `./gcp-m2c-vm/.env`. Edit values before running the numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `VM_NAME` | `NOT_SET` | Source Compute Engine instance name. |
| `CONTAINER_NAME` | `NOT_SET` | Name used for the generated container and Cloud Run service. |
| `CONTAINER_NAME` | `NOT_SET` | Name used for the generated container and Cloud Run service. |

`VM_ZONE` and `GCP_REGION` are **not** stored in `.env` — steps 2, 3 and 4
recompute them at run time from `gcloud compute instances list` filtered on
`$VM_NAME`, so they cannot be overridden by editing the file.

## Menu walkthrough

Run options `1` → `4` in order. Steps `2` and `3` include manual review
checkpoints — don't skip them.

### `(1) Enable APIs`
Enables the APIs required by the migration pipeline:
`servicemanagement`, `servicecontrol`, `cloudresourcemanager`, `compute`,
`container`, `artifactregistry`, `cloudbuild`, `clouddeploy`,
`containeranalysis`, and `run`.

### `(2) Analyze virtual machine`
1. Starts `$VM_NAME` if it's stopped.
2. Downloads the `mcdc-linux-collect.sh` collector onto the VM and runs it to
   gather installed packages, services, listening ports, and filesystem
   metadata.
3. Downloads the `mcdc` CLI and runs `mcdc discover import` followed by
   `mcdc report --format json` and `--format html` on the VM.
4. Pulls both reports back to `./gcp-m2c-vm/${VM_NAME}-mcdc-report.{json,html}`
   via `gcloud compute scp`.

**Open the HTML report** before continuing — it tells you whether the VM is a
good candidate for containerization and what to expect.

In delete mode this step deletes the source VM with
`gcloud compute instances delete`.

### `(3) Generate Migrate to Containers artefacts`
1. Installs `rsync` on the VM and downloads the `m2c` CLI plus the offline
   plugin bundle locally.
2. Exports default rsync filters to `./gcp-m2c-vm/filters.txt`.
3. **Pauses for review** — edit `filters.txt` to exclude directories you
   don't need in the container (e.g. `/tmp`, `/var/cache`, `/var/log`).
   Smaller scope = faster sync and a smaller image.
4. Runs `rsync` over SSH to copy the VM filesystem into
   `./gcp-m2c-vm/filesystem/`.
5. Generates a migration plan with
   `m2c analyze -s filesystem -p linux-vm-container -o migrationplan/`.
6. Runs `netstat` on the VM to print the listening ports for reference.
7. **Pauses again** — edit `./gcp-m2c-vm/migrationplan/config.yaml` to tune
   port mappings, environment variables, and entrypoint as needed.
8. Runs `m2c generate -i migrationplan -o artifacts` to produce the
   Dockerfile, Kubernetes deployment / service specs, and `skaffold` files.
9. Deletes `./gcp-m2c-vm/filesystem/` to reclaim disk space.

### `(4) Migrate virtual machine to container`
1. Patches `artifacts/Dockerfile` to pre-create
   `/var/log/${CONTAINER_NAME}/` so the container has a writable log path.
2. Writes a Cloud Run-flavored `skaffold_cloudrun.yaml` and matching Knative
   `Service` (`HC_V2K_SERVICE_MANAGER=true`, ingress=`all`, min replicas=1).
3. Runs `skaffold run -f artifacts/skaffold_cloudrun.yaml` to:
   - build the image with **Cloud Build**,
   - push it to **Artifact Registry** under `eu.gcr.io/${GCP_PROJECT}`,
   - deploy it as the Cloud Run service `${CONTAINER_NAME}` in `${GCP_REGION}`.
4. Pre-creates the `gs://${GCP_PROJECT}_cloudbuild` staging bucket, then
   always runs `skaffold run -f artifacts/skaffold.yaml` to also deploy to
   whichever cluster `kubectl`'s current context points at. There is no
   prompt — if you don't want the GKE deploy, interrupt the step.

In delete mode it removes the Cloud Run service and the GKE deployment.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — runs `cloudshell launch-tutorial .tutorial.md` (Cloud Shell only).
  No `.tutorial.md` ships here, so this fails unless you add one yourself.
- `Q` — quit.

## Working files

```
./gcp-m2c-vm/
├── .env                                # current configuration
├── m2c                                 # Migrate to Containers CLI
├── m2c                                 # Migrate to Containers CLI
├── filters.txt                         # rsync exclusion list (edit before sync)
├── analyzevm.sh                        # helper copied to the source VM
├── <VM_NAME>-mcdc-report.json          # JSON discovery report
├── <VM_NAME>-mcdc-report.html          # HTML discovery report (review this!)
├── filesystem/                         # synced VM rootfs (deleted after step 3)
├── migrationplan/
│   └── config.yaml                     # migration plan (edit before generate)
└── artifacts/
    ├── Dockerfile
    ├── deployment_spec.yaml
    ├── service_spec.yaml
    ├── deployment_cloudrun.yaml        # Knative Service written by step 4
    ├── skaffold.yaml                   # GKE deployment
    └── skaffold_cloudrun.yaml          # Cloud Run deployment
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-m2c-vm.sh.env`.

## Tips & troubleshooting

- **Long syncs.** Aggressively trim `filters.txt`. Excluding caches, logs,
  and package archives often cuts the rsync to a fraction of the original.
- **SSH failures.** `gcloud compute ssh` uses IAP by default — make sure your
  user has `roles/iap.tunnelResourceAccessor` and the VM allows IAP ranges.
- **Wrong project after first run.** Just re-run option `0` with the correct
  project ID.
- **Re-running step 3.** If you change `config.yaml` and re-run, the script
  will re-sync the filesystem. Keep `filters.txt` in place to avoid repeating
  the slow parts.
- **Costs.** The source VM, Cloud Build minutes, Artifact Registry storage,
  and the Cloud Run service all incur charges. Run option `0` → `d` to clean
  up when you're done.

## Cleanup

1. Option `0` → `d` (delete mode).
2. Step `4` to delete the Cloud Run service and any GKE deployment.
3. Step `2` to delete the source VM (only if you no longer need it).
4. Optionally remove built images from Artifact Registry by hand.
5. Delete `./gcp-m2c-vm/`.
