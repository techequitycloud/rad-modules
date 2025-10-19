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
