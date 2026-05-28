# Google Cloud Migration Center — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Migration_Center)**

This lab guide walks you through discovering, analysing, and planning a cloud migration using
**Google Cloud Migration Center** and the **Migration Center** module. You will connect to a
pre-configured Windows VM running the MC Discovery Client (MCDCv6), register it against the
Migration Center project that Terraform has already initialised, configure SSH-based discovery
of Debian Linux target VMs, review the discovered inventory alongside AWS EC2 data, and
generate and explore a TCO cost optimisation report.

The module automates every infrastructure and Migration Center configuration step. You complete
the Google OAuth login in MCDCv6, run the discovery scan, and then generate a report from the
console once the asset inventory is fully populated — ensuring the report reflects real data.

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
environments. It aggregates data from multiple discovery sources — agent-based scans (via the
MC Discovery Client), agentless network discovery, VMware vCenter integration, and manual CSV
imports from AWS, Azure, or on-premises tools — and produces inventory reports, dependency
maps, and total cost of ownership (TCO) projections.

> **Regional commitment:** When Migration Center is first initialised for a project (via the
> `initializeConfig` API call or from the Cloud Console), you select a GCP region where all
> assessment data will be stored. This choice is permanent — you cannot change the region
> without creating a new project. The module locks in the region specified in the `region`
> variable (default `us-central1`).

### Use Cases

| Use Case | Description |
|---|---|
| **Data centre inventory** | Automatically discover and catalogue all VMs across heterogeneous environments using agent-based scanning, agentless methods, VMware vCenter integration, or CSV import |
| **Cloud cost modelling** | Generate TCO projections comparing current infrastructure costs against GCP machine types, commitment plans, and licensing models |
| **Right-sizing** | Identify over-provisioned VMs and recommend appropriately sized GCP machine types based on actual utilisation data collected over time |
| **Multi-cloud assessment** | Import AWS (EC2), Azure, or on-premises inventory (RVTools, manual CSV) into a single unified inventory alongside live-scanned data |
| **Dependency analysis** | Map network connections between VMs to identify inter-VM dependencies, enabling informed migration wave sequencing |
| **Migration wave planning** | Group assets into logical waves based on dependency analysis, OS type, business unit, or criticality, then model cost scenarios per wave |
| **Fitness assessment** | Evaluate workloads for GCP compatibility and identify any re-platforming considerations before committing to migration |

### What This Lab Automates

