---
title: "Migration Center Module Documentation"
sidebar_label: "Migration Center"
---

# Migration Center Module

## Overview

The Migration Center module provisions a complete **Google Cloud Migration Center** assessment
environment. Migration Center is Google Cloud's free, unified platform for discovering,
analysing, and planning the migration of workloads from on-premises data centres or other cloud
environments (including AWS and Azure). Unlike migration execution tools, Migration Center
focuses on the *assessment phase* — building an accurate inventory of what you have, estimating
the cost to run it on Google Cloud, and identifying dependencies so you can plan migration waves.

This module is designed as a hands-on learning environment for cloud architects, platform
engineers, and migration specialists who want to experience the end-to-end Migration Center
workflow without the overhead of setting it up from scratch. All infrastructure, API
initialisation, sample data import, and report generation are automated by Terraform — users
connect via RDP to a pre-configured Windows VM and complete only the Google OAuth login step
before exploring a fully populated Migration Center environment.

By deploying this module, you gain direct experience with:

- **Migration Center initialisation** — the `initializeConfig` API that prepares a GCP project
  for Migration Center usage and locks in the region for all assessment data
- **Discovery sources** — how the MCDCv6 agent registers against a named source in Migration
  Center, and how scan results from multiple agents can be combined in a single inventory
- **Guest OS scanning** — MCDCv6's SSH-based discovery of Linux VMs that collects hardware
  profiles, installed software, running processes, and open network ports without installing
  any agent on the target VMs
- **CSV data import** — the bulk import pipeline for AWS, Azure, or on-premises inventory
  exported from tools like RVTools, collecting asset data into Migration Center without live
  discovery
- **Asset groups** — how to organise discovered VMs into logical sets (by OS, by business unit,
  by migration wave) that map to specific cost preference scenarios in TCO reports
- **Migration preference sets** — how to model different GCP machine series, right-sizing
  strategies, and committed use discount terms to produce range-bound cost projections
- **TCO reports** — the `TOTAL_COST_OF_OWNERSHIP` report type that maps each asset group to a
  preference set and generates per-VM GCP cost estimates

The module deploys in approximately **5–8 minutes** to a single GCP project. The Windows VM
startup script (MCDCv6 installation) runs in parallel and is ready within 10–15 minutes total.

---

## What Gets Deployed

**Google Cloud infrastructure:**

| Resource | Name Pattern | Purpose |
|---|---|---|
| VPC Network | `migcenter-{id}-vpc` | Dedicated auto-mode network for lab VMs |
| Firewall rules | `migcenter-{id}-allow-*` | RDP, SSH, ICMP, internal, HTTP access |
| Windows Server 2022 VM | `migcenter-{id}-winvm01` | MCDCv6 host with RDP access |
| Debian 12 Linux VMs | `migcenter-{id}-linvm-{N}` | Discovery scan targets (default: 3) |
| Cloud Storage bucket | `migcenter-{id}-mc-keys` | SSH private key storage |
| SSH keypair | `lab-ssh-key.pem` | RSA 4096-bit key for Linux VM authentication |

**Migration Center resources (via REST API):**

