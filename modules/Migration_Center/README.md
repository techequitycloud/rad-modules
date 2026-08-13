# Migration Center Assessment Lab

## Overview

This module deploys a fully configured **Google Cloud Migration Center**
assessment environment. Migration Center is Google Cloud's free tool for
discovering, analyzing, and planning migrations from on-premises or other
cloud environments.

**Industry use cases:** Data center exit planning, cloud-to-cloud migration
assessment, infrastructure rightsizing analysis, TCO comparison for
FinOps teams.

The module provisions the complete lab environment and automates all
infrastructure and Migration Center configuration steps. Users connect
via RDP, complete the MCDCv6 Google OAuth login, run a discovery scan,
and then generate a TCO report from the console against fully populated
asset data.

## What Gets Deployed

| Resource | Description |
|---|---|
| Windows Server 2022 VM | MCDCv6 pre-installed; RDP-ready with lab credentials |
| 3× Debian 12 Linux VMs | Discovery scan targets with `migrationcenter` SSH user |
| VPC + Firewall Rules | Auto-mode VPC with SSH, RDP, ICMP, and internal rules |
| Cloud Storage Bucket | Holds the generated SSH private key (lab-ssh-key.pem) |
| Migration Center Source | Discovery client registration |
| AWS EC2 Import (optional) | Only when `aws_access_key_id` is supplied: live EC2 inventory queried under an auto-created scoped IAM user and imported as 4 CSVs (vmInfo, diskInfo, tagInfo, perfInfo). Otherwise a sample AWS CSV zip is pre-staged on the Windows VM for manual import. |
| Asset Groups & Migration Preferences | Not pre-created — built as hands-on lab exercises in the Migration Center console after discovery data arrives |

## Deployment Options

### RAD UI

Select **Migration Center** from the module catalog and click **Deploy**.
All defaults are production-ready for the lab.

### Advanced — Launcher CLI (automation/maintainers)

```bash
cd modules/Migration_Center
cat > terraform.tfvars <<EOF
project_id = "your-project-id"
region     = "us-central1"
zone       = "us-central1-a"
EOF
tofu init && tofu apply
```

## Advanced — Terraform module (maintainers)

> **Platform users don't need this** — deploy from the [RAD Modules UI](https://radmodules.dev) above. The Terraform module call below is for maintainers/automation integrating the module directly.

```hcl
module "migration_center" {
  source = "github.com/techequitycloud/rad-modules//modules/Migration_Center"

  project_id = "my-gcp-project"
  region     = "us-central1"
  zone       = "us-central1-a"

  # Optional overrides
  linux_vm_count           = 3
  mc_discovery_client_name = "mc-discovery-client"
}
```

## Key Outputs

| Output | Description |
|---|---|
| `windows_vm_external_ip` | RDP target IP — Username: `migrationcenter` / Password: `m1grat10nc#nt#r` |
| `linux_vm_internal_ips` | Internal IPs for configuring the MCDCv6 IP scan range |
| `ssh_key_bucket_name` | GCS bucket holding `lab-ssh-key.pem` for MCDCv6 SSH credential |
| `ssh_key_user` | SSH username (`migrationcenter`) for the Lab-key credential |
| `mc_discovery_client_name` | Name to enter in MCDCv6 during the login flow |
| `migration_center_url` | Direct link to the Migration Center console |

## Lab Guide

Full step-by-step instructions: [Migration Center Lab Guide](../../docs/labs/Migration_Center.md)

The only manual steps are:
1. RDP into the Windows VM (credentials in outputs)
2. Complete the Google OAuth login in MCDCv6 (browser-based)
3. Add OS credentials and SSH key in MCDCv6 UI
4. Run the IP scan
5. Create asset groups and migration preference sets in the Migration Center console, then generate a TCO report from them

