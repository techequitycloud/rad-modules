# Container\_Migration Module

This module deploys **Google Cloud Migrate to Containers (M2C)** infrastructure — the automated path for replatforming VM-based Linux workloads to containers on Google Kubernetes Engine (GKE) without manual application refactoring.

M2C uses two distinct CLIs: the **`mcdc` CLI** runs on each source VM to assess containerisation suitability, scoring readiness across multiple migration journeys (GKE, GKE Autopilot, Cloud Run, and Compute Engine) and generating reports in HTML, Excel, CSV, and JSON formats; the **`m2c` CLI** runs on a migration workstation to copy VM filesystems, analyse them with workload-specific plugins, produce a customisable migration plan, migrate persistent data to GKE PersistentVolumes, and generate production-ready Dockerfiles and Kubernetes manifests.

The full migration lifecycle spans three phases: **Transformation** (copy, analyse, customise, generate), **Workload Deployment** (build, push, deploy via Skaffold), and **Maintenance** (scale, autoscale, rolling updates using native Kubernetes).

The module provisions two Ubuntu source VMs (PostgreSQL 14 and Apache Tomcat 10 running the Spring PetClinic application), a Migrate to Containers CLI workstation pre-installed with the `m2c` toolchain, Docker, `kubectl`, and Skaffold, and a three-node GKE cluster ready to receive migrated workloads.

All resources are named with the prefix `mig-{deployment_id}-` (e.g. `mig-8b56-postgres`, `mig-8b56-tomcat`, `mig-8b56-m2c`, `mig-8b56-gke-cluster`, `mig-8b56-vpc`).

## Industry Value & Use Cases

Migrate to Containers is the Google-recommended path for engineering teams modernising VM fleets to Kubernetes without application-level refactoring. It is commonly adopted by organisations with large Java, Python, and Node.js VM estates that need to reduce operational overhead, improve density, and unlock CI/CD workflows — without a full application rewrite. Beyond Linux VMs, M2C also supports Apache Tomcat, IBM WebSphere, JBoss/WildFly, Apache HTTP Server, and WordPress workloads, with GKE and Cloud Run as deployment targets.

**Key use cases this module demonstrates:**
- **VM-to-container replatforming** — automatically containerise Linux VMs using the `m2c` CLI without modifying application source code
- **Workload assessment** — use `mcdc` to generate multi-format suitability reports scoring VMs across GKE, GKE Autopilot, Cloud Run, and Compute Engine migration journeys
- **Stateful workload migration** — migrate persistent database volumes (PostgreSQL data directory) to GKE PersistentVolumes using `m2c migrate-data`
- **Kubernetes Day 2 operations** — use generated Skaffold and deployment manifests as a foundation for CI/CD pipelines
- **Horizontal pod autoscaling** — configure GKE HPA on migrated Tomcat deployments to scale on CPU demand
- **Rolling update strategy** — configure zero-downtime rolling updates for migrated deployments

For a detailed technical walkthrough of the full lab, see [Container_Migration.md](../../docs/labs/Container_Migration.md).

Last tested on Mon May 26, 2026

## Deployment Options

Deploy this module from the **[RAD Modules platform UI](https://radmodules.dev)** — the recommended path, with **no command line or local toolchain required**. Advanced/automation users can alternatively use the Launcher CLI or call the Terraform module directly (see **Advanced** below).

| | [RAD Modules UI](https://radmodules.dev) | RAD Modules Launcher (CLI) |
|---|---|---|
| **Setup required** | None — runs in your browser | Python 3.7+, OpenTofu, and `gcloud` CLI |
| **Best for** | Quick starts, demos, and guided deployments | Automation, scripting, and full variable control |
| **Configuration** | Point-and-click form with sensible defaults | `--varfile` with `key = "value"` overrides |
| **State management** | Managed by the platform | GCS bucket you own and manage |

### Option 1: RAD Modules UI (no setup required)

Visit **[https://radmodules.dev](https://radmodules.dev)**, sign in with your Google account, and select this module from the catalog.

### Advanced — RAD Modules Launcher (CLI, for automation/maintainers)

Use the [RAD Modules Launcher](../../rad-launcher/README.md) to deploy from your workstation or Google Cloud Shell.

## Advanced — Terraform module (maintainers)

> **Platform users don't need this** — deploy from the [RAD Modules UI](https://radmodules.dev) above. The Terraform module call below is for maintainers/automation integrating the module directly.

```hcl
module "container_migration" {
  source = "./modules/Container_Migration"

  project_id            = "my-gcp-project"
  region                = "us-central1"
  zone                  = "us-central1-a"
  gke_node_count        = 3
  gke_node_machine_type = "e2-medium"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0, < 6.0 |
| null | >= 3.0 |
| random | >= 3.0 |

## Resources

| Name | Type |
|------|------|
| google_compute_firewall.allow_icmp | resource |
| google_compute_firewall.allow_internal | resource |
| google_compute_firewall.allow_ssh | resource |
| google_compute_firewall.allow_tomcat | resource |
| google_compute_instance.m2c_cli | resource |
| google_compute_instance.petclinic_postgres | resource |
| google_compute_instance.tomcat_petclinic | resource |
| google_compute_network.vpc | resource |
| google_container_cluster.m2c_guide | resource |
| google_container_node_pool.default_pool | resource |
| google_project_service.enabled_services | resource |
| random_id.default | resource |
| google_compute_network.vpc | data source |
| google_project.existing_project | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | GCP project ID where Container Migration resources will be deployed. | `string` | `null` | yes |
| region | GCP region (e.g. 'us-central1'). | `string` | `"us-central1"` | no |
| zone | GCP zone (e.g. 'us-central1-a'). | `string` | `"us-central1-a"` | no |
| gke\_node\_machine\_type | Machine type for GKE worker nodes. | `string` | `"e2-medium"` | no |
| gke\_node\_count | Number of GKE worker nodes. | `number` | `3` | no |
| postgres\_machine\_type | Machine type for the PostgreSQL source VM. | `string` | `"e2-medium"` | no |
| tomcat\_machine\_type | Machine type for the Tomcat source VM. | `string` | `"e2-medium"` | no |
| m2c\_machine\_type | Machine type for the m2c-cli VM. | `string` | `"e2-standard-4"` | no |
| m2c\_disk\_size\_gb | Boot disk size in GB for the m2c-cli VM. | `number` | `200` | no |
| enable\_services | Automatically enable required GCP APIs. | `bool` | `true` | no |
| create\_vpc | Create a new VPC for the lab. | `bool` | `true` | no |
| create\_default\_firewall\_rules | Create default firewall rules on the VPC. | `bool` | `true` | no |
| deployment\_id | Alphanumeric suffix for resource names. | `string` | `null` | no |
| resource\_creator\_identity | Terraform service account email. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| deployment\_id | Module Deployment ID |
| project\_id | GCP Project ID |
| gke\_cluster\_name | GKE cluster name |
| gke\_cluster\_location | GKE cluster zone |
| postgres\_vm\_name | PostgreSQL source VM name |
| postgres\_vm\_internal\_ip | PostgreSQL VM internal IP |
| tomcat\_vm\_name | Tomcat source VM name |
| tomcat\_vm\_external\_ip | Tomcat VM external IP |
| m2c\_cli\_vm\_name | m2c CLI VM name |
| petclinic\_url | PetClinic application URL |
| vpc\_name | VPC network name |
<!-- END_TF_DOCS -->