| Step | Automated by Terraform | Manual Step Required |
|---|---|---|
| Initialise Migration Center service | Yes — `initializeConfig` REST API call | None |
| Register MCDCv6 discovery source | Yes — REST API `sources` | None |
| Import AWS EC2 inventory | **Conditional** — runs only when `aws_access_key_id` is provided; queries real EC2 instances | If no credentials: manually import the pre-staged sample CSV zip in Exercise 5 |
| Create asset groups | **No** | **You create these in Exercise 6** |
| Create preference sets | **No** | **You create these in Exercise 7** |
| Generate TCO report | **No — requires fully populated inventory** | **You generate this in Exercise 8** |
| Install MCDCv6 on Windows VM | Yes — PowerShell startup script | None |
| Pre-stage AWS sample CSV zip | Yes — startup script downloads to `Downloads\vm-aws-import-files\` | None |
| Google OAuth login in MCDCv6 | **No — requires browser-based login** | **You complete this in Exercise 2** |
| Configure SSH credential in MCDCv6 | **No** | **You complete this in Exercise 3** |
| Configure IP scan range | **No** | **You complete this in Exercise 4** |

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
│  │  │  migcenter-{id}-winvm01      │  │  migcenter-{id}-linvm-1      │   │  │
│  │  │  e2-medium                   │  │  migcenter-{id}-linvm-2      │   │  │
│  │  │  • MCDCv6 pre-installed      │  │  migcenter-{id}-linvm-3      │   │  │
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
│  │  Discovery Source: migcenter-{id}-mc-source (SOURCE_TYPE_DISCOVERY_CLIENT)  │  │
│  │                    ↓ MCDCv6 scan results (after manual OAuth + scan)   │  │
│  │                    ↓ EC2 import (real AWS data, if credentials given)  │  │
│  │  Asset Inventory:  Debian Linux VMs + AWS VMs (real or sample data)   │  │
│  │                                                                        │  │
│  │  Groups, Preferences, Reports: ← created as hands-on lab exercises    │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  Migration_Center
    region                      = "us-central1"         →  All resources in this region
    zone                        = "us-central1-a"        →  Compute Engine zone
    linux_vm_count              = 3                      →  3 Debian Linux scan targets
    create_windows_vm           = true                   →  Windows MCDCv6 host
    initialize_migration_center = true                   →  Initialise MC service + register discovery source
    aws_access_key_id           = "<key>"                →  (Optional) bootstrap creds → scoped IAM user + EC2 import
    mc_discovery_client_name    = "mc-discovery-client"  →  Source name entered in MCDCv6 during login
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

Deploy the `Migration Center` module via the RAD UI. In the variable form, set:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `region` | `us-central1` | GCP region for all resources |
| `zone` | `us-central1-a` | GCP zone for Compute Engine VMs |
| `linux_vm_count` | `3` | Number of Debian Linux scan targets |
| `initialize_migration_center` | `true` | Auto-initialise MC service and register discovery source |
| `aws_access_key_id` | *(optional)* | Bootstrap AWS credentials — module creates scoped IAM user and imports EC2 inventory |
| `aws_secret_access_key` | *(optional)* | AWS Secret Key corresponding to the Access Key ID |
| `mc_discovery_client_name` | `mc-discovery-client` | Source name to enter in MCDCv6 |

Click **Deploy** and wait for provisioning to complete.

> **Note:** Terraform provisioning takes approximately **5–8 minutes**. The Windows VM startup
> script (MCDCv6 install + Chrome download) runs in the background after the VM boots and takes
> an additional **3–5 minutes**. Wait for the startup script to finish before starting Exercise 2.

> **What this provisions:** A VPC with firewall rules, a Windows Server 2022 VM with MCDCv6
> pre-installed, three Debian 12 Linux VMs, a Cloud Storage bucket containing an SSH private
> key, and a fully configured Migration Center environment including a registered discovery
> source, AWS EC2 inventory import (if credentials provided), pre-created asset groups, and
> migration preference sets. TCO report generation is a manual step performed after discovery.

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
capacity, installed packages, running processes, and open network ports collected by MCDCv6.

> **Performance data and right-sizing accuracy:** The single scan you just ran captures a
> point-in-time snapshot of CPU and memory utilisation. In a real assessment engagement,
> MCDCv6 is typically left running for **2–4 weeks** with scheduled recurring scans to build
> a utilisation history. Migration Center uses this history to produce statistically-grounded
> right-sizing recommendations — peak utilisation from a single scan often understates actual
> workload demand, leading to under-provisioned GCP machine type suggestions. For the purposes
> of this lab, a single scan is sufficient to populate the inventory and generate a TCO report.

### Step 4.6 — Explore Network Connections (Dependency Mapping)

MCDCv6 also records the active network connections on each scanned VM — which ports are
listening and which remote IPs have established connections. This data underpins Migration
Center's **dependency analysis** capability, which identifies inter-VM communication patterns
for migration wave planning.

In the asset detail view, click the **Open ports** tab to see the listening TCP/UDP ports and
the process bound to each. In a multi-tier application environment, this view reveals which
VMs are fronting web traffic, which are database servers, and which VMs depend on each other
— critical information for grouping assets into coherent migration waves rather than migrating
them one by one and breaking application connectivity.

---

## Exercise 5 — Review AWS Data and All Assets

### Objective

Understand the AWS inventory data in Migration Center alongside the live Linux VM scan results.
Depending on whether AWS credentials were provided at deployment time, this data arrives via
automatic import or manual upload.

### Step 5.1 — Check Whether the AWS Import Job Ran Automatically

If `aws_access_key_id` was provided during deployment, Terraform queried your AWS EC2 inventory
and submitted an import job to Migration Center.

**Cloud Console:**
Navigate to **Migration Center → Data Sources** and look for an import job. The status should
show **Completed** (or **Completed with warnings** if any optional fields were absent from the
generated CSV).

**REST API — list import jobs:**
```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.importJobs[] | {displayName, state, createTime}'
```

If no import jobs appear, proceed to Step 5.1a to manually import the pre-staged sample data.

### Step 5.1a — Manually Import Sample CSV Data (if no AWS credentials were provided)

The Windows VM startup script pre-staged a sample AWS CSV export to
`C:\Users\migrationcenter\Downloads\vm-aws-import-files\`. This folder contains four CSV files
(`vmInfo.csv`, `diskInfo.csv`, `tagInfo.csv`, `perfInfo.csv`) representing a simulated AWS VM
inventory that you can import manually.

**From the Windows VM — Cloud Console:**

1. Open Chrome and navigate to the Migration Center console for your project
2. Click **Data Sources → Add source**
3. Select **Uploads**
4. Give the source a name (e.g. `aws-sample-import`)
5. Under **File format**, select **AWS VM export**
6. Click **Upload files** and select all CSV files from
   `C:\Users\migrationcenter\Downloads\vm-aws-import-files\`
7. Click **Import** and wait for the job to complete

**REST API — alternative approach via the Windows VM PowerShell or your local machine:**
```bash
TOKEN=$(gcloud auth print-access-token)

