# VM Migration — Migration Center Assessment Lab

## Overview

This module deploys a fully configured **Google Cloud Migration Center**
assessment environment. Migration Center is Google Cloud's free tool for
discovering, analyzing, and planning migrations from on-premises or other
cloud environments.

**Industry use cases:** Data center exit planning, cloud-to-cloud migration
assessment, infrastructure rightsizing analysis, TCO comparison for
FinOps teams.

The module provisions the complete lab environment and runs all Migration
Center setup steps automatically, so users spend their time exploring
assets and reports — not configuring infrastructure.

## What Gets Deployed

| Resource | Description |
|---|---|
| Windows Server 2022 VM | MCDCv6 pre-installed; RDP-ready with lab credentials |
| 3× Debian 12 Linux VMs | Discovery scan targets with `migrationcenter` SSH user |
| VPC + Firewall Rules | Auto-mode VPC with SSH, RDP, ICMP, and internal rules |
| Cloud Storage Bucket | Holds the generated SSH private key (lab-ssh-key.pem) |
| Migration Center Source | Discovery client registration |
| AWS Sample Data Import | 4-file AWS CSV export imported into the asset inventory |
| Asset Groups | All Assets · windows-only · linux-only |
| Migration Preferences | Aggressive 3-year · Moderate 1-year CUD |
| TCO Report | Pre-generated, visible within ~5 minutes of deployment |

## Deployment Options

### RAD UI

Select **VM Migration** from the module catalog and click **Deploy**.
All defaults are production-ready for the lab.

### Launcher CLI

```bash
cd modules/VM_Migration
cat > terraform.tfvars <<EOF
project_id = "your-project-id"
region     = "us-central1"
zone       = "us-central1-a"
EOF
tofu init && tofu apply
```

## Usage (as a Terraform module)

```hcl
module "vm_migration" {
  source = "github.com/techequitycloud/rad-modules//modules/VM_Migration"

  project_id = "my-gcp-project"
  region     = "us-central1"
  zone       = "us-central1-a"

  # Optional overrides
  linux_vm_count           = 3
  mc_discovery_client_name = "mc-discovery-client"
  mc_report_name           = "lab-tco-report"
}
```

## Key Outputs

| Output | Description |
|---|---|
| `windows_vm_external_ip` | RDP target IP — Username: `migrationcenter` / Password is in Secret Manager. |
| `linux_vm_internal_ips` | Internal IPs for configuring the MCDCv6 IP scan range |
| `ssh_key_bucket_name` | GCS bucket holding `lab-ssh-key.pem` for MCDCv6 SSH credential |
| `ssh_key_user` | SSH username (`migrationcenter`) for the Lab-key credential |
| `mc_discovery_client_name` | Name to enter in MCDCv6 during the login flow |
| `migration_center_url` | Direct link to the Migration Center console |

## Lab Guide

Full step-by-step instructions: [LAB_GUIDE.md](./LAB_GUIDE.md)