| Resource | ID Pattern | Purpose |
|---|---|---|
| Discovery source | `migcenter-{id}-mc-source` | Named source for MCDCv6 scan results |
| Import job | `migcenter-{id}-aws-import` | Bulk import of sample AWS CSV data |
| Asset group | `migcenter-{id}-all-assets` | All Assets group for report configuration |
| Asset group | `migcenter-{id}-windows-only` | Windows-only filter group |
| Asset group | `migcenter-{id}-linux-only` | Linux-only filter group |
| Preference set | `migcenter-{id}-aggressive-3yr` | N2/N2D, aggressive sizing, 3-year CUD |
| Preference set | `migcenter-{id}-moderate-1yr` | C2/C2D + SSD, moderate sizing, 1-year CUD |
| Report config | `migcenter-{id}-report-config` | Group-to-preference mapping for the report |
| TCO report | `migcenter-{id}-tco` | Generated TOTAL_COST_OF_OWNERSHIP report |

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Migration Center Module                                 │
│                                                                              │
│   Google Cloud Project                                                       │
│   ──────────────────────────────────────────────────────────────────────     │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  VPC Network (auto-mode)                                             │   │
│   │  ┌──────────────────────────┐   ┌────────────────────────────────┐  │   │
│   │  │  Windows Server 2022 VM  │   │  Debian 12 Linux VMs (×3)      │  │   │
│   │  │  • MCDCv6 installed      │   │  • migrationcenter SSH user    │  │   │
│   │  │  • Chrome installed      │   │  • RSA key auth enabled        │  │   │
│   │  │  • RDP port 3389 open    │   │  • e2-medium                   │  │   │
│   │  │  • e2-medium             │   └────────────────────────────────┘  │   │
│   │  └──────────────────────────┘              ↑                        │   │
│   │             │  MCDCv6 SSH scan              │                        │   │
│   │             └───────────────────────────────┘                        │   │
│   │  Firewall: allow-rdp · allow-ssh · allow-icmp · allow-internal · http│   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Cloud Storage Bucket                                                       │
│   └─ lab-ssh-key.pem  (RSA 4096 private key)                                 │
│                                                                              │
│   Migration Center (regional service)                                        │
│   ├─ Discovery Source  (GUEST_OS_SCAN)                                       │
│   │   ├─ MCDCv6 scan results  (Linux VMs)                                    │
│   │   └─ CSV import job  (simulated AWS data)                                │
│   ├─ Asset Inventory  (all discovered + imported VMs)                        │
│   ├─ Groups: all-assets · windows-only · linux-only                          │
│   ├─ Preferences: aggressive-3yr · moderate-1yr                              │
│   └─ TCO Report: lab-tco-report                                              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

Deployment sequence:
  1. Enable GCP APIs (migrationcenter, compute, storage, cloudresourcemanager, iam)
  2. Create VPC network (auto-mode)
  3. Create 5 firewall rules (RDP, SSH, ICMP, internal, HTTP)
  4. Generate RSA 4096-bit SSH keypair (tls_private_key)
  5. Create Cloud Storage bucket and upload SSH private key as lab-ssh-key.pem
  6. Deploy Windows Server 2022 VM; startup script installs MCDCv6, Chrome, and pre-stages data
  7. Deploy 3 Debian 12 Linux VMs; startup script creates migrationcenter SSH user
  8. POST initializeConfig — initialises Migration Center for the project/region
  9. POST sources — registers the MCDCv6 discovery source
  10. Download AWS sample zip, upload CSV files, validate and run the import job
  11. POST groups — creates all-assets, windows-only, linux-only groups
  12. POST preferencesSets — creates aggressive-3yr and moderate-1yr preference sets
  13. POST reportConfigs + reports — creates report config and triggers TCO report generation
```

---

## VPC and Firewall

The module creates a dedicated **auto-mode VPC network** for the lab. Auto-mode creates one
subnet per GCP region automatically, each with a `/20` CIDR from the `10.128.0.0/9` range.
For a lab environment with VMs in a single region, auto-mode is the simplest choice — it
provides connectivity without requiring explicit subnet CIDR management.

**Why a dedicated VPC?** Isolation prevents the lab's firewall rules (which include broad
allow-SSH and allow-RDP rules) from affecting other workloads in the project. All lab VMs
land in this network and are visible to each other at the IP layer.

### Firewall Rules

Five firewall rules define the network boundary:

| Rule | Source | Ports | Purpose |
|---|---|---|---|
| `allow-internal` | `10.128.0.0/9` | All | Unrestricted internal traffic within the VPC — covers MCDCv6 SSH scans and VM-to-VM communication |
| `allow-ssh` | `0.0.0.0/0` | TCP 22 | SSH access to Linux VMs (for manual administration and troubleshooting) |
| `allow-rdp` | `0.0.0.0/0` | TCP 3389 | RDP access to the Windows VM from any IP |
| `allow-icmp` | `0.0.0.0/0` | ICMP | Ping for network diagnostics |
| `allow-http` | `0.0.0.0/0` | TCP 80, 8080 | HTTP to `windows-vm`-tagged instances (MCDCv6 web UI) |

**The allow-internal rule and MCDCv6:** MCDCv6 discovers Linux VMs over SSH from the Windows
VM's internal IP. The `allow-internal` rule uses the `10.128.0.0/9` CIDR — the full range
for auto-mode VPC subnets across all regions — ensuring that all VMs in the VPC can
communicate regardless of which region's auto-subnet they are in.

```bash
# View all firewall rules for the lab VPC
gcloud compute firewall-rules list \
  --filter="network~migcenter" \
  --project=PROJECT_ID \
  --format="table(name, direction, sourceRanges, allowed)"