# Create a new import job
IMPORT_JOB_ID="manual-aws-import-$(date +%s)"
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs?importJobId=${IMPORT_JOB_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"displayName\": \"aws-sample-import\", \"assetSource\": \"projects/${PROJECT_ID}/locations/${REGION}/sources/${MC_SOURCE_ID}\"}" \
  | jq '{name, state}'

# Upload each CSV file
for FILE in vmInfo diskInfo tagInfo perfInfo; do
  curl -s -X POST \
    "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs/${IMPORT_JOB_ID}/importDataFiles?importDataFileId=${FILE}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: text/csv" \
    --data-binary "@${FILE}.csv" \
    | jq '{name, state}'
done

# Validate and run
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs/${IMPORT_JOB_ID}:validate" \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d '{}'
sleep 30
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/importJobs/${IMPORT_JOB_ID}:run" \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d '{}'
```

### Step 5.2 — Explore the Full Asset Inventory

In Migration Center → **Assets** → **Virtual Machines**. You should now see:

- **3 Debian Linux VMs** — discovered by MCDCv6 scan (your lab VMs, rich with OS and process data)
- **AWS VMs** — from the CSV import (real EC2 instances or the sample dataset), with hardware
  profile and tag data but no guest-OS-level detail (no package lists, no running processes)

This contrast illustrates a key Migration Center concept: **depth of inventory data varies by
discovery method**. Agent-based scanning (MCDCv6) provides comprehensive guest OS data
including installed software and open ports; CSV import provides hardware inventory and tags
but no live OS insight.

Use the search and filter controls to explore:

- **Filter by OS type:** Compare the Windows/Linux AWS VMs against the Debian scan targets
- **Filter by source:** Distinguish MCDCv6 scan results from the CSV import source
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

## Exercise 6 — Create Asset Groups

### Objective

Create three asset groups that organise the discovered inventory into logical sets, then add
assets to each group. Groups are required inputs when generating a TCO report in Exercise 8.

Set your deployment ID in the shell before starting:
```bash
export DEPLOYMENT_ID="<your-deployment-id>"   # from Terraform output deployment_id
```

### Step 6.1 — Create Groups via REST API

```bash
TOKEN=$(gcloud auth print-access-token)

create_group() {
  local GROUP_ID="$1"
  local DISPLAY_NAME="$2"
  curl -s -X POST \
    "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups?groupId=${GROUP_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"displayName\": \"${DISPLAY_NAME}\"}" \
    | jq '{name, displayName}'
}

create_group "migcenter-${DEPLOYMENT_ID}-all-assets"    "All Assets"
create_group "migcenter-${DEPLOYMENT_ID}-windows-only"  "windows-only"
create_group "migcenter-${DEPLOYMENT_ID}-linux-only"    "linux-only"
```

**Cloud Console alternative:**
Navigate to **Migration Center → Groups** → **Create group**, enter the display name, and click **Create**.

### Step 6.2 — Verify Groups Were Created

```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.groups[] | {displayName, name: (.name | split("/") | last)}'
```

You should see three groups: `All Assets`, `windows-only`, `linux-only`.

### Step 6.3 — Add Assets to Groups

In **Migration Center → Assets**, select one or more VMs by checking their checkboxes, then
click **Add to group** and select the appropriate group. Repeat for each group.

**REST API — add an asset to a group:**
```bash
TOKEN=$(gcloud auth print-access-token)
GROUP_ID="migcenter-${DEPLOYMENT_ID}-all-assets"
ASSET_RESOURCE="projects/${PROJECT_ID}/locations/${REGION}/assets/<asset-id>"

curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups/${GROUP_ID}:addAssets" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"assets\": [{\"asset\": \"${ASSET_RESOURCE}\"}]}" \
  | jq '{done}'
```

**REST API — list assets in a group:**
```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/groups/migcenter-${DEPLOYMENT_ID}-linux-only/assets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.assets[].name'
```

---

## Exercise 7 — Create Migration Preference Sets

### Objective

Create two migration preference sets that model different cost optimisation strategies. These
preference sets are paired with asset groups when generating the TCO report in Exercise 8.

### Step 7.1 — Understand the Two Strategies

| Preference Set | Machine Series | Sizing Strategy | Commitment | Best For |
|---|---|---|---|---|
| **aggressive-optimization-3-year-commit** | N2, N2D | Aggressive — shrinks to actual observed peak utilisation | 3-year CUD (~57% discount on N2) | Stable, predictable workloads where right-sizing risk is low |
| **moderate-optimization-1-year-commit** | C2, C2D + SSD | Moderate — keeps 20–30% headroom above observed peak | 1-year CUD | Variable or spiky workloads where over-sizing avoidance is critical |

> **Why two strategies?** Right-sizing based on a short observation window risks under-provisioning
> production workloads. Presenting both an aggressive and a moderate estimate in a business case
> gives stakeholders a cost range: the aggressive figure shows the theoretical minimum if all VMs
> are perfectly right-sized; the moderate figure is a safer planning number. In practice, most
> migrations land somewhere between the two as teams gain confidence in workload characterisation.
>
> **Machine series choice:** N2/N2D are cost-optimised general-purpose machines suited to most
> workloads. C2/C2D are compute-optimised with higher per-core performance but at a higher base
> price — they are more appropriate for CPU-intensive workloads. The SSD disk type in the
> moderate preset adds cost but is realistic for database and I/O-sensitive workloads.

### Step 7.2 — Create Preference Sets via REST API

```bash
TOKEN=$(gcloud auth print-access-token)

echo "Creating aggressive-optimization-3-year-commit..."
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferenceSets?preferenceSetId=migcenter-${DEPLOYMENT_ID}-aggressive-3yr" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "aggressive-optimization-3-year-commit",
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
  }' | jq '{name, displayName}'

