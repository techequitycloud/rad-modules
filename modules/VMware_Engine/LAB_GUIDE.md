# Migrate to Virtual Machines v5 — Lab Guide

## Overview

This guide walks through the full Migrate to Virtual Machines v5 lab using the
`VMware_Engine` Terraform module. The module automates the Google Cloud
infrastructure setup. Everything inside vSphere and NSX-T, and all Migrate to
Virtual Machines console operations, are performed manually.

**Estimated time:** 2–3 hours (includes ~150 minutes of background provisioning)

### What Terraform Automates

- Enabling required GCP APIs
- Creating the VMware Engine Network and Private Cloud
- Configuring VPC Network Peering (GCVE ↔ your VPC)
- Creating the Network Policy (internet access and external IPs)
- Creating default VPC firewall rules (SSH, RDP, ICMP, internal, HTTP/HTTPS)
- Deploying the Windows Server 2022 jump host
- Resetting vCenter solution user credentials

### What You Do Manually

- Setting the Windows password and connecting via RDP
- All vCenter and NSX-T operations (segments, OVA deployments, powering on VMs)
- Deploying and registering the Migrate Connector
- All Migrate to Virtual Machines operations (replication, test clones, cut-over)

---

## REST API Overview

Every action in this lab can be performed via the VM Migration REST API
(`vmmigration.googleapis.com/v1`) as an alternative to the Cloud Console UI.
API equivalents are shown after each relevant step.

**Base URL:** `https://vmmigration.googleapis.com/v1`

**Set these shell variables once before running any API command:**

```bash
export TOKEN=$(gcloud auth print-access-token)
export BASE="https://vmmigration.googleapis.com/v1"
export PROJECT="your-project-id"
export REGION="us-west2"
export SOURCE_ID="migrate-vsphere"
```

**All mutating operations return a long-running Operation. Poll for completion:**

```bash
curl -s "$BASE/projects/$PROJECT/locations/$REGION/operations/OPERATION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.done, .error'
```

`done: true` with no `error` means the operation succeeded.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| GCP Project | Must already exist with billing enabled |
| Terraform resource provisioning Service Account | Must hold `roles/owner` on the target project. |
| Caller permissions | The identity running `tofu apply` must hold `roles/iam.serviceAccountTokenCreator` on the service account above |
| RDP client | Windows built-in Remote Desktop, or any third-party RDP client |
| PuTTY + PuTTYgen | Required for Migrate Connector SSH key setup — pre-installed on the Windows jump host |

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/VMware_Engine
```

Create a `terraform.tfvars` file with the following inputs. All values shown are
the module defaults — override only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `existing_project_id` | *(required — no default)* | GCP project ID where all resources are created |
| `region` | `us-west2` | Region for the private cloud and network policy |
| `zone` | `us-west2-a` | Zone for the private cloud and jump host |
| `vmware_engine_network_name` | `altostrat-<id>-ven` | Auto-scoped to deployment ID. Must start with `altostrat-` if overridden |
| `private_cloud_name` | `altostrat-<id>-private-cloud` | Auto-scoped to deployment ID. Must start with `altostrat-` if overridden |
| `management_cidr` | `172.20.0.0/24` | Immutable after creation — plan carefully; must not overlap with peer VPC or edge services CIDR |
| `private_cloud_type` | `TIME_LIMITED` | `TIME_LIMITED` = single-node evaluation cloud (lab use); `STANDARD` = production (minimum 3 nodes) |
| `node_type_id` | `standard-72` | API identifier for the node type. Note: the GCP console displays this as `ve1-standard-72` but the API and Terraform require `standard-72` |
| `node_count` | `1` | Set to 1 for `TIME_LIMITED`; minimum 3 for `STANDARD` |
| `network_peering_name` | `altostrat-<id>-vpc-ven` | Auto-scoped to deployment ID |
| `peer_vpc_name` | `altostrat-<id>-vpc` | Auto-scoped to deployment ID |
| `network_policy_name` | `altostrat-<id>-edge-policy` | Auto-scoped to deployment ID |
| `edge_services_cidr` | `10.11.2.0/26` | Must not overlap with `management_cidr` or the peer VPC subnets |
| `enable_internet_access` | `true` | Enables internet egress from workload VMs |
| `enable_external_ip` | `true` | Enables external IP allocation for workload VMs |
| `create_default_firewall_rules` | `true` | Set to `false` if the four default rules already exist on the peer VPC |
| `internal_traffic_cidr` | `10.128.0.0/9` | Source range for the allow-internal rule; matches auto-mode VPC default |
| `create_jump_host` | `true` | Deploys the Windows Server 2022 jump host |
| `jump_host_name` | `jump-host` | Name of the jump host VM instance |
| `jump_host_machine_type` | `e2-medium` | Machine type for the jump host |
| `jump_host_boot_disk_size_gb` | `50` | Minimum 50 GB for Windows Server 2022 |
| `reset_vcenter_credentials` | `true` | Resets and retrieves vCenter solution user credentials after provisioning |
| `vcenter_solution_user` | `solution-user-01@gve.local` | vCenter solution user used for Migrate Connector integration |
| `resource_creator_identity` | *(not required if using cloud shell)* | Service account used by terraform to provision resources |

Minimum `terraform.tfvars` example:

```hcl
existing_project_id = "your-project-id"
```

### Step 1.2 — Initialise and Deploy

```bash
tofu init
tofu validate
tofu plan -out=plan.tfplan
tofu apply plan.tfplan
```

**Expected duration:**

| Resource | Typical time |
|---|---|
| API enablement | 1–2 minutes |
| VMware Engine Network | 1–2 minutes |
| Jump host + firewall rules | 2–3 minutes |
| Private Cloud | 120–180 minutes |
| Network Peering (activation) | Up to 5 minutes after private cloud is ready |
| Network Policy (internet activation) | Up to 15 minutes after private cloud is ready |
| vCenter credential reset | 1–2 minutes after private cloud is ready |

> The `tofu apply` command will not return until the private cloud is fully
> provisioned. Allow up to 90 minutes.

### Step 1.3 — Record Terraform Outputs

When `apply` completes, note the following outputs — you will use them
throughout the rest of the lab:

```bash
tofu output
```

| Output | Used in |
|---|---|
| `vcenter_fqdn` | Phase 3 — vCenter login URL |
| `nsx_fqdn` | Phase 3 — NSX-T Manager login URL |
| `hcx_fqdn` | Reference only |
| `network_peering_state` | Phase 3 — confirm peering is Active |
| `private_cloud_id` | Reference only |

The vCenter solution user credentials are printed to the apply log by the
`null_resource.vcenter_credentials_reset` provisioner. Scroll back through
the output and save both the username (`solution-user-01@gve.local`) and the
generated password — you will need them in Phase 3. You can retrieve the credentials using the command
`gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud=<altostrat-<id>-private-cloud> \
  --location=us-west1-a \
  --project=<existing_project_id> \
  --username=solution-user-01@gve.local`

  Optionally add `--impersonate-service-account=<terraform_resource_creator_identity_SA>` if required.

---

## Phase 2 — Access the Jump Host [MANUAL]

### Step 2.1 — Set the Windows Administrator Password

The jump host VM is created by Terraform but its Windows password must be set
manually — there is no API to do this programmatically.

1. In the Google Cloud console, navigate to **Compute Engine > VM instances**.
2. Click the instance name **jump-host**.
3. Click **Set Windows Password**.
4. Leave the username as the default lab username and click **Set**.
5. Copy the generated password and save it in a text file — you will need it
   throughout the lab.
6. Click **Close**.

**Expected result:** A Windows administrator password is now associated with the
jump host. The instance is ready for RDP connection.

> **Note:** The jump host takes approximately 2 minutes to finish Windows
> startup after Terraform creates it. If the password reset fails, click
> **Serial port 1** in the Logs section of the instance details page and
> refresh until you see `Instance setup finished. jump-host is ready to use.`

### Step 2.2 — Connect via RDP

1. On the jump host instance details page, click **RDP**.
2. Click **Download the RDP file**.
3. Open the downloaded `.rdp` file in your RDP client.
4. Click **Connect**.
5. Enter the administrator password saved in Step 2.1.
6. Click **OK**.
7. If an identity verification warning appears, click **Yes**.
8. Once logged in, minimize Server Manager to reveal the desktop.
9. If a Network dialog appears on the right side of the screen, click **Yes**.

**Expected result:** You are logged in to the Windows Server 2022 desktop on
the jump host.

### Step 2.3 — Start the OVA Download

The Bank of Anthos OVA is large — start the download now so it is ready when
you reach Phase 5.

1. Double-click the **Google Cloud Shell** icon on the jump host desktop.
2. Run the following command:

```cmd
gsutil cp gs://gcve-lab-bank-of-anthos-ova/bank-of-anthos.ova %HOMEPATH%\Downloads\
```

3. Leave the download running in the background and continue with Phase 3.

**Expected result:** The OVA begins downloading to `C:\Users\<username>\Downloads\`.
It will be available by the time you reach Phase 5.

---

## Phase 3 — Access vCenter and NSX-T [MANUAL]

The vCenter and NSX-T FQDNs were output by Terraform at the end of Phase 1.
You access both consoles from the Edge browser on the jump host — direct access
from your local machine will not work without GCVE-specific DNS configuration.

### Step 3.1 — Open the Edge Browser on the Jump Host

1. On the jump host desktop, click the **Edge** browser icon in the taskbar.
2. Click **Start without your data**, then **Continue without this data**,
   then **Confirm and start browsing** to skip personalisation prompts.

### Step 3.2 — Log in to vCenter

1. From your Terraform outputs, copy the value of `vcenter_fqdn`.
   It will be in the format `https://vcsa-XXX.XXXXXX.<region>.gve.goog`.
