# Migration Center Assessment Lab Guide

## Overview

This guide walks through the full Migration Center assessment lab using the
`VM_Migration` Terraform module. The module automates all GCP infrastructure
setup and Migration Center configuration. Your hands-on work focuses on using
the MC Discovery Client (MCDCv6) and exploring the populated Migration Center
console.

**Estimated time:** 45–60 minutes (infrastructure deploys in ~5 minutes)

### What Terraform Automates

- Enabling all required GCP APIs
- Creating the VPC network and firewall rules (SSH, RDP, ICMP, internal, HTTP)
- Deploying the Windows Server 2022 VM with MCDCv6 pre-installed
- Creating the `migrationcenter` Windows user and enabling RDP
- Pre-downloading the AWS sample import files to the Windows VM
- Deploying three Debian Linux VMs as discovery scan targets
- Generating an SSH key pair and storing the private key in Cloud Storage
- Initializing the Migration Center service
- Creating a discovery source (MC Discovery Client registration)
- Importing sample AWS CSV data into Migration Center
- Creating asset groups (All Assets, windows-only, linux-only)
- Creating migration preferences (aggressive 3-year, moderate 1-year)
- Triggering TCO report generation

### What You Do Manually

- Connecting via RDP to the Windows VM
- Completing the Google OAuth login in MCDCv6 (browser-based, cannot be automated)
- Configuring OS credentials and SSH key in MCDCv6
- Running the IP range discovery scan
- Exploring assets, reports, and groups in the Migration Center console

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| GCP Project | Must already exist with billing enabled |
| Terraform service account | Must hold `roles/owner` on the target project |
| Caller permissions | Must hold `roles/iam.serviceAccountTokenCreator` on the SA above |
| RDP client | Windows built-in Remote Desktop, or any third-party RDP client |

