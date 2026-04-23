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
| terraform | >= 1.0 |
| google | >= 5.0 |
| google-beta | >= 5.0 |
| random | >= 3.0 |
| null | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |
| google-beta | >= 5.0 |
| random | >= 3.0 |
| null | >= 3.0 |

## Resources

| Name | Type |
|------|------|
| google\_container\_cluster.primary | resource |
| google\_container\_node\_pool.primary | resource |
| google\_service\_account.cluster\_sa | resource |
| google\_project\_iam\_member (×9 roles) | resource |
| google\_compute\_network.vpc | resource |
| google\_compute\_subnetwork.subnet | resource |
| google\_compute\_firewall (×6 rules) | resource |
| google\_compute\_router.router | resource |
| google\_compute\_router\_nat.nat | resource |
| google\_compute\_global\_address.bank\_of\_anthos | resource |
| google\_gke\_hub\_membership.cluster | resource |
| google\_gke\_hub\_feature.servicemesh | resource |
| google\_gke\_hub\_feature\_membership.cluster | resource |
| google\_monitoring\_service (×9 services) | resource |
| google\_monitoring\_slo (×9 SLOs) | resource |
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