2. Paste the URL into the Edge address bar and press Enter.
3. Click **Advanced**, then click **Continue to vcsa-XXX... (unsafe)** to
   bypass the self-signed certificate warning.
4. Click **Launch vSphere Client (HTML5)**.
5. Log in using:
   - **Username:** `solution-user-01@gve.local`
   - **Password:** the credential saved in Step 1.3

**Expected result:** The vSphere Client dashboard loads showing the
`lab-private-cloud` management cluster.

> **Alternative:** If the FQDN does not resolve, use the direct IP address
> `https://10.11.0.2` (only reachable from the jump host after peering is Active).

### Step 3.3 — Log in to NSX-T Manager

1. From your Terraform outputs, copy the value of `nsx_fqdn`.
   It will be in the format `https://nsx-XXX.XXXXXX.<region>.gve.goog`.
2. Open a new Edge browser tab and paste the URL.
3. Click **Advanced**, then **Continue to nsx-XXX... (unsafe)**.
4. Log in using the NSX-T credentials from the VMware Engine console:
   - In the Google Cloud console, navigate to **VMware Engine > Private Clouds**.
   - Click **altostrat-private-cloud**.
   - In the **Management Appliances** section, click **NSX Manager** to view
     the NSX-T credentials.

**Expected result:** The NSX-T Manager dashboard loads. You are ready to
create workload network segments in Phase 4.

> **Alternative:** Use the direct IP address `https://10.11.0.18` if the FQDN
> does not resolve.

### Step 3.4 — Confirm Network Peering is Active

Before proceeding, verify that the VPC peering Terraform created is fully
active.

1. In the Google Cloud console, navigate to
   **VMware Engine > VPC Network Peerings**.
2. Confirm the peering named **altostrat-vpc-ven** shows a state of
   **Active**.

**Expected result:** Peering state is **Active**. Routes between the GCVE
management network and your peer VPC are now exchanged. If it still shows
**Inactive**, wait a few minutes and refresh — peering can take up to
5 minutes to activate after the private cloud finishes provisioning.

---

## Phase 4 — Create NSX-T Workload Segment and Deploy Workload VMs [MANUAL]

> **Why this is manual:** The Google Cloud Terraform provider does not expose
> NSX-T segment resources inside a GCVE private cloud. Segment creation
> requires the NSX-T Manager UI or the VMware NSX-T Terraform provider with
> separate API credentials.

### Step 4.1 — Create the NSX-T Workload Segment

1. On the jump host, switch to the **NSX-T Manager** browser tab.
2. On the NSX-T Manager home page, click **Networking > Segments**.
3. Click **Add Segment**.
4. Enter the following values:

| Field | Value |
|---|---|
| Segment Name | `my-nsx-network` |
| Connected Gateway | `Tier1` |
| Transport Zone | `TZ-OVERLAY \| Overlay` (select from dropdown) |
| Subnets — Gateway IP/Prefix Length | `192.168.142.1/24` |

