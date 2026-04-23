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

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 5.0 |
| random | >= 3.0 |
| null | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |
| random | >= 3.0 |
| null | >= 3.0 |

## Resources

| Name | Type |
|------|------|
| google\_container\_cluster.primary | resource |
| google\_container\_node\_pool.primary | resource |
| google\_service\_account.cluster\_sa | resource |
| google\_project\_iam\_member (×10 roles) | resource |
| google\_compute\_network.vpc | resource |
| google\_compute\_subnetwork.subnet | resource |
| google\_compute\_firewall (×6 rules) | resource |
| google\_compute\_router.router | resource |
| google\_compute\_router\_nat.nat | resource |
| google\_project\_service.enabled\_services | resource |
| null\_resource.install\_istio\_sidecar | resource |
| null\_resource.install\_istio\_ambient | resource |
| null\_resource.install\_observability\_addons | resource |
| random\_id.default | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| existing\_project\_id | GCP project ID where the GKE cluster and Istio mesh will be deployed. | `string` | n/a | yes |
| enable\_services | Set to `true` to automatically enable the required GCP APIs (`cloudapis.googleapis.com`, `container.googleapis.com`). | `bool` | `true` | no |
| gcp\_region | GCP region for the GKE cluster, VPC, and all supporting resources (e.g. `"us-central1"`). | `string` | `"us-central1"` | no |
| create\_network | Set to `true` to create a new VPC network and subnet. Set to `false` to use an existing network identified by `network_name`. | `bool` | `true` | no |
| network\_name | Name of the VPC network to create or use. | `string` | `"vpc-network"` | no |
| subnet\_name | Name of the subnet to create or use within the VPC. | `string` | `"vpc-subnet"` | no |
| ip\_cidr\_ranges | IPv4 CIDR blocks for the subnet primary and secondary ranges. First CIDR is the primary node range; additional CIDRs are secondary ranges for pods and services. | `set(string)` | `["10.132.0.0/16", "192.168.1.0/24"]` | no |
| create\_cluster | Set to `true` to create a new GKE Standard cluster. Set to `false` to install Istio onto an existing cluster identified by `gke_cluster`. | `bool` | `true` | no |
| gke\_cluster | Name of the GKE cluster to create or use. | `string` | `"gke-cluster"` | no |
| release\_channel | GKE release channel: `RAPID`, `REGULAR` (default), `STABLE`, or `NONE`. | `string` | `"REGULAR"` | no |
| pod\_ip\_range | Name of the subnet secondary IP range for Pod addresses. | `string` | `"pod-ip-range"` | no |
| pod\_cidr\_block | IPv4 CIDR block for cluster Pods. Must not overlap with node or service ranges. | `string` | `"10.62.128.0/17"` | no |
| service\_ip\_range | Name of the subnet secondary IP range for Service addresses. | `string` | `"service-ip-range"` | no |
| service\_cidr\_block | IPv4 CIDR block for cluster Services (ClusterIP). Must not overlap with node or pod ranges. | `string` | `"10.64.128.0/20"` | no |
| istio\_version | Open-source Istio version to install (format: `major.minor.patch`, e.g. `"1.24.2"`). | `string` | `"1.24.2"` | no |
| install\_ambient\_mesh | Set to `true` to install Istio in ambient mode (shared per-node ztunnel proxy + optional waypoint proxies). Set to `false` for sidecar mode (Envoy proxy injected into each pod). | `bool` | `false` | no |
| deploy\_application | Set to `true` to deploy the Istio Bookinfo sample application, providing live traffic for exploring mesh traffic management, telemetry, and security features. | `bool` | `true` | no |
| trusted\_users | Google account emails granted cluster-admin privileges on the GKE cluster. | `set(string)` | `[]` | no |
| deployment\_id | Alphanumeric suffix appended to resource names for uniqueness. Leave `null` to auto-generate. | `string` | `null` | no |
| resource\_creator\_identity | Email of the Terraform service account used to provision resources. | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| deployment\_id | The deployment ID suffix used in resource names |
| project\_id | The GCP project ID where resources were deployed |
| external\_ip | External IP address of the Istio Ingress Gateway (read from `scripts/app/external_ip.txt` after deployment) |
| cluster\_credentials\_cmd | `gcloud container clusters get-credentials` command to configure `kubectl` for this cluster |