<!-- BEGIN_TF_DOCS -->
Copyright 2024 Google LLC

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 6.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0, < 6.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 5.45.2 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.mc_discovery_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_policy.mc_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_user.mc_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.mc_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [google_compute_firewall.default_allow_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_icmp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_rdp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.linux_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.windows_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.lab_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_storage_bucket.ssh_key_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.ssh_private_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [null_resource.mc_aws_import](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.mc_init](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.mc_source](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [google_compute_network.lab_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_access_key_id"></a> [aws\_access\_key\_id](#input\_aws\_access\_key\_id) | Bootstrap AWS Access Key ID with IAM write permissions (iam:CreateUser, iam:CreatePolicy, iam:AttachUserPolicy, iam:CreateAccessKey and their Delete/Detach counterparts). The module uses these credentials to automatically provision a scoped EC2-read-only IAM user; EC2 discovery runs under the generated key, not these bootstrap credentials. Leave empty to skip AWS integration entirely. {{UIMeta group=8 order=803 updatesafe }} | `string` | `""` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region to discover EC2 instances from (e.g. 'us-east-1'). {{UIMeta group=8 order=805 updatesafe }} | `string` | `"us-east-1"` | no |
| <a name="input_aws_secret_access_key"></a> [aws\_secret\_access\_key](#input\_aws\_secret\_access\_key) | Bootstrap AWS Secret Access Key corresponding to the Access Key ID above. {{UIMeta group=8 order=804 updatesafe }} | `string` | `""` | no |
| <a name="input_create_default_firewall_rules"></a> [create\_default\_firewall\_rules](#input\_create\_default\_firewall\_rules) | Set to true (default) to create the four Google-default firewall rules (allow-internal, allow-ssh, allow-rdp, allow-icmp) on the VPC. Set to false if these rules already exist on the target network. {{UIMeta group=2 order=202 }} | `bool` | `true` | no |
| <a name="input_create_ssh_key_bucket"></a> [create\_ssh\_key\_bucket](#input\_create\_ssh\_key\_bucket) | Set to true (default) to create a Cloud Storage bucket and store the generated SSH private key. The bucket name is surfaced in Terraform outputs for easy retrieval. {{UIMeta group=7 order=701 }} | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Set to true (default) to create a dedicated VPC network for this lab. Set to false to use an existing VPC. {{UIMeta group=2 order=201 }} | `bool` | `true` | no |
| <a name="input_create_windows_vm"></a> [create\_windows\_vm](#input\_create\_windows\_vm) | Set to true (default) to deploy the Windows Server 2022 VM that hosts the MC Discovery Client. The startup script automatically installs MCDCv6. {{UIMeta group=3 order=301 }} | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }} | `number` | `0` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to use no suffix. {{UIMeta group=0 order=108 }} | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_initialize_migration_center"></a> [initialize\_migration\_center](#input\_initialize\_migration\_center) | Set to true (default) to automatically initialize the Migration Center service and register the MCDCv6 discovery source. AWS EC2 inventory is also imported when aws\_access\_key\_id is provided. Asset groups, preferences, and reports are created as lab exercises. {{UIMeta group=8 order=801 }} | `bool` | `true` | no |
| <a name="input_internal_traffic_cidr"></a> [internal\_traffic\_cidr](#input\_internal\_traffic\_cidr) | CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. {{UIMeta group=2 order=203 }} | `string` | `"10.128.0.0/9"` | no |
| <a name="input_linux_vm_boot_disk_size_gb"></a> [linux\_vm\_boot\_disk\_size\_gb](#input\_linux\_vm\_boot\_disk\_size\_gb) | Boot disk size in GB for each Linux target VM. {{UIMeta group=3 order=306 }} | `number` | `20` | no |
| <a name="input_linux_vm_count"></a> [linux\_vm\_count](#input\_linux\_vm\_count) | Number of Debian Linux VMs to deploy as discovery scan targets. The MCDCv6 scanner will discover and inventory these VMs. {{UIMeta group=3 order=304 }} | `number` | `3` | no |
| <a name="input_linux_vm_machine_type"></a> [linux\_vm\_machine\_type](#input\_linux\_vm\_machine\_type) | Machine type for each Linux discovery target VM. e2-medium is sufficient for lab purposes. {{UIMeta group=3 order=305 }} | `string` | `"e2-medium"` | no |
| <a name="input_mc_discovery_client_name"></a> [mc\_discovery\_client\_name](#input\_mc\_discovery\_client\_name) | Name to register for the MC Discovery Client data source. This name appears in the Migration Center console and must match what you enter in the MCDCv6 UI during login. {{UIMeta group=8 order=802 }} | `string` | `"mc-discovery-client"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }} | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. {{UIMeta group=0 order=100 }} | `string` | `"This module deploys a Google Cloud Migration Center assessment environment. It provisions a Windows Server 2022 VM with the MC Discovery Client (MCDCv6) pre-installed, Debian Linux target VMs for live network scanning, and automatically initialises the Migration Center service and registers the discovery source. AWS EC2 inventory can be imported automatically when credentials are provided. Asset groups, migration preferences, and TCO reports are created as hands-on lab exercises using the Migration Center console."` | no |
| <a name="input_module_documentation"></a> [module\_documentation](#input\_module\_documentation) | URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }} | `string` | `"https://github.com/techequitycloud/rad-modules/blob/main/docs/labs/Migration_Center.md"` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP",<br>  "Migration Center",<br>  "Compute Engine",<br>  "Cloud Storage",<br>  "Cloud IAM",<br>  "VPC Network"<br>]</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID where Migration Center resources will be deployed. Must already exist and the service account must hold roles/owner. {{UIMeta group=1 order=101 updatesafe }} | `string` | `null` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to false to restrict this module to platform administrators only. Set to true (the default) to make it visible and deployable by all platform users. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region where all resources will be deployed (e.g. 'us-central1'). Migration Center must be available in this region. {{UIMeta group=1 order=103 }} | `string` | `"us-central1"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. {{UIMeta group=0 order=107 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_shared_users"></a> [shared\_users](#input\_shared\_users) | List of users who can view and deploy this module regardless of the public\_access setting. Enter one or more user email addresses. Metadata only — not referenced within the Terraform module execution; consumed by the deployment platform only. {{UIMeta group=0 order=107 }} | `list(string)` | `[]` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Tenant identifier used in resource naming. Shared by every module deployed to the same tenant in this project — reuse it to share that tenant VPC, service accounts and Artifact Registry, or change it to create a separate namespace. Must be 1-20 lowercase alphanumeric characters and hyphens (e.g. prod, dev, tenant-1). {{UIMeta group=1 order=102 updatesafe }} | `string` | `"demo"` | no |
| <a name="input_windows_vm_boot_disk_size_gb"></a> [windows\_vm\_boot\_disk\_size\_gb](#input\_windows\_vm\_boot\_disk\_size\_gb) | Boot disk size in GB for the Windows VM. Minimum 50 GB recommended for Windows Server 2022 plus MCDCv6. {{UIMeta group=3 order=303 }} | `number` | `50` | no |
| <a name="input_windows_vm_machine_type"></a> [windows\_vm\_machine\_type](#input\_windows\_vm\_machine\_type) | Machine type for the Windows MCDCv6 host VM. e2-medium provides sufficient resources for running the discovery client. {{UIMeta group=3 order=302 }} | `string` | `"e2-medium"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | GCP zone where Compute Engine instances will be deployed (e.g. 'us-central1-a'). {{UIMeta group=1 order=104 }} | `string` | `"us-central1-a"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_iam_user_arn"></a> [aws\_iam\_user\_arn](#output\_aws\_iam\_user\_arn) | ARN of the scoped AWS IAM user created for EC2 discovery. Null when AWS integration is disabled. |
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_linux_vm_internal_ips"></a> [linux\_vm\_internal\_ips](#output\_linux\_vm\_internal\_ips) | Internal IP addresses of the Linux target VMs. Use the first three octets to define the MCDCv6 IP scan range (e.g. if IPs are 10.128.0.2–10.128.0.4, scan 10.128.0.1 to 10.128.0.8). |
| <a name="output_linux_vm_names"></a> [linux\_vm\_names](#output\_linux\_vm\_names) | Names of the Debian Linux VMs deployed as MCDCv6 discovery scan targets. |
| <a name="output_mc_discovery_client_name"></a> [mc\_discovery\_client\_name](#output\_mc\_discovery\_client\_name) | Name to enter in the MCDCv6 'Add a discovery client name' field during login. Must match exactly. |
| <a name="output_mc_source_id"></a> [mc\_source\_id](#output\_mc\_source\_id) | Migration Center discovery source ID created by this module. |
| <a name="output_migration_center_url"></a> [migration\_center\_url](#output\_migration\_center\_url) | Direct URL to the Migration Center console for this project. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | GCP Project ID |
| <a name="output_ssh_key_bucket_name"></a> [ssh\_key\_bucket\_name](#output\_ssh\_key\_bucket\_name) | Cloud Storage bucket containing the SSH private key (lab-ssh-key.pem). Download this file and load it into MCDCv6 as the 'Lab-key' SSH credential. |
| <a name="output_ssh_key_user"></a> [ssh\_key\_user](#output\_ssh\_key\_user) | Linux username that corresponds to the SSH private key stored in GCS. Enter this as the 'Username for this key' field in MCDCv6. |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | Name of the VPC network created for this lab. |
| <a name="output_windows_vm_external_ip"></a> [windows\_vm\_external\_ip](#output\_windows\_vm\_external\_ip) | External IP address of the Windows VM — use this to connect via RDP. Username: migrationcenter  Password: m1grat10nc#nt#r |
| <a name="output_windows_vm_name"></a> [windows\_vm\_name](#output\_windows\_vm\_name) | Name of the Windows Server 2022 VM that hosts MCDCv6. Use this to locate the instance in the GCP Console. |
<!-- END_TF_DOCS -->

*Last tested: Tue May 27, 2026*