# Verify a specific rule
gcloud compute firewall-rules describe migcenter-<id>-allow-rdp \
  --project=PROJECT_ID
```

---

## Windows VM — MCDCv6 Host

The Windows Server 2022 VM is the lab's interactive workstation. It runs the **MC Discovery
Client (MCDCv6)** — the agent that performs guest-OS-level scanning of target VMs and streams
inventory data to Migration Center. The VM is fully configured by a PowerShell startup script
that runs on first boot.

### What the Startup Script Does

The `windows-startup-script-ps1` metadata key is a GCE mechanism that runs a PowerShell script
once after Windows boots for the first time. The startup script performs five steps:

1. **Creates the lab user** — Creates a local Windows user named `migrationcenter` with
   password `m1grat10nc#nt#r`, adds it to the `Administrators` and `Remote Desktop Users`
   groups. This gives students a predictable credential for RDP without requiring a
   `gcloud compute reset-windows-password` step.

2. **Enables RDP** — Sets the `fDenyTSConnections` registry key to `0` and enables the
   built-in Remote Desktop firewall rule. Windows Server 2022 disables RDP by default; this
   step is required before any RDP client can connect.

3. **Installs Google Chrome** — Downloads and silently installs the Chrome standalone installer.
   MCDCv6's OAuth login flow opens in the system default browser — Chrome is required because
   MCDCv6 does not support Internet Explorer/Edge for its OAuth flow on all versions.

4. **Downloads and installs MCDCv6** — Downloads `mcdc.msi` from the public GCS release
   bucket (`storage.googleapis.com/mcdc-release/current/windows/mcdc.msi`) and runs a silent
   MSI install. MCDCv6 is a cross-platform discovery agent that collects hardware profiles,
   installed packages, running processes, and open network ports from target VMs over SSH.

5. **Pre-stages AWS sample data** — Downloads the AWS CSV export zip from the public lab
   bucket and extracts it to `C:\Users\migrationcenter\Downloads\vm-aws-import-files\`. This
   mirrors what a real customer would have: a zip of CSV files exported from their AWS account
   using the Migration Hub inventory export feature.

### Startup Script Timing

The startup script runs in the background after Windows boot. GCE marks the instance as
`RUNNING` as soon as the OS is responsive — the startup script may still be installing MCDCv6
or downloading Chrome. The typical completion time is **3–5 minutes** after the VM first boots.

```bash
# Monitor startup script progress via the serial port
gcloud compute instances get-serial-port-output <windows-vm-name> \
  --zone=ZONE --project=PROJECT_ID | grep -E "MCDCv6|Chrome|lab setup|startup"

# View the full instance metadata (including the startup script itself)
gcloud compute instances describe <windows-vm-name> \
  --zone=ZONE --project=PROJECT_ID \
  --format="value(metadata.items)"