The only manual steps are:
1. RDP into the Windows VM (credentials in outputs)
2. Complete the Google OAuth login in MCDCv6 (browser-based)
3. Add OS credentials and SSH key in MCDCv6 UI
4. Run the IP scan and explore the populated console

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
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0, < 6.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0, < 6.0 |
| <a name="provider_google.impersonated"></a> [google.impersonated](#provider\_google.impersonated) | >= 5.0, < 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.default_allow_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_icmp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_rdp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.linux_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.windows_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.lab_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_project_iam_member.migrationcenter_sa_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_secret_manager_secret.windows_vm_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.windows_vm_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_storage_bucket.ssh_key_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.ssh_private_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.windows_vm_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [google_compute_network.lab_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_service_account_access_token.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account_access_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_default_firewall_rules"></a> [create\_default\_firewall\_rules](#input\_create\_default\_firewall\_rules) | Set to true (default) to create the four Google-default firewall rules (allow-internal, allow-ssh, allow-rdp, allow-icmp) on the VPC. Set to false if these rules already exist on the target network. {{UIMeta group=4 order=401 }} | `bool` | `true` | no |
| <a name="input_create_ssh_key_bucket"></a> [create\_ssh\_key\_bucket](#input\_create\_ssh\_key\_bucket) | Set to true (default) to create a Cloud Storage bucket and store the generated SSH private key. The bucket name is surfaced in Terraform outputs for easy retrieval. {{UIMeta group=7 order=701 }} | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Set to true (default) to create a dedicated VPC network for this lab. Set to false to use an existing VPC. {{UIMeta group=3 order=301 }} | `bool` | `true` | no |
| <a name="input_create_windows_vm"></a> [create\_windows\_vm](#input\_create\_windows\_vm) | Set to true (default) to deploy the Windows Server 2022 VM that hosts the MC Discovery Client. The startup script automatically installs MCDCv6 and pre-stages AWS import data. {{UIMeta group=5 order=501 }} | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }} | `number` | `20` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to use no suffix. {{UIMeta group=0 order=108 }} | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. {{UIMeta group=1 order=105 }} | `bool` | `true` | no |
| <a name="input_generate_reports"></a> [generate\_reports](#input\_generate\_reports) | Set to true (default) to automatically create asset groups, migration preferences, and trigger TCO report generation in Migration Center after the AWS data import completes. {{UIMeta group=9 order=901 }} | `bool` | `true` | no |
| <a name="input_import_aws_sample_data"></a> [import\_aws\_sample\_data](#input\_import\_aws\_sample\_data) | Set to true (default) to automatically download and import the sample AWS CSV export data into Migration Center. This populates the asset inventory with simulated AWS VM data alongside the live scan results. {{UIMeta group=8 order=803 }} | `bool` | `true` | no |
| <a name="input_initialize_migration_center"></a> [initialize\_migration\_center](#input\_initialize\_migration\_center) | Set to true (default) to automatically initialize the Migration Center service, create a discovery source, import sample AWS data, create asset groups and migration preferences, and trigger report generation. {{UIMeta group=8 order=801 }} | `bool` | `true` | no |
| <a name="input_internal_traffic_cidr"></a> [internal\_traffic\_cidr](#input\_internal\_traffic\_cidr) | CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. {{UIMeta group=3 order=302 }} | `string` | `"10.128.0.0/9"` | no |
| <a name="input_linux_vm_boot_disk_size_gb"></a> [linux\_vm\_boot\_disk\_size\_gb](#input\_linux\_vm\_boot\_disk\_size\_gb) | Boot disk size in GB for each Linux target VM. {{UIMeta group=6 order=603 }} | `number` | `20` | no |
| <a name="input_linux_vm_count"></a> [linux\_vm\_count](#input\_linux\_vm\_count) | Number of Debian Linux VMs to deploy as discovery scan targets. The MCDCv6 scanner will discover and inventory these VMs. {{UIMeta group=6 order=601 }} | `number` | `3` | no |
| <a name="input_linux_vm_machine_type"></a> [linux\_vm\_machine\_type](#input\_linux\_vm\_machine\_type) | Machine type for each Linux discovery target VM. e2-medium is sufficient for lab purposes. {{UIMeta group=6 order=602 }} | `string` | `"e2-medium"` | no |
| <a name="input_mc_discovery_client_name"></a> [mc\_discovery\_client\_name](#input\_mc\_discovery\_client\_name) | Name to register for the MC Discovery Client data source. This name appears in the Migration Center console and must match what you enter in the MCDCv6 UI during login. {{UIMeta group=8 order=802 }} | `string` | `"mc-discovery-client"` | no |
| <a name="input_mc_report_name"></a> [mc\_report\_name](#input\_mc\_report\_name) | Name for the generated TCO and detailed pricing report in Migration Center. {{UIMeta group=9 order=902 }} | `string` | `"lab-tco-report"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }} | `list(string)` | <pre>[<br/>  "GCP Project"<br/>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. {{UIMeta group=0 order=100 }} | `string` | `"This module deploys a fully configured Google Cloud Migration Center assessment environment. Migration Center is Google Cloud's free tool for discovering, analyzing, and planning migrations from on-premises or other cloud environments. The module provisions a Windows Server 2022 VM with the MC Discovery Client (MCDCv6) pre-installed, Debian Linux target VMs for live network scanning, and runs all Migration Center setup steps automatically — including initializing the service, registering the discovery source, importing sample AWS data, creating asset groups, configuring migration preferences, and generating TCO and inventory reports. Users connect via RDP and complete only the Google OAuth login step before exploring a fully populated Migration Center environment."` | no |
| <a name="input_module_documentation"></a> [module\_documentation](#input\_module\_documentation) | URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }} | `string` | `"https://github.com/techequitycloud/rad-modules/blob/main/modules/VM_Migration/LAB_GUIDE.md"` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br/>  "GCP",<br/>  "Migration Center",<br/>  "Compute Engine",<br/>  "Cloud Storage",<br/>  "Cloud IAM"<br/>]</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID where Migration Center resources will be deployed. Must already exist and the service account must hold roles/owner. {{UIMeta group=1 order=101 updatesafe }} | `string` | `null` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region where all resources will be deployed (e.g. 'us-central1'). Migration Center must be available in this region. {{UIMeta group=1 order=103 }} | `string` | `"us-central1"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. {{UIMeta group=0 order=107 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_windows_vm_boot_disk_size_gb"></a> [windows\_vm\_boot\_disk\_size\_gb](#input\_windows\_vm\_boot\_disk\_size\_gb) | Boot disk size in GB for the Windows VM. Minimum 50 GB recommended for Windows Server 2022 plus MCDCv6. {{UIMeta group=5 order=503 }} | `number` | `50` | no |
| <a name="input_windows_vm_machine_type"></a> [windows\_vm\_machine\_type](#input\_windows\_vm\_machine\_type) | Machine type for the Windows MCDCv6 host VM. e2-medium provides sufficient resources for running the discovery client. {{UIMeta group=5 order=502 }} | `string` | `"e2-medium"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | GCP zone where Compute Engine instances will be deployed (e.g. 'us-central1-a'). {{UIMeta group=1 order=104 }} | `string` | `"us-central1-a"` | no |

## Outputs

| Name | Description |
|------|-------------|
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
| <a name="output_windows_vm_external_ip"></a> [windows\_vm\_external\_ip](#output\_windows\_vm\_external\_ip) | External IP address of the Windows VM — use this to connect via RDP. Username: migrationcenter. Password is in Secret Manager. |
| <a name="output_windows_vm_name"></a> [windows\_vm\_name](#output\_windows\_vm\_name) | Name of the Windows Server 2022 VM that hosts MCDCv6. Use this to locate the instance in the GCP Console. |
| <a name="output_windows_vm_password_secret_id"></a> [windows\_vm\_password\_secret\_id](#output\_windows\_vm\_password\_secret\_id) | Secret Manager secret ID containing the randomly generated RDP password for the Windows VM. |
<!-- END_TF_DOCS -->

*Last tested: Tue May 27, 2026*
