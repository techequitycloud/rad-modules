---
name: gke-application-modules
description: How the Bank_GKE, MC_Bank_GKE, and Istio_GKE modules provision native GKE clusters, install a service mesh, and deploy a demo application on top.
---

# GKE Application Modules

Three modules provision Google-native GKE clusters and install a full Kubernetes workload on top of them:

| Module | Clusters | Service Mesh | Workload |
|---|---|---|---|
| `Bank_GKE` | 1 GKE (Autopilot or Standard) | Cloud Service Mesh (managed) | Bank of Anthos v0.6.7 |
| `MC_Bank_GKE` | N GKE (2–4 typical), multi-region | CSM fleet-wide + MCI + MCS | Bank of Anthos v0.6.7 across clusters |
| `Istio_GKE` | 1 GKE Standard | Open-source Istio (sidecar or ambient) | Istio Bookinfo sample |

They all use provider-auth Pattern B (impersonated Google provider in `provider-auth.tf`) and share the same `main.tf` boilerplate described in the `module-conventions` skill.

## File Decomposition

```
modules/Bank_GKE/          modules/MC_Bank_GKE/        modules/Istio_GKE/
├── main.tf                ├── main.tf                 ├── main.tf
├── variables.tf           ├── variables.tf            ├── variables.tf
├── versions.tf            ├── versions.tf             ├── versions.tf
├── provider-auth.tf       ├── provider-auth.tf        ├── provider-auth.tf
├── network.tf             ├── network.tf              ├── network.tf
├── gke.tf                 ├── gke.tf                  ├── gke.tf
├── hub.tf                 ├── hub.tf                  ├── istiosidecar.tf
├── asm.tf                 ├── asm.tf                  ├── istioambient.tf
├── deploy.tf              ├── mcs.tf                  ├── outputs.tf
├── glb.tf                 ├── glb.tf                  └── (no deploy.tf — inline in istio*.tf)
├── monitoring.tf          ├── deploy.tf
├── outputs.tf             ├── manifests.tf
├── templates/*.tpl        ├── outputs.tf
└── ...                    └── templates/*.tpl
```

`templates/*.yaml.tpl` files (rendered via `templatefile(...)`) hold Kubernetes manifests with variable substitution. `Istio_GKE` uses `manifests/*.yaml` instead (no substitution).

## Cluster Creation (`gke.tf`)

### Single-cluster (Bank_GKE, Istio_GKE)

```hcl
resource "google_container_cluster" "gke_cluster" {
  count                    = var.create_cluster ? 1 : 0
  project                  = local.project.project_id
  name                     = var.gke_cluster
  location                 = var.gcp_region
  deletion_protection      = false
  network                  = local.network.name
  subnetwork               = local.subnet.name
  enable_autopilot         = var.create_autopilot_cluster
  remove_default_node_pool = var.create_autopilot_cluster ? null : true
  initial_node_count       = var.create_autopilot_cluster ? null : 1
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_ip_range
    services_secondary_range_name = var.service_ip_range
  }
  addons_config { http_load_balancing { disabled = false } ... }
}
```

`Bank_GKE` also supports `var.create_cluster = false` (adopt an existing cluster) by routing a `data.google_container_cluster.existing_cluster` data source through a `local.cluster` selector. Mirror this pattern when adding optional-BYO-cluster support to other modules.

### Multi-cluster (MC_Bank_GKE)

`MC_Bank_GKE` creates N clusters via `for_each`, assigning them round-robin across `var.available_regions`. It pre-declares **per-cluster** `kubernetes` provider aliases (`cluster1`, `cluster2`, `cluster3`, `cluster4`) in `gke.tf`, because Terraform providers cannot themselves be dynamic. **This caps the module at 4 clusters.** If expanding beyond 4, add more aliased providers; if the alias ceiling is in the way, consider splitting the module.

```hcl
provider "kubernetes" {
  alias                  = "cluster1"
  host                   = "https://${google_container_cluster.gke_cluster["cluster1"].endpoint}"
  token                  = data.google_client_config.gke_cluster.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster["cluster1"].master_auth[0].cluster_ca_certificate)
}
# ... cluster2, cluster3, cluster4
```

## Service Mesh (`asm.tf`, `hub.tf`, `istiosidecar.tf`, `istioambient.tf`)

### Cloud Service Mesh (Bank_GKE, MC_Bank_GKE)

Managed mesh, installed via GKE Hub features:

```hcl
# hub.tf
resource "google_gke_hub_membership" "cluster" {
  project       = local.project.project_id
  membership_id = "<cluster-name>"
  endpoint { gke_cluster { resource_link = "//container.googleapis.com/${local.cluster.id}" } }
}

# asm.tf
resource "google_gke_hub_feature" "servicemesh" {
  project  = local.project.project_id
  name     = "servicemesh"
  location = "global"
}

resource "google_gke_hub_feature_membership" "cluster" {
  project    = local.project.project_id
  feature    = "servicemesh"
  membership = google_gke_hub_membership.cluster.membership_id
  mesh { management = "MANAGEMENT_AUTOMATIC" }
  location   = "global"
}
```

Both modules wrap these with `null_resource` polling blocks (`verify_gke_hub_api_activation`, `verify_mesh_api_activation`) that shell out to `gcloud services list` until the API is ready. This is deliberate — `google_project_service` returns before the API is actually usable, and downstream `google_gke_hub_feature` calls race ahead otherwise. Preserve these verification resources when refactoring.

`MC_Bank_GKE` additionally creates `google_gke_hub_feature.multiclusteringress_feature` to enable MCI at fleet level (see `deploy.tf`). MCS resources (MultiClusterService manifests) are applied via `null_resource.app_multicluster_ingress` in `deploy.tf`. `mcs.tf` contains only the destroy-time cleanup resource (`null_resource.cleanup_mci_resources`).

### Open-source Istio (Istio_GKE)

Installed via `null_resource` that runs `istioctl install` locally against the cluster. Two mutually-exclusive files:

- `istiosidecar.tf` — `count = var.install_ambient_mesh ? 0 : 1`, installs sidecar-mode Istio + observability addons (Prometheus, Jaeger, Grafana, Kiali).
- `istioambient.tf` — `count = var.install_ambient_mesh ? 1 : 0`, installs ambient-mode Istio + ztunnel/waypoint.

Both shell scripts install `kubectl` and `istioctl` locally if missing and write an `external_ip.txt` file for the Ingress Gateway address (exposed via the `external_ip` output). When editing these, remember the **destroy** provisioner also needs to reference `var.resource_creator_identity` — it is pulled through `triggers` precisely so the `local-exec` on destroy has access to it.

## Application Deployment (`deploy.tf`, `manifests.tf`)

### Bank of Anthos (Bank_GKE, MC_Bank_GKE)

`deploy.tf` downloads a release tarball from GitHub and extracts it to `${path.module}/.terraform/bank-of-anthos/...`:

```hcl
locals {
  bank_of_anthos_version = "v0.6.7"
  release_url            = "https://github.com/GoogleCloudPlatform/bank-of-anthos/archive/refs/tags/${local.bank_of_anthos_version}.tar.gz"
  download_path          = "${path.module}/.terraform/bank-of-anthos"
  extracted_path         = "${local.download_path}/bank-of-anthos-${trimprefix(local.bank_of_anthos_version, "v")}"
  manifests_path         = "${local.extracted_path}/kubernetes-manifests"
  jwt_secret_path        = "${local.extracted_path}/extras/jwt/jwt-secret.yaml"
}

resource "null_resource" "download_bank_of_anthos" {
  count    = var.deploy_application ? 1 : 0
  triggers = { version = local.bank_of_anthos_version, always_run = timestamp() }
  provisioner "local-exec" { /* curl | tar -xz | verify */ }
}

# Bank_GKE — single cluster, uses count
resource "null_resource" "deploy_bank_of_anthos" {
  count      = var.deploy_application ? 1 : 0
  depends_on = [ null_resource.download_bank_of_anthos, ... ]
  provisioner "local-exec" { /* kubectl apply -f <manifests_path> */ }
}

# MC_Bank_GKE — one resource per cluster via for_each; includes primary/non-primary logic
resource "null_resource" "deploy_bank_of_anthos" {
  for_each   = var.deploy_application ? local.cluster_configs : {}
  triggers   = { ..., is_primary = each.key == "cluster1" ? "true" : "false" }
  provisioner "local-exec" {
    # Primary cluster (cluster1): apply all manifests including accounts-db.yaml, ledger-db.yaml
    # Non-primary clusters: skip DB manifests; delete any pre-existing DB resources so
    # they are not duplicated. Non-primary clusters reach the DBs via Multi-Cluster Services.
  }
}
```

**Primary/non-primary cluster distinction (MC_Bank_GKE only):** The `accounts-db` and `ledger-db` StatefulSets are deployed exclusively to `cluster1` (the primary cluster). Non-primary clusters apply all other manifests and rely on MCS to route to the databases on the primary. On re-apply, any pre-existing DB resources on non-primary clusters are deleted. `cluster1` is always the primary; this is hard-coded, not configurable.

Templates in `templates/*.yaml.tpl` (ingress, nodeport service, managed cert, frontend/backend config) are rendered to disk with `templatefile(...)` before `kubectl apply`, so the deployed application can be tied to a module-specific global IP and managed certificate. `MC_Bank_GKE` adds two templates not present in the single-cluster variant: `multicluster_ingress.yaml.tpl` and `multicluster_service.yaml.tpl`.

