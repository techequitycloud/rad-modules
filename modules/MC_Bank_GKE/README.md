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
| terraform | >= 1.0 |
| google | >= 5.0 |
| google-beta | >= 5.0 |
| kubernetes | >= 2.0 |
| random | >= 3.0 |
| null | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |
| google-beta | >= 5.0 |
| kubernetes (×4 cluster-specific aliases) | >= 2.0 |
| random | >= 3.0 |
| null | >= 3.0 |

## Resources

| Name | Type |
|------|------|
| google\_container\_cluster.clusters (for\_each) | resource |
| google\_container\_node\_pool.clusters (for\_each, Standard only) | resource |
| google\_service\_account.cluster\_sa | resource |
| google\_project\_iam\_member (×9 roles) | resource |
| google\_compute\_network.vpc | resource |
| google\_compute\_subnetwork.subnets (for\_each) | resource |
| google\_compute\_firewall (×6 rules) | resource |
| google\_compute\_router (per region) | resource |
| google\_compute\_router\_nat (per region) | resource |
| google\_compute\_global\_address.bank\_of\_anthos | resource |
| google\_gke\_hub\_membership.clusters (for\_each) | resource |
| google\_gke\_hub\_feature.servicemesh | resource |
| google\_gke\_hub\_feature.multiclusterservicediscovery | resource |
| google\_gke\_hub\_feature.multiclusteringress | resource |
| google\_gke\_hub\_feature\_membership.clusters (for\_each) | resource |
| null\_resource.deploy\_bank\_of\_anthos | resource |
| null\_resource.cleanup\_mci\_mcs | resource |
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
