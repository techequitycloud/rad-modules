# Azure AKS

This script is meant to be a quick start to working with Anthos on Azure. For more information on Anthos Multi-Cloud please [click here](https://cloud.google.com/anthos/clusters/docs/multi-cloud/). This terraform script will install all relevant IaaS in Azure _(VNet, App Registration, Resource Groups, KMS)_.
The Anthos on **Azure Cluster full Terraform** references area here:
 - [Clusters ](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_azure_cluster)
 - [Node Pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_azure_node_pool)
 - [Azure Client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_azure_client)

![Anthos Multi-Cloud](Anthos-Multi-Azure.png)

 **The Terraform script deploys Anthos GKE with:**
- 3 control plane nodes _(1 in each AZ)_ of type [Standard_B2s](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-b-series-burstable)
- A single node pool of type Standard_B2s with 1 node in an autoscaling group to max 3 nodes to the `Azure East US` region.

**Other information:**
- Supported instance types in Azure can be found [here](https://cloud.google.com/anthos/clusters/docs/multi-cloud/azure/reference/supported-vms).
- You can adjust the region and AZs in the [variables.tf](/anthos-multi-cloud/Azure/variables.tf) file.
- For a list of Azure regions and associated K8s version supported per GCP region please use the following command:
```bash
gcloud alpha container azure get-server-config --location [gcp-region]
```
After the cluster has been installed it will show up in the [Kubernetes Engine page](https://console.cloud.google.com/kubernetes/list/overview) of the GCP console in your relevant GCP project.

## Prerequisites

1. Ensure you have gCloud SDK 365.0.1 or greater [installed](https://cloud.google.com/sdk/docs/install)
   ```
   gcloud components update
   ```

2. Download the `az` CLI utility. Ensure it is in your `$PATH`.

   ```bash
   sudo apt autoremove -y
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```
                 
3. Set the following variables for Azure Terraform authentication. The example uses [Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) way of authenticating Terraform.

   ```bash
   export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
   export ARM_CLIENT_SECRET="12345678-0000-0000-0000-000000000000"
   export ARM_TENANT_ID="10000000-0000-0000-0000-000000000000"
   export ARM_SUBSCRIPTION_ID="20000000-0000-0000-0000-000000000000"
   ```

## Prepare Terraform

4. Configure GCP Terraform authentication.

   ```bash
   echo PROJECT_ID=Your GCP Project ID

   gcloud config set project "${PROJECT_ID}"
   gcloud auth application-default login --no-launch-browser
   ```

5. Enable services in your GCP project.

   ```bash
   gcloud --project="${PROJECT_ID}" services enable gkemulticloud.googleapis.com 
   ```

## Deploy Anthos Clusters(GKE) on Azure cluster

6. Edit the following values in the **terraform.tfvars** file. The admin user will be the GCP account email address that can login to the clusters once they are created via the connect gateway.

   Select a **supported GKE version** for your chosen region. To find the supported versions, see [GKE on AWS versioning and support](https://cloud.devsite.corp.google.com/kubernetes-engine/multi-cloud/docs/aws/reference/versioning#version_lifespans).

  ```bash
   gcp_project_id = "xxx-xxx-xxx"
   admin_user = "example@example.com"

   cluster_version = "supported_gke_version"
   # supported versions at https://cloud.devsite.corp.google.com/kubernetes-engine/multi-cloud/docs/aws/reference/versioning#version_lifespans
   ```

7. Initialize and create terraform plan.

   ```bash
   terraform init
   ```

8. Apply terraform.

   ```bash
   terraform apply
   ```
    Once started the installation process will take about 12 minutes. **After the script completes you will see a var.sh file in the root directory that has varialbles for the anthos install** if you need to create more node pools manually in the future. Note manually created node pools will need to be deleted manually before you run terraform destroy

10. Login to the Cluster

   ```bash
   gcloud container azure clusters get-credentials [cluster name]
   kubectl get nodes
   ```
## Extra: Connect Anthos Configuration Management

If you would like to test out the Anthos Configuration and Policy Management feature you can visit this [quickstart](https://cloud.google.com/anthos-config-management/docs/archive/1.9/config-sync-quickstart).

## Delete Anthos on Azure Cluster

11. Run the following command to delete Anthos on Azure cluster.

   ```bash
   terraform destroy
   ```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin\_users | User to get default Admin RBAC | `list(string)` | n/a | yes |
| azure\_region | Azure region to deploy to | `string` | n/a | yes |
| cluster\_version | GKE version to install | `string` | n/a | yes |
| control\_plane\_instance\_type | Azure instance type for control plane | `string` | n/a | yes |
| gcp\_location | GCP region to deploy the multi-cloud API | `string` | n/a | yes |
| gcp\_project\_id | GCP project ID to register the Anthos Cluster to | `string` | n/a | yes |
| name\_prefix | prefix of all artifacts created and cluster name | `string` | n/a | yes |
| node\_pool\_instance\_type | Azure instance type for node pool | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_name | The automatically generated name of your Azure GKE cluster |
| cluster\_resource\_group | VNET Resource Group |
| message | Connect Instructions |
| vars\_file | The variables needed to create more node pools are in the vars.sh file.<br> If you create additional node pools they must be manually deleted before you run terraform destroy |
| vnet\_resource\_group | VNET Resource Group |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.54.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 7.12.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_kubernetes_cluster.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_resource_group.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.aks_least_privilege](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.aks_least_privilege](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [google_container_attached_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_attached_cluster) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_region"></a> [azure\_region](#input\_azure\_region) | Azure resource region. {{UIMeta group=2 order=303 updatesafe }} | `string` | `"westus2"` | no |
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | Azure Client ID (Application ID). This is used for the Azure provider to authenticate. | `string` | n/a | yes |
| <a name="input_client_secret"></a> [client\_secret](#input\_client\_secret) | Azure Client Secret. This is used for the Azure provider to authenticate. | `string` | n/a | yes |
| <a name="input_cluster_name_prefix"></a> [cluster\_name\_prefix](#input\_cluster\_name\_prefix) | Prefix to use for generating cluster resources. {{UIMeta group=0 order=301 updatesafe }} | `string` | `"azure-aks-cluster"` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Specify the module cost {{UIMeta group=0 order=103 }} | `number` | `100` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Unique ID suffix for resources.  Leave blank to generate random ID. | `string` | `null` | no |
| <a name="input_dns_prefix"></a> [dns\_prefix](#input\_dns\_prefix) | DNS prefix for the AKS cluster. | `string` | `"azure-aks-dns"` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }} | `string` | n/a | yes |
| <a name="input_gcp_location"></a> [gcp\_location](#input\_gcp\_location) | GCP region where Azure resources will be registered and managed. {{UIMeta group=2 order=302 updatesafe }} | `string` | `"us-central1"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | Kubernetes version of the AKS cluster. {{UIMeta group=0 order=304 updatesafe }} | `string` | `"1.31"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "Azure Account",<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | The description of the module. {{UIMeta group=0 order=100 }} | `string` | `"**Purpose:** This module enables you to create and manage a Microsoft Azure Kubernetes Service (AKS) cluster from your Google Cloud console. This is useful for organizations that use both Azure and Google Cloud and want a unified way to manage their applications. This is a demo module for training purposes.\n\n**What it does:**\n- Creates an AKS cluster on Azure.\n- Connects the AKS cluster to your Google Cloud project.\n- Enables you to manage Azure applications from the Google Cloud console.\n\n**Dependencies:** This module deploys into an existing Google Cloud project and requires an Azure account. You are advised to delete deployed resources within your Azure AKS cluster prior to deleting this module.\n"` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | Specify the module services. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "Azure",<br>  "AKS",<br>  "Resource Group",<br>  "GCP",<br>  "GKE Hub",<br>  "Anthos"<br>]</pre> | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | The number of nodes in the default node pool. {{UIMeta group=3 order=304 updatesafe }} | `number` | `3` | no |
| <a name="input_platform_version"></a> [platform\_version](#input\_platform\_version) | Platform version of the attached cluster resource. {{UIMeta group=0 order=304 updatesafe }} | `string` | `"1.31.0-gke.3"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=106 }} | `bool` | `false` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the Azure resource group. | `string` | `"azure-aks-rg"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Azure Subscription ID. {{UIMeta group=4 order=404 updatesafe }} | `string` | n/a | yes |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Azure Tenant ID. {{UIMeta group=4 order=403 updatesafe }} | `string` | n/a | yes |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | Email addresses of cluster admin users (e.g. `username@abc.com`). At least one trusted user must be specified. {{UIMeta group=1 order=404 updatesafe }} | `list(string)` | n/a | yes |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | The size of the virtual machine for the AKS cluster nodes. {{UIMeta group=3 order=305 updatesafe }} | `string` | `"Standard_D2s_v3"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->