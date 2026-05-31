# Container_Migration Module

## Overview

The **Container_Migration** module provisions a complete lab environment for practising **Google Cloud Migrate to Containers (M2C)** — the automated path for replatforming Linux VM workloads to containers on GKE without modifying application source code. It deploys two source VMs running real applications, a dedicated migration workstation with the full M2C toolchain, and a GKE cluster ready to receive migrated workloads.

The module creates an end-to-end environment in which engineers can execute the full container migration lifecycle: assessing source VMs with `mcdc`, copying filesystems and generating Kubernetes manifests with `m2c`, building container images with Skaffold, and deploying to GKE.

---

## Resources Created

### Networking
- **VPC network** (`google_compute_network`) — auto-mode VPC named `mig-<id>-vpc`, created when `create_vpc = true`
- **Firewall rules** (when `create_default_firewall_rules = true`):
  - `mig-<id>-allow-internal` — all traffic within `internal_traffic_cidr` (default `10.128.0.0/9`)
  - `mig-<id>-allow-ssh` — TCP/22 from `0.0.0.0/0`
  - `mig-<id>-allow-icmp` — ICMP from `0.0.0.0/0`
  - `mig-<id>-allow-tomcat` — TCP/8080 from `0.0.0.0/0`, targeting instances with tag `tomcat`

### Compute Engine — Source VMs
- **PostgreSQL VM** (`mig-<id>-postgres`) — Ubuntu 22.04, `e2-medium` (configurable), tagged `postgres`. Startup script installs PostgreSQL 14, creates the `petclinic` database, sets the `postgres` password to `petclinic`, enables remote connections, and installs the `mcdc` collector CLI.
- **Tomcat VM** (`mig-<id>-tomcat`) — Ubuntu 22.04, `e2-medium` (configurable), tagged `tomcat`. Startup script installs Java 17, Maven, Apache Tomcat 10.1.25, clones and builds the Spring PetClinic WAR (`petclinic.war`), deploys it to Tomcat, and installs the `mcdc` collector CLI. The PostgreSQL VM's internal IP is injected into `/etc/hosts` as `petclinic-postgres`.

### Compute Engine — Migration Workstation
- **m2c-cli VM** (`mig-<id>-m2c`) — Ubuntu 22.04, `e2-standard-4` (configurable), 200 GB disk (configurable). Startup script pre-installs: Docker, `m2c` CLI (latest), `kubectl` (latest stable), Skaffold (latest), and `gke-gcloud-auth-plugin`. Writes a `/root/filters.txt` exclusion list and creates the `/root/m2c-petclinic/` working directory.

### GKE Cluster
- **Zonal GKE cluster** (`mig-<id>-gke-cluster`) — located in `var.zone`. Default node pool removed and replaced by a custom `default-pool` with `var.gke_node_count` nodes (default 3) of machine type `var.gke_node_machine_type` (default `e2-medium`), 50 GB `pd-standard` disk, `cloud-platform` OAuth scope. Uses VPC-native networking with empty `ip_allocation_policy {}` (GKE assigns pod/service ranges automatically).

### APIs Enabled (when `enable_services = true`)
`compute.googleapis.com`, `container.googleapis.com`, `artifactregistry.googleapis.com`, `containerregistry.googleapis.com`, `iam.googleapis.com`, `iamcredentials.googleapis.com`, `cloudresourcemanager.googleapis.com`, `storage.googleapis.com`, `logging.googleapis.com`, `monitoring.googleapis.com`

---

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | null | GCP project ID (required) |
| `region` | string | `us-central1` | GCP region for all resources |
| `zone` | string | `us-central1-a` | GCP zone for VMs and GKE cluster |
| `deployment_id` | string | null | Suffix for resource names; auto-generated if null |
| `enable_services` | bool | true | Enable required GCP APIs |
| `create_vpc` | bool | true | Create a new auto-mode VPC |
| `create_default_firewall_rules` | bool | true | Create allow-internal/ssh/icmp firewall rules |
| `internal_traffic_cidr` | string | `10.128.0.0/9` | Source CIDR for allow-internal firewall rule |
| `postgres_machine_type` | string | `e2-medium` | Machine type for PostgreSQL source VM |
| `postgres_disk_size_gb` | number | 20 | Boot disk size (GB) for PostgreSQL VM |
| `tomcat_machine_type` | string | `e2-medium` | Machine type for Tomcat source VM |
| `tomcat_disk_size_gb` | number | 20 | Boot disk size (GB) for Tomcat VM |
| `m2c_machine_type` | string | `e2-standard-4` | Machine type for m2c-cli workstation |
| `m2c_disk_size_gb` | number | 200 | Boot disk size (GB) for m2c-cli VM (must hold source VM filesystem copies) |
| `gke_node_machine_type` | string | `e2-medium` | Machine type for GKE worker nodes |
| `gke_node_count` | number | 3 | Number of GKE nodes |