5. Click **Save**.
6. When prompted to continue editing, click **No**.

**Expected result:** The segment `my-nsx-network` appears in the Segments list
with a status of **Success**. The route `192.168.142.0/24` is automatically
exported to the peered VPC via the active network peering.

### Step 4.2 — Verify the Route is Exported to the VPC

1. Switch back to the Google Cloud console on your local machine.
2. Navigate to **VMware Engine > VPC Network Peerings**.
3. Click the peering name **altostrat-vpc-ven**.
4. Click the **Exported Routes** tab.
5. Confirm a route with destination `192.168.142.0/24` is listed.

**Expected result:** The NSX-T segment route is visible in the exported routes,
confirming end-to-end connectivity between the GCVE workload network and
the peer VPC.

### Step 4.3 — Confirm Internet Access is Active

Terraform created the network policy with internet access enabled, but
activation can take up to 15 minutes.

1. In the Google Cloud console, navigate to **VMware Engine > Network Policies**.
2. Confirm the policy **altostrat-<id>-edge-policy** shows **Internet access: Enabled**
   for region `us-west2`.

**Expected result:** Internet access and external IP services show as
**Enabled**. If they still show as pending, wait and refresh before proceeding
to Step 4.5.

### Step 4.4 — Confirm the HTTP Firewall Rule Exists

Terraform created the `default-allow-http` rule automatically. Verify it is
in place before deploying workload VMs.

1. In the Google Cloud console, navigate to
   **VPC Network > Firewall**.
2. Confirm a rule named **default-allow-http** exists with:
   - Direction: Ingress
   - Targets: `jump-host` tag
   - Protocols/ports: `tcp:80, tcp:443`
   - Source ranges: `0.0.0.0/0`

**Expected result:** Rule is present. No manual action needed — this was
created by Terraform.

### Step 4.5 — Deploy the Bank of Anthos OVF Template

1. On the jump host, switch to the **vSphere Client** browser tab.
2. Click **Menu > Inventory**, then click the **VMs and Templates** icon.
3. Expand the vCenter appliance name in the resource tree.
4. Right-click **Datacenter** and select **Deploy OVF Template**.
5. Select **Local File**, click **Upload Files**.
6. Navigate to **This PC > Downloads**, select **bank-of-anthos.ova**,
   and click **Open**.
7. Click **Next** through each wizard step using the values below:

| Wizard Step | Value |
|---|---|
| Select a name and folder | Navigate to **Datacenter > Workload VMs**, click Next |
| Select a compute resource | Select **lab-cluster**, click Next |
| Review details | Click Next |
| Select storage | Select **vsanDatastore**, click Next |
| Select networks — Destination Network | Click the dropdown, select **Browse**, choose **my-nsx-network**, click OK, then Next |

8. Review the summary and click **Finish**.
9. Monitor the **Recent Tasks** pane and wait for the OVF deployment to
   complete before proceeding.

**Expected result:** The `bank-of-anthos` VM template appears under
**Datacenter > Workload VMs** in the vSphere inventory.

### Step 4.6 — Power On the Workload VMs

1. In the vSphere Client, click **Menu > VMs and Templates**.
2. Navigate to **Datacenter > Workload VMs**.
3. Select **bank-of-anthos**.
4. Click **Actions > Power > Power On**.
5. In the bank-of-anthos details pane, click **VMs**.
6. Wait for all three VMs to show a powered-on state:
   - `back-end`
   - `front-end`
   - `db-server`

**Expected result:** All three VMs are running and have been assigned IP
addresses on the `192.168.142.0/24` network.

### Step 4.7 — Verify Workload Connectivity

1. On the jump host, open the **Cloud Shell** window.
2. Ping the front-end VM to confirm network reachability:

```cmd
ping 192.168.142.70
```

3. Open a new browser tab and navigate to:

```
http://192.168.142.70
```

> Use HTTP, not HTTPS. Accept any certificate warnings.

**Expected result:** The Bank of Anthos web application loads in the browser,
confirming that GCVE workload VMs are reachable from the jump host via the
peered VPC network.

> **VM console credentials** (if you need to log in to any of the three VMs):
> - Username: `user`
> - Password: `password`

---

## Phase 5 — Verify the VM Migration API [AUTOMATED]

Terraform enabled the `vmmigration.googleapis.com` API as part of Phase 1.
This step confirms it is active before proceeding.

1. In the Google Cloud console, navigate to the search bar, type
   **VM Migration API** and press Enter.
2. Click the **VM Migration API** result.
3. Confirm you see a **MANAGE** button — this means the API is enabled.
4. Navigate to **Compute Engine > Migrate to Virtual Machines**.

**Expected result:** The Migrate to Virtual Machines dashboard is displayed.
If the API is not yet enabled, click **Enable** and wait 1–2 minutes.

---

## Phase 6 — Deploy the Migrate Connector VM [MANUAL]

> **Why this is manual:** Deploying OVF templates to a vCenter instance inside
> GCVE requires the vSphere Client UI. There is no Google Cloud Terraform
> provider resource for this operation.

### Step 6.1 — Generate an SSH Key Pair with PuTTYgen

The Migrate Connector OVF requires an SSH public key at deploy time to allow
admin access to the appliance.

1. On the jump host, click the Windows **Start** button and search for
   **PuTTYgen**. Open the application.
2. Click **Generate** and move your mouse over the blank area to generate
   randomness until the progress bar completes.
3. Click **Save private key**. When prompted about saving without a passphrase,
   click **Yes**.
4. Enter `m2vm_key` as the filename and click **Save**.
5. Leave PuTTYgen open — you will copy the public key from it in the next step.

**Expected result:** The private key file `m2vm_key.ppk` is saved to the
Desktop. The public key is displayed in the PuTTYgen window.

### Step 6.2 — Deploy the Migrate Connector OVF

1. On the jump host, switch to the **vSphere Client** browser tab.
2. Right-click the **lab-cluster** in the left-hand resource tree and select
   **Deploy OVF Template**.
3. On the **Select an OVF template** page, enter the following URL and click
   **Next**:

```
https://storage.googleapis.com/vmmigration-public-artifacts/migrate-connector-2-7-2874.ova
```

4. If prompted to accept an SSL certificate, click **Yes**.
5. Step through the wizard using the values below:

| Wizard Step | Value |
|---|---|
| Select a name and folder | Leave defaults, click Next |
| Select a compute resource | Leave defaults, click Next |
| Review details | Click Next |
| Select storage — Virtual disk format | Select **Thin Provision**, click Next |
| Select networks — VM Network | Select **Internal management**, click Next |

6. On the **Customize Template** screen, locate the **SSH Public Key** field.
7. Switch to PuTTYgen, select the entire public key text starting with
   `ssh-rsa` through to the end, and copy it.
8. Paste the public key into the **SSH Public Key** field in the vSphere wizard.
9. Click **Next**, then click **Finish**.
10. Monitor the **Recent Tasks** pane and wait for the deployment to complete.

> If you encounter an error during deployment, start the wizard again from
> Step 2.

**Expected result:** The `migrate-connector` VM appears in the vSphere
inventory and the Recent Tasks pane shows the deployment as completed
successfully.

### Step 6.3 — Power On the Migrate Connector

1. In the vSphere Client left-hand navigation, select the
   **migrate-connector** instance.
2. Click the **Power on** button.
3. Wait until the VM details pane shows an IP address assigned
   (format: `172.16.10.xx`). Note this IP address — you will SSH to it
   in Phase 7.

**Expected result:** The Migrate Connector VM is running and has an IP address
on the internal management network.

---

## Phase 7 — Register the Migrate Connector [MANUAL]

### Step 7.1 — Retrieve the vCenter Solution User Credentials

Terraform reset and retrieved the vCenter solution user credentials at the end
of Phase 1. Retrieve them now if you did not save them earlier.

1. On your local machine, open Cloud Shell in the Google Cloud console.
2. Run the following command (replace `us-west2-a` and `altostrat-private-cloud`
   if you used different values):

```bash
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud=altostrat-private-cloud \
  --username=solution-user-01@gve.local \
  --location=us-west2-a
```

3. Save the returned username and password.

**Expected result:** The credentials for `solution-user-01@gve.local` are
displayed. These are used by the Migrate Connector to authenticate with
vCenter.

### Step 7.2 — SSH into the Migrate Connector

1. On the jump host, click the Windows **Start** button and search for
   **PuTTY**. Open the application.
2. In the PuTTY window, expand **Connection > SSH > Auth** in the left-hand
   tree.
3. Click **Browse** and select the `m2vm_key.ppk` private key saved in
   Step 6.1.
4. Scroll to the top of the left-hand tree and click **Session**.
5. In the **Host Name** field, enter:

```
admin@172.16.10.xx
```

   Replace `xx` with the IP address noted in Step 6.3.

6. Click **Open**.
7. If prompted with a server host key warning, click **Accept**.

**Expected result:** You are logged in to the Migrate Connector appliance
shell as `admin`.

### Step 7.3 — Verify Connector Status

In the PuTTY SSH window, run:

```bash
m2vm status
```

**Expected result:** Output shows the connector is **not registered**.

### Step 7.4 — Obtain a Google Cloud Access Token

The `m2vm register` command requires a short-lived OAuth token to authenticate
with Google Cloud.

1. Switch to the Google Cloud console on your local machine.
2. Open Cloud Shell and run:

```bash
gcloud auth print-access-token
```

3. Click **Authorize** if prompted.
4. Select and copy the entire token returned.

**Expected result:** A long alphanumeric token string is copied to your
clipboard.

### Step 7.5 — Register the Migrate Connector

1. In the PuTTY SSH window, run:

```bash
m2vm register
```

2. When prompted for an **access token**, right-click in the PuTTY window to
   paste the token copied in Step 7.4, then press **Enter**.
3. When prompted for each value, enter the following:

| Prompt | Value |
|---|---|
| Project | Select your `migrate-training-xx-1234` project (option 2) |
| Region | `us-west2` (type exactly) |
| Source name | `migrate-vsphere` (type exactly) |
| KMS Key | Leave blank, press Enter |

4. When prompted to select a service account, choose the default option.
5. Wait approximately 5 minutes for the source to be created and the connector
   to become active.

> **If you see:** `Read access to project '...' was denied` — navigate to
> **Compute Engine > Migrate to Virtual Machines** in the console, confirm the
> API is enabled, and retry.
>
> **If registration fails and you need to retry:** delete all VM Migrations,
> Disk Migrations, and Utilization Reports in the Migrate to VMs console
> before running `m2vm register` again.

**Expected result:** Registration completes with a message confirming the
connector is active and the source `migrate-vsphere` has been created.

### Step 7.6 — Confirm Registration and Set Bandwidth Limit

1. In the PuTTY SSH window, confirm the connector is registered:

```bash
m2vm status
```

2. Set the maximum upload bandwidth to 100 MiBps:

```bash
m2vm upload-max-rate set 100
```

3. Confirm the setting:

```bash
m2vm upload-max-rate show
```

**Expected result:** Status shows the connector as **registered and active**.
Upload rate shows **100 MiBps**.

### Step 7.7 — Verify the Source in the Migrate to VMs Console

1. In the Google Cloud console, navigate to
   **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Sources** tab.
3. Select **migrate-vsphere** from the source dropdown.
4. A list of VMware VMs discovered from the GCVE environment is displayed.
   If the list is empty, wait 1–2 minutes and refresh.
5. Click **Source Details** (top right) to confirm the source configuration.
6. Click the back arrow to return to the main Migrate to VMs screen.

**Expected result:** The source `migrate-vsphere` is active and the VM
inventory is populated with the VMs running in GCVE.