`always_run = timestamp()` on the download resource forces a fresh pull every apply; keep it — Bank of Anthos releases are updated in place.

### Bookinfo (Istio_GKE)

Installed inline in the istio install scripts (`istiosidecar.tf` / `istioambient.tf`), gated on `var.deploy_application`. The script `kubectl apply`s the Bookinfo manifests that ship with the Istio release tarball.

## Networking (`network.tf`)

All three modules create:

```hcl
resource "google_compute_network"    "vpc"      { routing_mode = "GLOBAL" }  # MC_Bank_GKE uses GLOBAL
resource "google_compute_subnetwork" "subnet"   { secondary_ip_range = [pod, service] }
resource "google_compute_firewall"   "..." * 6  # internal, health-checks, SSH, etc.
resource "google_compute_router"     "router"   { }
resource "google_compute_router_nat" "nat"      { }
```

Both single-cluster modules support `var.create_network = false` with a data-source fallback pattern; preserve this when adding a new variant. `MC_Bank_GKE` creates one router + NAT per region via `for_each`.

A module-level `google_compute_global_address.bank_of_anthos` (Bank_GKE / MC_Bank_GKE) reserves a global IP for the Ingress in the GCLB created by `glb.tf`.

## Required GCP APIs

Declared in `main.tf → local.default_apis`. Representative (Bank_GKE):

```
iap.googleapis.com               container.googleapis.com        compute.googleapis.com
monitoring.googleapis.com        logging.googleapis.com          servicenetworking.googleapis.com
containersecurity.googleapis.com iamcredentials.googleapis.com   iam.googleapis.com
artifactregistry.googleapis.com  storage.googleapis.com          cloudtrace.googleapis.com
anthos.googleapis.com            mesh.googleapis.com             gkeconnect.googleapis.com
gkehub.googleapis.com            anthospolicycontroller.googleapis.com
anthosconfigmanagement.googleapis.com  websecurityscanner.googleapis.com
billingbudgets.googleapis.com
```

`Istio_GKE` is much shorter (only `cloudapis.googleapis.com` and `container.googleapis.com`) because open-source Istio does not depend on GCP managed services.

Keep `disable_dependent_services = false` and `disable_on_destroy = false` — see the `module-conventions` skill for why.

## Monitoring (Bank_GKE)

`monitoring.tf` creates `google_monitoring_service` + `google_monitoring_slo` for each of the nine Bank of Anthos microservices, gated on `var.enable_monitoring`. This pattern is specific to `Bank_GKE` — `MC_Bank_GKE` does not currently replicate it, and adding it would require per-cluster SLO definitions.

## Gotchas When Modifying These Modules

- **Kubernetes provider alias cap (MC_Bank_GKE)**: The explicit `cluster1`..`cluster4` aliases limit the module to 4 clusters. `var.cluster_size > 4` will fail at plan time.
- **Verification `null_resource` blocks**: `verify_gke_hub_api_activation`, `verify_mesh_api_activation`, `wait_for_container_api` exist to defeat API-readiness races. Deleting them to "simplify" the code will cause intermittent apply failures.
- **Bank of Anthos version pin**: Hard-coded to `v0.6.7` in `deploy.tf`. Bumping it may require new fields in the rendered template files; test end-to-end.
- **Primary cluster is always `cluster1` (MC_Bank_GKE)**: The DB StatefulSets are applied to the cluster whose `local.cluster_configs` key is `"cluster1"`. This is not driven by a variable. If you rename cluster keys, the primary cluster assignment silently changes; always keep the first/main cluster as `cluster1`.
- **`path.module/.terraform/...` staging**: `deploy.tf` writes into `.terraform/` under each module. Do not put this path in `.gitignore` at module scope — the root-level `.gitignore` already covers it.
- **`always_run = timestamp()`**: Used deliberately on download resources to force a re-run. Changing it to a stable trigger (e.g. a version string) will leave stale tarballs in place.
- **Istio destroy provisioner variables**: `triggers = { ... resource_creator_identity = var.resource_creator_identity }` looks redundant, but destroy provisioners cannot reference `var.*` directly — they must go through `self.triggers.*`. Keep the duplication.
- **Global routing mode (MC_Bank_GKE)**: `routing_mode = "GLOBAL"` is required on the VPC for MCI/MCS to work. Do not flip to `REGIONAL`.
- **Multiple copyright holders**: Some files carry `Google LLC`, others `Tech Equity Ltd` (e.g. `asm.tf`, `hub.tf`, `istiosidecar.tf`). Preserve whichever header is already present; don't normalize them in a drive-by.
