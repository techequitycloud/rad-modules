# gcp-cr-mesh.sh — Configure Cloud Service Mesh for Cloud Run

Interactive bash script that walks you through enabling Cloud Service Mesh
between two Cloud Run services. It automates the steps documented at
<https://cloud.google.com/service-mesh/docs/configure-cloud-service-mesh-for-cloud-run>:
enabling APIs, granting IAM, creating a `Mesh` resource, deploying a destination
Cloud Run service, fronting it with a serverless NEG + global backend service +
`HTTPRoute`, and finally invoking it from a mesh-enrolled `fortio` client.

## Prerequisites

- A Google Cloud project with billing enabled.
- `gcloud` CLI installed and authenticated as a project Owner or Editor.
- `gsutil` (bundled with `gcloud`) and `curl`.
- The script installs `pv` automatically with `sudo apt-get`. On other distros,
  install it manually first.
- Runs cleanly from Cloud Shell or any Linux shell with sudo rights.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-cr-mesh.sh
```

The script presents a menu that loops until you choose `Q`. The first thing you
should do every session is press `0` to choose an execution mode and confirm
your project.

## Execution modes (option `0`)

When you select `0` the script asks how it should behave:

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints every `gcloud` command without running it. Safe for review. |
| `n` | **Create** | Authenticates, sets the project, and actually executes commands. |
| `d` | **Delete** | Tears down the resources created by each step. |

In Create or Delete mode the script will:

1. Run `gcloud auth login` if no service-account key is cached.
2. Prompt for the Google Cloud project ID to operate against.
3. Create a service account `<project>@<project>.iam.gserviceaccount.com`,
   grant it `roles/owner`, save its key to
   `./gcp-cr-mesh/.<project>.json`, and create a `gs://<project>` bucket for
   backing up `.env`.
4. Re-export the configuration to `./gcp-cr-mesh/.env`.

To change projects later, delete the cached key file and run option `0` again.

## Configuration (`.env`)

The script creates `./gcp-cr-mesh/.env` on first run. Edit it to override any
of the defaults before running the numbered steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `GCP_REGION` | `us-central1` | Region for Cloud Run and the NEG. |
| `MESH_NAME` | `mesh` | Name of the `networkservices` `Mesh` resource. |
| `SERVICE_NAME` | `hello` | Cloud Run destination service name. |
| `SERVICE_IMAGE` | `us-docker.pkg.dev/cloudrun/container/hello:latest` | Container image for the destination service. |

After editing, re-run the affected step — values are re-sourced at the start of
every option.

## Menu walkthrough

Run the steps in order the first time. Each option works in all three modes
(preview / create / delete) unless noted.

### `(1) Enable APIs`
Enables `run`, `dns`, `networkservices`, `networksecurity`, and
`trafficdirector` APIs on the project. Delete mode disables them.

### `(2) Configure IAM Policies`
Grants the calling user `roles/run.developer` and
`roles/iam.serviceAccountUser`, and grants the project's default Compute
service account `roles/trafficdirector.client`, `roles/cloudtrace.agent`, and
`roles/run.admin`. Delete mode removes these bindings.

### `(3) Configure Service Mesh`
Writes `mesh.yaml` (`name: $MESH_NAME`) and imports it via
`gcloud network-services meshes import`. Delete mode deletes the mesh.

### `(4) Deploy Destination Service`
Deploys `$SERVICE_NAME` to Cloud Run in `$GCP_REGION` with
`--no-allow-unauthenticated` and grants the project's compute service account
`roles/run.invoker` on it. Delete mode removes the binding and the service.

### `(5) Configure Destination Service Mesh Networking`
Creates a serverless NEG pointing at the Cloud Run service, a global
`INTERNAL_SELF_MANAGED` backend service, attaches the NEG to it, then writes
`http_route.yaml` and imports it as an `HTTPRoute` bound to the mesh. The route
matches the service's `*.run.app` hostname so requests sent through the mesh
hit the destination. Delete mode removes the route, backend service, and NEG.

### `(6) Deploy Client Service in Service Mesh`
Deploys the `fortio/fortio` image as a Cloud Run service named `fortio`,
attached to the mesh via `--mesh="projects/$GCP_PROJECT/locations/global/meshes/$MESH_NAME"`
on the `default` VPC network and subnet. Delete mode removes the `fortio`
service.

### `(7) Invoke Destination Service from Client Service`
Resolves the destination Cloud Run URL, then calls
`$TEST_SERVICE_URL/fortio/fetch/<destination-host>` with an identity token. A
successful response proves the client traffic is being routed through the mesh
to the backend.

### `(R)` / `(G)` / `(Q)`
- `R` — print the maintainer credits.
- `G` — launch the bundled Cloud Shell tutorial (only works inside Cloud Shell).
- `Q` — quit.

## Working files

After running option `0` you'll have:

```
./gcp-cr-mesh/
├── .env                       # current configuration (edit to customize)
├── .<GCP_PROJECT>.json        # service-account key (delete to switch projects)
├── mesh.yaml                  # written by step 3
└── http_route.yaml            # written by step 5
```

The same `.env` is also copied to `gs://<GCP_PROJECT>/gcp-cr-mesh.sh.env` so it
can be restored across Cloud Shell sessions.

## Cleanup

Run option `0` and choose `d` (delete), then step through `(7)` down to `(1)`
in reverse order. Once everything is gone you can also delete the local
`./gcp-cr-mesh/` working directory and remove the cached service-account key
to avoid unexpected re-use.
