# Google Cloud VMware Engine — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/VMware_Engine)**

This lab guide walks you through deploying and operating a **Google Cloud VMware Engine (GCVE)**
private cloud using the **VMware_Engine** module. You will provision a VMware Software-Defined
Data Centre (SDDC) in Google Cloud, access vCenter and NSX-T management consoles via a Windows
jump host, configure VMware networking, and explore the VM migration workflow using Migrate to
Virtual Machines.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Access the Jump Host and Management Consoles](#exercise-1--access-the-jump-host-and-management-consoles)
6. [Exercise 2 — Explore vCenter and the Private Cloud](#exercise-2--explore-vcenter-and-the-private-cloud)
7. [Exercise 3 — NSX-T Network Configuration](#exercise-3--nsx-t-network-configuration)
8. [Exercise 4 — VPC Peering and Network Connectivity](#exercise-4--vpc-peering-and-network-connectivity)
9. [Exercise 5 — Network Policies (Internet and External IP Access)](#exercise-5--network-policies-internet-and-external-ip-access)
10. [Exercise 6 — VM Migration with Migrate to Virtual Machines](#exercise-6--vm-migration-with-migrate-to-virtual-machines)
11. [Exercise 7 — Monitoring and Logging](#exercise-7--monitoring-and-logging)
12. [Exercise 8 — Advanced Operations](#exercise-8--advanced-operations)
13. [Cleanup](#13-cleanup)
14. [Reference](#14-reference)

---

## REST API Overview

Every action in this lab can be performed via the VM Migration REST API
(`vmmigration.googleapis.com/v1`) as an alternative to the Cloud Console UI.
API equivalents are shown throughout the exercises.

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

## 1. Overview

### What Is Google Cloud VMware Engine?

**Google Cloud VMware Engine (GCVE)** is a fully managed service that lets you run VMware
workloads natively on Google Cloud infrastructure. GCVE deploys a complete VMware SDDC stack
(vSphere, vSAN, NSX-T) on dedicated bare-metal hardware managed by Google. Your existing
VMware tools, processes, and skills work without modification.

### Use Cases

| Use Case | Description |
|---|---|
| **Data centre exit** | Lift-and-shift VMware workloads to Google Cloud with minimal refactoring |
| **Disaster recovery** | GCVE as a DR target for on-premises VMware environments |
| **Virtual Desktop Infrastructure (VDI)** | Citrix and VMware Horizon deployments on GCVE |
| **Hybrid cloud bridge** | Extend on-premises VMware into Google Cloud for burst capacity |
| **Workload modernisation** | Stage VMs in GCVE before containerising or refactoring to GKE |

### Deployment Types

| Type | Nodes | Use Case | Cost |
|---|---|---|---|
| `TIME_LIMITED` | 1 | Evaluation and lab (72-hour limit) | Minimal |
| `STANDARD` | 3+ | Production workloads | Standard pricing |

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Google Cloud                                                        │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  VMware Engine Network (VMware-managed fabric)                 │   │
│  │  ┌─────────────────────────────────────────────────────────┐  │   │
│  │  │  GCVE Private Cloud                                      │  │   │
│  │  │  • vCenter Server (VCSA)                                 │  │   │
│  │  │  • NSX-T Manager                                         │  │   │
│  │  │  • vSAN storage (all-NVMe)                               │  │   │
│  │  │  • HCX (migration appliance)                             │  │   │
│  │  │  • Management CIDR: 172.20.1.0/24                        │  │   │
│  │  │  • Node type: standard-72 (1–N nodes)                    │  │   │
│  │  └─────────────────────────────────────────────────────────┘  │   │
│  └──────────┬────────────────────────────────────────────────────┘   │
│             │ VPC Peering (VMware Engine Network ↔ Peer VPC)         │
│  ┌──────────▼────────────────────────────────────────────────────┐   │
│  │  Peer VPC (Google-managed)                                     │   │
│  │  ┌─────────────────────────────────────────────────────────┐  │   │
│  │  │  Jump Host (Windows Server 2022)                         │  │   │
│  │  │  • e2-medium (default)                                   │  │   │
│  │  │  • RDP access for vCenter/NSX-T console                  │  │   │
│  │  └─────────────────────────────────────────────────────────┘  │   │
│  │  Firewall Rules: SSH, RDP, HTTP, ICMP, internal traffic       │  │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Network Policy                                                      │
│  • Internet access via GCVE network (optional)                       │
│  • External IP access for NSX-T edge services (optional)             │
└──────────────────────────────────────────────────────────────────────┘

Module variable wiring:

  VMware_Engine
    private_cloud_type = "TIME_LIMITED"  →  Evaluation private cloud (1 node)
    node_type_id       = "standard-72"   →  Node hardware type
    node_count         = 1               →  1 for TIME_LIMITED, 3+ for STANDARD
    management_cidr    = "172.20.1.0/24" →  Management network (immutable after creation)
    create_jump_host   = true            →  Windows Server 2022 jump host
    reset_vcenter_credentials = true     →  Auto-reset vCenter solution user password
```

---

## 3. Prerequisites

### Required Tools

| Tool | Minimum Version | Install |
|---|---|---|
| `gcloud` CLI | 480.0.0 | [Install guide](https://cloud.google.com/sdk/docs/install) |
| RDP client | Any | Windows Remote Desktop, Microsoft Remote Desktop (macOS), Remmina (Linux) |
| Web browser | Any | For vCenter and NSX-T web consoles |
| `curl` / `jq` | Any | System package manager |

### GCP Permissions

```
roles/vmwareengine.admin
roles/compute.admin
roles/iam.serviceAccountAdmin
roles/logging.admin
roles/monitoring.admin
```

### GCP APIs Required

The module enables these APIs automatically:

```
vmwareengine.googleapis.com
compute.googleapis.com
cloudresourcemanager.googleapis.com
iam.googleapis.com
logging.googleapis.com
monitoring.googleapis.com
```

### Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"                 # matches the region variable
export ZONE="us-central1-a"               # matches the zone variable
export PRIVATE_CLOUD_NAME="pvt-cloud"    # default module value

gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${REGION}"
```

---

## 4. Lab Setup

### 4.1 Deploy via RAD UI

Deploy the `VMware_Engine` module via the RAD UI. In the variable form, set:

| Variable | Value | Notes |
|---|---|---|
| `project_id` | `your-gcp-project-id` | Required |
| `region` | `us-central1` | GCP region |
| `zone` | `us-central1-a` | GCP zone |
| `private_cloud_type` | `TIME_LIMITED` | `TIME_LIMITED` (eval) or `STANDARD` (prod) |
| `node_count` | `1` | 1 for TIME_LIMITED, 3 for STANDARD |
| `node_type_id` | `standard-72` | Node hardware type |
| `management_cidr` | `172.20.1.0/24` | Management CIDR — **cannot be changed after creation** |
| `create_jump_host` | `true` | Deploy Windows jump host |
| `reset_vcenter_credentials` | `true` | Auto-reset vCenter credentials |

Click **Deploy** and wait for provisioning to complete.

> **Note:** TIME_LIMITED private clouds provision in approximately **30–90 minutes**. STANDARD
> private clouds (3+ nodes) take **2–4 hours** for initial provisioning.

> **What this provisions:** A VMware Engine Network, GCVE private cloud with vCenter and NSX-T,
> VPC network peered to the VMware Engine Network, Windows Server 2022 jump host with RDP
> access, firewall rules, and optional network policies for internet and external IP access.

### 4.2 Deploy via Terraform (Alternative)

If deploying directly with Terraform/OpenTofu rather than the RAD UI:

```bash
cd modules/VMware_Engine
```

Create a `terraform.tfvars` file. The full list of configurable variables is:

| Variable | Default | Description |
|---|---|---|
| `project_id` | *(required)* | GCP project ID where all resources are created |
| `region` | `us-west2` | Region for the private cloud and network policy |
| `zone` | `us-west2-a` | Zone for the private cloud and jump host |
| `vmware_engine_network_name` | `altostrat-<id>-ven` | Must start with `altostrat-` if overridden |
| `private_cloud_name` | `altostrat-<id>-private-cloud` | Must start with `altostrat-` if overridden |
| `management_cidr` | `172.20.0.0/24` | Immutable after creation — must not overlap with peer VPC or edge services CIDR |
| `private_cloud_type` | `TIME_LIMITED` | `TIME_LIMITED` = single-node evaluation; `STANDARD` = production (minimum 3 nodes) |
| `node_type_id` | `standard-72` | API identifier. The GCP console displays `ve1-standard-72` but Terraform requires `standard-72` |
| `node_count` | `1` | Set to 1 for `TIME_LIMITED`; minimum 3 for `STANDARD` |
| `network_peering_name` | `altostrat-<id>-vpc-ven` | Auto-scoped to deployment ID |
| `peer_vpc_name` | `altostrat-<id>-vpc` | Auto-scoped to deployment ID |
| `network_policy_name` | `altostrat-<id>-edge-policy` | Auto-scoped to deployment ID |
| `edge_services_cidr` | `10.11.2.0/26` | Must not overlap with `management_cidr` or peer VPC subnets |
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
| `resource_creator_identity` | *(not required if using Cloud Shell)* | Service account used by Terraform to provision resources |

Minimum `terraform.tfvars` example:

```hcl
project_id = "your-project-id"
```

Then initialise and deploy:

```bash
tofu init
tofu validate
tofu plan -out=plan.tfplan
tofu apply plan.tfplan
```

**Expected provisioning times:**

| Resource | Typical time |
|---|---|
| API enablement | 1–2 minutes |
| VMware Engine Network | 1–2 minutes |
| Jump host + firewall rules | 2–3 minutes |
| Private Cloud | 120–180 minutes |
| Network Peering (activation) | Up to 5 minutes after private cloud is ready |
| Network Policy (internet activation) | Up to 15 minutes after private cloud is ready |
| vCenter credential reset | 1–2 minutes after private cloud is ready |

> The `tofu apply` command will not return until the private cloud is fully provisioned.
> Allow up to 90 minutes.

The vCenter solution user credentials are printed to the apply log by the
`null_resource.vcenter_credentials_reset` provisioner. Scroll back through the output and
save both the username (`solution-user-01@gve.local`) and the generated password — you will
need them when accessing vCenter. You can also retrieve them at any time with:

```bash
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud=<private-cloud-name> \
  --location=<zone> \
  --project=<project_id> \
  --username=solution-user-01@gve.local
```

### 4.2 Retrieve Deployment Outputs

After deployment, note the Terraform outputs:

**gcloud:**
```bash
gcloud vmware private-clouds list \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.privateClouds[] | {name, state, nsx: .nsx.fqdn, vcenter: .vcenter.fqdn}'
```

---

## Exercise 1 — Access the Jump Host and Management Consoles

### Objective

Connect to the Windows jump host via RDP, retrieve vCenter credentials, and access the vCenter
and NSX-T management consoles.

### Step 1.1 — Get the Jump Host External IP

**gcloud:**
```bash
gcloud compute instances list \
  --filter="name~jump-host" \
  --project="${PROJECT_ID}" \
  --format="table(name, zone, status, networkInterfaces[0].accessConfigs[0].natIP)"
```

**REST API:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${ZONE}/instances" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | select(.name | test("jump")) | {name, status, ip: .networkInterfaces[0].accessConfigs[0].natIP}'
```

### Step 1.2 — Set the Windows Password

The jump host runs Windows Server 2022. Before RDP, generate a Windows password:

**gcloud:**
```bash
JUMP_HOST=$(gcloud compute instances list \
  --filter="name~jump-host" \
  --project="${PROJECT_ID}" \
  --format="value(name)")

gcloud compute reset-windows-password "${JUMP_HOST}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"
```

Note the username and password from the output.

**REST API:**
```bash
# Password reset via metadata key (requires Cloud-init support)
curl -s -X POST \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/zones/${ZONE}/instances/${JUMP_HOST}/setMetadata" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "fingerprint": "<metadata-fingerprint>",
    "items": [{"key": "windows-startup-script-cmd", "value": "net user Administrator <new-password>"}]
  }'
```

### Step 1.3 — Connect via RDP

Use your RDP client to connect to the jump host:

```
Host: <jump-host-external-ip>:3389
Username: <username-from-gcloud-output>
Password: <password-from-gcloud-output>
```

> **Tip:** On macOS, use Microsoft Remote Desktop. On Linux, use Remmina or FreeRDP:
> ```bash
> xfreerdp /u:<username> /p:<password> /v:<jump-host-ip>:3389 /dynamic-resolution
> ```

If the password reset fails, check the serial port output for
`Instance setup finished. jump-host is ready to use.` before retrying. The jump host takes
approximately 2 minutes to finish Windows startup after Terraform creates it.

Once logged in, minimize Server Manager to reveal the desktop. If a Network dialog appears
on the right side of the screen, click **Yes**.

### Step 1.3a — Start the OVA Download (if doing the VM Migration exercises)

The Bank of Anthos OVA is large — start the download now so it is ready when you reach
Exercise 6.

1. Double-click the **Google Cloud Shell** icon on the jump host desktop.
2. Run the following command:

```cmd
gsutil cp gs://gcve-lab-bank-of-anthos-ova/bank-of-anthos.ova %HOMEPATH%\Downloads\
```

3. Leave the download running in the background and continue with the next step.

**Expected result:** The OVA begins downloading to `C:\Users\<username>\Downloads\`.

### Step 1.4 — Retrieve vCenter and NSX-T Credentials

**gcloud (vCenter credentials):**
```bash
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}/vcenterCredentials" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{username, password}'
```

**gcloud (NSX-T credentials):**
```bash
gcloud vmware private-clouds nsx credentials describe \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}/nsxCredentials" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{username, password}'
```

### Step 1.5 — Get Console FQDNs

**gcloud:**
```bash
gcloud vmware private-clouds describe "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(vcenter, nsx, hcx)"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{vcenter: .vcenter.fqdn, nsx: .nsx.fqdn, hcx: .hcx.fqdn}'
```

### Step 1.6 — Log In to vCenter

From inside the jump host RDP session:

1. Open Edge (click the icon in the taskbar; skip personalisation prompts)
2. Navigate to `https://<vcenter-fqdn>` — the FQDN is in the format
   `https://vcsa-XXX.XXXXXX.<region>.gve.goog`
3. Click **Advanced**, then click **Continue to vcsa-XXX... (unsafe)** to bypass the
   self-signed certificate warning
4. Click **Launch vSphere Client (HTML5)**
5. Log in with the credentials from Step 1.4 (username: `solution-user-01@gve.local`)

> **Alternative:** If the FQDN does not resolve, use the direct IP address `https://10.11.0.2`
> (only reachable from the jump host after peering is Active).

**Expected result:** The vSphere Client dashboard loads showing the private cloud management
cluster.

### Step 1.7 — Log In to NSX-T Manager

1. Open a new Edge browser tab and navigate to `https://<nsx-fqdn>` — the FQDN is in the
   format `https://nsx-XXX.XXXXXX.<region>.gve.goog`
2. Click **Advanced**, then **Continue to nsx-XXX... (unsafe)**
3. Log in using the NSX-T credentials from Step 1.4

> **Alternative:** Use the direct IP address `https://10.11.0.18` if the FQDN does not
> resolve.

**Expected result:** The NSX-T Manager dashboard loads.

---

## Exercise 2 — Explore vCenter and the Private Cloud

### Objective

Navigate vCenter to understand the GCVE private cloud topology and verify all VMware components
are healthy.

### Step 2.1 — Verify the Private Cloud State

**gcloud:**
```bash
gcloud vmware private-clouds describe "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(state, hcx, vcenter, nsx)"
```

Expected: `state: ACTIVE`

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, state, nodeCount: (.managementCluster.nodeCount)}'
```

### Step 2.2 — Explore vCenter Inventory

In the vCenter web client (from the jump host):

1. Navigate to **Hosts and Clusters** — view the VMware Engine management cluster
2. Click the cluster → **Monitor** → **vSAN** → verify vSAN health is green
3. Navigate to **Storage** — view the vSAN datastore
4. Navigate to **Networking** — view the management network port groups

### Step 2.3 — View Management Cluster Nodes

**gcloud:**
```bash
gcloud vmware private-clouds clusters list \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}/clusters" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.clusters[] | {name, state, nodeCount: .nodeCount}'
```

### Step 2.4 — List Subnets

**gcloud:**
```bash
gcloud vmware private-clouds subnets list \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}/subnets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.subnets[] | {name, ipCidrRange, state}'
```

---

## Exercise 3 — NSX-T Network Configuration

### Objective

Access NSX-T Manager, create a DHCP server and workload segment, and verify route export
to the peered VPC.

### Step 3.1 — Log In to NSX-T Manager

From the jump host:

1. Open a browser and navigate to `https://<nsx-fqdn>`
2. Log in with NSX-T credentials (from Exercise 1 Step 1.4)
3. Username typically: `admin`

### Step 3.2 — Create a DHCP Server on the NSX-T Tier-1 Gateway

A DHCP Server must be configured on the Tier-1 Gateway before creating the workload segment
so that VMs deployed to the segment can receive IP addresses automatically.

1. On the NSX-T Manager home page, click **Networking > Tier-1 Gateways**
2. Next to the deployed Tier-1 Gateway, click the **three ellipsis dots (⋮)** and select
   **Edit**
3. In the **DHCP Config** row, click **Set**
4. Under **Type**, select **DHCP Server** from the dropdown
5. Click the **three ellipsis dots (⋮)** next to **DHCP Server Profile** and select
   **Create New**
6. Enter the following values:

| Field | Value |
|---|---|
| DHCP Profile Name | `DHCP-Class` |
| Server IP Address | `172.21.0.5/24` |
| Edge Cluster | `edge-cluster` (select from dropdown) |

7. Click **Save** to save the DHCP profile
8. Click **Apply** and then **Save** to apply the DHCP config to the gateway
9. Click **Close Editing** to exit the Tier-1 Gateway configuration

**Expected result:** The Tier-1 Gateway shows the DHCP Server profile `DHCP-Class` configured
with server IP `172.21.0.5/24`. The gateway is now ready to serve DHCP leases to VMs on
segments connected to it.

### Step 3.3 — Create a Workload Segment

In NSX-T Manager:

1. Navigate to **Networking > Segments**
2. Click **Add Segment**
3. Configure:

| Field | Value |
|---|---|
| Segment Name | `my-nsx-network` |
| Connected Gateway | `Tier1` |
| Transport Zone | `TZ-OVERLAY \| Overlay` (select from dropdown) |
| Subnets — Gateway IP/Prefix Length | `192.168.142.1/24` |

4. Click **Set DHCP Config** and configure:

| Field | Value |
|---|---|
| DHCP Type | `Gateway DHCP Server` |
| DHCP Range | `192.168.142.10-192.168.142.50` (press Enter to confirm) |
| DNS Servers | `172.20.1.234` |

5. Click **Apply**, then **Save**
6. When prompted to continue editing, click **No**

**Expected result:** The segment `my-nsx-network` appears in the Segments list with a status
of **Success**. The route `192.168.142.0/24` is automatically exported to the peered VPC via
the active network peering.

### Step 3.4 — Verify Route Export to Peer VPC

After creating the segment, GCVE automatically exports routes to the peered VPC network:

**gcloud:**
```bash
gcloud vmware networks peerings list \
  --project="${PROJECT_ID}" \
  --location=global

# View exported routes
gcloud compute routes list \
  --filter="network~vmware" \
  --project="${PROJECT_ID}"
```

**REST API (peerings):**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/vmwareEngineNetworks" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.vmwareEngineNetworks[] | {name, state}'
```

---

## Exercise 4 — VPC Peering and Network Connectivity

### Objective

Verify the VPC peering between the VMware Engine Network and the peer VPC, and test
network connectivity from the jump host to private cloud resources.

### Step 4.1 — Inspect the VPC Peering

**gcloud:**
```bash
gcloud vmware network-peerings list \
  --project="${PROJECT_ID}" \
  --location=global
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/networkPeerings" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.networkPeerings[] | {name, state, vmwareEngineNetwork, peerNetwork}'
```

### Step 4.2 — Inspect the Compute VPC Peering

**gcloud:**
```bash
gcloud compute networks peerings list \
  --network="peer-network" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/networks/peer-network" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.peerings[] | {name, state, network}'
```

### Step 4.3 — Test Connectivity from Jump Host

From the Windows jump host, open PowerShell and test connectivity to the private cloud:

```powershell
# Ping vCenter IP (from management CIDR)
# Get vCenter internal IP from the GCVE console
Test-NetConnection -ComputerName <vcenter-internal-ip> -Port 443

# Ping NSX-T IP
Test-NetConnection -ComputerName <nsx-internal-ip> -Port 443
```

From the jump host, you should be able to reach vCenter and NSX-T via their internal IPs
because the jump host is in the peered VPC.

### Step 4.4 — View Peered Routes

**gcloud:**
```bash
gcloud compute routes list \
  --project="${PROJECT_ID}" \
  --format="table(name, network, destRange, nextHopGateway, priority)"
```

**REST API:**
```bash
curl -s \
  "https://compute.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/routes" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.items[] | {name, destRange, nextHopGateway}'
```

---

## Exercise 5 — Network Policies (Internet and External IP Access)

### Objective

Explore and configure VMware Engine Network Policies that control internet access and external
IP routing for the GCVE private cloud.

### Step 5.1 — View Existing Network Policies

**gcloud:**
```bash
gcloud vmware network-policies list \
  --location="${REGION}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/networkPolicies" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.networkPolicies[] | {name, vmwareEngineNetwork, edgeServicesCidr, internetAccess: .internetAccess.enabled, externalIp: .externalIp.enabled}'
```

### Step 5.2 — Enable Internet Access

If `enable_internet_access` was set to `true` during deployment, the network policy already
allows outbound internet access from the GCVE network. To verify or update:

**gcloud:**
```bash
gcloud vmware network-policies describe "<network-policy-name>" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(internetAccess, externalIp)"
```

**REST API (update to enable internet access):**
```bash
NETWORK_POLICY="<your-network-policy-name>"

curl -s -X PATCH \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/networkPolicies/${NETWORK_POLICY}?updateMask=internet_access" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "internetAccess": {"enabled": true}
  }'
```

### Step 5.3 — Test Internet Access from vCenter VM

From within vCenter, deploy a test VM and verify internet connectivity through the NSX-T edge:

1. In vCenter, right-click the cluster → **New Virtual Machine**
2. Use a minimal Linux ISO (e.g., Tiny Core Linux)
3. Assign the VM to `workload-segment`
4. Boot and test: `curl -s ifconfig.me`

### Step 5.4 — External IP Access for Edge Services

External IP access allows NSX-T to assign public IPs to NAT rules:

**gcloud:**
```bash
gcloud vmware network-policies update "<network-policy-name>" \
  --external-ip \
  --location="${REGION}" \
  --project="${PROJECT_ID}"
```

---

## Exercise 6 — VM Migration with Migrate to Virtual Machines

### Objective

Use the Migrate to Virtual Machines service to migrate a VM from an on-premises VMware
environment (or another source) into GCVE. This exercise covers the Migrate Connector
setup and migration job configuration.

### Step 6.1 — Verify Migration APIs

**gcloud:**
```bash
gcloud services list \
  --filter="config.name~vmmigration OR config.name~vmwareengine" \
  --project="${PROJECT_ID}" \
  --format="table(config.name, state)"
```

**REST API:**
```bash
curl -s \
  "https://serviceusage.googleapis.com/v1/projects/${PROJECT_ID}/services?filter=state:ENABLED" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.services[] | select(.name | test("vmmigration|vmware")) | .name'
```

### Step 6.2 — Create a Migration Source

**gcloud:**
```bash
gcloud migration vms sources create "on-prem-vcenter" \
  --vcenter-ip="<vcenter-on-prem-ip>" \
  --vcenter-username="administrator@vsphere.local" \
  --vcenter-password="<password>" \
  --project="${PROJECT_ID}" \
  --location="${REGION}"
```

**REST API:**
```bash
curl -s -X POST \
  "https://vmmigration.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/sources?sourceId=on-prem-vcenter" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "vmware": {
      "vcenterClient": {
        "datacenterPath": "<datacenter-name>",
        "vcenterIp": "<vcenter-ip>",
        "username": "administrator@vsphere.local",
        "password": "<password>"
      }
    }
  }'
```

### Step 6.3 — Deploy the Migrate Connector

The Migrate Connector is an OVA deployed to the source vCenter environment. First, generate an SSH key pair, then deploy the OVA.

#### Step 6.3a — Generate an SSH Key Pair with PuTTYgen

The Migrate Connector OVF requires an SSH public key at deploy time to allow admin access to the appliance.

1. On the jump host, click the Windows **Start** button and search for **PuTTYgen**. If not found, download from https://puttygen.com/ and install. Open the application.
2. Click **Generate** and move your mouse over the blank area to generate randomness until the progress bar completes.
3. Click **Save private key**. When prompted about saving without a passphrase, click **Yes**.
4. Enter `m2vm_key` as the filename and click **Save**.
5. Leave PuTTYgen open — you will copy the public key from it in the next step.

**Expected result:** The private key file `m2vm_key.ppk` is saved to the Desktop. The public key is displayed in the PuTTYgen window.

#### Step 6.3b — Deploy the Migrate Connector OVF

1. Paste the URL below to download the Migrate Connector OVA file:

```
https://storage.googleapis.com/vmmigration-public-artifacts/migrate-connector-2-8-2977.ova
```

2. On the jump host, switch to the **vSphere Client** browser tab.
3. Right-click the **Workload** in the left-hand resource tree and select **Deploy OVF Template**.
4. On the **Select an OVF template** page, select **Local file** and click the **UPLOAD FILES** button and select the downloaded `migrate-connector-2-8-2977.ova` file. Click **Next**.
5. If prompted to accept an SSL certificate, click **Yes**.
6. Step through the wizard using the values below:

| Wizard Step | Value |
|---|---|
| Select a name and folder | Navigate to **Datacenter > Workload**, click Next |
| Select a compute resource | Navigate to **Datacenter > Workload**, click Next |
| Review details | Click Next |
| Select storage | Select **vsanDatastore**, click Next |
| Select networks — Destination Network | Click the dropdown, select **Browse**, choose **my-nsx-network**, click OK, then Next |

7. On the **Customize Template** screen, locate the **SSH Public Key** field.
8. Switch to PuTTYgen, select the entire public key text starting with `ssh-rsa` through to the end, and copy it.
9. Paste the public key into the **SSH Public Key** field in the vSphere wizard.
10. Click **Next**, then click **Finish**.
11. Monitor the **Recent Tasks** pane and wait for the deployment to complete.

> If you encounter an error during deployment, start the wizard again from Step 2.

**Expected result:** The `M4C` VM appears in the vSphere inventory and the Recent Tasks pane shows the deployment as completed successfully.

#### Step 6.3c — Power On the Migrate Connector

1. In the vSphere Client left-hand navigation, select the **M4C** instance.
2. Click the **Power on** button.
3. Wait until the VM details pane shows an IP address assigned (format: `192.168.142.xx`). Note this IP address — you will SSH to it in the next step.

**Expected result:** The Migrate Connector VM is running and has an IP address on the `my-nsx-network` workload segment.

### Step 6.4 — Register the Migrate Connector

#### Step 6.4a — Retrieve the vCenter Solution User Credentials

Terraform reset and retrieved the vCenter solution user credentials at the end of deployment. Retrieve them now if you did not save them earlier.

1. On your local machine, open Cloud Shell in the Google Cloud console.
2. Run the following command (replace values as needed):

```bash
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud=altostrat-ID-private-cloud \
  --username=solution-user-01@gve.local \
  --location=us-west2-a
```

3. Save the returned username and password.

**Expected result:** The credentials for `solution-user-01@gve.local` are displayed. These are used by the Migrate Connector to authenticate with vCenter.

#### Step 6.4b — SSH into the Migrate Connector

1. On the jump host, click the Windows **Start** button and search for **PuTTY**. Open the application.
2. In the PuTTY window, expand **Connection > SSH > Auth** in the left-hand tree.
3. Click **Browse** and select the `m2vm_key.ppk` private key saved in Step 6.3a.
4. Scroll to the top of the left-hand tree and click **Session**.
5. In the **Host Name** field, enter:

```
admin@192.168.142.xx
```

   Replace `xx` with the IP address noted in Step 6.3c.

6. Click **Open**.
7. If prompted with a server host key warning, click **Accept**.

**Expected result:** You are logged in to the Migrate Connector appliance shell as `admin`.

#### Step 6.4c — Verify Connector Status

In the PuTTY SSH window, run:

```bash
m2vm status
```

**Expected result:** Output shows the connector is **not registered**.

#### Step 6.4d — Obtain a Google Cloud Access Token

The `m2vm register` command requires a short-lived OAuth token to authenticate with Google Cloud.

1. Switch to the Google Cloud console on your local machine.
2. Open Cloud Shell and run:

```bash
gcloud auth print-access-token
```

3. Click **Authorize** if prompted.
4. Select and copy the entire token returned.

**Expected result:** A long alphanumeric token string is copied to your clipboard.

#### Step 6.4e — Register the Migrate Connector

1. In the PuTTY SSH window, run:

```bash
m2vm register
```

2. When prompted for an **access token**, right-click in the PuTTY window to paste the token copied in Step 6.4d, then press **Enter**.
3. When prompted for each value, enter the following:

| Prompt | Value |
|---|---|
| Project | Select your `migrate-training-xx-1234` project (option 2) |
| Region | `us-west2` (type exactly) |
| Source name | `migrate-vsphere` (type exactly) |
| KMS Key | Leave blank, press Enter |

4. When prompted to select a service account, choose the default option.
5. Wait approximately 5 minutes for the source to be created and the connector to become active.

> **If you see:** `Read access to project '...' was denied` — navigate to **Compute Engine > Migrate to Virtual Machines** in the console, confirm the API is enabled, and retry.
>
> **If registration fails and you need to retry:** delete all VM Migrations, Disk Migrations, and Utilization Reports in the Migrate to VMs console before running `m2vm register` again.

**Expected result:** Registration completes with a message confirming the connector is active and the source `migrate-vsphere` has been created.

#### Step 6.4f — Confirm Registration and Set Bandwidth Limit

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

**Expected result:** Status shows the connector as **registered and active**. Upload rate shows **100 MiBps**.

#### Step 6.4g — Verify the Source in the Migrate to VMs Console

1. In the Google Cloud console, navigate to **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Sources** tab.
3. Select **migrate-vsphere** from the source dropdown.
4. A list of VMware VMs discovered from the GCVE environment is displayed. If the list is empty, wait 1–2 minutes and refresh.
5. Click **Source Details** (top right) to confirm the source configuration.

**Expected result:** The source `migrate-vsphere` is active and the VM inventory is populated with the VMs running in GCVE.

> **REST API equivalent — fetch VM inventory:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID:fetchInventory?forceRefresh=true" \
>   -H "Authorization: Bearer $TOKEN" | jq '.vmwareVms.details[] | {vmId, displayName}'
> ```
> Note the `vmId` value for each VM (e.g. `vm-12345`) — you need it as `sourceVmId` when creating migration jobs via the API.

### Step 6.5 — Clean Up Any Previous Lab Resources

Before starting migration operations, confirm no leftover VMs or disks from a previous lab run exist in the project. Orphaned resources will conflict with migration target names.

1. In the Google Cloud console, navigate to **Compute Engine > VM instances**.
2. If any migrated VMs from a previous run are present (e.g. `front-end`, `back-end`, `db-server`), select them and click **Delete**.
3. Navigate to **Compute Engine > Disks**.
4. If any migrated disks from a previous run are present, select them and click **Delete**.

**Expected result:** No migrated VMs or disks remain. Only the jump host VM created by Terraform should be present.

### Step 6.6 — Create Utilization Reports

Utilization reports confirm connectivity between the Migrate Connector and Google Cloud, and provide rightsizing data for migration planning.

1. In the Google Cloud console, navigate to **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Sources** tab and select **migrate-vsphere**.
3. In the VM list, select the checkboxes for the following VMs:
   - `front-end`
   - `back-end`
   - `db-server`
4. Click **Create Report**.
5. Create the following three reports in sequence. For each report, click **Create Report**, enter the values below, and click **Create**:

| Name | Time period |
|---|---|
| `weekly-utilization` | `Weekly` |
| `monthly-utilization` | `Monthly` |
| `yearly-utilization` | `Yearly` |

**Expected result:** All three reports are queued. Successfully generated reports confirm that the Migrate Connector has active connectivity to Google Cloud and can read VM metrics from the vCenter source.

> **REST API equivalent — create utilization reports:**
> Replace `VM_ID_*` with the `vmId` values returned by `fetchInventory`.
> ```bash
> for PERIOD in WEEK MONTH YEAR; do
>   ID="${PERIOD,,}-utilization"
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/utilizationReports?utilizationReportId=$ID" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d "{
>       \"displayName\": \"$ID\",
>       \"timeFrame\": \"$PERIOD\",
>       \"vms\": [
>         {\"vmId\": \"VM_ID_FRONTEND\"},
>         {\"vmId\": \"VM_ID_BACKEND\"},
>         {\"vmId\": \"VM_ID_DBSERVER\"}
>       ]
>     }" | jq '.name'
> done
> ```

To view a report, click the **Sources** tab, then click **View Reports** (top right), then click a report name to open it.

### Step 6.7 — Create VM Migrations and Start Replication

#### Step 6.7a — Create VM Migrations for the Bank of Anthos VMs

1. In the Google Cloud console, navigate to **Compute Engine > Migrate to Virtual Machines**.
2. Click the **Sources** tab and select **migrate-vsphere**.
3. In the VM list, select the checkboxes for all three Bank of Anthos VMs:
   - `front-end`
   - `back-end`
   - `db-server`
4. Click **Add Migrations > VM Migration**.
5. Click **Confirm** when prompted.

**Expected result:** VM migration jobs are created for all three VMs. Click the **VM Migrations** tab to see them listed.

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

#### Step 6.7b — Create the Bank-of-Anthos Migration Group

Groups allow you to manage related VMs together and apply shared target settings in a single operation.

1. Click the **Sources** tab.
2. Select the checkboxes for `front-end`, `back-end`, and `db-server`.
3. Click **Add to Group**.
4. Type `bank-of-anthos` as the new group name and click **Add to Group**.

**Expected result:** The three VMs are added to the `bank-of-anthos` group and the group is visible on the **Groups** tab.

> **REST API equivalent — create group and add members:**
> ```bash
> # Create the group
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/groups?groupId=bank-of-anthos" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{"displayName": "bank-of-anthos", "migrationTargetType": "MIGRATION_TARGET_TYPE_GCE"}' | jq '.name'
>
> # Add each VM to the group
> for VM in front-end back-end db-server; do
>   curl -s -X POST \
>     "$BASE/projects/$PROJECT/locations/$REGION/groups/bank-of-anthos:addGroupMigration" \
>     -H "Authorization: Bearer $TOKEN" \
>     -H "Content-Type: application/json" \
>     -d "{\"migratingVm\": \"projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/$VM\"}" \
>     | jq '.name'
> done
> ```

#### Step 6.7c — Start Replication for the Bank-of-Anthos Group

1. Click the **Groups** tab.
2. Click the group name **bank-of-anthos** (click the name itself, not the checkbox).
3. Select the checkboxes for `front-end`, `back-end`, and `db-server`.
4. Click **Migration > Start Replication**.
5. Click the back arrow (top left) to return to the groups list.

**Expected result:** Replication starts for all three VMs. Their status changes to **Replicating**. The first sync will take approximately 15 minutes.

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

#### Step 6.7d — Monitor Replication Progress and View Cycle History

1. Click the **VM Migrations** tab to monitor sync progress for all three VMs.
2. Wait until the replication status for all three VMs changes to **Active** before proceeding.
3. Click the name **front-end** to open its details page, then click the **Replication Cycles** tab to review completed cycles — each row shows start time, duration, data transferred, and status.

**Expected result:** All three VMs show **Active** replication. At least one completed replication cycle is listed for `front-end`, confirming that incremental CBT replication is working.

> **REST API equivalent — list replication cycles:**
> ```bash
> curl -s \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/front-end/replicationCycles" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.replicationCycles[] | {cycleNumber, state, startTime, endTime, progressPercent}'
> ```

#### Step 6.7e — Pause and Resume Replication

Pausing halts the incremental replication cycle without deleting any replicated data. This is useful during planned maintenance windows on the source environment.

1. On the **VM Migrations** tab, select the checkbox for **front-end**.
2. Click **Migration > Pause Replication**.
3. Observe the status change to **Paused**.
4. Click **Migration > Resume Replication**.
5. Observe the status return to **Active**.

**Expected result:** Replication pauses and resumes cleanly. No data is lost during the pause — the next cycle after resuming picks up only the blocks changed since the last completed cycle.

> **Note:** Replication cannot be paused while a cut-over is in progress.

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

### Step 6.7f — Configure Migration Target Details

Target details define the Compute Engine instance configuration that will be created when a test clone or cut-over is triggered.

**front-end:**

1. In **Migrate to Virtual Machines**, click the **Groups** tab and click the group name **bank-of-anthos**.
2. Select the checkbox for **front-end** and click **Edit Target Details**.
3. Enter the following values:

| Section | Field | Value |
|---|---|---|
| General | Instance name | `front-end` |
| General | Zone | `us-west2-a` |
| Machine Configuration | Machine type | `e2-medium` |
| Networking | Network | `default` |
| Networking | Subnetwork | `default` |
| Networking | Network tags | `http-server` (click Add Network Tag) |

4. Click **Save**.

**back-end and db-server:** Repeat for each VM with the same settings (no network tag needed for `back-end` and `db-server`).

> **REST API equivalent — configure target details:**
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

### Step 6.8 — Perform a Test Clone and Cut-Over

A **test clone** creates a copy of the VM in Google Cloud without stopping the source VM — useful for validating the migrated workload before committing. A **cut-over** stops the source VM, performs a final sync, and creates the permanent Compute Engine instance.

#### Step 6.8a — Test Clone front-end

1. In the **bank-of-anthos** group, confirm the replication status for **front-end** is **Active**.
2. Select the checkbox for **front-end**.
3. Click **Cut-Over and Test-Clone > Test-Clone**.
4. Click **Confirm**.

**Expected result:** A test clone job is initiated for `front-end`. The cloned VM will appear in **Compute Engine > VM Instances** within approximately 15 minutes.

> **REST API equivalent — create clone job:**
> ```bash
> curl -s -X POST \
>   "$BASE/projects/$PROJECT/locations/$REGION/sources/$SOURCE_ID/migratingVms/front-end/cloneJobs?cloneJobId=clone-$(date +%s)" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{}' | jq '{operation: .name}'
> ```

#### Step 6.8b — Cut-Over back-end and db-server

Cut-over stops the source VM, performs a final incremental sync, and creates the permanent Compute Engine instance. It is an irreversible operation and should be scheduled during a maintenance window.

1. In the **bank-of-anthos** group, confirm the replication status for **back-end** and **db-server** is **Active**.
2. Select the checkboxes for **back-end** and **db-server**.
3. Click **Cut-Over and Test-Clone > Cut-Over**.
4. Click **Confirm** when prompted.

**Expected result:** Cut-over jobs are initiated for `back-end` and `db-server`. VM creation takes approximately 15 minutes.

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

#### Step 6.8c — Verify the front-end Test Clone

In Cloud Shell on your local machine, run:

```bash
gcloud compute ssh front-end --zone=us-west2-a --tunnel-through-iap -- -NL "8080:localhost:80"
```

When Cloud Shell offers a port preview, select **Preview on port 8080**.

**Expected result:** The Bank of Anthos front-end application loads in your browser via the Cloud Shell port preview, confirming the VM migrated successfully.

#### Step 6.8d — Cancel a Cut-Over (Awareness)

If a cut-over is initiated at the wrong time or against the wrong VM, it can be cancelled while in progress.

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Select a VM that is in **Cutting Over** state.
3. Click **Migration > Cancel Cut-Over**.

**Expected result:** The cut-over is cancelled and the VM returns to **Active** replication state.

> **Note:** Cancellation is only available while the cut-over job is still running. Once the Compute Engine instance has been created the operation cannot be reversed via cancel.

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

#### Step 6.8e — Finalise Migrations (Optional)

Finalisation permanently removes all migration management resources for a completed cut-over, freeing up quota and cleaning up the migration state.

1. In **Migrate to Virtual Machines**, select any cut-over migration.
2. Click **Migration > Finalize**.

**Expected result:** The migration management resources are deleted. The Compute Engine VM remains running and is now fully independent of the migration service.

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

#### Step 6.8f — View the Adaptation Report

The service automatically adapts each migrated OS to run on Compute Engine — installing virtio drivers, Compute Engine guest agents, and configuring the serial console.

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Click the name **front-end** (or any cut-over VM) to open its details page.
3. Click the **Adaptation Report** tab.
4. Review the list of adaptations applied.

**Expected result:** The adaptation report lists the OS-level changes applied automatically during the clone or cut-over, confirming the VM is prepared for Compute Engine without manual guest OS changes.

---

## Exercise 7 — Monitoring and Logging

### Objective

Explore Cloud Monitoring and Cloud Logging data for the GCVE private cloud and jump host.

### Step 7.1 — View Jump Host Metrics

**gcloud:**
```bash
JUMP_HOST=$(gcloud compute instances list \
  --filter="name~jump-host" \
  --project="${PROJECT_ID}" \
  --format="value(name)")

gcloud monitoring metrics list \
  --filter="metric.type:compute.googleapis.com/instance" \
  --project="${PROJECT_ID}" \
  | grep -E "cpu|memory|disk"
```

**REST API (CPU utilisation for jump host):**
```bash
curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/timeSeries:query" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"fetch gce_instance::compute.googleapis.com/instance/cpu/utilization | filter resource.instance_id = '$(gcloud compute instances describe ${JUMP_HOST} --zone=${ZONE} --project=${PROJECT_ID} --format=value(id))' | within 1h\"
  }" | jq '.timeSeriesData[].pointData[-1].values[0].doubleValue'
```

### Step 7.2 — View Jump Host System Logs

**gcloud:**
```bash
gcloud logging read \
  "resource.type=gce_instance \
   AND resource.labels.instance_id=$(gcloud compute instances describe ${JUMP_HOST} --zone=${ZONE} --project=${PROJECT_ID} --format=value(id))" \
  --project="${PROJECT_ID}" \
  --limit=20 \
  --format=json \
  | jq '.[] | {timestamp, message: .textPayload}'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"resource.type=gce_instance resource.labels.zone=${ZONE}\",
    \"pageSize\": 10
  }" | jq '.entries[] | {timestamp, severity, message: .textPayload}'
```

### Step 7.3 — VMware Engine Audit Logs

```bash
gcloud logging read \
  "protoPayload.serviceName=vmwareengine.googleapis.com" \
  --project="${PROJECT_ID}" \
  --limit=10 \
  --format=json \
  | jq '.[] | {
    timestamp,
    method: .protoPayload.methodName,
    caller: .protoPayload.authenticationInfo.principalEmail,
    status: .protoPayload.status.code
  }'
```

**REST API:**
```bash
curl -s -X POST \
  "https://logging.googleapis.com/v2/entries:list" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceNames\": [\"projects/${PROJECT_ID}\"],
    \"filter\": \"protoPayload.serviceName=vmwareengine.googleapis.com\",
    \"pageSize\": 10
  }" | jq '.entries[] | {timestamp, method: .protoPayload.methodName}'
```

### Step 7.4 — Security Command Center Findings

```bash
echo "https://console.cloud.google.com/security/command-center?project=${PROJECT_ID}"
```

SCC reports configuration findings, vulnerability detections, and threat detections for all
GCP resources including Compute Engine instances and VMware Engine networks.

---

## Exercise 8 — Advanced Operations

### Objective

Explore advanced GCVE operations: additional cluster creation, vCenter lifespan management,
IAM roles, and bulk migration configuration.

### Step 8.1 — Create an Additional Cluster (STANDARD only)

For STANDARD private clouds, you can add additional clusters for workload isolation:

**gcloud:**
```bash
gcloud vmware private-clouds clusters create "workload-cluster" \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --node-count=3 \
  --node-type="standard-72" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s -X POST \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}/clusters?clusterId=workload-cluster" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "nodeTypeConfigs": {
      "standard-72": {
        "nodeCount": 3
      }
    }
  }'
```

### Step 8.2 — Manage vCenter Credentials

vCenter `solution@gve.local` credentials expire periodically. The module auto-resets them
when `reset_vcenter_credentials = true`. To reset manually:

**gcloud:**
```bash
gcloud vmware private-clouds vcenter credentials reset \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

**REST API:**
```bash
curl -s -X POST \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}/vcenterCredentials:reset" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Step 8.3 — View IAM Roles for VMware Engine

```bash
gcloud projects get-iam-policy "${PROJECT_ID}" \
  --format="json" \
  | jq '.bindings[] | select(.role | test("vmware")) | {role, members}'
```

### Step 8.4 — Private Cloud Lifespan Extension (TIME_LIMITED)

TIME_LIMITED private clouds expire after 72 hours. To extend:

**REST API:**
```bash
curl -s -X POST \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}:resetNsxCredentials" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
```

> **Note:** TIME_LIMITED private clouds cannot be extended. For longer evaluations, provision
> a STANDARD private cloud with `private_cloud_type = "STANDARD"` and `node_count = 3`.

### Step 8.5 — Bulk Migration Configuration via CSV Export and Import

For large migrations with many VMs, configuring target details individually in the console is impractical. The service supports exporting the current VM list to CSV, editing it externally, and re-importing to bulk-create or update migrations. Up to 100 migrations can be processed per import file.

**Export:**

1. In **Migrate to Virtual Machines**, click the **VM Migrations** tab.
2. Click the **Export** button (top right).
3. Select **CSV** as the format and click **Export**.
4. Open the downloaded file in a spreadsheet editor.
5. Review the columns — each row represents one migrating VM with fields for instance name, project, zone, machine type, network, subnetwork, network tags, disk type, and boot mode.

**Edit and re-import:**

6. Modify target detail columns for one or more VMs (e.g. change machine type or add a network tag).
7. Save the file as CSV.
8. In the console, click **Import**.
9. Upload the edited CSV file and click **Import**.

**Expected result:** The import updates target details for all rows in the file. Any validation errors are reported before the import is committed.

> **Tip:** The import can also create new migrations and assign VMs to groups by populating the `group` column. This makes it the fastest way to onboard and configure a large VM fleet in one operation.

### Step 8.6 — Configure IAM Access for Migration Operations

In production, migration operations should be delegated using least-privilege IAM roles rather than granting broad project access.

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

**Expected result:** The team member can view all migration status and reports in the Migrate to Virtual Machines console but cannot start replication, trigger cut-overs, or modify target details.

### Step 8.7 — Review Audit Logs for Migration Operations

Every migration operation (start replication, cut-over, finalize) generates an entry in Cloud Audit Logs, providing a complete compliance trail.

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

**Expected result:** Audit log entries are visible for all migration operations performed during the lab, confirming that `vmmigration.googleapis.com` Admin Activity logs are captured automatically with no additional configuration.

### Step 8.8 — Understand VM Migration Lifespan and Expiry

Be aware of the following lifecycle limits when planning long-running migrations:

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

**Expected result:** The migration lifespan is extended by 100 days. This option is available only once — plan cut-overs well within the 200-day window to avoid losing replication state.

### Step 8.9 — Register an Additional Target Project

By default the host project (where the Migrate Connector source is registered) is also the target project where Compute Engine instances are created. You can register additional GCP projects as migration targets — useful when migrating workloads into a separate production project from the migration management project.

1. In **Migrate to Virtual Machines**, click the **Settings** tab.
2. Click **Target Projects**.
3. Click **Add Target Project**.
4. Enter the project ID of the target project.
5. Follow the prompts to grant the required Compute Engine IAM permissions to the migration service account in that project.

**Expected result:** The additional project appears in the target project list and becomes available in the **Project** dropdown when configuring target details for any migrating VM.

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

## 13. Cleanup

Return to the RAD UI and click **Undeploy** on the `VMware_Engine` deployment. This removes
the GCVE private cloud, VMware Engine Network, peer VPC, jump host, and all associated
resources.

> **Warning:** GCVE private cloud deletion is irreversible. All VMs running in the private
> cloud will be permanently deleted. Ensure workloads are migrated or backed up before
> triggering cleanup.

### Manual Cleanup Order

Deletions must happen in this order to avoid dependency errors:

1. Delete VMs running in vCenter (from the vCenter console or NSX-T)
2. Delete NSX-T segments and DHCP servers
3. Delete additional clusters (if created in Exercise 8)
4. Delete the private cloud

**gcloud:**
```bash
# Step 1: Delete additional clusters (if created)
gcloud vmware private-clouds clusters delete "workload-cluster" \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet

# Step 2: Delete private cloud (triggers full SDDC deletion)
gcloud vmware private-clouds delete "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet

# Step 3: Delete jump host
gcloud compute instances delete "${JUMP_HOST}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet

# Step 4: Delete VPC network and firewall rules
gcloud compute networks delete "peer-network" \
  --project="${PROJECT_ID}" \
  --quiet
```

**REST API — delete private cloud:**
```bash
curl -s -X DELETE \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

---

## 14. Reference

### Key Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | GCP project ID (required) |
| `region` | string | — | GCP region (required) |
| `zone` | string | — | GCP zone (required) |
| `private_cloud_type` | string | `TIME_LIMITED` | `TIME_LIMITED` (eval) or `STANDARD` (prod) |
| `node_count` | number | `1` | 1 for TIME_LIMITED, 3+ for STANDARD |
| `node_type_id` | string | `standard-72` | VMware Engine node hardware type |
| `management_cidr` | string | `172.20.1.0/24` | Management CIDR — **immutable after creation** |
| `create_jump_host` | bool | `true` | Deploy Windows Server 2022 jump host |
| `jump_host_machine_type` | string | `e2-medium` | Jump host Compute Engine machine type |
| `reset_vcenter_credentials` | bool | `true` | Auto-reset vCenter solution user password |
| `create_network` | bool | `true` | Create peer VPC network |
| `enable_internet_access` | bool | `false` | Enable internet access from GCVE network |
| `enable_external_ip` | bool | `false` | Enable external IP access for NSX-T edge |
| `create_firewall_rules` | bool | `true` | Create firewall rules (RDP, SSH, HTTP, ICMP) |

### Terraform Outputs

| Output | Description |
|---|---|
| `deployment_id` | Unique deployment suffix |
| `project_id` | GCP project ID |
| `vmware_engine_network_id` | VMware Engine Network resource ID |
| `private_cloud_id` | GCVE private cloud resource ID |
| `vcenter_fqdn` | vCenter FQDN for browser access |
| `nsx_fqdn` | NSX-T Manager FQDN for browser access |
| `hcx_fqdn` | HCX appliance FQDN |
| `network_peering_state` | VPC peering status |
| `network_policy_id` | VMware Engine Network Policy ID |

### VMware Engine Node Types

| Node Type | Cores | RAM | vSAN Capacity | Use Case |
|---|---|---|---|---|
| `standard-72` | 72 vCPUs | 768 GB | ~36 TB NVMe | General workloads |
| `highmem-72` | 72 vCPUs | 1,536 GB | ~36 TB NVMe | Memory-intensive workloads |
| `standard-32` | 32 vCPUs | 384 GB | ~18 TB NVMe | Smaller deployments |

### Useful Commands Reference

```bash
# List private clouds
gcloud vmware private-clouds list --location="${ZONE}" --project="${PROJECT_ID}"

# Get vCenter credentials
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud="${PRIVATE_CLOUD_NAME}" --location="${ZONE}" --project="${PROJECT_ID}"

# Get NSX-T credentials
gcloud vmware private-clouds nsx credentials describe \
  --private-cloud="${PRIVATE_CLOUD_NAME}" --location="${ZONE}" --project="${PROJECT_ID}"

# List clusters in private cloud
gcloud vmware private-clouds clusters list \
  --private-cloud="${PRIVATE_CLOUD_NAME}" --location="${ZONE}" --project="${PROJECT_ID}"

# List network policies
gcloud vmware network-policies list --location="${REGION}" --project="${PROJECT_ID}"

# Reset vCenter credentials
gcloud vmware private-clouds vcenter credentials reset \
  --private-cloud="${PRIVATE_CLOUD_NAME}" --location="${ZONE}" --project="${PROJECT_ID}"

# Jump host external IP
gcloud compute instances list --filter="name~jump-host" --project="${PROJECT_ID}"

# VMware Engine audit logs
gcloud logging read "protoPayload.serviceName=vmwareengine.googleapis.com" \
  --project="${PROJECT_ID}" --limit=10
```

### Further Reading

- [Google Cloud VMware Engine overview](https://cloud.google.com/vmware-engine/docs/overview)
- [Private cloud provisioning](https://cloud.google.com/vmware-engine/docs/private-cloud/provision-private-cloud)
- [NSX-T network configuration in GCVE](https://cloud.google.com/vmware-engine/docs/networking/nsx-t-configuration)
- [Migrate to Virtual Machines overview](https://cloud.google.com/migrate/virtual-machines/docs/migrate-to-gcp-overview)
- [VMware Engine node types](https://cloud.google.com/vmware-engine/docs/concepts-node-types)
- [VPC peering for VMware Engine](https://cloud.google.com/vmware-engine/docs/networking/vpc-network-peering)
- [GCVE security best practices](https://cloud.google.com/vmware-engine/docs/security/secure-your-private-cloud)
