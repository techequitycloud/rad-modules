# VMware\_Engine Module

This module deploys **Google Cloud VMware Engine (GCVE)** infrastructure, including a VMware Engine Network, a private cloud (single-node TIME\_LIMITED or multi-node STANDARD), VPC peering between the GCVE management network and a peer VPC, a network policy enabling internet access and external IPs for workload VMs, default VPC firewall rules, a Windows Server 2022 jump host for accessing vCenter and NSX-T, and automated vCenter solution user credential reset. It is designed to support VM migration workflows and GCVE lab environments.

## Industry Value & Use Cases

Google Cloud VMware Engine is the enterprise standard for data center exit and VMware cloud migration without refactoring. Large organizations across financial services, healthcare, and manufacturing use GCVE to lift and shift entire VMware estates to Google Cloud, preserving their existing vSphere operational model while gaining access to Google Cloud's AI, data, and networking services as a next step. One documented enterprise case study (BHP) shows infrastructure provisioning time reduced from 6 months to 6 days after adopting GCVE to replace a legacy VMware vRA environment.

**Key use cases this module demonstrates:**
- **Data center exit without refactoring** — lift and shift VMware VMs to Google Cloud preserving vCenter, NSX-T, and vSphere operations; no application or OS changes required
- **Disaster recovery modernization** — replace expensive secondary data center hardware with GCVE private clouds sized for DR, activated on-demand
- **VDI migration** — move VMware Horizon or Citrix virtual desktop infrastructure to Google Cloud, leveraging Google's global network for low-latency access
- **Hybrid cloud bridge to GCP-native services** — GCVE clusters connect directly to GCP VPC networks, enabling VMware workloads to consume BigQuery, Cloud SQL, Vertex AI, and other GCP services without traversing the internet
- **Validated migration lab environment** — the TIME\_LIMITED single-node private cloud option lets teams validate GCVE connectivity, HCX workflows, and vCenter access before committing to STANDARD production deployments

For a detailed technical walkthrough of the full lab, see [VMware_Engine.md](../../docs/labs/VMware_Engine.md).

Last tested on Fri May 15, 2026

## Deployment Options

