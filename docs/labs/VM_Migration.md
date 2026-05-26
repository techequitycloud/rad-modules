# Google Cloud Migration Center — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/VM_Migration)**

This lab guide walks you through discovering, analysing, and planning a cloud migration using
**Google Cloud Migration Center** and the **VM_Migration** module. You will connect to a
pre-configured Windows VM running the MC Discovery Client (MCDCv6), register it against the
Migration Center project that Terraform has already initialised, configure SSH-based discovery
of Debian Linux target VMs, review the discovered inventory alongside sample AWS data, and
explore the pre-generated TCO cost optimisation report.

The module automates every infrastructure and Migration Center setup step — you complete only
the Google OAuth login in the MCDCv6 UI and the asset collection configuration.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Connect to the Windows VM via RDP](#exercise-1--connect-to-the-windows-vm-via-rdp)
6. [Exercise 2 — Launch MCDCv6 and Complete Google Login](#exercise-2--launch-mcdcv6-and-complete-google-login)
7. [Exercise 3 — Configure SSH Credentials for Linux VM Discovery](#exercise-3--configure-ssh-credentials-for-linux-vm-discovery)
8. [Exercise 4 — Run the Discovery Scan and Review Linux Assets](#exercise-4--run-the-discovery-scan-and-review-linux-assets)
9. [Exercise 5 — Review AWS Sample Data and All Assets](#exercise-5--review-aws-sample-data-and-all-assets)
10. [Exercise 6 — Explore Asset Groups](#exercise-6--explore-asset-groups)
11. [Exercise 7 — Explore Migration Preferences](#exercise-7--explore-migration-preferences)
12. [Exercise 8 — View the TCO Report](#exercise-8--view-the-tco-report)
13. [Cleanup](#13-cleanup)
14. [Reference](#14-reference)

---

## 1. Overview

### What Is Google Cloud Migration Center?

**Google Cloud Migration Center** is Google Cloud's free, unified platform for discovering,
assessing, and planning the migration of workloads from on-premises data centres or other cloud
environments. It aggregates data from multiple discovery sources — agent-based scans, agentless
network discovery, and manual CSV imports — and produces inventory reports, dependency maps,
and total cost of ownership (TCO) projections.

### Use Cases

| Use Case | Description |
|---|---|
| **Data centre inventory** | Automatically discover and catalogue all VMs across heterogeneous environments |
| **Cloud cost modelling** | Generate TCO projections comparing on-premises costs against GCP machine types and commitment plans |
| **Right-sizing** | Identify over-provisioned VMs and recommend appropriately sized GCP machine types |
| **Multi-cloud assessment** | Import AWS, Azure, or on-premises data into a single unified inventory |
| **Migration wave planning** | Group assets into logical waves based on dependency analysis and business criticality |

### What This Lab Automates

| Step | Automated by Terraform | Manual Step Required |
|---|---|---|
| Initialise Migration Center service | Yes — REST API `initializeConfig` | None |
| Register MCDCv6 discovery source | Yes — REST API `sources` | None |
| Import AWS sample data | Yes — downloads zip, uploads CSV files, runs job | None |
| Create asset groups | Yes — All Assets, windows-only, linux-only | None |
| Create preference sets | Yes — aggressive-3yr, moderate-1yr | None |
| Generate TCO report | Yes — REST API `reportConfigs` + `reports` | None |
| Install MCDCv6 on Windows VM | Yes — PowerShell startup script | None |
| Google OAuth login in MCDCv6 | **No — requires browser-based login** | **You complete this** |
| Configure SSH credential in MCDCv6 | **No** | **You complete this** |
| Configure IP scan range | **No** | **You complete this** |

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Google Cloud Project                                                        │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  VPC Network (auto-mode, migcenter-{id}-vpc)                           │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────┐  ┌──────────────────────────────┐   │  │
│  │  │  Windows Server 2022 VM      │  │  Debian 12 Linux VMs         │   │  │
│  │  │  migcenter-{id}-winvm01      │  │  migcenter-{id}-linvm-0      │   │  │
│  │  │  e2-medium                   │  │  migcenter-{id}-linvm-1      │   │  │
│  │  │  • MCDCv6 pre-installed      │  │  migcenter-{id}-linvm-2      │   │  │
│  │  │  • Chrome pre-installed      │  │  e2-medium × 3               │   │  │
│  │  │  • RDP enabled (port 3389)   │  │  • migrationcenter user      │   │  │
│  │  │  • User: migrationcenter     │  │  • SSH key auth enabled      │   │  │
│  │  └──────────────────────────────┘  └──────────────────────────────┘   │  │
│  │                 │                              ↑                       │  │
│  │         MCDCv6 SSH scan                  discovers via                 │  │
│  │                 └────────────────────────────┘                         │  │
│  │                                                                        │  │
│  │  Firewall: allow-rdp, allow-ssh, allow-icmp, allow-internal, http      │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  Cloud Storage (migcenter-{id}-mc-keys)                                │  │
│  │  • lab-ssh-key.pem  (RSA 4096 private key for Linux VM SSH access)     │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  Migration Center (migrationcenter.googleapis.com)                     │  │
│  │                                                                        │  │
│  │  Discovery Source: migcenter-{id}-mc-source  (GUEST_OS_SCAN)          │  │
│  │                    ↓ live scan results + AWS CSV import                │  │
│  │  Asset Inventory:  Debian Linux VMs + simulated AWS VMs                │  │
│  │                                                                        │  │
│  │  Groups:       All Assets  │  windows-only  │  linux-only              │  │
│  │  Preferences:  aggressive-3yr (N2/N2D, 3yr CUD)                       │  │
│  │                moderate-1yr  (C2/C2D, SSD, 1yr CUD)                   │  │
│  │                                                                        │  │
│  │  Report:  lab-tco-report  (TOTAL_COST_OF_OWNERSHIP)                   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  VM_Migration
    region                      = "us-central1"         →  All resources in this region
    zone                        = "us-central1-a"        →  Compute Engine zone
    linux_vm_count              = 3                      →  3 Debian Linux scan targets
    create_windows_vm           = true                   →  Windows MCDCv6 host
    initialize_migration_center = true                   →  Auto-initialise MC service
    import_aws_sample_data      = true                   →  Import sample AWS CSV data
    generate_reports            = true                   →  Auto-generate TCO report
    mc_discovery_client_name    = "mc-discovery-client"  →  Source name entered in MCDCv6
```

---

## 3. Prerequisites

### Required Tools

| Tool | Minimum Version | Install |
|---|---|---|
| `gcloud` CLI | 480.0.0 | [Install guide](https://cloud.google.com/sdk/docs/install) |
| RDP client | Any | Windows Remote Desktop, Microsoft Remote Desktop (macOS), Remmina (Linux) |
| Web browser | Any | For Migration Center Cloud Console |
| `curl` / `jq` | Any | System package manager |

### GCP Permissions

```
roles/owner  (or)
roles/migrationcenter.admin
roles/compute.admin
roles/storage.admin
roles/iam.serviceAccountAdmin
```

### GCP APIs Required

The module enables these APIs automatically:

```
migrationcenter.googleapis.com
compute.googleapis.com
storage.googleapis.com
cloudresourcemanager.googleapis.com
iam.googleapis.com
iamcredentials.googleapis.com
```

### Environment Variables

Set these in your terminal before running lab commands:

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"

gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${REGION}"
gcloud config set compute/zone "${ZONE}"
```

After deployment, set these from the Terraform outputs:

```bash
export WINDOWS_VM=$(gcloud compute instances list \
  --filter="name~migcenter AND name~winvm" \
  --format="value(name)" \
  --project="${PROJECT_ID}")

export SSH_KEY_BUCKET=$(gcloud storage buckets list \
  --filter="name~migcenter AND name~mc-keys" \
  --format="value(name)" \
  --project="${PROJECT_ID}")
```

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `VM_Migration` module via the RAD UI. In the variable form, set:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `region` | `us-central1` | GCP region for all resources |
| `zone` | `us-central1-a` | GCP zone for Compute Engine VMs |
| `linux_vm_count` | `3` | Number of Debian Linux scan targets |
| `initialize_migration_center` | `true` | Auto-initialise MC, create source, import data |
| `import_aws_sample_data` | `true` | Import sample AWS CSV data |
| `generate_reports` | `true` | Create groups, preferences, and TCO report |
| `mc_discovery_client_name` | `mc-discovery-client` | Source name to enter in MCDCv6 |

Click **Deploy** and wait for provisioning to complete.

> **Note:** Terraform provisioning takes approximately **5–8 minutes**. The Windows VM startup
> script (MCDCv6 install + Chrome download) runs in the background after the VM boots and takes
> an additional **3–5 minutes**. Wait for the startup script to finish before starting Exercise 2.

> **What this provisions:** A VPC with firewall rules, a Windows Server 2022 VM with MCDCv6
> pre-installed, three Debian 12 Linux VMs, a Cloud Storage bucket containing an SSH private
> key, and a fully configured Migration Center environment including a registered discovery
> source, imported AWS sample data, asset groups, migration preferences, and a TCO report.

### 4.2 Retrieve Deployment Outputs

After deployment, note the Terraform outputs from the RAD UI, or retrieve them via gcloud:

**Windows VM external IP:**
```bash
gcloud compute instances list \
  --filter="name~migcenter AND name~winvm" \
  --project="${PROJECT_ID}" \
  --format="table(name, zone, status, networkInterfaces[0].accessConfigs[0].natIP)"
```

**Linux VM internal IPs:**
```bash
gcloud compute instances list \
  --filter="name~migcenter AND name~linvm" \
  --project="${PROJECT_ID}" \
  --format="table(name, zone, networkInterfaces[0].networkIP)"
```

**SSH key bucket name:**
```bash
gcloud storage buckets list \
  --filter="name~migcenter" \
  --project="${PROJECT_ID}" \
  --format="value(name)"
```

**REST API — list all module Compute instances:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/aggregated/instances" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items | to_entries[] | .value.instances[]? | select(.name | test("migcenter")) | {name, status, internalIP: .networkInterfaces[0].networkIP, externalIP: .networkInterfaces[0].accessConfigs[0]?.natIP}'
```

---

## Exercise 1 — Connect to the Windows VM via RDP

### Objective

Connect to the Windows Server 2022 VM via RDP using the pre-created `migrationcenter` lab
user, and verify that MCDCv6 and Chrome are installed and ready.

### Step 1.1 — Get the Windows VM External IP

**gcloud:**
```bash
gcloud compute instances describe "${WINDOWS_VM}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
```

**REST API:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${ZONE}/instances/${WINDOWS_VM}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, status, externalIP: .networkInterfaces[0].accessConfigs[0].natIP}'
```

### Step 1.2 — Connect via RDP

Open your RDP client and connect with these credentials:

```
Host:     <windows-vm-external-ip>:3389
Username: migrationcenter
Password: m1grat10nc#nt#r
```

> **Tip:** On macOS use **Microsoft Remote Desktop**. On Linux use Remmina or FreeRDP:
> ```bash
> xfreerdp /u:migrationcenter /p:'m1grat10nc#nt#r' /v:<external-ip>:3389 /dynamic-resolution
> ```

> **If RDP fails to connect:** The Windows startup script may still be running. Wait 3–5 minutes
> after the Terraform deployment completes and try again. You can check startup progress from
> your local machine:
> ```bash
> gcloud compute instances get-serial-port-output "${WINDOWS_VM}" \
>   --zone="${ZONE}" --project="${PROJECT_ID}" | tail -20
> ```

### Step 1.3 — Verify MCDCv6 Is Installed

Once inside the Windows VM:

1. Click **Start** and look for **Migration Center Discovery Client** in the program list, or
   check `C:\Program Files\Google\MCDCv6\`
2. Verify that **Google Chrome** is installed (required for the OAuth login flow in Exercise 2)
3. Open **File Explorer** → navigate to `C:\Users\migrationcenter\Downloads\` to confirm the
   `vm-aws-import-files` folder is present (pre-staged by the startup script)

### Step 1.4 — Test Connectivity to Linux VMs

From the Windows VM, open **PowerShell** and test SSH port reachability to the Linux VMs.
Use the internal IPs from the `linux_vm_internal_ips` Terraform output:

```powershell
# Replace with actual IP from Terraform output linux_vm_internal_ips
Test-NetConnection -ComputerName 10.128.0.2 -Port 22
Test-NetConnection -ComputerName 10.128.0.3 -Port 22
Test-NetConnection -ComputerName 10.128.0.4 -Port 22
```

Expected: `TcpTestSucceeded: True` for each VM — they are on the same VPC and the firewall
allows internal traffic including SSH.

---

## Exercise 2 — Launch MCDCv6 and Complete Google Login

### Objective

Launch the MC Discovery Client, authenticate with a Google account, and register this
Discovery Client against the Migration Center source that Terraform pre-created.

### Step 2.1 — Launch MCDCv6

On the Windows VM:

1. Open **Start** → search for and launch **Migration Center Discovery Client**
2. MCDCv6 opens using Google Chrome (the application uses a browser-based UI)

### Step 2.2 — Sign In with Google

On the MCDCv6 welcome screen:

1. Click **Sign in with Google**
2. Chrome opens a Google OAuth consent screen
3. Sign in with a Google account that has **Migration Center Admin** access to the lab project
4. Grant the requested permissions and return to the MCDCv6 window

> **Note:** This is the one step that cannot be automated — the MCDCv6 OAuth flow requires an
> interactive browser session to authenticate the discovery client against your GCP project.
> All other Migration Center setup steps are handled by Terraform.

### Step 2.3 — Select the GCP Project

After signing in, MCDCv6 asks you to choose a GCP project:

1. Select the lab project from the dropdown (matching the `project_id` in your Terraform
   deployment)
2. Click **Next**

### Step 2.4 — Enter the Discovery Client Name

MCDCv6 asks you to enter a **discovery client name** — this name must exactly match the source
ID that Terraform already registered in Migration Center:

1. In the **Add a discovery client name** field, enter the value from the Terraform output
   `mc_discovery_client_name`. The default value is: `mc-discovery-client`
2. Click **Next**

> **Important:** The name must match exactly (case-sensitive). Terraform created a source with
> this name in Migration Center. If the names don't match, MCDCv6 creates a new unregistered
> source and scan results will not appear in the expected source.

### Step 2.5 — Verify the Dashboard Appears

After completing login, MCDCv6 shows its main dashboard. Confirm:

- The project name shown matches your lab project
- The discovery client name matches `mc-discovery-client`
- The connection status shows **Connected** or **Ready**

---

## Exercise 3 — Configure SSH Credentials for Linux VM Discovery

### Objective

Download the SSH private key from Cloud Storage, add it to MCDCv6 as a named credential, and
prepare the discovery client to authenticate against the Linux target VMs.

### Step 3.1 — Download the SSH Private Key from GCS

The SSH private key was generated by Terraform using the `tls_private_key` resource and stored
in Cloud Storage. Download it from inside the Windows VM using Chrome or PowerShell.

**Option A — Cloud Console (recommended from the Windows VM):**

Open Chrome and navigate to:
```
https://console.cloud.google.com/storage/browser/<bucket-name-from-terraform-output>
```
Click `lab-ssh-key.pem` → click **Download**. The file saves to
`C:\Users\migrationcenter\Downloads\`.

**Option B — PowerShell (from the Windows VM):**
```powershell
# Authenticate to GCP (use your lab Google account)
gcloud auth login

# Download the key (replace BUCKET_NAME with the ssh_key_bucket_name output)
$bucketName = "BUCKET_NAME"
gsutil cp "gs://$bucketName/lab-ssh-key.pem" "$env:USERPROFILE\Downloads\lab-ssh-key.pem"
```

**gcloud (from your local machine, to inspect the bucket):**
```bash
gcloud storage ls "gs://${SSH_KEY_BUCKET}/" --project="${PROJECT_ID}"
```

**REST API — list objects in the SSH key bucket:**
```bash
curl -s \
  "https://storage.googleapis.com/storage/v1/b/${SSH_KEY_BUCKET}/o" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | {name, selfLink, size}'
```

### Step 3.2 — Add the SSH Key as a Credential in MCDCv6

In the MCDCv6 dashboard:

1. Click **Credentials** in the left navigation pane
2. Click **Add Credential**
3. Configure the credential:
   - **Credential type**: SSH private key
   - **Credential name**: `Lab-key`
   - **Username for this key**: `migrationcenter` ← from Terraform output `ssh_key_user`
   - **Private key file**: click **Browse** and select `lab-ssh-key.pem` from Downloads
4. Click **Save**

### Step 3.3 — Verify the Credential Is Saved

Back on the Credentials page, confirm `Lab-key` appears in the list. The status may show
**Not tested** until a scan is run — this is expected.

---

## Exercise 4 — Run the Discovery Scan and Review Linux Assets

### Objective

Configure MCDCv6 with the Linux VM subnet scan range, run a discovery collection, and verify
that the Linux VMs appear in the Migration Center asset inventory.

### Step 4.1 — Determine the IP Scan Range

Use the Linux VM internal IPs from the Terraform output `linux_vm_internal_ips` to determine
the scan range. The IPs are consecutive in the auto-mode VPC subnet.

**From your local machine:**
```bash
gcloud compute instances list \
  --filter="name~migcenter AND name~linvm" \
  --project="${PROJECT_ID}" \
  --format="value(networkInterfaces[0].networkIP)" \
  | sort
```

For example, if the output is:
```
10.128.0.2
10.128.0.3
10.128.0.4
```

Use scan range:
- **Start IP:** `10.128.0.1`
- **End IP:** `10.128.0.10`

**REST API — list Linux VM IPs:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${ZONE}/instances" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | select(.name | test("linvm")) | {name, ip: .networkInterfaces[0].networkIP}'
```

### Step 4.2 — Configure a New Collection Source

In MCDCv6:

1. Click **Data Sources** in the left navigation
2. Click **Add Data Source**
3. Select **Linux/Windows** as the source type
4. Click **Next**

### Step 4.3 — Configure the IP Scan Range and Credential

In the data source configuration form:

1. Enter the **Start IP** and **End IP** for the scan range (from Step 4.1)
2. Leave port settings at default (SSH port 22)
3. From the **Credentials** dropdown, select **Lab-key**
4. Click **Save**

### Step 4.4 — Start the Discovery Collection

1. On the Data Sources page, click **Collect** or **Run Now** on your newly created source
2. Watch the **Collection Status** — it transitions from **Pending** → **Running** → **Completed**
3. Scans typically complete within **2–5 minutes** for 3 VMs

> **If a VM shows "Access Denied":** Confirm the `migrationcenter` user exists on the Linux VM
> and the `Lab-key` credential uses exactly the username `migrationcenter`. Check the
> Troubleshooting section for further steps.

### Step 4.5 — Verify Assets in Migration Center

After the collection completes, open the **Migration Center Console** and verify the Linux
VMs appear:

**Cloud Console:**
```
https://console.cloud.google.com/migration/center?project=<PROJECT_ID>
```
Click **Assets** → **Virtual Machines** → look for the three `migcenter-*-linvm-*` VMs.

**REST API — list all assets:**
```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/assets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.assets[] | {name, machineName: .machineDetails.machineName, os: .machineDetails.guestOsDetails.osName, source: .sources[0]}'
```

Click on one Linux VM to explore its full detail profile — OS version, kernel, CPU/memory
capacity, installed packages, and running processes collected by MCDCv6.

---

## Exercise 5 — Review AWS Sample Data and All Assets

### Objective

Explore the AWS sample data that Terraform automatically imported, understand the combined
asset inventory, and compare the live Linux VM data with the simulated AWS environment.

### Step 5.1 — Verify the AWS Import Job Completed

Terraform submitted an import job with four CSV files of simulated AWS VM inventory data.

**Cloud Console:**
Navigate to **Migration Center → Data Sources** and look for the AWS import job. The status
should show **Completed** (or **Completed with warnings** if any optional fields were absent
from the CSV).

**REST API — list import jobs:**
```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.importJobs[] | {displayName, state, createTime}'
```

### Step 5.2 — Explore the Full Asset Inventory

In Migration Center → **Assets** → **Virtual Machines**. You should now see:

- **3 Debian Linux VMs** — discovered by MCDCv6 scan (your lab VMs)
- **Multiple simulated AWS VMs** — from the CSV import (a mix of Windows and Linux)

Use the search and filter controls to explore:

- **Filter by OS type:** Compare the Windows AWS VMs against the Debian scan targets
- **Filter by source:** Distinguish MCDCv6 scan results from the AWS import
- **Sort by CPU or memory:** Identify the highest-resource VMs in the inventory

### Step 5.3 — View an Individual Asset's Detail

Click on any asset to open its detail view and explore the available tabs:

| Tab | What You'll See |
|---|---|
| **Attributes** | CPU cores, RAM, total disk capacity, OS version, kernel |
| **Installed software** | Application list collected from the guest OS |
| **Open ports** | Active network ports discovered during the scan |
| **Performance** | CPU and memory utilisation history (if performance data was collected) |

**REST API — get details for a specific asset:**
```bash
# List assets and extract the first one's resource name
ASSET_NAME=$(curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/assets?pageSize=1" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq -r '.assets[0].name')

# Fetch the full asset detail
curl -s \
  "https://migrationcenter.googleapis.com/v1/${ASSET_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, machineDetails, performanceSamples: (.performanceSamples | length)}'
```

---

## Exercise 6 — Explore Asset Groups

### Objective

Explore the three asset groups that Terraform pre-created and understand how groups organise
assets into logical sets for targeted TCO reporting.

### Step 6.1 — View Groups in the Cloud Console

Navigate to **Migration Center → Groups**. Three groups should be present:

| Group Display Name | Purpose |
|---|---|
| **All Assets** | All discovered VMs — used in the report with the aggressive-3yr preferences |
| **windows-only** | Windows VMs from the AWS import — used with the moderate-1yr preferences |
| **linux-only** | Linux VMs from the scan and AWS import — used with the moderate-1yr preferences |

Click on **All Assets** to see the member list and total asset count.

### Step 6.2 — View Groups via REST API

```bash
# List all groups with asset counts
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.groups[] | {displayName, name, createTime}'
```

```bash
# List assets in a specific group (replace GROUP_ID with the group's resource name)
GROUP_ID="migcenter-<deployment-id>-linux-only"
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups/${GROUP_ID}/assets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.assets[].name'
```

### Step 6.3 — Add an Asset to a Group Manually

To explore group management, add a VM to a group via the Cloud Console:

1. In **Migration Center → Assets**, select any VM by checking its checkbox
2. Click **Add to group** in the actions bar
3. Select **All Assets** from the dropdown
4. Click **Confirm**

**REST API — add an asset to a group:**
```bash
GROUP_ID="migcenter-<deployment-id>-all-assets"
ASSET_RESOURCE="projects/${PROJECT_ID}/locations/${REGION}/assets/<asset-id>"

curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups/${GROUP_ID}:addAssets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{\"assets\": [{\"asset\": \"${ASSET_RESOURCE}\"}]}"
```

---

## Exercise 7 — Explore Migration Preferences

### Objective

Explore the two pre-created migration preference sets and understand how they model different
cost optimisation strategies that drive the TCO report projections.

### Step 7.1 — View Preference Sets in the Cloud Console

Navigate to **Migration Center → Preferences** (or **Migration preferences**). Two sets should
be present:

| Preference Set | Machine Series | Sizing Strategy | Commitment |
|---|---|---|---|
| **aggressive-optimization-3-year-commit** | N2, N2D | Aggressive | 3-year CUD |
| **moderate-optimization-1-year-commit** | C2, C2D + SSD | Moderate | 1-year CUD |

Click on each to inspect the detailed configuration.

### Step 7.2 — View Preference Sets via REST API

```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferencesSets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.preferencesSets[] | {
      displayName,
      name,
      targetProduct: .virtualMachinePreferences.targetProduct,
      sizingStrategy: .virtualMachinePreferences.sizingOptimizationStrategy,
      commitmentPlan: .virtualMachinePreferences.commitmentPlan
    }'
```

### Step 7.3 — Understand the Preference Parameters

**Aggressive optimisation (3-year):**
- **Machine series:** N2 / N2D — general-purpose cost-effective series
- **Sizing:** `AGGRESSIVE` — right-sizes VMs based on actual observed peak utilisation
- **Commitment:** 3-year CUD — maximum discount, minimum flexibility; best for stable workloads

**Moderate optimisation (1-year):**
- **Machine series:** C2 / C2D with SSD persistent disk — compute-optimised, faster per core
- **Sizing:** `MODERATE` — maintains larger headroom above observed utilisation
- **Commitment:** 1-year CUD — balanced discount with more flexibility for changing needs

> **Why two preference sets?** Different business units typically have different risk tolerances
> for VM right-sizing and different budget planning cycles. The TCO report projects both
> scenarios simultaneously, giving cloud architects a range to work with when presenting
> migration business cases.

---

## Exercise 8 — View the TCO Report

### Objective

View the pre-generated Total Cost of Ownership report and understand how Migration Center
projects GCP costs for each asset group under both preference scenarios.

### Step 8.1 — Open the Report

Navigate to **Migration Center → Reports** in the Cloud Console.

The report `lab-tco-report` was generated automatically by Terraform. If the report is still
processing (it can take up to 5 minutes after Terraform completes), wait and refresh the page.

### Step 8.2 — Explore the Report Summary

On the report overview page, review:

1. **Total estimated monthly GCP cost** — combined projection across all groups
2. **Cost breakdown by group** — All Assets vs. windows-only vs. linux-only sections
3. **Preference set comparison** — side-by-side aggressive-3yr vs. moderate-1yr cost estimates

### Step 8.3 — Explore the Detailed Report

Click **View report** to open the detailed breakdown:

| Tab | What You'll See |
|---|---|
| **Assets** | Per-VM cost estimates with recommended machine types |
| **Machines** | Recommended GCP machine type and vCPU/RAM for each VM |
| **Storage** | Estimated persistent disk costs based on discovered disk profiles |
| **Licenses** | Windows licence cost modelling (BYOL vs. Google-provided) |

### Step 8.4 — View Report Metadata via REST API

```bash
# List all report configurations
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.reportConfigs[] | {name, displayName}'
```

```bash
# List reports within a report config
REPORT_CONFIG=$(curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq -r '.reportConfigs[0].name')

curl -s \
  "https://migrationcenter.googleapis.com/v1/${REPORT_CONFIG}/reports" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.reports[] | {displayName, type, state, createTime}'
```

### Step 8.5 — Generate a New Report (Optional)

To create a second report variation, trigger another generation run:

```bash
# Use the report config name retrieved above
REPORT_CONFIG_ID=$(basename "${REPORT_CONFIG}")

curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs/${REPORT_CONFIG_ID}/reports?reportId=lab-tco-report-v2" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "lab-tco-report-v2",
    "type": "TOTAL_COST_OF_OWNERSHIP"
  }'
```

The new report appears in **Migration Center → Reports** within 5 minutes.

---

## 13. Cleanup

Return to the RAD UI and click **Undeploy** on the `VM_Migration` deployment. This removes
the VPC network, Windows VM, Linux VMs, Cloud Storage bucket, and associated firewall rules.

> **Note:** Migration Center resources — discovery sources, import jobs, asset groups,
> preference sets, and reports — are created via REST API calls and are **not tracked** in
> Terraform state. Terraform destroy does not delete them. These resources must be removed
> manually via the Cloud Console or the REST API.

### Manual Cleanup — Migration Center Resources

**Delete asset groups:**
```bash
for GROUP_SUFFIX in all-assets windows-only linux-only; do
  GROUP_ID="migcenter-<deployment-id>-${GROUP_SUFFIX}"
  curl -s -X DELETE \
    "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups/${GROUP_ID}" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"
  echo "Deleted group: ${GROUP_ID}"
done
```

**Delete preference sets:**
```bash
for PREF_SUFFIX in aggressive-3yr moderate-1yr; do
  PREF_ID="migcenter-<deployment-id>-${PREF_SUFFIX}"
  curl -s -X DELETE \
    "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferencesSets/${PREF_ID}" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"
  echo "Deleted preference set: ${PREF_ID}"
done
```

**Delete report config (also deletes its associated reports):**
```bash
REPORT_CONFIG=$(curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq -r '.reportConfigs[0].name')

curl -s -X DELETE \
  "https://migrationcenter.googleapis.com/v1/${REPORT_CONFIG}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

**Delete discovery source:**
```bash
SOURCE_ID="migcenter-<deployment-id>-mc-source"
curl -s -X DELETE \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/sources/${SOURCE_ID}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

**Delete Compute resources (if Terraform undeploy fails):**
```bash
# Delete Windows VM
gcloud compute instances delete "${WINDOWS_VM}" \
  --zone="${ZONE}" --project="${PROJECT_ID}" --quiet

# Delete Linux VMs
gcloud compute instances list \
  --filter="name~migcenter AND name~linvm" \
  --project="${PROJECT_ID}" \
  --format="value(name,zone)" | while IFS=$'\t' read -r name zone; do
    gcloud compute instances delete "${name}" --zone="${zone}" --project="${PROJECT_ID}" --quiet
  done

# Delete VPC (firewall rules are deleted automatically with the VPC)
VPC_NAME=$(gcloud compute networks list \
  --filter="name~migcenter" --project="${PROJECT_ID}" --format="value(name)")
gcloud compute networks delete "${VPC_NAME}" --project="${PROJECT_ID}" --quiet
```

---

## 14. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `region` | string | `us-central1` | GCP region for all resources |
| `zone` | string | `us-central1-a` | GCP zone for Compute Engine VMs |
| `linux_vm_count` | number | `3` | Number of Debian Linux scan target VMs |
| `create_windows_vm` | bool | `true` | Deploy Windows Server 2022 VM with MCDCv6 |
| `windows_vm_machine_type` | string | `e2-medium` | Windows VM machine type |
| `windows_vm_boot_disk_size_gb` | number | `50` | Windows VM boot disk size in GB |
| `linux_vm_machine_type` | string | `e2-medium` | Linux VM machine type |
| `initialize_migration_center` | bool | `true` | Auto-initialise MC, source, AWS import |
| `import_aws_sample_data` | bool | `true` | Import AWS sample CSV data |
| `generate_reports` | bool | `true` | Create groups, preferences, and TCO report |
| `mc_discovery_client_name` | string | `mc-discovery-client` | MCDCv6 source name |
| `mc_report_name` | string | `lab-tco-report` | Name for the generated TCO report |

### Terraform Outputs

| Output | Description |
|---|---|
| `deployment_id` | Unique deployment suffix appended to all resource names |
| `project_id` | GCP project ID |
| `windows_vm_name` | Windows VM name |
| `windows_vm_external_ip` | External IP — use for RDP (user: `migrationcenter`, pass: `m1grat10nc#nt#r`) |
| `linux_vm_names` | List of Linux target VM names |
| `linux_vm_internal_ips` | List of Linux VM internal IPs — use to set MCDCv6 scan range |
| `ssh_key_bucket_name` | GCS bucket containing `lab-ssh-key.pem` |
| `ssh_key_user` | Linux SSH username: `migrationcenter` |
| `mc_discovery_client_name` | Source name to enter in MCDCv6 login |
| `migration_center_url` | Direct URL to Migration Center console for this project |
| `mc_source_id` | Migration Center discovery source resource ID |
| `vpc_name` | VPC network name |

### Troubleshooting

| Issue | Likely Cause | Resolution |
|---|---|---|
| RDP cannot connect | Windows startup script still running | Wait 3–5 min after Terraform completes; check serial port output |
| MCDCv6 OAuth fails | Google account lacks MC Admin role | Grant `roles/migrationcenter.admin` to the login account |
| MCDCv6 source name mismatch | Entered wrong name | Must exactly match `mc_discovery_client_name` output |
| SSH scan shows "Access Denied" | Wrong SSH key or username | Use `migrationcenter` user and `lab-ssh-key.pem` key |
| Linux VMs not discovered | IP range too narrow | Ensure range covers all IPs from `linux_vm_internal_ips` output |
| AWS import job pending/failed | API propagation delay | Check job state via REST API; may take up to 10 min |
| TCO report still generating | Reports take up to 5 min | Refresh Migration Center → Reports |
| `prevent_destroy` blocks destroy | Expected lifecycle policy | See SKILLS.md for full project decommission instructions |

### Useful Commands Reference

```bash
# List all Migration Center assets
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/assets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.assets[] | {name: (.name | split("/") | last), os: .machineDetails.guestOsDetails.osName}'

# List all import jobs and their states
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.importJobs[] | {displayName, state}'

# List all asset groups
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.groups[] | {displayName, name: (.name | split("/") | last)}'

# List all preference sets
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferencesSets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.preferencesSets[] | {displayName}'

# Windows VM external IP
gcloud compute instances list \
  --filter="name~migcenter AND name~winvm" \
  --project="${PROJECT_ID}" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# Linux VM internal IPs
gcloud compute instances list \
  --filter="name~migcenter AND name~linvm" \
  --project="${PROJECT_ID}" \
  --format="table(name, networkInterfaces[0].networkIP)"

# Check Windows VM startup script status (serial port output)
gcloud compute instances get-serial-port-output "${WINDOWS_VM}" \
  --zone="${ZONE}" --project="${PROJECT_ID}" | tail -30

# Verify GCP APIs are enabled
gcloud services list \
  --filter="config.name~migrationcenter OR config.name~compute OR config.name~storage" \
  --project="${PROJECT_ID}" \
  --format="table(config.name, state)"
```

### Further Reading

- [Google Cloud Migration Center overview](https://cloud.google.com/migration-center/docs/overview)
- [MC Discovery Client (MCDCv6) documentation](https://cloud.google.com/migration-center/docs/discovery-client-overview)
- [Migration Center REST API reference](https://cloud.google.com/migration-center/docs/reference/rest)
- [Total cost of ownership reports](https://cloud.google.com/migration-center/docs/create-tco-report)
- [Asset groups and preference sets](https://cloud.google.com/migration-center/docs/create-groups)
- [Importing data from AWS](https://cloud.google.com/migration-center/docs/import-aws-data)
- [Migration Center pricing](https://cloud.google.com/migration-center/pricing)
- [Committed use discounts on Compute Engine](https://cloud.google.com/compute/docs/instances/signing-up-committed-use-discounts)