```

### Machine Configuration

| Parameter | Value | Rationale |
|---|---|---|
| Machine type | `e2-medium` (2 vCPU, 4 GB RAM) | Sufficient for MCDCv6 plus Chrome; configurable via `windows_vm_machine_type` |
| Boot disk | `pd-balanced`, 50 GB | Windows Server 2022 minimum is 32 GB; 50 GB provides headroom for MCDCv6 and Chrome |
| Image | `windows-cloud/windows-2022` | Latest Windows Server 2022 image from the public Google image family |
| Network tag | `windows-vm` | Targets the `allow-http` firewall rule for MCDCv6's browser-based UI |
| External IP | Yes (ephemeral) | Required for RDP access from the lab operator's machine |

### RDP Credentials

```
Username: migrationcenter
Password: m1grat10nc#nt#r
```

These credentials are hardcoded in the startup script for lab simplicity. They are surfaced in
the `windows_vm_external_ip` Terraform output description and in the lab guide for operator
reference.

```bash
# Get the Windows VM external IP
gcloud compute instances describe <windows-vm-name> \
  --zone=ZONE --project=PROJECT_ID \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# REST API
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/PROJECT_ID/zones/ZONE/instances/<windows-vm-name>" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.networkInterfaces[0].accessConfigs[0].natIP'
```

---

## Linux VMs — Discovery Scan Targets

The Debian 12 Linux VMs serve as MCDCv6 discovery targets. Their purpose is to give students
realistic scan results in the Migration Center asset inventory — showing MCDCv6 discovering
actual Linux systems with real OS metadata, package lists, and network port information.

### Startup Script

Each Linux VM runs a small bash startup script that:

1. Creates the `migrationcenter` local user (the same username MCDCv6 uses as an SSH credential)
2. Configures SSH `authorized_keys` with the RSA public key generated by `tls_private_key`
3. Restarts `sshd` to apply the key

This creates a complete SSH authentication chain: Terraform generates the keypair, the public
key is injected into each Linux VM, and the private key is stored in GCS for users to download.

### Resource Configuration

| Parameter | Value | Notes |
|---|---|---|
| Count | 3 (default) | Configurable via `linux_vm_count` — set to 0 to skip |
| Machine type | `e2-medium` | Configurable via `linux_vm_machine_type` |
| Boot disk | 20 GB, `pd-standard` | Configurable via `linux_vm_boot_disk_size_gb` |
| Image | `debian-cloud/debian-12` | Latest Debian 12 from the public Google image family |
| External IP | None | Linux VMs have no external IP — MCDCv6 reaches them via their internal VPC IP |

**Why no external IP on Linux VMs?** MCDCv6 scans from the Windows VM on the same VPC.
Internal IPs are sufficient and keeping Linux VMs private reduces the attack surface. The
`allow-internal` firewall rule ensures SSH (port 22) flows freely between VMs.

```bash
# List all Linux VMs and their internal IPs
gcloud compute instances list \
  --filter="name~migcenter AND name~linvm" \
  --project=PROJECT_ID \
  --format="table(name, zone, status, networkInterfaces[0].networkIP)"

# Describe a specific Linux VM
gcloud compute instances describe <linux-vm-name> \
  --zone=ZONE --project=PROJECT_ID \
  --format="yaml(name, status, machineType, disks, networkInterfaces)"

# REST API
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/PROJECT_ID/zones/ZONE/instances/<linux-vm-name>" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, status, machineType, ip: .networkInterfaces[0].networkIP}'
```

---

## SSH Key Management

The module uses the Terraform `tls_private_key` resource to generate a **4096-bit RSA keypair**
at deployment time. This approach avoids shell-generated keys and ensures the keypair is fully
managed within the Terraform execution context.

### How the Key Is Used

| Component | Key Material | How It Gets There |
|---|---|---|
| Linux VMs | RSA **public key** | Injected via `metadata.startup-script` → written to `~migrationcenter/.ssh/authorized_keys` |
| Cloud Storage | RSA **private key** | Stored as `lab-ssh-key.pem` object in the `migcenter-{id}-mc-keys` bucket |
| MCDCv6 | RSA **private key** | Downloaded from GCS and loaded into MCDCv6 as the `Lab-key` SSH credential |

### Key Storage Details

The GCS bucket that stores the key is configured with:
- `uniform_bucket_level_access = true` — IAM controls apply uniformly to all objects
- `force_destroy = true` — allows Terraform destroy to delete the bucket even if the key object
  exists; without this, Terraform destroy would fail when objects are present

The private key is stored in PEM format as `lab-ssh-key.pem`. This file is what students
download from GCS and load into MCDCv6 during the credential setup step.

```bash
# Download the SSH private key from GCS
gcloud storage cp "gs://<bucket-name>/lab-ssh-key.pem" ./lab-ssh-key.pem \
  --project=PROJECT_ID

# Test the key manually against a Linux VM (optional)
chmod 600 ./lab-ssh-key.pem
ssh -i ./lab-ssh-key.pem migrationcenter@<linux-vm-internal-ip>
```

### Security Considerations

The private key is stored in Terraform state as a sensitive value. Anyone with access to the
Terraform state file (or the GCS bucket) can obtain it. For production deployments:

- Restrict GCS bucket IAM to only the identities that need the key
- Consider rotating the key after the lab session concludes
- Audit bucket access via Cloud Audit Logs

---

## Migration Center Automation Pipeline

The six `null_resource` steps in `migration_center.tf` implement the full Migration Center
setup pipeline. Each step uses a `local-exec` provisioner with `gcloud auth print-access-token`
(impersonated via the `resource_creator_identity` service account) and `curl` to call the
Migration Center REST API.

### Step 1 — initializeConfig

The `initializeConfig` API call locks in the Migration Center region for the project. This is
a one-time, idempotent operation — calling it on an already-initialised project returns HTTP
409, which the script treats as a success.

```bash
# Call initializeConfig manually
TOKEN=$(gcloud auth print-access-token)
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION:initializeConfig" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Why this matters:** Migration Center data is regional. The `initializeConfig` call commits
all asset data, groups, preferences, and reports to a specific GCP region. You cannot change
the region after initialisation without creating a new project.