> **Mac/Chromebook users:** Use a third-party RDP client such as
> [Microsoft Remote Desktop](https://apps.apple.com/app/microsoft-remote-desktop/id1295203466)
> or [Spark View](https://www.spark-view.com/) since the GCP Console RDP
> button requires the Chrome browser extension.

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/VM_Migration
```

Create a `terraform.tfvars` file with your project settings:

```hcl
project_id = "your-project-id"
region     = "us-central1"
zone       = "us-central1-a"
```

All other variables use sensible defaults. Override only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `project_id` | *(required)* | GCP project ID where all resources are created |
| `region` | `us-central1` | Region for all resources and Migration Center |
| `zone` | `us-central1-a` | Zone for Compute Engine instances |
| `linux_vm_count` | `3` | Number of Linux VMs to deploy as scan targets |
| `mc_discovery_client_name` | `mc-discovery-client` | Name to enter in MCDCv6 during login |
| `mc_report_name` | `lab-tco-report` | Name of the generated TCO report |

### Step 1.2 — Deploy

```bash
tofu init
tofu apply
```

Deployment takes approximately 3–5 minutes. Note the outputs — you will use
them throughout the lab.

```
Outputs:

windows_vm_external_ip    = "34.x.x.x"
windows_vm_name           = "altostrat-ab12-winvm01"
linux_vm_internal_ips     = ["10.128.0.2", "10.128.0.3", "10.128.0.4"]
ssh_key_bucket_name       = "altostrat-ab12-mc-keys"
ssh_key_user              = "migrationcenter"
mc_discovery_client_name  = "mc-discovery-client"
migration_center_url      = "https://console.cloud.google.com/migration/center?project=..."
```

---

## Phase 2 — Connect to the Windows VM [MANUAL]

### Step 2.1 — RDP into the Windows VM

Open your RDP client and connect to the external IP from the Terraform output:

| Field | Value |
|---|---|
| Host | `windows_vm_external_ip` (from output) |
| Username | `migrationcenter` |
| Password | Fetch from Secret Manager (`windows_vm_password_secret_id`) |

> **Note:** The startup script runs on first boot. If MCDCv6 is not yet on
> the desktop, wait 2–3 minutes and reconnect.

---

## Phase 3 — Launch MCDCv6 and Login [MANUAL]

The MC Discovery Client shortcut is on the Windows desktop after the startup
script completes.

### Step 3.1 — Launch MCDCv6

1. Double-click the **Migration Center Discovery Client** shortcut on the desktop.
2. Click **Yes** when prompted by User Account Control.

### Step 3.2 — Login to Migration Center

1. Click **Log in to Migration Center**.
2. The connectivity check completes automatically — click **Next**.
3. Under **Log in with Google**, click **Login with Google**.
4. A Chrome browser window opens. Sign in with the Google Cloud account that
   owns the project.
5. Under **Choose a Google Cloud Project**, select your project from the dropdown.
6. Click **Continue**.
7. Under **Add an access key**, click **Continue** (the key was pre-created by Terraform).
8. Under **Add a discovery client name**, enter exactly:

   ```
   mc-discovery-client
   ```

   > This must match the `mc_discovery_client_name` Terraform variable (default: `mc-discovery-client`).

9. Click **Finish**.

---

## Phase 4 — Configure Asset Collection [MANUAL]

### Step 4.1 — Add Windows OS Credentials

1. On the MCDCv6 overview page, click **Add OS credentials** (bottom left).
2. Enter the following values:

   | Field | Value |
   |---|---|
   | Name for the credentials | `Lab` |
   | Credential type | `Username and Password` |
   | Username | `migrationcenter` |
   | Password | Fetch from Secret Manager (`windows_vm_password_secret_id`) |

3. Click **Save**.

### Step 4.2 — Download and Add SSH Key

The SSH private key was automatically stored in Cloud Storage by Terraform.

1. Open Chrome on the Windows VM and browse to:
   ```
   https://console.cloud.google.com/storage/browser
   ```
2. Locate the bucket named with your deployment ID (shown in the `ssh_key_bucket_name` output).
3. Click the bucket, find `lab-ssh-key.pem`, and click the **Download** icon.
4. Return to the MCDCv6 overview page.
5. Click **Add Credentials** → **Add OS Credentials**.
6. Enter the following values:

   | Field | Value |
   |---|---|
   | Name for the credentials | `Lab-key` |
   | Credential type | `SSH Key / Certificate (Linux Only)` |
   | Username for this key | `migrationcenter` |
   | Key file | Browse and select the `lab-ssh-key.pem` file downloaded above |

7. Click **Save**.

### Step 4.3 — Add IP Scan Range

1. In MCDCv6, click the **Discovery** tab → **IP addresses** → **Add IP addresses** → **Add ranges manually**.
2. Accept the scan warning by checking **I agree** and clicking **Accept**.
3. Using the Linux VM internal IPs from the Terraform output (e.g., `10.128.0.2` through `10.128.0.4`):
   - **Beginning IP:** Use the first three octets + `.1` (e.g., `10.128.0.1`)
   - **Ending IP:** Use the first three octets + `.8` (e.g., `10.128.0.8`)
4. Click **Save**. The scan starts immediately and completes in ~2 minutes.

### Step 4.4 — Verify Discovery

1. Click the **Servers** tab and confirm the Linux VMs appear in the list.
2. Click a server name → **Scans** tab → verify **Upload Status** shows `Sent`.
   - `Sent` means assets were successfully exported to Migration Center.
   - If `Pending`, wait 2–3 minutes and refresh.

---

## Phase 5 — Review Assets in Migration Center [MANUAL]

All steps in this phase are performed in the **Migration Center** console, not
in MCDCv6. Browse to the URL from the `migration_center_url` output.

### Step 5.1 — View Asset Inventory

1. From the Navigation menu, select **Migration Center** → **Assets**.
2. The list includes both live-scanned Linux VMs and the imported AWS VMs.
3. Click any VM name to view asset details.
4. Switch between tabs: **Insights**, **Source VM Details**, **Metadata**, **Performance data**.

> Performance data is available for live-scanned VMs only, not AWS-imported assets.

### Step 5.2 — Mark Assets Out of Scope

1. Select one or more assets from the list.
2. Click **Out of scope**, provide a reason (e.g., `Old Servers`), and confirm.
3. View out-of-scope assets in the **Out of Scope** tab.
4. Select those assets and click **Put back in scope** to restore them.

---

## Phase 6 — Generate Reports [MANUAL/AUTOMATED]

Terraform pre-generated the TCO report and group structure. This phase walks
through the console to explore the generated data and produce additional exports.

### Step 6.1 — Inventory and Performance Export

1. Navigate to **Migration Center** → **Create Reports**.
2. Select **Assets Details Export**.
3. Click the **Servers** tab, select all servers, click **Export to CSV/Google Sheets**.
4. Click **Export to Google Sheets** in the popup and wait for completion.
5. Click **Open spreadsheet** to view the exported inventory.
6. Repeat with **Performance data export** tile for performance metrics.

### Step 6.2 — Review the TCO Report (Pre-Generated)

1. Navigate to **Migration Center** → **Create Reports**.
2. The `lab-tco-report` appears in the list (generated by Terraform, allow up to 5 minutes).
3. Click the report name to view the detailed pricing breakdown.
4. Click **Export report** → **Export detailed pricing report to CSV/Google Sheets**.

### Step 6.3 — Network Dependencies Export (Optional)

1. Navigate to **Migration Center** → **Create Reports**.
2. Select **Network Dependencies Export**.
3. Select all groups (All Assets, windows-only, linux-only).
4. Click **Export to CSV** → **Export** and wait for generation.
5. Click **Download** to retrieve the CSV.

---

## REST API Reference

All Migration Center operations can also be performed via the REST API at
`https://migrationcenter.googleapis.com/v1`. Set these variables once:

```bash
export TOKEN=$(gcloud auth print-access-token)
export BASE="https://migrationcenter.googleapis.com/v1"
export PROJECT="your-project-id"
export REGION="us-central1"
```

**Initialize Migration Center:**
```bash
curl -X POST "$BASE/projects/$PROJECT/locations/$REGION:initializeConfig" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'
```

**List assets:**
```bash
curl -s "$BASE/projects/$PROJECT/locations/$REGION/assets" \
  -H "Authorization: Bearer $TOKEN" | jq '.assets[].name'
```

**List groups:**
```bash
curl -s "$BASE/projects/$PROJECT/locations/$REGION/groups" \
  -H "Authorization: Bearer $TOKEN" | jq '.groups[].displayName'
```

**List reports:**
```bash
curl -s "$BASE/projects/$PROJECT/locations/$REGION/reportConfigs" \
  -H "Authorization: Bearer $TOKEN" | jq '.reportConfigs[].displayName'
```

---

## Troubleshooting

| Issue | Resolution |
|---|---|
| MCDCv6 not on desktop after RDP | Wait 3–5 minutes for the startup script to complete, then reconnect |
| MCDCv6 connectivity check fails | Confirm the Windows VM has an external IP and port 443 outbound is open |
| Scan shows no servers | Verify the IP range covers the Linux VM IPs from the `linux_vm_internal_ips` output |
| Upload Status stays Pending | Wait up to 5 minutes; MCDCv6 uploads every few minutes automatically |
| SSH key authentication fails | Confirm the `Lab-key` credential uses username `migrationcenter` and the PEM file from the GCS bucket |
| TCO report not visible | Reports take up to 5 minutes after Terraform apply; refresh the page |
| AWS assets not in inventory | The import job runs asynchronously; check status under Migration Center → Discover Assets |

---

## Cleanup

To destroy all resources:

```bash
tofu destroy
```

> Migration Center data (groups, preferences, reports, import jobs) is not
> managed by Terraform state and must be deleted manually from the console,
> or will be cleaned up when the GCP project is deleted.

---

*Last tested: Tue May 27, 2026*