> **REST API equivalent — fetch VM inventory:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID:fetchInventory?forceRefresh=true" \
>   -H "Authorization: Bearer $TOKEN" | jq '.vmwareVms.details[] | {vmId, displayName}'
> ```
> Note the `vmId` value for each VM (e.g. `vm-12345`) — you need it as
> `sourceVmId` when creating migration jobs via the API.

---

## Phase 8 — Clean Up Any Previous Lab Resources [MANUAL]

Before starting migration operations, confirm no leftover VMs or disks from
a previous lab run exist in the project. Orphaned resources will conflict with
migration target names.

### Step 8.1 — Check for Leftover VM Instances

1. In the Google Cloud console, navigate to **Compute Engine > VM instances**.
2. If any migrated VMs from a previous run are present (e.g. `front-end`,
   `back-end`, `db-server`), select them and click **Delete**.

### Step 8.2 — Check for Leftover Disks

1. Navigate to **Compute Engine > Disks**.
2. If any migrated disks from a previous run are present (e.g. `win-ad-clone`),
   select them and click **Delete**.

**Expected result:** No migrated VMs or disks remain. Only the jump host VM
created by Terraform should be present.

---

## Phase 9 — Create Utilization Reports [MANUAL]

Utilization reports confirm connectivity between the Migrate Connector and
Google Cloud, and provide rightsizing data for migration planning.

### Step 9.1 — Select VMs and Create the Report

1. In the Google Cloud console, navigate to
   **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Sources** tab and select **migrate-vsphere**.
3. In the VM list, select the checkboxes for the following VMs:
   - `front-end`
   - `back-end`
   - `db-server`
4. Click **Create Report**.
5. Enter the following values:

| Field | Value |
|---|---|
| Name | `utilization` |
| Time period | `Weekly` |

6. Click **Create**.

**Expected result:** The report is queued. A successfully generated report
confirms that the Migrate Connector has active connectivity to Google Cloud
and can read VM metrics from the vCenter source.

> **REST API equivalent — create utilization report:**
> Replace `VM_ID_*` with the `vmId` values returned by `fetchInventory`.
> ```bash
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/utilizationReports?utilizationReportId=utilization" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{
>     "displayName": "utilization",
>     "timeFrame": "WEEK",
>     "vms": [
>       {"vmId": "VM_ID_FRONTEND"},
>       {"vmId": "VM_ID_BACKEND"},
>       {"vmId": "VM_ID_DBSERVER"}
>     ]
>   }' | jq '.name'
> ```

### Step 9.2 — View the Report

1. Click the **Sources** tab.
2. Click **View Reports** (top right).
3. Click the report name **utilization** to open it.

**Expected result:** The report displays CPU, memory, and disk utilisation
metrics for each selected VM. This data can be used to rightsize target
Compute Engine instances before migration.

---

## Phase 10 — Configure Migrations and Start Replication [MANUAL]

This phase creates the migration jobs for each VM and starts the initial
replication cycle. Replication is continuous — the first sync takes
approximately 15 minutes; subsequent incremental syncs run every two hours
using Change Block Tracking (CBT).

### Step 10.1 — Create VM Migrations for the Bank of Anthos VMs

1. In the Google Cloud console, navigate to
   **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Sources** tab and select **migrate-vsphere**.
3. In the VM list, select the checkboxes for all three Bank of Anthos VMs:
   - `front-end`
   - `back-end`
   - `db-server`
4. Click **Add Migrations > VM Migration**.
5. Click **Confirm** when prompted.

**Expected result:** VM migration jobs are created for all three VMs. Click
the **VM Migrations** tab to see them listed.

> **REST API equivalent — create migrating VMs (repeat for each VM):**
> ```bash
> for VM in front-end back-end db-server; do
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms?migratingVmId=$VM" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d "{
>       \"sourceVmId\": \"VM_ID_FOR_${VM}\",
>       \"computeEngineTargetDefaults\": {
>         \"vmName\": \"$VM\",
>         \"zone\": \"${REGION}-a\",
>         \"machineTypeSeries\": \"e2\",
>         \"machineType\": \"e2-medium\",
>         \"networkInterfaces\": [{
>           \"network\": \"projects/$PROJECT/global/networks/default\",
>           \"subnetwork\": \"projects/$PROJECT/regions/$REGION/subnetworks/default\"
>         }]
>       }
>     }" | jq '.name'
> done
> ```

### Step 10.2 — Create the 3-Tier Migration Group

Groups allow you to manage related VMs together and apply shared target
settings in a single operation — ideal for multi-tier applications where
all components should move together.

1. Click the **Sources** tab.
2. Select the checkboxes for `front-end`, `back-end`, and `db-server`.
3. Click **Add to Group**.
4. Type `3-tier` as the new group name and click **Add to Group**.

**Expected result:** The three VMs are added to the `3-tier` group and the
group is visible on the **Groups** tab.

> **REST API equivalent — create group and add members:**
> ```bash
> # Create the group
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/groups?groupId=3-tier" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{"displayName": "3-tier", "migrationTargetType": "MIGRATION_TARGET_TYPE_GCE"}' | jq '.name'
>
> # Add each VM to the group
> for VM in front-end back-end db-server; do
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/groups/3-tier:addGroupMigration" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d "{\"migratingVm\": \"projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/$VM\"}" \
>     | jq '.name'
> done
> ```

### Step 10.3 — Start Replication for the 3-Tier Group

1. Click the **Groups** tab.
2. Click the group name **3-tier** (click the name itself, not the checkbox).
3. Select the checkboxes for `front-end`, `back-end`, and `db-server`.
4. Click **Migration > Start Replication**.
5. Click the back arrow (top left) to return to the groups list.

**Expected result:** Replication starts for all three VMs. Their status
changes to **Replicating**. The first sync will take approximately 15 minutes.

> **REST API equivalent — start replication for each VM:**
> ```bash
> for VM in front-end back-end db-server; do
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/$VM:startMigration" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d '{}' | jq '.name'
> done
> ```

### Step 10.4 — Monitor Replication Progress

1. Click the **VM Migrations** tab to monitor sync progress for all three VMs.
2. Wait until the replication status for all three VMs changes to **Active**
   before proceeding to Phase 11.

**Expected result:** All three VMs show a status of **Active**, indicating
the initial replication is complete and incremental syncing is underway.

### Step 10.5 — View Replication Cycle History

The service retains up to 100 replication cycles per VM, giving a complete
audit trail of every incremental sync.

1. Click the **VM Migrations** tab.
2. Click the name **front-end** to open its details page.
3. Click the **Replication Cycles** tab.
4. Review the list of completed cycles — each row shows start time, duration,
   data transferred, and status.

**Expected result:** At least one completed replication cycle is listed,
confirming that incremental CBT replication is working after the initial sync.

> **REST API equivalent — list replication cycles:**
> ```bash
> curl -s \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/front-end/replicationCycles" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.replicationCycles[] | {cycleNumber, state, startTime, endTime, progressPercent}'
> ```

### Step 10.6 — Pause and Resume Replication

Pausing halts the incremental replication cycle without deleting any replicated
data or storage resources. This is useful during planned maintenance windows on
the source environment.

1. On the **VM Migrations** tab, select the checkbox for **front-end**.
2. Click **Migration > Pause Replication**.
3. Observe the status change to **Paused**.
4. Click **Migration > Resume Replication**.
5. Observe the status return to **Active**.

**Expected result:** Replication pauses and resumes cleanly. No data is lost
during the pause — the next cycle after resuming picks up only the blocks
changed since the last completed cycle.

> **Note:** Replication cannot be paused while a cut-over is in progress.
> After a cut-over completes, resume can be used to reactivate replication
> if the cut-over needs to be rolled back.

> **REST API equivalent — pause and resume:**
> ```bash
> # Pause
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/front-end:pauseMigration" \
>   -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}' | jq '.name'
>
> # Resume
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/front-end:resumeMigration" \
>   -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}' | jq '.name'
> ```

---

## Phase 11 — Configure Migration Target Details [MANUAL]

Target details define the Compute Engine instance or disk configuration that
will be created when a test clone or cut-over is triggered.

### Step 11.1 — Configure Target Details for front-end

1. In the Google Cloud console, navigate to
   **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Groups** tab and click the group name **3-tier**.
3. Select the checkbox for **front-end**.
4. Click **Edit Target Details**.
5. Enter the following values:

| Section | Field | Value |
|---|---|---|
| General | Instance name | `front-end` |
| General | Project | your project ID |
| General | Zone | `us-west2-a` |
| Machine Configuration | Machine configuration | `e2` |
| Machine Configuration | Machine type | `e2-medium` |
| Networking | Network | `default` |
| Networking | Subnetwork | `default` |
| Networking | Network tags | `http-server` (click Add Network Tag) |

6. Click **Save**.

**Expected result:** Target details are saved for `front-end`.

### Step 11.2 — Configure Target Details for back-end

1. Select the checkbox for **back-end**.
2. Click **Edit Target Details**.
3. Enter the following values:

| Section | Field | Value |
|---|---|---|
| General | Instance name | `back-end` |
| General | Project | your project ID |
| General | Zone | `us-west2-a` |
| Machine Configuration | Machine configuration | `e2` |
| Machine Configuration | Machine type | `e2-medium` |
| Networking | Network | `default` |
| Networking | Subnetwork | `default` |

4. Click **Save**.

**Expected result:** Target details are saved for `back-end`.

### Step 11.3 — Configure Target Details for db-server

1. Select the checkbox for **db-server**.
2. Click **Edit Target Details**.
3. Enter the following values:

| Section | Field | Value |
|---|---|---|
| General | Instance name | `db-server` |
| General | Project | your project ID |
| General | Zone | `us-west2-a` |
| Machine Configuration | Machine configuration | `e2` |
| Machine Configuration | Machine type | `e2-medium` |
| Networking | Network | `default` |
| Networking | Subnetwork | `default` |

4. Click **Save**.

**Expected result:** Target details are saved for `db-server`.

> **REST API equivalent — configure target details for all three VMs:**
> Target details are set by PATCHing the migratingVm resource. The
> `updateMask` restricts which fields are modified.
> ```bash
> for VM in front-end back-end db-server; do
>   TAGS=""
>   [[ "$VM" == "front-end" ]] && TAGS='"networkTags": ["http-server"],'
>   curl -s -X PATCH \
>     "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/$VM?updateMask=computeEngineTargetDefaults" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d "{
>       \"computeEngineTargetDefaults\": {
>         \"vmName\": \"$VM\",
>         \"zone\": \"${REGION}-a\",
>         \"machineTypeSeries\": \"e2\",
>         \"machineType\": \"e2-medium\",
>         $TAGS
>         \"networkInterfaces\": [{
>           \"network\": \"projects/$PROJECT/global/networks/default\",
>           \"subnetwork\": \"projects/$PROJECT/regions/$REGION/subnetworks/default\"
>         }]
>       }
>     }" | jq '.name'
> done
> ```

---

## Phase 12 — Test Clone and Cut-Over [MANUAL]

A **test clone** creates a copy of the VM in Google Cloud without stopping the
source VM — useful for validating the migrated workload before committing.
A **cut-over** stops the source VM, performs a final sync, and creates the
permanent Compute Engine instance.

### Step 12.1 — Test Clone front-end

A test clone creates a Compute Engine instance from the latest replicated data
without stopping the source VM. Use it to validate the migrated workload before
committing to a full cut-over.

1. In the Google Cloud console, navigate to
   **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Groups** tab and click the group name **3-tier**.
3. Confirm the replication status for **front-end** is **Active**.
4. Select the checkbox for **front-end**.
5. Click **Cut-Over and Test-Clone > Test-Clone**.
6. Click **Confirm**.

**Expected result:** A test clone job is initiated for `front-end`. The cloned
VM will appear in **Compute Engine > VM Instances** within approximately
15 minutes. Leave this running and proceed to the next step.

> **REST API equivalent — create clone job:**
> ```bash
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/front-end/cloneJobs?cloneJobId=clone-$(date +%s)" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{}' | jq '{operation: .name}'
> ```

### Step 12.2 — Cut-Over back-end and db-server

Cut-over stops the source VM, performs a final incremental sync, and creates
the permanent Compute Engine instance. It is an irreversible operation and
should be scheduled during a maintenance window.

1. In the **3-tier** group, confirm the replication status for **back-end**
   and **db-server** is **Active**.
2. Select the checkboxes for **back-end** and **db-server**.
3. Click **Cut-Over and Test-Clone > Cut-Over**.
4. Click **Confirm** when prompted.

**Expected result:** Cut-over jobs are initiated for `back-end` and
`db-server`. VM creation takes approximately 15 minutes. Progress can be
monitored in the **Groups > 3-tier** view — both VMs will show **Cut Over**
in the status column when complete.

> **REST API equivalent — create cutover jobs:**
> ```bash
> for VM in back-end db-server; do
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/$VM/cutoverJobs?cutoverJobId=cutover-$(date +%s)" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d '{}' | jq '{vm: "'$VM'", operation: .name}'
> done
> ```

### Step 12.3 — Verify the front-end Test Clone

1. In Cloud Shell on your local machine, run:

```bash
gcloud compute ssh front-end --zone=us-west2-a --tunnel-through-iap -- -NL "8080:localhost:80"
```

2. When Cloud Shell offers a port preview, select **Preview on port 8080**.

**Expected result:** The Bank of Anthos front-end application loads in your
browser via the Cloud Shell port preview, confirming the VM migrated
successfully and the web service is running on Compute Engine.

### Step 12.4 — Verify back-end and db-server

1. In the Google Cloud console, navigate to **Compute Engine > VM Instances**.
2. Click **Refresh** until `back-end` and `db-server` appear in the list.
3. Confirm both VMs are running in zone `us-west2-a`.

**Expected result:** All three Bank of Anthos VMs are now running as Compute
Engine instances — `front-end` as a test clone and `back-end` and `db-server`
as permanent cut-over instances.

### Step 12.7 — Finalise Migrations (Optional)

Finalisation permanently removes all migration management resources for a
completed cut-over, freeing up quota and cleaning up the migration state.

1. In **Migrate to Virtual Machines**, select any cut-over migration.
2. Click **Migration > Finalize**.

**Expected result:** The migration management resources are deleted. The
Compute Engine VM remains running and is now fully independent of the
migration service.

> **REST API equivalent — finalize migration:**
> ```bash
> for VM in front-end back-end db-server; do
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/$VM:finalizeMigration" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d '{}' | jq '{vm: "'$VM'", operation: .name}'
> done
> ```

### Step 12.8 — View the Adaptation Report

The service automatically adapts each migrated OS to run on Compute Engine —
installing virtio drivers, Compute Engine guest agents, and configuring the
serial console. The adaptation report shows exactly what was changed.

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Click the name **front-end** (or any cut-over VM) to open its details page.
3. Click the **Adaptation Report** tab.
4. Review the list of adaptations applied, such as:
   - Bootloader reconfigured to output to serial port
   - virtio network and disk drivers installed
   - Google Compute Engine guest agent installed

**Expected result:** The adaptation report lists the OS-level changes applied
automatically during the clone or cut-over, confirming the VM is prepared for
Compute Engine without manual guest OS changes.

### Step 12.9 — Cancel a Cut-Over (Awareness)

If a cut-over is initiated at the wrong time or against the wrong VM, it can
be cancelled while in progress.

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Select a VM that is in **Cutting Over** state.
3. Click **Migration > Cancel Cut-Over**.

**Expected result:** The cut-over is cancelled and the VM returns to
**Active** replication state. The source VM is restarted if it was shut down
as part of the cut-over sequence.

> **Note:** Cancellation is only available while the cut-over job is still
> running. Once the Compute Engine instance has been created the operation
> cannot be reversed via cancel — you would need to delete the target VM and
> resume replication manually.

> **REST API equivalent — cancel a cutover job:**
> ```bash
> # First get the cutover job ID
> curl -s \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/back-end/cutoverJobs" \
>   -H "Authorization: Bearer $TOKEN" | jq '.cutoverJobs[] | select(.state=="ACTIVE") | .name'
>
> # Then cancel it
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/back-end/cutoverJobs/JOB_ID:cancel" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{}' | jq '.name'
> ```

---

## Phase 13 — Explore Google Cloud [MANUAL]

### Step 13.1 — Explore Monitoring

1. In the Google Cloud console, navigate to **Monitoring > Metrics Explorer**.
2. Search for metrics scoped to `gce_instance`.
3. Select a metric such as **CPU utilisation** and filter by the instance names
   `front-end`, `back-end`, or `db-server`.
4. Navigate to **Monitoring > Dashboards** and explore the pre-built
   **VM Instances** dashboard.

**Expected result:** CPU, memory, disk, and network metrics are visible for
the migrated Compute Engine instances, confirming that Cloud Monitoring is
collecting telemetry without any additional agent configuration.

### Step 13.2 — Explore Logging

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the resource filter, select **VM Instance** and choose one of the
   migrated VMs.
3. Browse the system and application logs streamed from the instance.

**Expected result:** Logs from the migrated VMs are visible in Cloud Logging,
providing a centralised view of system activity across all migrated workloads.

### Step 13.3 — Explore Security Command Center

1. In the Google Cloud console, navigate to **Security > Security Command
   Center**.
2. Click **Findings** and filter by resource type `google.compute.Instance`.
3. Review any findings raised against the migrated VMs, such as open firewall
   ports or missing OS patches.

**Expected result:** Security Command Center displays findings for the migrated
Compute Engine instances, giving immediate visibility into the security posture
of workloads after migration.

---

## Phase 14 — Advanced Features [MANUAL]

### Step 14.1 — Bulk Migration Configuration via CSV Export and Import

For large migrations with many VMs, configuring target details individually in
the console is impractical. The service supports exporting the current VM list
to CSV, editing it externally, and re-importing to bulk-create or update
migrations. Up to 100 migrations can be processed per import file.

**Export:**

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Click the **Export** button (top right).
3. Select **CSV** as the format and click **Export**.
4. Open the downloaded file in a spreadsheet editor.
5. Review the columns — each row represents one migrating VM with fields for
   instance name, project, zone, machine type, network, subnetwork, network
   tags, disk type, and boot mode.

**Edit and re-import:**

6. Modify target detail columns for one or more VMs (e.g. change machine type
   or add a network tag).
7. Save the file as CSV.
8. In the console, click **Import**.
9. Upload the edited CSV file and click **Import**.

**Expected result:** The import updates target details for all rows in the
file. Any validation errors (unknown machine types, missing required fields)
are reported before the import is committed.

> **Tip:** The import can also create new migrations and assign VMs to groups
> by populating the `group` column. This makes it the fastest way to onboard
> and configure a large VM fleet in one operation.

### Step 14.2 — Configure IAM Access for Migration Operations

In production, migration operations should be delegated using least-privilege
IAM roles rather than granting broad project access.

| Role | Purpose |
|---|---|
| `roles/vmmigration.admin` | Full control — create sources, manage migrations, execute cut-overs |
| `roles/vmmigration.viewer` | Read-only — view migration status and reports without making changes |

**Grant viewer access to a team member:**

1. In the Google Cloud console, navigate to **IAM & Admin > IAM**.
2. Click **Grant Access**.
3. Enter the team member's email address.
4. Search for and select **Migrate to Virtual Machines Viewer**.
5. Click **Save**.

**Expected result:** The team member can view all migration status and reports
in the Migrate to Virtual Machines console but cannot start replication,
trigger cut-overs, or modify target details.

### Step 14.3 — Review Audit Logs for Migration Operations

Every migration operation (start replication, cut-over, finalize) generates
an entry in Cloud Audit Logs, providing a complete compliance trail.

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query editor, enter:

```
resource.type="audited_resource"
protoPayload.serviceName="vmmigration.googleapis.com"
```

3. Press **Run Query**.
4. Expand individual log entries to see:
   - The method called (e.g. `StartMigration`, `CreateCutoverJob`)
   - The caller identity (service account or user)
   - The resource affected (source name, migrating VM name)
   - Timestamp and result status

**Expected result:** Audit log entries are visible for all migration operations
performed during the lab, confirming that `vmmigration.googleapis.com` Admin
Activity logs are captured automatically with no additional configuration.

### Step 14.4 — Understand VM Migration Lifespan and Expiry

Be aware of the following lifecycle limits when planning long-running
migrations:

| Milestone | Timing |
|---|---|
| Initial active lifespan | 100 days from onboarding |
| Expiry warning window | Days 86–100 (14 days before expiry) |
| Extension available | +100 days (once only, available days 86–130) |
| Maximum total lifespan | 200 days |
| Post-expiry resource retention | 30 days in EXPIRED state, then removed |

**To extend a migration's lifespan:**

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Identify any VM showing an expiry warning in its status column.
3. Select the VM and click **Migration > Extend Lifespan**.

**Expected result:** The migration lifespan is extended by 100 days. This
option is available only once — plan cut-overs well within the 200-day window
to avoid losing replication state.

### Step 14.5 — Register an Additional Target Project

By default the host project (where the Migrate Connector source is registered)
is also the target project where Compute Engine instances are created. You can
register additional GCP projects as migration targets — useful when migrating
workloads into a separate production project from the migration management
project.

1. In **Migrate to Virtual Machines**, click the **Settings** tab.
2. Click **Target Projects**.
3. Click **Add Target Project**.
4. Enter the project ID of the target project.
5. Follow the prompts to grant the required Compute Engine IAM permissions to
   the migration service account in that project.

**Expected result:** The additional project appears in the target project list
and becomes available in the **Project** dropdown when configuring target
details for any migrating VM.

> **REST API equivalent — register a target project:**
> ```bash
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/global/targetProjects?targetProjectId=my-target-project" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{"project": "destination-project-id", "description": "Production landing zone"}' \
>   | jq '.name'
> ```

---

## Summary

The table below recaps every action in the lab, its phase, and whether it is
automated by the `VMware_Engine` Terraform module or performed manually.

| Action | Phase | Automated |
|---|---|---|
| Enable GCP APIs | 1 | Yes — `main.tf` |
| Create VMware Engine Network | 1 | Yes — `vmware_network.tf` |
| Create Private Cloud | 1 | Yes — `private_cloud.tf` |
| Configure VPC Network Peering | 1 | Yes — `network_peering.tf` |
| Create Network Policy (internet + external IP) | 1 | Yes — `network_policy.tf` |
| Create default VPC firewall rules | 1 | Yes — `firewall.tf` |
| Create HTTP/HTTPS firewall rule for jump host | 1 | Yes — `firewall.tf` |
| Deploy Windows Server 2022 jump host | 1 | Yes — `jump_host.tf` |
| Reset vCenter solution user credentials | 1 | Yes — `vcenter_credentials.tf` |
| Set Windows administrator password | 2 | No — GCP console only |
| RDP connection to jump host | 2 | No — requires RDP client |
| Download bank-of-anthos OVA | 2 | No — run from jump host Cloud Shell |
| Open vCenter in browser | 3 | No — jump host browser session |
| Open NSX-T Manager in browser | 3 | No — jump host browser session |
| Confirm peering is Active | 3 | No — console verification |
| Create NSX-T workload segment | 4 | No — NSX-T Manager UI |
| Verify exported routes | 4 | No — console verification |
| Confirm Network Policy internet activation | 4 | No — console verification |
| Deploy bank-of-anthos OVF to vCenter | 4 | No — vSphere Client UI |
| Power on workload VMs | 4 | No — vSphere Client UI |
| Verify Bank of Anthos connectivity | 4 | No — manual ping and browser test |
| Verify VM Migration API is enabled | 5 | No — console verification (API enabled by Terraform) |
| Generate SSH key pair with PuTTYgen | 6 | No — Windows tool on jump host |
| Deploy Migrate Connector OVF | 6 | No — vSphere Client UI |
| Power on Migrate Connector VM | 6 | No — vSphere Client UI |
| SSH into Migrate Connector | 7 | No — PuTTY from jump host |
| Retrieve vCenter credentials | 7 | No — `gcloud` command in Cloud Shell |
| Obtain OAuth access token | 7 | No — `gcloud auth print-access-token` |
| Run `m2vm register` | 7 | No — interactive CLI on connector |
| Set upload bandwidth limit | 7 | No — `m2vm` CLI on connector |
| Verify source in Migrate to VMs console | 7 | No — console verification |
| Delete leftover VMs and disks from prior runs | 8 | No — console cleanup |
| Create utilization report for front-end, back-end, db-server | 9 | No — Migrate to VMs console |
| Create VM migrations for front-end, back-end, db-server | 10 | No — Migrate to VMs console |
| Create 3-tier migration group | 10 | No — Migrate to VMs console |
| Start replication via group | 10 | No — Migrate to VMs console |
| Monitor replication progress | 10 | No — Migrate to VMs console |
| View replication cycle history | 10 | No — Migrate to VMs console |
| Pause and resume replication | 10 | No — Migrate to VMs console |
| Configure target details for front-end | 11 | No — Migrate to VMs console |
| Configure target details for back-end | 11 | No — Migrate to VMs console |
| Configure target details for db-server | 11 | No — Migrate to VMs console |
| Test clone front-end | 12 | No — Migrate to VMs console |
| Cut-over back-end and db-server | 12 | No — Migrate to VMs console |
| Verify cloned and cut-over VMs | 12 | No — Cloud Shell and browser |
| View adaptation report | 12 | No — Migrate to VMs console |
| Cancel a cut-over (awareness) | 12 | No — Migrate to VMs console |
| Finalise migrations | 12 | No — Migrate to VMs console |
| Explore Monitoring and Logging | 13 | No — exploratory console activity |
| Explore Security Command Center | 13 | No — exploratory console activity |
| Export and import migration config via CSV | 14 | No — Migrate to VMs console |
| Configure IAM roles for migration access | 14 | No — IAM & Admin console |
| Review audit logs for migration operations | 14 | No — Cloud Logging |
| Understand VM migration lifespan (awareness) | 14 | No — reference only |
| Register an additional target project | 14 | No — Migrate to VMs console |
