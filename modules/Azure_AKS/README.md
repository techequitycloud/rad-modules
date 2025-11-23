# Azure AKS Terraform Module

This Terraform module creates an Azure Kubernetes Service (AKS) cluster and attaches it to a Google Cloud project.

## Prerequisites

- An active Azure subscription
- An active Google Cloud project
- Terraform v0.13+

## Usage

```hcl
module "azure_aks" {
  source = "./modules/Azure_AKS"

  # Azure Credentials
  tenant_id       = "your-azure-tenant-id"
  client_id       = "your-azure-client-id"
  client_secret   = "your-azure-client-secret"
  subscription_id = "your-azure-subscription-id"

  # Google Cloud Project
  existing_project_id = "your-gcp-project-id"

  # Cluster Configuration
  cluster_name_prefix = "my-aks-cluster"
  gcp_location        = "us-central1"
  azure_region        = "westus2"
  node_count          = 3
  k8s_version         = "1.23"
  platform_version    = "1.23.0-gke.1"
  vm_size             = "Standard_D2s_v3"

  # IAM
  trusted_users = ["user@example.com"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tenant\_id | Azure Tenant ID. | `string` | n/a | yes |
| client\_id | Azure Client ID (Application ID). | `string` | n/a | yes |
| client\_secret | Azure Client Secret. | `string` | n/a | yes |
| subscription\_id | Azure Subscription ID. | `string` | n/a | yes |
| existing\_project\_id | The project ID of the destination project. | `string` | n/a | yes |
| cluster\_name\_prefix | Prefix to use for generating cluster resources. | `string` | `"azure-aks-cluster"` | no |
| gcp\_location | GCP region where Azure resources will be registered and managed. | `string` | `"us-central1"` | no |
| azure\_region | Azure resource region. | `string` | `"westus2"` | no |
| node\_count | The number of nodes in the default node pool. | `number` | `3` | no |
| k8s\_version | Kubernetes version of the AKS cluster. | `string` | `"1.23"` | no |
| platform\_version | Platform version of the attached cluster resource. | `string` | `"1.23.0-gke.1"` | no |
| vm\_size | The size of the virtual machine for the AKS cluster nodes. | `string` | `"Standard_D2s_v3"` | no |
| trusted\_users | Email addresses of cluster admin users. | `list(string)` | n/a | yes |

## Outputs

This module does not produce any outputs.
