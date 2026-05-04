# AKS\_GKE Module

This module creates a Microsoft Azure Kubernetes Service (AKS) cluster and registers it with Google Cloud as a **GKE Attached Cluster**. The cluster becomes a member of a GKE Fleet and appears in the Google Cloud Console alongside native GKE clusters, with centralized logging, metrics, and access control managed through Google Cloud.

For a detailed technical walkthrough covering OIDC federation, fleet management, observability, and service mesh, see [AKS\_GKE.md](AKS_GKE.md).

## Usage

```hcl
module "aks_gke" {
  source = "./modules/AKS_GKE"

  existing_project_id = "my-gcp-project"
  azure_region        = "westus2"
  gcp_location        = "us-central1"
  k8s_version         = "1.34"
  platform_version    = "1.34.0-gke.1"

  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id

  trusted_users = ["engineer@example.com"]
}
```

<!-- BEGIN_TF_DOCS -->
Copyright 2022 Google LLC

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
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >=3.17.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=5.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.71.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 7.30.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_attached_install_manifest"></a> [attached\_install\_manifest](#module\_attached\_install\_manifest) | ./modules/attached-install-manifest | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_kubernetes_cluster.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_resource_group.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.aks_network_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [google_container_attached_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_attached_cluster) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/3.6.2/docs/resources/id) | resource |
| [google_client_openid_userinfo.me](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_openid_userinfo) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_region"></a> [azure\_region](#input\_azure\_region) | Azure region where the AKS cluster and its supporting resources (Resource Group, Virtual Network) will be created (e.g. 'westus2', 'eastus', 'westeurope'). Defaults to 'westus2'. Availability of AKS features and VM SKUs varies by region. | `string` | `"westus2"` | no |
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | Azure Active Directory Application (Client) ID for the service principal used to create and manage AKS resources (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Required; no default. Obtain from Azure Portal > Azure Active Directory > App Registrations. Stored as sensitive and never shown in logs. | `string` | n/a | yes |
| <a name="input_client_secret"></a> [client\_secret](#input\_client\_secret) | Client secret for the Azure AD service principal identified by client\_id. Required; no default. Obtain from Azure Portal > Azure Active Directory > App Registrations > Certificates & Secrets. Stored as sensitive and never shown in logs. | `string` | n/a | yes |
| <a name="input_cluster_name_prefix"></a> [cluster\_name\_prefix](#input\_cluster\_name\_prefix) | Prefix prepended to all generated cluster and resource names (e.g. 'azure-aks-cluster' produces names like 'azure-aks-cluster-<deployment\_id>'). Use lowercase letters, digits, and hyphens only. Defaults to 'azure-aks-cluster'. | `string` | `"azure-aks-cluster"` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require\_credit\_purchases is true, users must have sufficient credit balance before deploying. Defaults to 100. | `number` | `100` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources. | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | GCP project ID of the destination project where the AKS cluster will be registered via GKE Hub (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource\_creator\_identity service account must hold roles/owner in it. Required; no default. | `string` | n/a | yes |
| <a name="input_gcp_location"></a> [gcp\_location](#input\_gcp\_location) | GCP region where the AKS cluster will be registered in GKE Hub and appear in the Google Cloud console (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Must be a region that supports GKE Hub Attached Clusters. | `string` | `"us-central1"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | Kubernetes version to deploy on the AKS cluster, specified as major.minor (e.g. '1.34'). Must be a version currently supported by AKS in the selected azure\_region. The patch version is managed automatically by AKS. Defaults to '1.34'. | `string` | `"1.34"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['Azure Account', 'GCP Project']. | `list(string)` | <pre>[<br>  "Azure Account",<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. | `string` | `"This module enables you to create and manage a Microsoft Azure Kubernetes Service (AKS) cluster from your Google Cloud console, providing a unified way for organizations using both Azure and Google Cloud to manage their applications. This module is for demonstration purposes only."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. | `list(string)` | <pre>[<br>  "Azure",<br>  "AKS",<br>  "Resource Group",<br>  "GCP",<br>  "GKE Hub",<br>  "Anthos"<br>]</pre> | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of nodes in the AKS default node pool. A minimum of 2 is recommended for high availability. Defaults to 3. Higher node counts increase Azure compute costs proportionally. | `number` | `3` | no |
| <a name="input_platform_version"></a> [platform\_version](#input\_platform\_version) | GKE Hub Attached Clusters platform version for the managed components installed onto the AKS cluster (format: major.minor.patch-gke.N, e.g. '1.34.0-gke.1'). Must be compatible with the selected k8s\_version. Defaults to '1.34.0-gke.1'. | `string` | `"1.34.0-gke.1"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. | `bool` | `true` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Azure Subscription ID where AKS resources will be provisioned (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Required; no default. Find this in Azure Portal > Subscriptions. Stored as sensitive and never shown in logs. | `string` | n/a | yes |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Azure Active Directory Tenant ID for the Azure account (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Required; no default. Find this in Azure Portal > Azure Active Directory > Overview > Tenant ID. Stored as sensitive and never shown in logs. | `string` | n/a | yes |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | List of Google account email addresses granted cluster-admin privileges on the AKS cluster (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). Entries must be valid, non-blank email addresses with no duplicates. | `list(string)` | `[]` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Azure VM SKU used for AKS node pool worker nodes (e.g. 'Standard\_D2s\_v3' = 2 vCPUs, 8 GB RAM; 'Standard\_D4s\_v3' = 4 vCPUs, 16 GB RAM). Defaults to 'Standard\_D2s\_v3'. Larger SKUs increase Azure compute costs; availability varies by azure\_region. | `string` | `"Standard_D2s_v3"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
