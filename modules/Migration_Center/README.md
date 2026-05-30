# Migration Center Assessment Lab

## Overview

This module deploys a fully configured **Google Cloud Migration Center**
assessment environment. Migration Center is Google Cloud's free tool for
discovering, analyzing, and planning migrations from on-premises or other
cloud environments.

The module provisions the complete lab environment and automates all
infrastructure and Migration Center configuration steps. Users connect
via RDP, complete the MCDCv6 Google OAuth login, run a discovery scan,
and then generate a TCO report from the console against fully populated
asset data.

## Industry Value & Use Cases

Data center exit and cloud migration programmes consistently stall at the assessment phase — organizations lack a complete, trustworthy inventory of what they own, what it costs to run, and what it would cost to move. Migration Center is Google Cloud's free answer to this problem, delivering automated discovery, performance-based rightsizing, and TCO modelling in a single console. It is the recommended starting point for any GCP migration engagement, with adoption highest among enterprises preparing to consolidate aging data centers or move workloads from another cloud provider.

**Key use cases this module demonstrates:**
- **Data center exit planning** — discover and inventory on-premises VMs, analyze performance data, and generate TCO comparisons to build a migration business case before committing to a GCP investment
- **Cloud-to-cloud migration assessment** — import AWS EC2 asset data via CSV export and evaluate migration paths alongside on-premises assets in a unified view, supporting multi-source migration programmes
- **Infrastructure rightsizing analysis** — identify over-provisioned VMs and generate rightsizing recommendations that reduce cloud spend from day one, directly supporting FinOps cost-optimization mandates
- **Migration business case development** — use preference sets (aggressive 3-year CUD vs. moderate 1-year CUD) to model different commitment scenarios for FinOps and procurement teams negotiating cloud contracts

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

## Deployment Options

### RAD UI

Select **Migration Center** from the module catalog and click **Deploy**.
All defaults are production-ready for the lab.

### Launcher CLI

```bash
cd modules/Migration_Center
cat > terraform.tfvars <<EOF
project_id = "your-project-id"
region     = "us-central1"
zone       = "us-central1-a"
EOF
tofu init && tofu apply
```

## Usage (as a Terraform module)

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
5. Generate a TCO report from the Migration Center console (asset groups and preference sets are pre-created and ready)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3 |
| aws | >= 5.0 |
| google | >= 5.0, < 6.0 |
| null | >= 3.0 |
| random | >= 3.0 |
| tls | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| google | >= 5.0, < 6.0 |
| null | >= 3.0 |
| random | >= 3.0 |
| tls | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| aws_iam_access_key.mc_discovery_key | resource |
| aws_iam_policy.mc_discovery | resource |
| aws_iam_user.mc_discovery | resource |
| aws_iam_user_policy_attachment.mc_discovery | resource |
| google_compute_firewall.default_allow_http | resource |
| google_compute_firewall.default_allow_icmp | resource |
| google_compute_firewall.default_allow_internal | resource |
| google_compute_firewall.default_allow_rdp | resource |
| google_compute_firewall.default_allow_ssh | resource |
| google_compute_instance.linux_vm | resource |
| google_compute_instance.windows_vm | resource |
| google_compute_network.lab_vpc | resource |
| google_project_service.enabled_services | resource |
| google_storage_bucket.ssh_key_bucket | resource |
| google_storage_bucket_object.ssh_private_key | resource |
| null_resource.mc_aws_import | resource |
| null_resource.mc_init | resource |
| null_resource.mc_source | resource |
| random_id.default | resource |
| tls_private_key.ssh_key | resource |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| aws_access_key_id | Bootstrap AWS Access Key ID with IAM write permissions; module auto-creates a scoped EC2-read-only IAM user. Leave empty to skip AWS integration. | `string` | `""` |
| aws_region | AWS region to discover EC2 instances from (e.g. `us-east-1`) | `string` | `"us-east-1"` |
| aws_secret_access_key | Bootstrap AWS Secret Access Key corresponding to the Access Key ID above | `string` | `""` |
| create_default_firewall_rules | Create allow-internal, allow-ssh, allow-rdp, allow-icmp firewall rules | `bool` | `true` |
| create_ssh_key_bucket | Create a GCS bucket and store the generated SSH private key | `bool` | `true` |
| create_vpc | Create the lab VPC network | `bool` | `true` |
| create_windows_vm | Deploy the Windows Server 2022 VM with MCDCv6 pre-installed | `bool` | `true` |
| deployment_id | Short alphanumeric suffix for resource name uniqueness | `string` | `null` |
| initialize_migration_center | Initialize Migration Center and create a discovery source | `bool` | `true` |
| internal_traffic_cidr | CIDR for allow-internal firewall rule | `string` | `"10.128.0.0/9"` |
| linux_vm_boot_disk_size_gb | Boot disk size in GB for each Linux VM | `number` | `20` |
| linux_vm_count | Number of Linux discovery target VMs | `number` | `3` |
| linux_vm_machine_type | Machine type for Linux VMs | `string` | `"e2-medium"` |
| mc_discovery_client_name | MCDCv6 discovery client name (must match what you enter in the UI) | `string` | `"mc-discovery-client"` |
| project_id | GCP project ID | `string` | `null` |
| region | GCP region | `string` | `"us-central1"` |
| resource_creator_identity | Terraform service account email | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` |
| windows_vm_boot_disk_size_gb | Boot disk size in GB for the Windows VM | `number` | `50` |
| windows_vm_machine_type | Machine type for the Windows VM | `string` | `"e2-medium"` |
| zone | GCP zone | `string` | `"us-central1-a"` |

## Outputs

| Name | Description |
|------|-------------|
| deployment_id | Module Deployment ID |
| linux_vm_internal_ips | Internal IPs of Linux target VMs for MCDCv6 scan range |
| linux_vm_names | Names of the Linux discovery target VMs |
| mc_discovery_client_name | Discovery client name to enter in MCDCv6 |
| mc_source_id | Migration Center discovery source ID |
| migration_center_url | Direct URL to the Migration Center console |
| project_id | GCP Project ID |
| ssh_key_bucket_name | GCS bucket containing the SSH private key |
| ssh_key_user | SSH username for the Lab-key credential in MCDCv6 |
| aws_iam_user_arn | ARN of the scoped EC2-read-only IAM user created for discovery. Null when AWS integration is disabled. |
| vpc_name | Name of the lab VPC network |
| windows_vm_external_ip | Windows VM external IP for RDP access |
| windows_vm_name | Windows VM instance name |
<!-- END_TF_DOCS -->

*Last tested: Tue May 27, 2026*