### Step 2 — Create a Discovery Source

A **source** is a named collection point for asset data. MCDCv6 agents and CSV imports both
write data to a source. Multiple agents can share a single source if they share the source name.

The module creates a `GUEST_OS_SCAN` source — the type used by MCDCv6 agents. The source ID
(`migcenter-{id}-mc-source`) must be entered verbatim in the MCDCv6 UI during login; this is
what links live scan results to the pre-configured source in Migration Center.

```bash
# List all sources
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/sources" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.sources[] | {name: (.name | split("/") | last), displayName, type}'

# Get details for a specific source
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/sources/SOURCE_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, displayName, type, managedObjectType, createTime}'
```

### Step 3 — Import AWS Sample Data

The AWS import pipeline is the most complex step. It:

1. Downloads `vm-aws-import-files.zip` from a public GCS bucket
2. Extracts four CSV files that simulate an AWS account inventory export
3. Creates an import job referencing the discovery source
4. Uploads each CSV file as an `importDataFile` within the job
5. Calls `:validate` to check for format errors
6. Calls `:run` to process the files and write assets to the inventory

This pipeline mirrors exactly what a real AWS customer would do after exporting their inventory
from AWS Migration Hub or generating a custom CSV export.

```bash
# Check the status of an import job
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/importJobs/IMPORT_JOB_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, displayName, state, assetSource, createTime}'

# List import data files within a job
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/importJobs/IMPORT_JOB_ID/importDataFiles" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.importDataFiles[] | {displayName, state, createTime}'
```

### Step 4 — Create Asset Groups

Three groups are created:

| Group | Display Name | Purpose |
|---|---|---|
| `migcenter-{id}-all-assets` | All Assets | Catch-all group for the aggressive TCO scenario |
| `migcenter-{id}-windows-only` | windows-only | Windows VMs under the moderate cost scenario |
| `migcenter-{id}-linux-only` | linux-only | Linux VMs under the moderate cost scenario |

Groups are created empty — assets are not assigned at creation time. In the lab, users explore
the groups and can manually add assets via the Cloud Console or REST API.

```bash
# List groups with asset counts
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/groups" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.groups[] | {displayName, name: (.name | split("/") | last)}'
```

### Step 5 — Create Migration Preference Sets

Preference sets define how Migration Center maps each discovered VM to a GCP machine type
when generating cost projections.

**aggressive-3yr preference set:**
```json
{
  "virtualMachinePreferences": {
    "targetProduct": "COMPUTE_MIGRATION_TARGET_PRODUCT_COMPUTE_ENGINE",
    "computeEnginePreferences": {
      "machinePreferences": {
        "allowedMachineSeries": [{"code": "n2"}, {"code": "n2d"}]
      },
      "licenseType": "LICENSE_TYPE_DEFAULT"
    },
    "sizingOptimizationStrategy": "SIZING_OPTIMIZATION_STRATEGY_AGGRESSIVE",
    "commitmentPlan": "COMMITMENT_PLAN_THREE_YEAR"
  }
}
```

**moderate-1yr preference set:**
```json
{
  "virtualMachinePreferences": {
    "targetProduct": "COMPUTE_MIGRATION_TARGET_PRODUCT_COMPUTE_ENGINE",
    "computeEnginePreferences": {
      "machinePreferences": {
        "allowedMachineSeries": [{"code": "c2"}, {"code": "c2d"}]
      },
      "licenseType": "LICENSE_TYPE_DEFAULT",
      "persistentDiskType": "PERSISTENT_DISK_TYPE_SSD"
    },
    "sizingOptimizationStrategy": "SIZING_OPTIMIZATION_STRATEGY_MODERATE",
    "commitmentPlan": "COMMITMENT_PLAN_ONE_YEAR"
  }
}
```