echo "Creating moderate-optimization-1-year-commit..."
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferenceSets?preferenceSetId=migcenter-${DEPLOYMENT_ID}-moderate-1yr" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "moderate-optimization-1-year-commit",
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
  }' | jq '{name, displayName}'
```

**Cloud Console alternative:**
Navigate to **Migration Center → Migration preferences** → **Create preference set** and fill
in the machine series, sizing strategy, and commitment plan fields.

### Step 7.3 — Verify Preference Sets

```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferenceSets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.preferenceSets[] | {
      displayName,
      sizingStrategy: .virtualMachinePreferences.sizingOptimizationStrategy,
      commitmentPlan: .virtualMachinePreferences.commitmentPlan
    }'
```

---

## Exercise 8 — Generate and View the TCO Report

### Objective

Create a report configuration, trigger TCO report generation, and explore how Migration Center
projects GCP costs for each asset group under both preference scenarios. This exercise is
intentionally performed after the MCDCv6 scan so the report reflects the full asset inventory.

> **Why now?** Generating a report at deploy time would produce an incomplete snapshot because
> MCDCv6 discovery data arrives only after the manual OAuth login and scan in Exercises 2–4.
> The asset groups and preference sets were pre-created by Terraform — you only need to
> trigger the report itself.

### Step 8.1 — Create a Report Configuration

A report configuration defines which groups and preference sets to compare. Create one via
the Cloud Console or the REST API.

**Cloud Console:**
1. Navigate to **Migration Center → Reports**
2. Click **Create report**
3. Give it a display name (e.g. `lab-tco-report`)
4. Under **Groups and preferences**, add the following assignments:

| Group | Preference set |
|---|---|
| All Assets (`migcenter-<id>-all-assets`) | aggressive-3yr (`migcenter-<id>-aggressive-3yr`) |
| windows-only (`migcenter-<id>-windows-only`) | moderate-1yr (`migcenter-<id>-moderate-1yr`) |
| linux-only (`migcenter-<id>-linux-only`) | moderate-1yr (`migcenter-<id>-moderate-1yr`) |

5. Click **Create** — Migration Center generates the report (allow up to 5 minutes)

**REST API — create report config and trigger report:**
```bash
DEPLOYMENT_ID="<your-deployment-id>"   # from Terraform output deployment_id

REPORT_CONFIG_ID="migcenter-${DEPLOYMENT_ID}-report-config"