Deploy this module from the **[RAD Modules platform UI](https://radmodules.dev)** — the recommended path, with **no command line or local toolchain required**. Advanced/automation users can alternatively use the Launcher CLI or call the Terraform module directly (see **Advanced** below).

| | [RAD Modules UI](https://radmodules.dev) | RAD Modules Launcher (CLI) |
|---|---|---|
| **Setup required** | None — runs in your browser | Python 3.7+, OpenTofu, and `gcloud` CLI |
| **Best for** | Quick starts, demos, and guided deployments | Automation, scripting, and full variable control |
| **Configuration** | Point-and-click form with sensible defaults | `--varfile` with `key = "value"` overrides |
| **State management** | Managed by the platform | GCS bucket you own and manage |

### Option 1: RAD Modules UI (no setup required)

Visit **[https://radmodules.dev](https://radmodules.dev)**, sign in with your Google account, and select this module from the catalog. The platform guides you through providing the required inputs and launches the deployment on your behalf — no local toolchain installation needed.

Choose this option if you want a fast, no-setup path to explore this module or run a guided demo.

### Advanced — RAD Modules Launcher (CLI, for automation/maintainers)

Use the [RAD Modules Launcher](../../rad-launcher/README.md) to deploy from your workstation or Google Cloud Shell. This option gives you full control over all module variables, supports non-interactive scripted deployments, and lets you manage Terraform state in a GCS bucket you own.

Choose this option if you need custom variable overrides, automated pipelines, or deeper integration with your own GCP environment.

## Advanced — Terraform module (maintainers)

> **Platform users don't need this** — deploy from the [RAD Modules UI](https://radmodules.dev) above. The Terraform module call below is for maintainers/automation integrating the module directly.

```hcl
module "vmware_engine" {
  source = "./modules/VMware_Engine"

  project_id  = "my-gcp-project"
  private_cloud_type   = "TIME_LIMITED"   # or "STANDARD" for production
  node_count           = 1
  create_jump_host     = true
  reset_vcenter_credentials = true
}
```

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

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0, < 6.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |
| <a name="provider_external"></a> [external](#provider\_external) | >= 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.default_allow_icmp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_rdp](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.default_allow_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.jump_host](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.peer_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_vmwareengine_network.vmware_engine_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vmwareengine_network) | resource |
| [google_vmwareengine_network_peering.vpc_peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vmwareengine_network_peering) | resource |
| [google_vmwareengine_network_policy.network_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vmwareengine_network_policy) | resource |
| [google_vmwareengine_private_cloud.private_cloud](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vmwareengine_private_cloud) | resource |
| [null_resource.vcenter_credentials_reset](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_compute_network.peer_vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_default_firewall_rules"></a> [create\_default\_firewall\_rules](#input\_create\_default\_firewall\_rules) | Set to true (default) to create the four Google-default firewall rules (allow-internal, allow-ssh, allow-rdp, allow-icmp) on the peer VPC. Set to false if these rules already exist on the target network. | `bool` | `true` | no |
| <a name="input_create_jump_host"></a> [create\_jump\_host](#input\_create\_jump\_host) | Set to true (default) to deploy a Windows Server 2022 jump host VM on the peer VPC for accessing vCenter, NSX-T, and HCX management consoles via RDP. | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Set to true (default) to create the peer VPC network. Set to false to use an existing VPC and skip creation. | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require\_credit\_purchases is true, users must have sufficient credit balance before deploying. Defaults to 500. | `number` | `500` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to use no suffix. | `string` | `null` | no |
| <a name="input_edge_services_cidr"></a> [edge\_services\_cidr](#input\_edge\_services\_cidr) | CIDR block for VMware Engine edge services (internet ingress/egress, e.g. '10.11.2.0/26'). Must not overlap with management\_cidr or the peer VPC subnets. | `string` | `"10.11.3.0/26"` | no |
| <a name="input_enable_external_ip"></a> [enable\_external\_ip](#input\_enable\_external\_ip) | Set to true (default) to enable external IP address allocation for VMware Engine workload VMs. | `bool` | `true` | no |
| <a name="input_enable_internet_access"></a> [enable\_internet\_access](#input\_enable\_internet\_access) | Set to true (default) to enable internet access from VMware Engine workload VMs via the edge services CIDR. | `bool` | `true` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. | `bool` | `true` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. | `bool` | `true` | no |
| <a name="input_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | GCP project ID where VMware Engine resources will be deployed. Must already exist and the service account must hold roles/owner. | `string` | n/a | yes |
| <a name="input_internal_traffic_cidr"></a> [internal\_traffic\_cidr](#input\_internal\_traffic\_cidr) | CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. Override if using a custom-mode VPC. | `string` | `"10.128.0.0/9"` | no |
| <a name="input_jump_host_boot_disk_size_gb"></a> [jump\_host\_boot\_disk\_size\_gb](#input\_jump\_host\_boot\_disk\_size\_gb) | Boot disk size in GB for the Windows jump host. Minimum 50 GB recommended for Windows Server 2022. | `number` | `50` | no |
| <a name="input_jump_host_machine_type"></a> [jump\_host\_machine\_type](#input\_jump\_host\_machine\_type) | Machine type for the Windows jump host (e.g. 'e2-medium'). | `string` | `"e2-medium"` | no |
| <a name="input_jump_host_subnetwork"></a> [jump\_host\_subnetwork](#input\_jump\_host\_subnetwork) | Subnetwork self-link or name for the jump host NIC. Required for custom-mode VPCs. Leave blank to let GCP auto-select the subnet for the region. | `string` | `""` | no |
| <a name="input_management_cidr"></a> [management\_cidr](#input\_management\_cidr) | CIDR block reserved for the VMware Engine management cluster. Cannot be changed after private cloud creation. Must not overlap with the peer VPC or edge services CIDR. | `string` | `"172.20.1.0/24"` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['GCP Project']. | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. | `string` | `"This module deploys Google Cloud VMware Engine (GCVE) infrastructure — the enterprise-proven path for lifting and shifting existing VMware workloads to Google Cloud without refactoring. Adopted by large enterprises across financial services, healthcare, and manufacturing to accelerate data center exits, disaster recovery modernization, and VDI migrations, GCVE preserves familiar VMware operational tooling (vCenter, NSX-T, HCX) while unlocking access to native GCP services; one documented enterprise case study shows infrastructure provisioning time shrinking from 6 months to 6 days. This module provisions the complete GCVE stack and a Windows Server 2022 jump host, providing a production-representative environment to validate VM migration workflows."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module, used for display and filtering in the platform UI. | `list(string)` | <pre>[<br>  "GCP",<br>  "VMware Engine",<br>  "Cloud Networking",<br>  "Cloud IAM"<br>]</pre> | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of nodes in the management cluster. Set to 1 for TIME\_LIMITED (single-node evaluation) private clouds. STANDARD type requires a minimum of 3 nodes. | `number` | `1` | no |
| <a name="input_node_type_id"></a> [node\_type\_id](#input\_node\_type\_id) | VMware Engine node type API identifier for the management cluster. The UI displays this as 've1-standard-72' but the API and Terraform require 'standard-72'. | `string` | `"standard-72"` | no |
| <a name="input_private_cloud_type"></a> [private\_cloud\_type](#input\_private\_cloud\_type) | Private cloud deployment type. 'TIME\_LIMITED' provisions a single-node evaluation private cloud suitable for labs and demos. 'STANDARD' is for production workloads and requires a minimum of 3 nodes. | `string` | `"TIME_LIMITED"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. | `bool` | `true` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. | `bool` | `false` | no |
| <a name="input_reset_vcenter_credentials"></a> [reset\_vcenter\_credentials](#input\_reset\_vcenter\_credentials) | Set to true (default) to reset and retrieve the vCenter solution user credentials via gcloud after the private cloud is provisioned. | `bool` | `true` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. | `string` | `""` | no |
| <a name="input_vcenter_solution_user"></a> [vcenter\_solution\_user](#input\_vcenter\_solution\_user) | vCenter solution user account whose credentials will be reset (e.g. 'solution-user-01@gve.local'). Required for accessing vCenter management consoles and deploying workloads in the private cloud. | `string` | `"solution-user-01@gve.local"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_hcx_fqdn"></a> [hcx\_fqdn](#output\_hcx\_fqdn) | HCX Manager FQDN |
| <a name="output_network_peering_state"></a> [network\_peering\_state](#output\_network\_peering\_state) | Current state of the VPC Network Peering (Active once the private cloud is fully provisioned) |
| <a name="output_network_policy_id"></a> [network\_policy\_id](#output\_network\_policy\_id) | Full resource ID of the VMware Engine Network Policy |
| <a name="output_nsx_fqdn"></a> [nsx\_fqdn](#output\_nsx\_fqdn) | NSX-T Manager FQDN — use this URL from the jump host browser to access the NSX-T console |
| <a name="output_private_cloud_id"></a> [private\_cloud\_id](#output\_private\_cloud\_id) | Full resource ID of the Private Cloud |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | GCP Project ID |
| <a name="output_vcenter_fqdn"></a> [vcenter\_fqdn](#output\_vcenter\_fqdn) | vCenter Server FQDN — use this URL from the jump host browser to access vSphere Client |
| <a name="output_vmware_engine_network_id"></a> [vmware\_engine\_network\_id](#output\_vmware\_engine\_network\_id) | Full resource ID of the VMware Engine Network |
<!-- END_TF_DOCS -->
