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
Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0, < 6.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 5.45.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.allow_icmp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_tomcat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.m2c_cli](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.petclinic_postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.tomcat_petclinic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_container_cluster.m2c_guide](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.default_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_default_firewall_rules"></a> [create\_default\_firewall\_rules](#input\_create\_default\_firewall\_rules) | Set to true (default) to create default firewall rules (allow-internal, allow-ssh, allow-icmp) on the VPC. Set to false if these rules already exist on the target network. {{UIMeta group=3 order=302 }} | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Set to true (default) to create a new auto-mode VPC network for the lab. Set to false to use an existing VPC. {{UIMeta group=3 order=301 }} | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }} | `number` | `0` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to use no suffix. {{UIMeta group=0 order=108 }} | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. {{UIMeta group=0 order=109 }} | `bool` | `true` | no |
| <a name="input_gke_node_count"></a> [gke\_node\_count](#input\_gke\_node\_count) | Number of nodes in the GKE default node pool. Minimum 3 recommended to support StatefulSet and Deployment scheduling during the lab. {{UIMeta group=6 order=602 }} | `number` | `3` | no |
| <a name="input_gke_node_machine_type"></a> [gke\_node\_machine\_type](#input\_gke\_node\_machine\_type) | Machine type for GKE worker nodes (e.g. 'e2-medium'). Used for the default node pool that runs migrated container workloads. {{UIMeta group=6 order=601 }} | `string` | `"e2-medium"` | no |
| <a name="input_internal_traffic_cidr"></a> [internal\_traffic\_cidr](#input\_internal\_traffic\_cidr) | CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. Override if using a custom-mode VPC. {{UIMeta group=3 order=303 }} | `string` | `"10.128.0.0/9"` | no |
| <a name="input_m2c_disk_size_gb"></a> [m2c\_disk\_size\_gb](#input\_m2c\_disk\_size\_gb) | Boot disk size in GB for the m2c-cli VM. Must be large enough to hold a copy of the source VM filesystems (minimum 200 GB recommended). {{UIMeta group=5 order=502 }} | `number` | `200` | no |
| <a name="input_m2c_machine_type"></a> [m2c\_machine\_type](#input\_m2c\_machine\_type) | Machine type for the Migrate to Containers CLI VM (e.g. 'e2-standard-4'). This VM requires sufficient CPU and memory to copy and analyse source VM filesystems. {{UIMeta group=5 order=501 }} | `string` | `"e2-standard-4"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }} | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. {{UIMeta group=0 order=100 }} | `string` | `"This module provisions the complete Google Cloud infrastructure required to run a Migrate to Containers (M2C) lab — the automated path for replatforming VM-based Linux workloads to containers on Google Kubernetes Engine (GKE) without manual application refactoring. Migrate to Containers analyses running Linux VMs using the mcdc CLI, auto-generates production-ready Dockerfiles and Kubernetes manifests, and migrates persistent data volumes to GKE PersistentVolumes. This module deploys two Ubuntu source VMs (PostgreSQL 14 and Apache Tomcat 10 running the Spring PetClinic application), a Migrate to Containers CLI workstation pre-installed with the m2c toolchain, Docker, kubectl, and Skaffold, and a three-node GKE cluster ready to receive migrated workloads — providing a complete, hands-on environment to practise the full container migration lifecycle from workload assessment through to GKE deployment and horizontal pod autoscaling."` | no |
| <a name="input_module_documentation"></a> [module\_documentation](#input\_module\_documentation) | URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }} | `string` | `"https://github.com/techequitycloud/rad-modules/blob/main/docs/labs/Container_Migration.md"` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP",<br>  "GKE",<br>  "Migrate to Containers",<br>  "Cloud Compute",<br>  "Cloud Networking",<br>  "Cloud IAM",<br>  "VPC Network",<br>  "Compute Engine"<br>]</pre> | no |
| <a name="input_postgres_disk_size_gb"></a> [postgres\_disk\_size\_gb](#input\_postgres\_disk\_size\_gb) | Boot disk size in GB for the PostgreSQL source VM. Minimum 20 GB recommended. {{UIMeta group=4 order=402 }} | `number` | `20` | no |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine type for the PostgreSQL source VM (e.g. 'e2-medium'). This VM runs PostgreSQL 14 and serves as the database migration source. {{UIMeta group=4 order=401 }} | `string` | `"e2-medium"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID where Container Migration resources will be deployed. Must already exist and the service account must hold roles/owner. {{UIMeta group=1 order=101 updatesafe }} | `string` | `null` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to false to restrict this module to platform administrators only. Set to true (the default) to make it visible and deployable by all platform users. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region where the GKE cluster and VMs will be deployed (e.g. 'us-central1'). {{UIMeta group=1 order=103 }} | `string` | `"us-central1"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. {{UIMeta group=0 order=107 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_shared_users"></a> [shared\_users](#input\_shared\_users) | List of users who can view and deploy this module regardless of the public\_access setting. Enter one or more user email addresses. Metadata only — not referenced within the Terraform module execution; consumed by the deployment platform only. {{UIMeta group=0 order=107 }} | `list(string)` | `[]` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Tenant identifier used in resource naming. Shared by every module deployed to the same tenant in this project — reuse it to share that tenant VPC, service accounts and Artifact Registry, or change it to create a separate namespace. Must be 1-20 lowercase alphanumeric characters and hyphens (e.g. prod, dev, tenant-1). {{UIMeta group=1 order=102 updatesafe }} | `string` | `"demo"` | no |
| <a name="input_tomcat_disk_size_gb"></a> [tomcat\_disk\_size\_gb](#input\_tomcat\_disk\_size\_gb) | Boot disk size in GB for the Tomcat source VM. Minimum 20 GB recommended. {{UIMeta group=4 order=404 }} | `number` | `20` | no |
| <a name="input_tomcat_machine_type"></a> [tomcat\_machine\_type](#input\_tomcat\_machine\_type) | Machine type for the Tomcat source VM (e.g. 'e2-medium'). This VM runs Apache Tomcat 10 with the Spring PetClinic application. {{UIMeta group=4 order=403 }} | `string` | `"e2-medium"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | GCP zone where the GKE cluster and VMs will be deployed (e.g. 'us-central1-a'). {{UIMeta group=1 order=104 }} | `string` | `"us-central1-a"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_gke_cluster_location"></a> [gke\_cluster\_location](#output\_gke\_cluster\_location) | Zone where the GKE cluster is deployed |
| <a name="output_gke_cluster_name"></a> [gke\_cluster\_name](#output\_gke\_cluster\_name) | Name of the GKE cluster that receives migrated container workloads |
| <a name="output_m2c_cli_vm_name"></a> [m2c\_cli\_vm\_name](#output\_m2c\_cli\_vm\_name) | Instance name of the Migrate to Containers CLI VM |
| <a name="output_petclinic_url"></a> [petclinic\_url](#output\_petclinic\_url) | Browser URL for the PetClinic application running on Tomcat |
| <a name="output_postgres_vm_internal_ip"></a> [postgres\_vm\_internal\_ip](#output\_postgres\_vm\_internal\_ip) | Internal IP address of the PostgreSQL source VM |
| <a name="output_postgres_vm_name"></a> [postgres\_vm\_name](#output\_postgres\_vm\_name) | Instance name of the PostgreSQL source VM |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | GCP Project ID |
| <a name="output_tomcat_vm_external_ip"></a> [tomcat\_vm\_external\_ip](#output\_tomcat\_vm\_external\_ip) | External IP address of the Tomcat VM — use this to browse the PetClinic app |
| <a name="output_tomcat_vm_name"></a> [tomcat\_vm\_name](#output\_tomcat\_vm\_name) | Instance name of the Tomcat source VM |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | Name of the VPC network created for the lab |
<!-- END_TF_DOCS -->