| Parameter | Aggressive | Moderate | Effect |
|---|---|---|---|
| Machine series | N2, N2D | C2, C2D | N2/N2D are cost-efficient; C2/C2D are compute-optimised |
| Disk type | Default (HDD) | SSD | SSD adds cost but improves I/O-bound workload performance |
| Sizing strategy | Aggressive | Moderate | Aggressive right-sizes to actual peak; moderate keeps more headroom |
| Commitment plan | 3-year | 1-year | 3-year CUDs offer the deepest discount (~57% on N2) |

```bash
# View preference set details
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/preferencesSets/PREF_SET_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.virtualMachinePreferences'
```

### Step 6 — Create Report Config and Trigger Report

A **report config** defines which groups are evaluated and which preference set applies to each.
The module creates one config with three group-to-preference assignments:

| Group | Preference Set |
|---|---|
| All Assets | aggressive-3yr |
| windows-only | moderate-1yr |
| linux-only | moderate-1yr |

The report config is persistent — you can generate multiple reports from it over time as the
asset inventory grows or preferences change.

After the config is created, the module immediately triggers a `TOTAL_COST_OF_OWNERSHIP`
report. Report generation takes 1–5 minutes and runs asynchronously; Terraform does not wait
for the report to complete.

```bash
# List report configs
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/reportConfigs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.reportConfigs[] | {name: (.name | split("/") | last), displayName}'

# List reports for a config
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/reportConfigs/REPORT_CONFIG_ID/reports" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.reports[] | {displayName, type, state, createTime}'
```

---

## MCDCv6 — The MC Discovery Client

The **Migration Center Discovery Client version 6 (MCDCv6)** is the primary data collection
agent used in this module. It is a GUI application that runs on the Windows VM and collects
inventory data from target VMs over SSH (for Linux/Windows targets) or WMI (for Windows targets).

### What MCDCv6 Collects

MCDCv6 performs **guest OS scanning** — it authenticates to each target VM via SSH and
collects:

| Data Category | Examples |
|---|---|
| Hardware profile | CPU model, core count, RAM, disk count and capacity |
| OS details | Distribution, version, kernel version, architecture |
| Installed software | Package manager inventory (rpm, dpkg), installed applications |
| Running processes | Process name, PID, user, memory usage at scan time |
| Network interfaces | IP addresses, MAC addresses, speed |
| Open ports | Listening TCP/UDP ports and the process bound to each |
| Performance data | CPU utilisation, memory utilisation (if extended scan is enabled) |

This data is streamed to Migration Center in real time as the scan completes, becoming
immediately visible in the asset inventory.

### MCDCv6 Authentication Flow

MCDCv6 requires two forms of authentication:

1. **Google OAuth** — binds the agent to a GCP project and a named discovery source. This
   is a browser-based flow that requires the user to sign in with a Google account. The module
   pre-creates the discovery source; users only need to select the correct project and enter
   the source name.

2. **SSH credential** — allows MCDCv6 to authenticate to each Linux target VM. The module
   provides an RSA private key via Cloud Storage. Users download the key, create an MCDCv6
   credential entry (type: SSH private key, username: `migrationcenter`), and MCDCv6 uses it
   for all subsequent scans.

### Why MCDCv6 Login Cannot Be Automated

The OAuth login step requires an interactive browser session. The user must:
- Click **Sign in with Google** in the MCDCv6 browser UI
- Complete the Google OAuth consent flow in Chrome
- Return to MCDCv6 to select the project and enter the source name

This flow involves user interaction with Google's OAuth endpoints and cannot be scripted or
pre-populated. Every other module action — infrastructure, MC initialisation, source creation,
data import, group creation, preference sets, report generation — is automated by Terraform.

---

## Configuration Reference

### Compute Resources

| Variable | Default | Description |
|---|---|---|
| `region` | `us-central1` | GCP region for all resources |
| `zone` | `us-central1-a` | GCP zone for Compute Engine VMs |
| `create_windows_vm` | `true` | Deploy the Windows MCDCv6 host VM |
| `windows_vm_machine_type` | `e2-medium` | Windows VM machine type |
| `windows_vm_boot_disk_size_gb` | `50` | Windows VM boot disk in GB (minimum 50 for Windows 2022) |
| `linux_vm_count` | `3` | Number of Debian Linux scan targets (set to 0 to skip) |
| `linux_vm_machine_type` | `e2-medium` | Linux VM machine type |
| `linux_vm_boot_disk_size_gb` | `20` | Linux VM boot disk in GB |

### Networking