# Create the report configuration
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs?reportConfigId=${REPORT_CONFIG_ID}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"displayName\": \"lab-report-config\",
    \"groupPreferencesetAssignments\": [
      {
        \"group\": \"projects/${PROJECT_ID}/locations/${REGION}/groups/migcenter-${DEPLOYMENT_ID}-all-assets\",
        \"preferenceSet\": \"projects/${PROJECT_ID}/locations/${REGION}/preferenceSets/migcenter-${DEPLOYMENT_ID}-aggressive-3yr\"
      },
      {
        \"group\": \"projects/${PROJECT_ID}/locations/${REGION}/groups/migcenter-${DEPLOYMENT_ID}-windows-only\",
        \"preferenceSet\": \"projects/${PROJECT_ID}/locations/${REGION}/preferenceSets/migcenter-${DEPLOYMENT_ID}-moderate-1yr\"
      },
      {
        \"group\": \"projects/${PROJECT_ID}/locations/${REGION}/groups/migcenter-${DEPLOYMENT_ID}-linux-only\",
        \"preferenceSet\": \"projects/${PROJECT_ID}/locations/${REGION}/preferenceSets/migcenter-${DEPLOYMENT_ID}-moderate-1yr\"
      }
    ]
  }" | jq '{name, displayName}'
```

```bash
# Generate a TCO report from the config
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs/${REPORT_CONFIG_ID}/reports?reportId=migcenter-${DEPLOYMENT_ID}-tco" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "lab-tco-report",
    "type": "TOTAL_COST_OF_OWNERSHIP"
  }' | jq '{name, displayName, state}'
```

### Step 8.2 — Wait for the Report to Complete

Report generation typically takes **2–5 minutes**. Poll the status:

```bash
curl -s \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs/${REPORT_CONFIG_ID}/reports" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.reports[] | {displayName, state, createTime}'
```

Wait until `state` shows `SUCCEEDED`.

### Step 8.3 — Explore the Report Summary

Open **Migration Center → Reports** in the Cloud Console and click on `lab-tco-report`.

On the overview page, review:

1. **Total estimated monthly GCP cost** — combined projection across all groups
2. **Cost breakdown by group** — All Assets vs. windows-only vs. linux-only sections
3. **Preference set comparison** — side-by-side aggressive-3yr vs. moderate-1yr cost estimates

### Step 8.4 — Explore the Detailed Report

Click **View report** to open the detailed breakdown:

| Tab | What You'll See |
|---|---|
| **Assets** | Per-VM cost estimates with recommended machine types, grouped by the asset group each VM belongs to |
| **Machines** | Recommended GCP machine type and vCPU/RAM for each VM based on the preference set's sizing strategy |
| **Storage** | Estimated persistent disk costs based on discovered disk capacity and the preference set's disk type |
| **Licenses** | Windows licence cost modelling — compares Google-provided licences against BYOL (Bring Your Own Licence) |

**Key observations to make:**

- Compare the per-VM machine type recommendations between the aggressive and moderate scenarios.
  Notice how the aggressive strategy maps VMs to smaller machine types (lower vCPU/RAM) based
  on observed peak utilisation, while the moderate strategy suggests larger types with headroom.
- Look at the **Licenses** tab for any Windows VMs. Migration Center distinguishes between
  Google-provided Windows licences (included in the VM price) and BYOL — for enterprises with
  existing Microsoft volume agreements, BYOL can significantly reduce the per-VM cost estimate.
- Notice that VMs from the CSV import have less precise recommendations than MCDCv6-scanned VMs,
  because the import data includes disk and hardware specs but no utilisation history.

### Step 8.5 — Generate a Second Report Variation (Optional)

Repeat the generation step with a different report ID to compare results after further
discovery data arrives:

```bash
curl -s -X POST \
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/reportConfigs/${REPORT_CONFIG_ID}/reports?reportId=migcenter-${DEPLOYMENT_ID}-tco-v2" \
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

Return to the RAD UI and click **Undeploy** on the `Migration Center` deployment. This removes
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
    "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferenceSets/${PREF_ID}" \
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
| `initialize_migration_center` | bool | `true` | Auto-initialise MC service and register discovery source |
| `aws_access_key_id` | string | `""` | Bootstrap AWS credentials — module creates scoped IAM user and imports EC2 inventory |
| `aws_secret_access_key` | string | `""` | AWS Secret Key corresponding to the Access Key ID |
| `aws_region` | string | `us-east-1` | AWS region for EC2 discovery |
| `mc_discovery_client_name` | string | `mc-discovery-client` | MCDCv6 source name |

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
| TCO report still generating | Reports take up to 5 min after triggering | Refresh Migration Center → Reports; poll via REST API until state = SUCCEEDED |
| `prevent_destroy` blocks destroy | Expected lifecycle policy | Delete resources manually via the Cloud Console or contact platform support |

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
  "https://migrationcenter.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/preferenceSets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.preferenceSets[] | {displayName}'

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
