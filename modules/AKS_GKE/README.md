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

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 5.0 |
| azurerm | >= 3.0 |
| helm | >= 2.0 |
| random | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |
| azurerm | >= 3.0 |
| helm | >= 2.0 |
| random | >= 3.0 |

## Modules

| Name | Source | Description |
|------|--------|-------------|
| attached\_install\_manifest | ./modules/attached-install-manifest | Installs the GKE Connect agent bootstrap manifests via Helm |

> **Note:** The `attached-install-mesh` submodule (for Anthos Service Mesh installation) is available in `modules/attached-install-mesh` but is not invoked automatically by this module. It must be called separately if service mesh installation is required.

## Resources

| Name | Type |
|------|------|
| azurerm\_resource\_group.aks | resource |
| azurerm\_kubernetes\_cluster.aks | resource |
| azurerm\_role\_assignment.aks\_network\_contributor | resource |
| google\_container\_attached\_cluster.primary | resource |
| google\_project\_service.enabled\_services | resource |
| random\_id.default | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| existing\_project\_id | GCP project ID where the AKS cluster will be registered. The `resource_creator_identity` service account must hold `roles/owner` in this project. | `string` | n/a | yes |
| client\_id | Azure AD Application (Client) ID for the service principal (UUID format). Obtain from Azure Portal > Azure Active Directory > App Registrations. | `string` | n/a | yes |
| client\_secret | Client secret for the Azure AD service principal. Obtain from Azure Portal > App Registrations > Certificates & Secrets. | `string` | n/a | yes |
| tenant\_id | Azure AD Tenant ID (UUID format). Find in Azure Portal > Azure Active Directory > Overview. | `string` | n/a | yes |
| subscription\_id | Azure Subscription ID where AKS resources will be provisioned (UUID format). Find in Azure Portal > Subscriptions. | `string` | n/a | yes |
| cluster\_name\_prefix | Prefix for the AKS cluster name and all Azure resources. Use lowercase letters, digits, and hyphens. | `string` | `"azure-aks-cluster"` | no |
| gcp\_location | GCP region where the attached cluster record and fleet membership are stored (e.g. `"us-central1"`). | `string` | `"us-central1"` | no |
| azure\_region | Azure region where the AKS cluster and Resource Group are created (e.g. `"westus2"`). | `string` | `"westus2"` | no |
| k8s\_version | Kubernetes minor version for the AKS cluster (e.g. `"1.34"`). The patch version is managed automatically by AKS. | `string` | `"1.34"` | no |
| platform\_version | GKE Hub Attached Clusters platform version (format: `major.minor.patch-gke.N`). Must be compatible with `k8s_version`. | `string` | `"1.34.0-gke.1"` | no |
| node\_count | Number of nodes in the AKS default node pool. | `number` | `3` | no |
| vm\_size | Azure VM SKU for AKS worker nodes (e.g. `"Standard_D2s_v3"` = 2 vCPU, 8 GB RAM). | `string` | `"Standard_D2s_v3"` | no |
| trusted\_users | Google account emails granted cluster-admin privileges via Connect Gateway. The deploying user is always included automatically. | `list(string)` | `[]` | no |
| deployment\_id | Alphanumeric suffix appended to resource names for uniqueness. Leave `null` to auto-generate a random suffix. | `string` | `null` | no |
| resource\_creator\_identity | Email of the Terraform service account used to provision GCP resources. | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |

## Outputs

No outputs. After deployment, connect to the cluster using:

```bash
gcloud container attached clusters get-credentials CLUSTER_NAME \
  --location=us-central1 \
  --project=my-gcp-project
```