| Variable | Default | Description |
|---|---|---|
| `create_vpc` | `true` | Create a dedicated VPC; set to `false` to use an existing VPC |
| `internal_traffic_cidr` | `10.128.0.0/9` | CIDR for the allow-internal firewall rule |
| `create_default_firewall_rules` | `true` | Create all 5 firewall rules |

### SSH Key Storage

| Variable | Default | Description |
|---|---|---|
| `create_ssh_key_bucket` | `true` | Create GCS bucket and store `lab-ssh-key.pem` |

### Migration Center

| Variable | Default | Description |
|---|---|---|
| `initialize_migration_center` | `true` | Run all MC setup steps (init, source, import, groups, prefs, report) |
| `mc_discovery_client_name` | `mc-discovery-client` | Source name — must be entered verbatim in MCDCv6 |
| `import_aws_sample_data` | `true` | Download and import AWS CSV sample data |
| `generate_reports` | `true` | Create groups, preference sets, and trigger TCO report |
| `mc_report_name` | `lab-tco-report` | Display name for the generated report |

### Platform Metadata

| Variable | Default | Description |
|---|---|---|
| `deployment_id` | `null` | Optional suffix for resource names; auto-generated if blank |
| `resource_creator_identity` | `rad-module-creator@...` | Service account for impersonation |
| `credit_cost` | `20` | Platform credit cost for deployment |

---

## Default Behaviours

Understanding the module's default configuration helps avoid surprises when deploying or
modifying the environment.

**All Migration Center steps run by default.** When `initialize_migration_center = true`
(the default), the module runs all six REST API steps: initialise, create source, import AWS
data, create groups, create preference sets, and trigger the report. Setting this to `false`
skips all Migration Center automation and deploys only the Compute and Storage infrastructure.

**Import and reports are gated on `initialize_migration_center`.** The variables
`import_aws_sample_data` and `generate_reports` are only evaluated when
`initialize_migration_center = true`. Both default to `true` and are rarely changed independently.

**MCDCv6 OAuth cannot be skipped.** The Google OAuth login step requires interactive user
input. The module does not and cannot automate this step. Students should plan for this
manual step after deployment.

**The SSH private key is stored in plaintext in Terraform state.** The `tls_private_key`
resource stores the private key in the Terraform state file. Ensure your state backend has
appropriate access controls. The GCS bucket containing the key is not publicly accessible
by default (uniform bucket-level access is enforced).

**Migration Center resources survive Terraform destroy.** Discovery sources, import jobs,
groups, preference sets, and reports are created via REST API `null_resource` provisioners
and are not tracked in Terraform state. Running `terraform destroy` removes Compute and
Storage resources but leaves Migration Center objects intact. These must be deleted manually
via the Cloud Console or REST API. See the Cleanup section in the Lab Guide.

**GCP APIs are protected from accidental deletion.** The `google_project_service` resources
have `lifecycle { prevent_destroy = true }`. Running `terraform destroy` against a deployed
module does not disable the enabled APIs. This is intentional — disabling APIs like
`migrationcenter.googleapis.com` in a shared project can break other users. To disable APIs,
remove the lifecycle block and re-run `tofu plan` before `tofu destroy`.

**The TCO report is generated asynchronously.** The module triggers report generation via
REST API but does not wait for completion. Reports typically appear in the Migration Center
console within 1–5 minutes of Terraform completing. If the report is not visible immediately,
refresh the console after a few minutes.

---

## Prerequisites

### Google Cloud

- A Google Cloud project with billing enabled
- The following APIs are enabled automatically on first run:
  - `migrationcenter.googleapis.com` — Migration Center service
  - `compute.googleapis.com` — VMs, VPC, firewall rules
  - `storage.googleapis.com` — SSH key bucket
  - `cloudresourcemanager.googleapis.com` — project metadata
  - `iam.googleapis.com` — service account operations
  - `iamcredentials.googleapis.com` — service account impersonation

```bash
# Verify API enablement after deployment
gcloud services list \
  --filter="config.name~migrationcenter OR config.name~compute OR config.name~storage" \
  --project=PROJECT_ID \
  --format="table(config.name, state)"
```

### Permissions

The service account running the module (`resource_creator_identity`) requires:

- `roles/owner` (or at minimum):
  - `roles/migrationcenter.admin` — initialise MC, create sources, import data, generate reports
  - `roles/compute.admin` — create VMs, VPC, firewall rules
  - `roles/storage.admin` — create GCS bucket and objects
  - `roles/iam.serviceAccountUser` — impersonate the provisioning service account

The Google account that completes the MCDCv6 OAuth login requires `roles/migrationcenter.admin`
on the project to associate the agent with the pre-created discovery source.

### Local Tools

No local tool installation is required for the RAD UI deployment path. For manual exploration:

- `gcloud` CLI (authenticated)
- `curl` and `jq` (for REST API calls)
- An RDP client (Microsoft Remote Desktop, Remmina, or FreeRDP)

---

## Deploying the Module

### Via RAD UI

1. Navigate to the RAD UI and select the `Migration Center` module
2. Fill in the required variable form:
   - `project_id` — your GCP project ID
   - `region` — GCP region (default `us-central1`)
   - `zone` — GCP zone (default `us-central1-a`)
   - Leave all other variables at their defaults for the full lab experience
3. Click **Deploy** and wait approximately 5–8 minutes

### Verify Deployment

```bash
# Confirm VMs are running
gcloud compute instances list \
  --filter="name~migcenter" \
  --project=PROJECT_ID \
  --format="table(name, status, zone, networkInterfaces[0].accessConfigs[0].natIP)"

# Confirm GCS bucket and SSH key exist
gcloud storage ls "gs://$(gcloud storage buckets list --filter='name~migcenter' --format='value(name)' --project=PROJECT_ID)/"\
  --project=PROJECT_ID

# Confirm Migration Center source was created
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/sources" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.sources[] | {name: (.name | split("/") | last), type}'
```

### Cleaning Up

Use the RAD UI **Undeploy** button to remove all Terraform-managed resources. Manually delete
Migration Center resources that are not tracked by Terraform:

```bash
# Delete all Migration Center resources for this deployment
REGION="us-central1"
PROJECT_ID="your-project-id"
TOKEN=$(gcloud auth print-access-token)

# Delete groups
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '.groups[].name' | while read -r name; do
    curl -s -X DELETE "https://migrationcenter.googleapis.com/v1/${name}" \
      -H "Authorization: Bearer ${TOKEN}"
  done

# Delete preference sets
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferencesSets" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '.preferencesSets[].name' | while read -r name; do
    curl -s -X DELETE "https://migrationcenter.googleapis.com/v1/${name}" \
      -H "Authorization: Bearer ${TOKEN}"
  done

# Delete report configs (also deletes associated reports)
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '.reportConfigs[].name' | while read -r name; do
    curl -s -X DELETE "https://migrationcenter.googleapis.com/v1/${name}" \
      -H "Authorization: Bearer ${TOKEN}"
  done

# Delete discovery sources
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/sources" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '.sources[].name' | while read -r name; do
    curl -s -X DELETE "https://migrationcenter.googleapis.com/v1/${name}" \
      -H "Authorization: Bearer ${TOKEN}"
  done
```

---

## Further Learning

### Google Cloud Migration Center
- [Migration Center overview](https://cloud.google.com/migration-center/docs/overview)
- [MC Discovery Client documentation](https://cloud.google.com/migration-center/docs/discovery-client-overview)
- [Migration Center REST API reference](https://cloud.google.com/migration-center/docs/reference/rest)
- [Total cost of ownership reports](https://cloud.google.com/migration-center/docs/create-tco-report)
- [Asset groups and preference sets](https://cloud.google.com/migration-center/docs/create-groups)
- [Importing inventory from AWS](https://cloud.google.com/migration-center/docs/import-aws-data)

### GCP Compute and Storage
- [Compute Engine machine types](https://cloud.google.com/compute/docs/machine-resource)
- [Committed use discounts](https://cloud.google.com/compute/docs/instances/signing-up-committed-use-discounts)
- [GCP machine series comparison: N2 vs C2](https://cloud.google.com/compute/docs/general-purpose-machines)
- [Cloud Storage uniform bucket-level access](https://cloud.google.com/storage/docs/uniform-bucket-level-access)

### Migration Strategy
- [Google Cloud Adoption Framework](https://cloud.google.com/adoption-framework)
- [Migration to Google Cloud: Getting started](https://cloud.google.com/architecture/migration-to-gcp-getting-started)
- [StratoZone → Migration Center transition](https://cloud.google.com/migration-center/docs/stratozone-migration-center)
