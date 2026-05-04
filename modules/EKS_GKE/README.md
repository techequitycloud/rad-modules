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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=4.5.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=5.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.43.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 7.30.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_attached_install_manifest"></a> [attached\_install\_manifest](#module\_attached\_install\_manifest) | ./modules/attached-install-manifest | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_role.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonEKSClusterPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [google_container_attached_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_attached_cluster) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_eks_cluster_auth.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy.AmazonEC2ContainerRegistryReadOnly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.AmazonEKSClusterPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.AmazonEKSWorkerNodePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.AmazonEKS_CNI_Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [google_client_openid_userinfo.me](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_openid_userinfo) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_access_key"></a> [aws\_access\_key](#input\_aws\_access\_key) | AWS Access Key ID for the IAM user or role used to provision EKS resources (format: 20-character alphanumeric string beginning with 'AKIA' or 'ASIA', e.g. 'AKIAIOSFODNN7EXAMPLE'). Required; no default. Obtain from AWS IAM Console > Security credentials. Stored as sensitive and never shown in logs. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where the EKS cluster, VPC, and supporting resources will be created (e.g. 'us-west-2', 'us-east-1', 'eu-west-1'). Defaults to 'us-west-2'. The subnet\_availability\_zones must be valid AZs within this region. | `string` | `"us-west-2"` | no |
| <a name="input_aws_secret_key"></a> [aws\_secret\_key](#input\_aws\_secret\_key) | AWS Secret Access Key corresponding to aws\_access\_key (40-character base64-encoded string). Required; no default. Obtain from AWS IAM Console > Security credentials at the time the access key is created (not retrievable afterwards). Stored as sensitive and never shown in logs. | `string` | n/a | yes |
| <a name="input_cluster_name_prefix"></a> [cluster\_name\_prefix](#input\_cluster\_name\_prefix) | Prefix prepended to all generated cluster and resource names (e.g. 'aws-eks-cluster' produces names like 'aws-eks-cluster-<deployment\_id>'). Use lowercase letters, digits, and hyphens only. Defaults to 'aws-eks-cluster'. | `string` | `"aws-eks-cluster"` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require\_credit\_purchases is true, users must have sufficient credit balance before deploying. Defaults to 100. | `number` | `100` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources. | `string` | `null` | no |
| <a name="input_enable_public_subnets"></a> [enable\_public\_subnets](#input\_enable\_public\_subnets) | Set to true (default) to place EKS worker nodes in public subnets with direct internet access. Set to false to place nodes in private subnets with internet access via NAT Gateway (recommended for production workloads for improved security). | `bool` | `true` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | GCP project ID of the destination project where the EKS cluster will be registered via GKE Hub (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource\_creator\_identity service account must hold roles/owner in it. Required; no default. | `string` | n/a | yes |
| <a name="input_gcp_location"></a> [gcp\_location](#input\_gcp\_location) | GCP region where the EKS cluster will be registered in GKE Hub and appear in the Google Cloud console (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Must be a region that supports GKE Hub Attached Clusters. | `string` | `"us-central1"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | Kubernetes version to deploy on the EKS cluster, specified as major.minor (e.g. '1.34'). Must be a version currently supported by EKS in the selected aws\_region. The patch version is managed automatically by EKS. Defaults to '1.34'. | `string` | `"1.34"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['AWS Account', 'GCP Project']. | `list(string)` | <pre>[<br>  "AWS Account",<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. | `string` | `"This module enables you to create and manage an Amazon Elastic Kubernetes Service (EKS) cluster from your Google Cloud console, providing a unified way for organizations using both AWS and Google Cloud to manage their applications. This module is for demonstration purposes only."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. | `list(string)` | <pre>[<br>  "AWS",<br>  "EKS",<br>  "IAM",<br>  "VPC",<br>  "GCP",<br>  "GKE Hub",<br>  "Anthos"<br>]</pre> | no |
| <a name="input_node_group_desired_size"></a> [node\_group\_desired\_size](#input\_node\_group\_desired\_size) | Desired number of worker nodes in the EKS managed node group at deployment time. Must be between node\_group\_min\_size and node\_group\_max\_size. Defaults to 2. The cluster autoscaler may adjust this value over time. | `number` | `2` | no |
| <a name="input_node_group_max_size"></a> [node\_group\_max\_size](#input\_node\_group\_max\_size) | Maximum number of worker nodes the EKS managed node group can scale up to. Must be >= node\_group\_desired\_size. Defaults to 5. Higher values allow greater burst capacity but increase potential AWS compute costs. | `number` | `5` | no |
| <a name="input_node_group_min_size"></a> [node\_group\_min\_size](#input\_node\_group\_min\_size) | Minimum number of worker nodes the EKS managed node group will maintain. Must be <= node\_group\_desired\_size. Defaults to 2. A minimum of 2 is recommended for high availability. | `number` | `2` | no |
| <a name="input_platform_version"></a> [platform\_version](#input\_platform\_version) | GKE Hub Attached Clusters platform version for the managed components installed onto the EKS cluster (format: major.minor.patch-gke.N, e.g. '1.34.0-gke.1'). Must be compatible with the selected k8s\_version. Defaults to '1.34.0-gke.1'. | `string` | `"1.34.0-gke.1"` | no |
| <a name="input_private_subnet_cidr_blocks"></a> [private\_subnet\_cidr\_blocks](#input\_private\_subnet\_cidr\_blocks) | List of IPv4 CIDR blocks for the private subnets, one per availability zone in subnet\_availability\_zones (e.g. ['10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24']). Must be subsets of vpc\_cidr\_block. Used when enable\_public\_subnets is false. Defaults to three /24 subnets. | `list(string)` | <pre>[<br>  "10.0.1.0/24",<br>  "10.0.2.0/24",<br>  "10.0.3.0/24"<br>]</pre> | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. | `bool` | `true` | no |
| <a name="input_public_subnet_cidr_blocks"></a> [public\_subnet\_cidr\_blocks](#input\_public\_subnet\_cidr\_blocks) | List of IPv4 CIDR blocks for the public subnets, one per availability zone in subnet\_availability\_zones (e.g. ['10.0.101.0/24', '10.0.102.0/24', '10.0.103.0/24']). Must be subsets of vpc\_cidr\_block. Only used when enable\_public\_subnets is true. Defaults to three /24 subnets. | `list(string)` | <pre>[<br>  "10.0.101.0/24",<br>  "10.0.102.0/24",<br>  "10.0.103.0/24"<br>]</pre> | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_subnet_availability_zones"></a> [subnet\_availability\_zones](#input\_subnet\_availability\_zones) | List of AWS availability zones in which to create subnets (e.g. ['us-west-2a', 'us-west-2b', 'us-west-2c']). Must be valid AZs within the selected aws\_region. The number of entries must match the number of entries in public\_subnet\_cidr\_blocks and private\_subnet\_cidr\_blocks. Defaults to three AZs in us-west-2. | `list(string)` | <pre>[<br>  "us-west-2a",<br>  "us-west-2b",<br>  "us-west-2c"<br>]</pre> | no |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | List of Google account email addresses granted cluster-admin privileges on the EKS cluster (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). Entries must be valid, non-blank email addresses with no duplicates. | `list(string)` | `[]` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | IPv4 CIDR block for the AWS VPC created for the EKS cluster (e.g. '10.0.0.0/16'). Must not overlap with other VPCs in the same AWS account if VPC peering is planned. Defaults to '10.0.0.0/16'. Only used when deploying the cluster. | `string` | `"10.0.0.0/16"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