### Platform / Metadata Variables
`module_description`, `module_documentation`, `module_dependency`, `module_services`, `credit_cost`, `require_credit_purchases`, `enable_purge`, `public_access`, `shared_users`, `resource_creator_identity`

---

## Outputs

| Output | Description |
|---|---|
| `deployment_id` | Deployment ID suffix used in resource names |
| `project_id` | GCP project ID |
| `gke_cluster_name` | Name of the GKE cluster receiving migrated containers |
| `gke_cluster_location` | Zone where the GKE cluster is deployed |
| `postgres_vm_name` | Instance name of the PostgreSQL source VM |
| `postgres_vm_internal_ip` | Internal IP address of the PostgreSQL VM |
| `tomcat_vm_name` | Instance name of the Tomcat source VM |
| `tomcat_vm_external_ip` | External IP of the Tomcat VM (access PetClinic at port 8080) |
| `m2c_cli_vm_name` | Instance name of the migration workstation |
| `petclinic_url` | Full URL to the PetClinic application running on Tomcat |
| `vpc_name` | Name of the VPC network |

---

## Common Issues and Variable Dependencies

### Variables That Depend on Each Other

- **`create_vpc` and `create_default_firewall_rules`**: The firewall rules reference `data.google_compute_network.vpc`, which depends on `google_compute_network.vpc` being created first. If `create_vpc = false`, the firewall resources still create against the existing VPC whose name is `local.vpc_name = "mig-<id>-vpc"`. This means if `create_vpc = false`, the named VPC must already exist with exactly that name — there is no variable to specify a different VPC name.

- **`region` and `zone` must be consistent**: The GKE cluster and all VMs are deployed to `var.zone`. The `var.region` is used only for GCP API calls and data lookups. Ensure `zone` is within `region` (e.g., `zone = "us-central1-a"` with `region = "us-central1"`).

- **`m2c_disk_size_gb` must accommodate source VM filesystems**: The m2c-cli VM copies the entire filesystem of each source VM before analysis. With default 20 GB disks on the source VMs, the m2c disk needs at least 50–60 GB for the copies plus working space. The default of 200 GB is intentionally generous.

### Mutually Exclusive Variable Combinations

- **`create_vpc = false` with no existing VPC**: The `data.google_compute_network.vpc` data source looks up a VPC by the name `mig-<id>-vpc`. If this VPC does not exist, Terraform will fail. There is no variable to specify a custom VPC name when `create_vpc = false`.

### Variables That Affect Other Variables' Behavior

- **`deployment_id`**: When set, all resource names (`local.vpc_name`, `local.gke_cluster_name`, `local.postgres_vm_name`, `local.tomcat_vm_name`, `local.m2c_cli_vm_name`) use this value as the suffix. When null, a random 2-byte hex ID is generated. Changing this after deployment forces recreation of all resources.

- **`zone` affects GKE cluster type**: The GKE cluster is created as a zonal cluster (not regional), so it uses `var.zone` as its location. This means a single control plane in one zone; there is no option for a regional cluster in this module.

### Common Pitfalls

1. **Startup script duration**: All three VMs run lengthy startup scripts (PostgreSQL installation + db setup, Tomcat installation + Maven build, m2c toolchain download). Allow 5–10 minutes after `terraform apply` completes before SSHing to the VMs and expecting the tools to be ready. Check `/var/log/startup-script.log` on each VM to confirm completion.

2. **`mcdc` and `m2c` versions are fetched at runtime**: The startup scripts download the latest version of `mcdc` and `m2c` from Google's public release storage at VM creation time. If these endpoints are unavailable or return a different version format, the installation may silently skip with `|| true`. Verify with `mcdc --version` and `m2c version` after connecting.

3. **Tomcat startup depends on PostgreSQL**: The Tomcat VM startup script injects the PostgreSQL VM's internal IP into `/etc/hosts` before starting Tomcat. If the PostgreSQL VM is not yet responding, the PetClinic application will start but fail to connect to the database. The Spring PetClinic will retry connections, so this is self-healing once PostgreSQL finishes initialization.

4. **GKE cluster uses empty `ip_allocation_policy {}`**: This tells GKE to automatically assign pod and service CIDR ranges from the VPC's secondary ranges. For a VPC-native cluster on an auto-mode VPC, GKE will select appropriate ranges automatically. This is intentional and removes the need to specify `pod_cidr_block` and `service_cidr_block` for this module.

5. **Container images built during the lab are not managed by Terraform**: Images pushed to Artifact Registry or Container Registry during the migration exercises are outside the Terraform state. They must be deleted manually if you want to clean up Artifact Registry storage after `terraform destroy`.

6. **`enable_services = false` pitfall**: If APIs are not yet enabled and `enable_services = false`, `terraform apply` will fail on resource creation. Only set this to `false` if all 10 required APIs are confirmed enabled in the target project.
