# EKS\_GKE Module

This module creates an Amazon Elastic Kubernetes Service (EKS) cluster and registers it with Google Cloud as a **GKE Attached Cluster**. The cluster becomes a member of a GKE Fleet and appears in the Google Cloud Console alongside native GKE clusters, with centralized logging, metrics, and access control managed through Google Cloud.

For a detailed technical walkthrough covering OIDC federation, fleet management, observability, and service mesh, see [EKS\_GKE.md](EKS_GKE.md).

## Usage

```hcl
module "eks_gke" {
  source = "./modules/EKS_GKE"

  existing_project_id = "my-gcp-project"
  aws_region          = "us-west-2"
  gcp_location        = "us-central1"
  k8s_version         = "1.34"
  platform_version    = "1.34.0-gke.1"

  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key

  subnet_availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]
  trusted_users              = ["engineer@example.com"]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | >= 5.0 |
| aws | >= 5.0 |
| helm | >= 2.0 |
| random | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |
| aws | >= 5.0 |
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
| aws\_vpc.eks | resource |
| aws\_subnet.public / aws\_subnet.private | resource |
| aws\_eks\_cluster.eks | resource |
| aws\_eks\_node\_group.eks | resource |
| aws\_iam\_role.eks\_cluster / aws\_iam\_role.eks\_node\_group | resource |
| google\_container\_attached\_cluster.primary | resource |
| google\_project\_service.enabled\_services | resource |
| random\_string.suffix | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| existing\_project\_id | GCP project ID where the EKS cluster will be registered. The `resource_creator_identity` service account must hold `roles/owner` in this project. | `string` | n/a | yes |
| aws\_access\_key | AWS Access Key ID for the IAM user or role used to provision EKS resources (20-character string, begins with `AKIA` or `ASIA`). | `string` | n/a | yes |
| aws\_secret\_key | AWS Secret Access Key corresponding to `aws_access_key` (40-character base64-encoded string, retrievable only at key creation time). | `string` | n/a | yes |
| cluster\_name\_prefix | Prefix for the EKS cluster name and all AWS resources. Use lowercase letters, digits, and hyphens. | `string` | `"aws-eks-cluster"` | no |
| gcp\_location | GCP region where the attached cluster record and fleet membership are stored (e.g. `"us-central1"`). | `string` | `"us-central1"` | no |
| aws\_region | AWS region where the EKS cluster, VPC, and subnets are created (e.g. `"us-west-2"`). | `string` | `"us-west-2"` | no |
| k8s\_version | Kubernetes minor version for the EKS cluster (e.g. `"1.34"`). The patch version is managed automatically by EKS. | `string` | `"1.34"` | no |
| platform\_version | GKE Hub Attached Clusters platform version (format: `major.minor.patch-gke.N`). Must be compatible with `k8s_version`. | `string` | `"1.34.0-gke.1"` | no |
| vpc\_cidr\_block | IPv4 CIDR block for the AWS VPC (e.g. `"10.0.0.0/16"`). | `string` | `"10.0.0.0/16"` | no |
| subnet\_availability\_zones | AWS availability zones for subnet creation. Count must match `public_subnet_cidr_blocks` and `private_subnet_cidr_blocks`. | `list(string)` | `["us-west-2a", "us-west-2b", "us-west-2c"]` | no |
| public\_subnet\_cidr\_blocks | IPv4 CIDR blocks for public subnets, one per AZ. Used when `enable_public_subnets` is true. | `list(string)` | `["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]` | no |
| private\_subnet\_cidr\_blocks | IPv4 CIDR blocks for private subnets, one per AZ. Used when `enable_public_subnets` is false. | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` | no |
| enable\_public\_subnets | Set to `true` to place EKS nodes in public subnets. Set to `false` for private subnets with NAT Gateway (recommended for production). | `bool` | `true` | no |
| node\_group\_desired\_size | Desired number of EKS worker nodes at deployment. | `number` | `2` | no |
| node\_group\_min\_size | Minimum number of EKS worker nodes. Must be ≤ `node_group_desired_size`. | `number` | `2` | no |
| node\_group\_max\_size | Maximum number of EKS worker nodes. Must be ≥ `node_group_desired_size`. | `number` | `5` | no |
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
