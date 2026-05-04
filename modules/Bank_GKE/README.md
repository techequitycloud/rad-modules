# Bank\_GKE Module

This module deploys the **Bank of Anthos** microservices banking demo application (v0.6.7) on a single Google Kubernetes Engine (GKE) cluster. It provisions the GKE cluster, configures Cloud Service Mesh, registers the cluster with a GKE Fleet, and optionally enables Anthos Config Management and Cloud Monitoring SLOs.

For a detailed technical walkthrough of the full implementation, see [Bank\_GKE.md](Bank_GKE.md).

## Usage

```hcl
module "bank_gke" {
  source = "./modules/Bank_GKE"

  existing_project_id = "my-gcp-project"
  gcp_region          = "us-central1"

  create_autopilot_cluster   = true
  enable_cloud_service_mesh  = true
  deploy_application         = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3 |
| google | >= 5.0 |
| kubernetes | >= 2.23 |
| kubectl | >= 1.14.0 |
| time | >= 0.9 |
| http | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |
| kubernetes | >= 2.23 |
| kubectl | >= 1.14.0 |
| time | >= 0.9 |
| http | >= 3.0 |
| random | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| google\_container\_cluster.gke\_cluster | resource |
| google\_container\_node\_pool.preemptible\_nodes | resource |
| google\_service\_account.gke\_standard | resource |
| google\_project\_iam\_member (×9 roles) | resource |
| google\_compute\_network.vpc | resource |
| google\_compute\_subnetwork.subnetwork | resource |
| google\_compute\_firewall (×6 rules) | resource |
| google\_compute\_router.cr\_region | resource |
| google\_compute\_router\_nat.nat\_gw\_region | resource |
| google\_compute\_global\_address.glb | resource |
| google\_gke\_hub\_membership.gke\_cluster | resource |
| google\_gke\_hub\_feature.service\_mesh | resource |
| google\_gke\_hub\_feature\_membership.service\_mesh\_feature\_member | resource |
| google\_monitoring\_service.gke\_services | resource |
| google\_monitoring\_slo.gke\_services\_slo\_limit\_utilization | resource |
| kubernetes\_namespace.bank\_of\_anthos | resource |
| null\_resource.download\_bank\_of\_anthos | resource |
| null\_resource.deploy\_bank\_of\_anthos | resource |
| google\_project\_service.enabled\_services | resource |
| random\_id.default | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| existing\_project\_id | GCP project ID where all resources are deployed. Leave blank to use the default project. | `string` | `""` | no |
| gcp\_region | GCP region for the GKE cluster, VPC, and all supporting resources (e.g. `"us-central1"`). | `string` | `"us-central1"` | no |
| enable\_services | Set to `true` to automatically enable required GCP APIs. Set to `false` if APIs are already enabled in the target project. | `bool` | `true` | no |
| create\_network | Set to `true` to create a new VPC network and subnet. Set to `false` to use an existing network identified by `network_name`. | `bool` | `true` | no |
| network\_name | Name of the VPC network to create or use. | `string` | `"vpc-network"` | no |
| subnet\_name | Name of the subnet to create or use within the VPC. | `string` | `"vpc-subnet"` | no |
| ip\_cidr\_ranges | IPv4 CIDR blocks for the subnet primary and secondary ranges. First CIDR is the primary node range; additional CIDRs are secondary ranges for pods and services. | `set(string)` | `["10.132.0.0/16", "192.168.1.0/24"]` | no |
| create\_cluster | Set to `true` to create a new GKE cluster. Set to `false` to use an existing cluster identified by `gke_cluster`. | `bool` | `true` | no |
| gke\_cluster | Name of the GKE cluster to create or use. | `string` | `"gke-cluster"` | no |
| create\_autopilot\_cluster | Set to `true` for GKE Autopilot (fully managed nodes). Set to `false` for Standard (manual node pools: 2 × `e2-standard-2` spot nodes, 50 GB SSD). | `bool` | `true` | no |
| release\_channel | GKE release channel: `RAPID`, `REGULAR` (default), `STABLE`, or `NONE`. | `string` | `"REGULAR"` | no |
| pod\_ip\_range | Name of the subnet secondary IP range for Pod addresses. | `string` | `"pod-ip-range"` | no |
| pod\_cidr\_block | IPv4 CIDR block for cluster Pods. Must not overlap with node or service ranges. | `string` | `"10.62.128.0/17"` | no |
| service\_ip\_range | Name of the subnet secondary IP range for Service addresses. | `string` | `"service-ip-range"` | no |
| service\_cidr\_block | IPv4 CIDR block for cluster Services (ClusterIP). Must not overlap with node or pod ranges. | `string` | `"10.64.128.0/20"` | no |
| enable\_cloud\_service\_mesh | Set to `true` to install Cloud Service Mesh (managed Istio) with `MANAGEMENT_AUTOMATIC` mode, enabling mTLS and traffic management. | `bool` | `true` | no |
| cloud\_service\_mesh\_version | Cloud Service Mesh version (format: `major.minor.patch-asm.N`, e.g. `"1.23.4-asm.1"`). Only used when `enable_cloud_service_mesh` is `true`. | `string` | `"1.23.4-asm.1"` | no |
| enable\_config\_management | Set to `true` to install Anthos Config Management (Config Sync), which syncs Kubernetes configuration from `config_sync_repo`. | `bool` | `false` | no |
| config\_management\_version | Anthos Config Management version (format: `major.minor.patch`, e.g. `"1.22.0"`). Only used when `enable_config_management` is `true`. | `string` | `"1.22.0"` | no |
| config\_sync\_repo | Git repository URL for Anthos Config Sync to pull Kubernetes manifests from. Only used when `enable_config_management` is `true`. | `string` | `"https://github.com/GoogleCloudPlatform/anthos-config-management-samples"` | no |
| config\_sync\_policy\_dir | Path within `config_sync_repo` containing the root Kubernetes configuration to sync. Only used when `enable_config_management` is `true`. | `string` | `"config-sync-quickstart/multirepo/root"` | no |
| enable\_monitoring | Set to `true` to enable Google Cloud Managed Prometheus and create Cloud Monitoring SLOs for the nine Bank of Anthos microservices. | `bool` | `true` | no |
| deploy\_application | Set to `true` to deploy the Bank of Anthos v0.6.7 application after the cluster is created. | `bool` | `true` | no |
| trusted\_users | Google account emails granted cluster-admin privileges on the GKE cluster. | `list(string)` | `[]` | no |
| deployment\_id | Alphanumeric suffix appended to resource names for uniqueness. Leave `null` to auto-generate. | `string` | `null` | no |
| resource\_creator\_identity | Email of the Terraform service account used to provision resources. | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| deployment\_id | The deployment ID suffix used in resource names |
| project\_id | The GCP project ID where resources were deployed |

<!-- BEGIN_TF_DOCS -->
Copyright 2023 Google LLC

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
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.14.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.23 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 7.30.0 |
| <a name="provider_google.impersonated"></a> [google.impersonated](#provider\_google.impersonated) | 7.30.0 |
| <a name="provider_kubernetes.primary"></a> [kubernetes.primary](#provider\_kubernetes.primary) | 3.1.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.fw_allow_gce_nfs_tcp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_allow_http_tcp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_allow_intra_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_allow_lb_hc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.fw_allow_nfs_hc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.glb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.cr_region](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat_gw_region](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.gke_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.preemptible_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_gke_hub_feature.service_mesh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/gke_hub_feature) | resource |
| [google_gke_hub_feature_membership.service_mesh_feature_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/gke_hub_feature_membership) | resource |
| [google_gke_hub_membership.gke_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/gke_hub_membership) | resource |
| [google_monitoring_service.gke_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_service) | resource |
| [google_monitoring_slo.gke_services_slo_limit_utilization](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_slo) | resource |
| [google_project_iam_member.gke_hub_service_account_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_standard_sa_role](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.gke_standard](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [kubernetes_namespace.bank_of_anthos](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [null_resource.deploy_bank_of_anthos](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.download_bank_of_anthos](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.verify_gke_hub_api_activation](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.verify_gke_hub_api_activation_hub](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.verify_hub_membership](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.verify_mesh_api_activation](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.verify_mesh_feature_active](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.verify_mesh_status](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_api_propagation](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_iam_propagation](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_service_mesh](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.gke_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_network.existing_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.existing_subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_zones.available_zones](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_container_cluster.existing_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_service_account_access_token.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account_access_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_service_mesh_version"></a> [cloud\_service\_mesh\_version](#input\_cloud\_service\_mesh\_version) | Version of Cloud Service Mesh to install (format: major.minor.patch-asm.N, e.g. '1.23.4-asm.1'). Only used when enable\_cloud\_service\_mesh is true. Defaults to '1.23.4-asm.1'. Must be a version compatible with the GKE cluster version and release channel. {{UIMeta group=6 order=603 }} | `string` | `"1.23.4-asm.1"` | no |
| <a name="input_config_management_version"></a> [config\_management\_version](#input\_config\_management\_version) | Version of Anthos Config Management to install (format: major.minor.patch, e.g. '1.22.0'). Only used when enable\_config\_management is true. Defaults to '1.22.0'. Must be compatible with the GKE cluster version. {{UIMeta group=6 order=605 }} | `string` | `"1.22.0"` | no |
| <a name="input_config_sync_policy_dir"></a> [config\_sync\_policy\_dir](#input\_config\_sync\_policy\_dir) | Path within the config\_sync\_repo Git repository containing the root Kubernetes configuration to sync (e.g. 'config-sync-quickstart/multirepo/root'). Only used when enable\_config\_management is true. Defaults to the quickstart multi-repo root directory. {{UIMeta group=6 order=607 }} | `string` | `"config-sync-quickstart/multirepo/root"` | no |
| <a name="input_config_sync_repo"></a> [config\_sync\_repo](#input\_config\_sync\_repo) | URL of the Git repository from which Anthos Config Sync will pull Kubernetes manifests (e.g. 'https://github.com/org/repo'). Only used when enable\_config\_management is true. Defaults to the Google Cloud Platform ACM samples repository. The repository must be publicly accessible or credentials must be configured separately. {{UIMeta group=6 order=606 }} | `string` | `"https://github.com/GoogleCloudPlatform/anthos-config-management-samples"` | no |
| <a name="input_create_autopilot_cluster"></a> [create\_autopilot\_cluster](#input\_create\_autopilot\_cluster) | Set to true (default) to create a GKE Autopilot cluster, where node provisioning and scaling are fully managed by Google. Set to false to create a Standard cluster where node pools are manually configured. Autopilot is recommended for most workloads; Standard offers more control over node configuration. {{UIMeta group=5 order=502 }} | `bool` | `true` | no |
| <a name="input_create_cluster"></a> [create\_cluster](#input\_create\_cluster) | Set to true (default) to create a new GKE cluster. Set to false to deploy the banking application onto an existing cluster identified by gke\_cluster. {{UIMeta group=5 order=501 }} | `bool` | `true` | no |
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | Set to true (default) to create a new VPC network and subnet for the GKE cluster. Set to false to use an existing network and subnet identified by network\_name and subnet\_name. {{UIMeta group=2 order=201 }} | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require\_credit\_purchases is true, users must have sufficient credit balance before deploying. Defaults to 200. {{UIMeta group=0 order=103 }} | `number` | `200` | no |
| <a name="input_deploy_application"></a> [deploy\_application](#input\_deploy\_application) | Set to true (default) to deploy the Bank of Anthos microservices banking demo application onto the GKE cluster after it is created. Set to false to provision only the cluster infrastructure without deploying the application. {{UIMeta group=7 order=701 }} | `bool` | `true` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources. {{UIMeta group=0 order=108 }} | `string` | `null` | no |
| <a name="input_enable_cloud_service_mesh"></a> [enable\_cloud\_service\_mesh](#input\_enable\_cloud\_service\_mesh) | Set to true (default) to install and configure Cloud Service Mesh (Google-managed Istio), which provides mTLS encryption, traffic management, and observability between microservices. Requires the mesh.googleapis.com API. Set to false to skip service mesh installation. {{UIMeta group=6 order=602 }} | `bool` | `true` | no |
| <a name="input_enable_config_management"></a> [enable\_config\_management](#input\_enable\_config\_management) | Set to true to install Anthos Config Management (ACM), which syncs Kubernetes configuration from a Git repository specified by config\_sync\_repo and config\_sync\_policy\_dir. Defaults to false. Requires enable\_cloud\_service\_mesh to also be true for full functionality. {{UIMeta group=6 order=604 }} | `bool` | `false` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Set to true (default) to enable Google Cloud Managed Service for Prometheus and Cloud Monitoring dashboards for the GKE cluster. Provides metrics, alerting, and observability for cluster workloads. Set to false to skip monitoring configuration. {{UIMeta group=6 order=601 }} | `bool` | `true` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable the required GCP project APIs (e.g. container.googleapis.com, mesh.googleapis.com). Set to false when deploying into an existing project where APIs are already enabled to avoid permission errors. {{UIMeta group=0 order=600 }} | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | GCP project ID of the destination project where the GKE cluster and banking application will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource\_creator\_identity service account must hold roles/owner in it. Leave blank to use the default project. {{UIMeta group=1 order=101 updatesafe }} | `string` | `""` | no |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region where the GKE cluster, VPC, and all supporting resources will be deployed (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Deployment may fail if sufficient resource quota is not available in the selected region. {{UIMeta group=1 order=102 }} | `string` | `"us-central1"` | no |
| <a name="input_gke_cluster"></a> [gke\_cluster](#input\_gke\_cluster) | Name of the GKE cluster. When create\_cluster is true, this is the name given to the newly created cluster. When create\_cluster is false, this identifies the existing cluster to use. Defaults to 'gke-cluster'. {{UIMeta group=5 order=503 }} | `string` | `"gke-cluster"` | no |
| <a name="input_ip_cidr_ranges"></a> [ip\_cidr\_ranges](#input\_ip\_cidr\_ranges) | Set of IPv4 CIDR blocks for the subnet primary and secondary ranges (e.g. ['10.132.0.0/16', '192.168.1.0/24']). Only used when create\_network is true. The first CIDR is the primary node range; additional CIDRs are secondary ranges for pods and services. Defaults to ['10.132.0.0/16', '192.168.1.0/24']. {{UIMeta group=2 order=204 }} | `set(string)` | <pre>[<br>  "10.132.0.0/16",<br>  "192.168.1.0/24"<br>]</pre> | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['GCP Project']. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. {{UIMeta group=0 order=100 }} | `string` | `"This module deploys an advanced, microservice banking demo application on Google Kubernetes Engine (GKE), utilizing Cloud Service Mesh for enhanced security and multi-cluster management. It serves as a reference implementation for highly scalable, secure, and feature-rich banking platforms. This module is for educational purposes only."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP",<br>  "GKE",<br>  "Anthos Service Mesh",<br>  "Anthos Config Management",<br>  "Cloud IAM",<br>  "Cloud Networking"<br>]</pre> | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the VPC network. When create\_network is true, this is the name given to the newly created network. When create\_network is false, this identifies the existing network to use. Defaults to 'vpc-network'. {{UIMeta group=2 order=202 }} | `string` | `"vpc-network"` | no |
| <a name="input_pod_cidr_block"></a> [pod\_cidr\_block](#input\_pod\_cidr\_block) | IPv4 CIDR block assigned to Pods running in the GKE cluster (e.g. '10.62.128.0/17'). Must be large enough to accommodate all pods across all nodes; a /17 supports up to 32,768 pod IPs. Must not overlap with the node or service CIDR ranges. Defaults to '10.62.128.0/17'. {{UIMeta group=5 order=506 }} | `string` | `"10.62.128.0/17"` | no |
| <a name="input_pod_ip_range"></a> [pod\_ip\_range](#input\_pod\_ip\_range) | Alias name for the secondary IP range used to assign IP addresses to Pods in the GKE cluster. This name is referenced when creating the subnet secondary range. Defaults to 'pod-ip-range'. Must be unique within the subnet. {{UIMeta group=0 order=505 }} | `string` | `"pod-ip-range"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel controlling the frequency and type of automatic cluster upgrades. Valid values: 'RAPID' (latest features, upgraded frequently), 'REGULAR' (balanced stability and features, default), 'STABLE' (least frequent upgrades, most stable), 'NONE' (manual upgrades only). Defaults to 'REGULAR'. {{UIMeta group=5 order=504 }} | `string` | `"REGULAR"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. {{UIMeta group=0 order=102 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_service_cidr_block"></a> [service\_cidr\_block](#input\_service\_cidr\_block) | IPv4 CIDR block assigned to Kubernetes Services (ClusterIP) in the GKE cluster (e.g. '10.64.128.0/20'). A /20 supports up to 4,096 service IPs. Must not overlap with the node or pod CIDR ranges. Defaults to '10.64.128.0/20'. {{UIMeta group=5 order=508 }} | `string` | `"10.64.128.0/20"` | no |
| <a name="input_service_ip_range"></a> [service\_ip\_range](#input\_service\_ip\_range) | Alias name for the secondary IP range used to assign IP addresses to Kubernetes Services (ClusterIP) in the GKE cluster. This name is referenced when creating the subnet secondary range. Defaults to 'service-ip-range'. Must be unique within the subnet. {{UIMeta group=0 order=507 }} | `string` | `"service-ip-range"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Name of the subnet within the VPC network. When create\_network is true, this is the name given to the newly created subnet. When create\_network is false, this identifies the existing subnet to use. Defaults to 'vpc-subnet'. {{UIMeta group=2 order=203 }} | `string` | `"vpc-subnet"` | no |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | List of Google account email addresses granted cluster-admin privileges on the GKE cluster and access via the Google Cloud console (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). {{UIMeta group=0 order=103 updatesafe }} | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID |
<!-- END_TF_DOCS -->