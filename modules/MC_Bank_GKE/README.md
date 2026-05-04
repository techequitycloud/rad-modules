# MC\_Bank\_GKE Module

This module deploys the **Bank of Anthos** microservices banking demo application (v0.6.7) across multiple GKE clusters in multiple GCP regions. It provisions all clusters from a single Terraform configuration, configures Cloud Service Mesh fleet-wide, enables Multi-Cluster Ingress (MCI) and Multi-Cluster Services (MCS) for cross-cluster traffic, and exposes the application via a global HTTPS load balancer.

For a detailed technical walkthrough of the full implementation, see [MC\_Bank\_GKE.md](MC_Bank_GKE.md).

## Usage

```hcl
module "mc_bank_gke" {
  source = "./modules/MC_Bank_GKE"

  existing_project_id = "my-gcp-project"
  available_regions   = ["us-west1", "us-east1"]
  cluster_size        = 2

  create_autopilot_cluster  = true
  enable_cloud_service_mesh = true
  deploy_application        = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13 |
| google | n/a |
| kubernetes | n/a |

## Providers

| Name | Version |
|------|---------|
| google | n/a |
| google-beta | n/a |
| kubernetes (×4 cluster-specific aliases) | n/a |
| random | n/a |
| null | n/a |
| local | n/a |

## Resources

| Name | Type |
|------|------|
| google\_container\_cluster.gke\_cluster (for\_each) | resource |
| google\_container\_node\_pool.preemptible\_nodes (for\_each, Standard only) | resource |
| google\_service\_account.gke\_standard | resource |
| google\_project\_iam\_member (×9 roles) | resource |
| google\_compute\_network.vpc | resource |
| google\_compute\_subnetwork.subnetwork (for\_each) | resource |
| google\_compute\_firewall (×6 rules) | resource |
| google\_compute\_router.router (per region) | resource |
| google\_compute\_router\_nat.nat\_gateway (per region) | resource |
| google\_compute\_global\_address.glb | resource |
| google\_gke\_hub\_membership.hub\_membership (for\_each) | resource |
| google\_gke\_hub\_feature.service\_mesh\_feature | resource |
| google\_gke\_hub\_feature.multiclusteringress\_feature | resource |
| google\_gke\_hub\_feature\_membership.service\_mesh\_feature\_member (for\_each) | resource |
| kubernetes\_namespace.bank\_of\_anthos\_cluster1 | resource |
| kubernetes\_namespace.bank\_of\_anthos\_cluster2 | resource |
| null\_resource.download\_bank\_of\_anthos | resource |
| null\_resource.deploy\_bank\_of\_anthos | resource |
| null\_resource.app\_multicluster\_ingress | resource |
| null\_resource.cleanup\_mci\_resources | resource |
| null\_resource.cleanup\_multicluster\_ingress | resource |
| local\_file (×8 manifest renders) | resource |
| google\_project\_service.enabled\_services | resource |
| random\_id.default | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| existing\_project\_id | GCP project ID where all clusters and resources are deployed. | `string` | n/a | yes |
| available\_regions | GCP regions available for cluster placement. Clusters are assigned in round-robin order (e.g. with 2 regions and 4 clusters: cluster1=region[0], cluster2=region[1], cluster3=region[0], cluster4=region[1]). | `list(string)` | `["us-west1", "us-east1"]` | no |
| cluster\_size | Number of GKE clusters to create. Minimum 2 for a meaningful multi-cluster deployment. | `number` | `2` | no |
| enable\_services | Set to `true` to automatically enable the 32 required GCP APIs. Set to `false` if APIs are already enabled. | `bool` | `true` | no |
| create\_network | Set to `true` to create a shared VPC network for all clusters. Set to `false` to use an existing network identified by `network_name`. | `bool` | `true` | no |
| network\_name | Name of the shared VPC network to create or use (GLOBAL routing mode). | `string` | `"vpc-network"` | no |
| subnet\_name | Base name for per-cluster subnets. Each cluster gets a subnet named `<subnet_name>-cluster<N>` (e.g. `"vpc-subnet-cluster1"`). | `string` | `"vpc-subnet"` | no |
| create\_autopilot\_cluster | Set to `true` for GKE Autopilot clusters (fully managed nodes). Set to `false` for Standard clusters (manual node pools: 2 × `e2-standard-2` spot nodes, 50 GB SSD). | `bool` | `true` | no |
| release\_channel | GKE release channel: `RAPID`, `REGULAR` (default), `STABLE`, or `NONE`. Applies to all clusters. | `string` | `"REGULAR"` | no |
| enable\_cloud\_service\_mesh | Set to `true` to enable Cloud Service Mesh fleet-wide with `MANAGEMENT_AUTOMATIC` mode, providing mTLS and traffic management across all clusters. | `bool` | `true` | no |
| cloud\_service\_mesh\_version | Cloud Service Mesh version (format: `major.minor.patch-asm.N`, e.g. `"1.23.4-asm.1"`). Only used when `enable_cloud_service_mesh` is `true`. | `string` | `"1.23.4-asm.1"` | no |
| deploy\_application | Set to `true` to deploy Bank of Anthos v0.6.7 across all clusters after they are created. | `bool` | `true` | no |
| trusted\_users | Google account emails granted cluster-admin privileges on all GKE clusters. | `list(string)` | `[]` | no |
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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_google.impersonated"></a> [google.impersonated](#provider\_google.impersonated) | n/a |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | n/a |
| <a name="provider_kubernetes.cluster1"></a> [kubernetes.cluster1](#provider\_kubernetes.cluster1) | n/a |
| <a name="provider_kubernetes.cluster2"></a> [kubernetes.cluster2](#provider\_kubernetes.cluster2) | n/a |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google-beta_google_gke_hub_feature.multiclusteringress_feature](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_gke_hub_feature) | resource |
| [google-beta_google_gke_hub_feature.service_mesh_feature](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_gke_hub_feature) | resource |
| [google-beta_google_gke_hub_feature_membership.service_mesh_feature_member](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_gke_hub_feature_membership) | resource |
| [google-beta_google_project_service_identity.gke_hub_sa](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_compute_address.static_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_gke_masters](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_health_checks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_webhooks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.glb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat_gateway](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.gke_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.preemptible_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_gke_hub_membership.hub_membership](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/gke_hub_membership) | resource |
| [google_project_iam_member.gke_standard_sa_role](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.hub_service_account_container_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.hub_service_account_gke_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.gke_standard](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [kubernetes_namespace.bank_of_anthos_cluster1](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.bank_of_anthos_cluster2](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [local_file.backend_config_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.configmap_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.frontend_config_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.ingress_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.managed_certificate_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.multicluster_ingress_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.multicluster_service_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.nodeport_service_yaml_output](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.app_multicluster_ingress](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cleanup_fleet_asm](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cleanup_mci_resources](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.cleanup_multicluster_ingress](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.deploy_bank_of_anthos](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.download_bank_of_anthos](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.enable_asm](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_fleet_registration](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_service_mesh](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.gke_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_network.existing_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_zones.available_zones](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_service_account_access_token.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account_access_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_available_regions"></a> [available\_regions](#input\_available\_regions) | List of GCP regions available for cluster deployment (e.g. ['us-west1', 'us-east1']). Clusters are assigned to regions in round-robin order based on their index; if fewer regions than clusters are specified, regions are cycled (e.g. 2 regions for 4 clusters: cluster1=us-west1, cluster2=us-east1, cluster3=us-west1, cluster4=us-east1). Must contain at least one entry. Defaults to ['us-west1', 'us-east1']. {{UIMeta group=1 order=102 }} | `list(string)` | <pre>[<br>  "us-west1",<br>  "us-east1"<br>]</pre> | no |
| <a name="input_cloud_service_mesh_version"></a> [cloud\_service\_mesh\_version](#input\_cloud\_service\_mesh\_version) | Version of Cloud Service Mesh to install across all clusters (format: major.minor.patch-asm.N, e.g. '1.23.4-asm.1'). Only used when enable\_cloud\_service\_mesh is true. Defaults to '1.23.4-asm.1'. Must be compatible with the GKE cluster versions and release channel. {{UIMeta group=4 order=402 }} | `string` | `"1.23.4-asm.1"` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Number of GKE clusters to create for the multi-cluster banking application deployment. Minimum 2 for meaningful multi-cluster demonstration; maximum is limited by the available quota in the selected regions. Regions are assigned from available\_regions in round-robin order. Defaults to 2. {{UIMeta group=3 order=303 }} | `number` | `2` | no |
| <a name="input_create_autopilot_cluster"></a> [create\_autopilot\_cluster](#input\_create\_autopilot\_cluster) | Set to true (default) to create GKE Autopilot clusters, where node provisioning and scaling are fully managed by Google. Set to false to create Standard clusters where node pools are manually configured. Applies to all clusters in this deployment. Autopilot is recommended for most workloads; Standard offers more control over node configuration. {{UIMeta group=3 order=301 }} | `bool` | `true` | no |
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | Set to true (default) to create a new shared VPC network for all GKE clusters. Set to false to use an existing network identified by network\_name. Each cluster receives its own subnet automatically derived from the cluster index. {{UIMeta group=2 order=201 }} | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require\_credit\_purchases is true, users must have sufficient credit balance before deploying. Defaults to 150. {{UIMeta group=0 order=104 }} | `number` | `150` | no |
| <a name="input_deploy_application"></a> [deploy\_application](#input\_deploy\_application) | Set to true (default) to deploy the Bank of Anthos microservices banking demo application across all GKE clusters after they are created. Set to false to provision only the cluster infrastructure without deploying the application. {{UIMeta group=5 order=501 }} | `bool` | `true` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources. {{UIMeta group=0 order=108 }} | `string` | `null` | no |
| <a name="input_enable_cloud_service_mesh"></a> [enable\_cloud\_service\_mesh](#input\_enable\_cloud\_service\_mesh) | Set to true (default) to install and configure Cloud Service Mesh (Google-managed Istio) across all clusters, enabling mTLS encryption, cross-cluster traffic management, and unified observability. Requires the mesh.googleapis.com API. Set to false to skip service mesh installation. {{UIMeta group=4 order=401 }} | `bool` | `true` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable the required GCP project APIs (e.g. container.googleapis.com, mesh.googleapis.com). Set to false when deploying into an existing project where APIs are already enabled to avoid permission errors. {{UIMeta group=0 order=401 }} | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | GCP project ID of the destination project where the GKE clusters and banking application will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource\_creator\_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=1 order=101 updatesafe }} | `string` | n/a | yes |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['GCP Project']. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. {{UIMeta group=0 order=100 }} | `string` | `"This module deploys an advanced, microservice banking demo application on Google Kubernetes Engine (GKE) across multiple clusters, utilizing Cloud Service Mesh for enhanced security and multi-cluster management. It serves as a reference implementation for highly scalable, secure, and feature-rich banking platforms. This module is for educational purposes only."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP",<br>  "GKE",<br>  "Anthos Service Mesh",<br>  "Cloud IAM",<br>  "Cloud Networking"<br>]</pre> | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the shared VPC network used by all clusters. When create\_network is true, this is the name given to the newly created network. When create\_network is false, this identifies the existing network to use. Defaults to 'vpc-network'. {{UIMeta group=2 order=202 }} | `string` | `"vpc-network"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel controlling the frequency and type of automatic upgrades for all clusters. Valid values: 'RAPID' (latest features, upgraded frequently), 'REGULAR' (balanced stability and features, default), 'STABLE' (least frequent upgrades, most stable), 'NONE' (manual upgrades only). Defaults to 'REGULAR'. {{UIMeta group=3 order=302 }} | `string` | `"REGULAR"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. {{UIMeta group=0 order=105 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. {{UIMeta group=0 order=102 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Base name for per-cluster subnets. Each cluster receives a subnet named '<subnet\_name>-cluster<N>' (e.g. 'vpc-subnet-cluster1', 'vpc-subnet-cluster2'). Only used when create\_network is true. Defaults to 'vpc-subnet'. {{UIMeta group=2 order=203 }} | `string` | `"vpc-subnet"` | no |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | List of Google account email addresses granted cluster-admin privileges on all GKE clusters in this deployment (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). {{UIMeta group=0 order=107 updatesafe }} | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID |
<!-- END_TF_DOCS -->