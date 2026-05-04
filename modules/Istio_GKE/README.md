# Istio\_GKE Module

This module provisions a GKE Standard cluster and installs **open-source Istio** onto it using `istioctl`. Engineers choose between two Istio data plane architectures at deployment time: **sidecar mode** (an Envoy proxy injected into each pod) or **ambient mode** (a shared per-node ztunnel proxy). The full open-source observability stack — Prometheus, Jaeger, Grafana, and Kiali — is installed alongside Istio. Optionally, the Istio Bookinfo sample application is deployed to provide a live traffic source for exploring mesh features.

For a detailed technical walkthrough of the full implementation, see [Istio\_GKE.md](Istio_GKE.md).

## Usage

```hcl
module "istio_gke" {
  source = "./modules/Istio_GKE"

  existing_project_id  = "my-gcp-project"
  gcp_region           = "us-central1"
  istio_version        = "1.24.2"
  install_ambient_mesh = false   # true for ambient mode
  deploy_application   = true
}
```

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
| <a name="provider_google"></a> [google](#provider\_google) | 7.30.0 |
| <a name="provider_google.impersonated"></a> [google.impersonated](#provider\_google.impersonated) | 7.30.0 |
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
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.cr_region](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat_gw_region](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.gke_standard_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.preemptible_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.gke_sa_role](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.gke_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [null_resource.get_ambient_istio_ingress_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.get_sidecar_istio_ingress_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_ambient_mesh](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_sidecar_mesh](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_container_api](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
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
| <a name="input_create_cluster"></a> [create\_cluster](#input\_create\_cluster) | Set to true (default) to create a new GKE cluster. Set to false to install Istio onto an existing cluster identified by gke\_cluster. | `bool` | `true` | no |
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | Set to true (default) to create a new VPC network and subnet for the GKE cluster. Set to false to use an existing network and subnet identified by network\_name and subnet\_name. | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require\_credit\_purchases is true, users must have sufficient credit balance before deploying. Defaults to 100. | `number` | `100` | no |
| <a name="input_deploy_application"></a> [deploy\_application](#input\_deploy\_application) | Set to true (default) to deploy the Istio Bookinfo sample application onto the GKE cluster after Istio is installed. The Bookinfo app demonstrates Istio traffic management, telemetry, and security features. Set to false to install only the Istio service mesh without a demo application. | `bool` | `true` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources. | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. | `bool` | `true` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable the required GCP project APIs (e.g. container.googleapis.com). Set to false when deploying into an existing project where APIs are already enabled to avoid permission errors. | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | GCP project ID of the destination project where the GKE cluster and Istio service mesh will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource\_creator\_identity service account must hold roles/owner in it. Required; no default. | `string` | n/a | yes |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region where the GKE cluster, VPC, and all supporting resources will be deployed (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Deployment may fail if sufficient resource quota is not available in the selected region. | `string` | `"us-central1"` | no |
| <a name="input_gke_cluster"></a> [gke\_cluster](#input\_gke\_cluster) | Name of the GKE cluster. When create\_cluster is true, this is the name given to the newly created cluster. When create\_cluster is false, this identifies the existing cluster onto which Istio will be installed. Defaults to 'gke-cluster'. | `string` | `"gke-cluster"` | no |
| <a name="input_install_ambient_mesh"></a> [install\_ambient\_mesh](#input\_install\_ambient\_mesh) | Set to true to install Istio in ambient mode, which uses node-level ztunnel proxies instead of per-pod sidecars — reducing resource overhead and simplifying pod configuration. Set to false (default) to install in sidecar mode, where an Envoy proxy is injected into each pod for full per-pod traffic control. | `bool` | `false` | no |
| <a name="input_ip_cidr_ranges"></a> [ip\_cidr\_ranges](#input\_ip\_cidr\_ranges) | Set of IPv4 CIDR blocks for the subnet primary and secondary ranges (e.g. ['10.132.0.0/16', '192.168.1.0/24']). Only used when create\_network is true. The first CIDR is the primary node range; additional CIDRs are secondary ranges for pods and services. Defaults to ['10.132.0.0/16', '192.168.1.0/24']. | `set(string)` | <pre>[<br>  "10.132.0.0/16",<br>  "192.168.1.0/24"<br>]</pre> | no |
| <a name="input_istio_version"></a> [istio\_version](#input\_istio\_version) | Version of open source Istio to install on the GKE cluster (format: major.minor.patch, e.g. '1.24.2'). Must be a version supported by the selected GKE release channel. Defaults to '1.24.2'. Refer to the Istio release page for available versions. | `string` | `"1.24.2"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['GCP Project']. | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. | `string` | `"This module configures the Open Source Istio service mesh on a Google Kubernetes Engine (GKE) cluster, providing a dedicated infrastructure layer for secure, fast, and reliable service-to-service communication. You can choose between ambient or sidecar mesh and explore advanced features like traffic management, security, and observability. This module is for educational purposes only."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. | `list(string)` | <pre>[<br>  "GCP",<br>  "GKE",<br>  "Istio",<br>  "Cloud IAM",<br>  "Cloud Networking"<br>]</pre> | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the VPC network. When create\_network is true, this is the name given to the newly created network. When create\_network is false, this identifies the existing network to use. Defaults to 'vpc-network'. | `string` | `"vpc-network"` | no |
| <a name="input_pod_cidr_block"></a> [pod\_cidr\_block](#input\_pod\_cidr\_block) | IPv4 CIDR block assigned to Pods running in the GKE cluster (e.g. '10.62.128.0/17'). Must be large enough to accommodate all pods across all nodes; a /17 supports up to 32,768 pod IPs. Must not overlap with the node or service CIDR ranges. Defaults to '10.62.128.0/17'. | `string` | `"10.62.128.0/17"` | no |
| <a name="input_pod_ip_range"></a> [pod\_ip\_range](#input\_pod\_ip\_range) | Alias name for the secondary IP range used to assign IP addresses to Pods in the GKE cluster. This name is referenced when creating the subnet secondary range. Defaults to 'pod-ip-range'. Must be unique within the subnet. | `string` | `"pod-ip-range"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. | `bool` | `true` | no |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel controlling the frequency and type of automatic cluster upgrades. Valid values: 'RAPID' (latest features, upgraded frequently), 'REGULAR' (balanced stability and features, default), 'STABLE' (least frequent upgrades, most stable), 'NONE' (manual upgrades only). Defaults to 'REGULAR'. | `string` | `"REGULAR"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_service_cidr_block"></a> [service\_cidr\_block](#input\_service\_cidr\_block) | IPv4 CIDR block assigned to Kubernetes Services (ClusterIP) in the GKE cluster (e.g. '10.64.128.0/20'). A /20 supports up to 4,096 service IPs. Must not overlap with the node or pod CIDR ranges. Defaults to '10.64.128.0/20'. | `string` | `"10.64.128.0/20"` | no |
| <a name="input_service_ip_range"></a> [service\_ip\_range](#input\_service\_ip\_range) | Alias name for the secondary IP range used to assign IP addresses to Kubernetes Services (ClusterIP) in the GKE cluster. This name is referenced when creating the subnet secondary range. Defaults to 'service-ip-range'. Must be unique within the subnet. | `string` | `"service-ip-range"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Name of the subnet within the VPC network. When create\_network is true, this is the name given to the newly created subnet. When create\_network is false, this identifies the existing subnet to use. Defaults to 'vpc-subnet'. | `string` | `"vpc-subnet"` | no |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | Set of Google account email addresses granted cluster-admin privileges on the GKE cluster (e.g. ['user@example.com']). Defaults to an empty set (no additional admin users). | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_credentials_cmd"></a> [cluster\_credentials\_cmd](#output\_cluster\_credentials\_cmd) | Kubernetes credentials |
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_external_ip"></a> [external\_ip](#output\_external\_ip) | External IP |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID |
<!-- END_TF_DOCS -->
