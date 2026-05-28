# Google Cloud VMware Engine — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/VMware_Engine)**

This lab guide walks you through deploying and operating a **Google Cloud VMware Engine (GCVE)**
private cloud using the **VMware_Engine** module. You will provision a VMware Software-Defined
Data Centre (SDDC) in Google Cloud, access vCenter and NSX-T management consoles via a Windows
jump host, configure VMware networking, and deploy a test workload to verify the environment is
fully operational.

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
10. [Exercise 6 — Deploy a Test Workload in vCenter](#exercise-6--deploy-a-test-workload-in-vcenter)
11. [Exercise 7 — Monitoring and Logging](#exercise-7--monitoring-and-logging)
12. [Exercise 8 — Advanced Operations](#exercise-8--advanced-operations)
13. [Cleanup](#13-cleanup)
14. [Reference](#14-reference)

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
| RDP client | Any | Windows Remote Desktop, Windows App (macOS), Remmina (Linux) |
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

> **macOS:** Microsoft Remote Desktop has been discontinued. Use **Windows App** instead:
> 1. Install via Homebrew: `brew install --cask windows-app`
> 2. Open Windows App: `open -a "Windows App.app"`
> 3. Add a new PC, enter the jump host IP and port (`<jump-host-external-ip>:3389`), and supply the username and password from the previous step.
>
> **Linux:** Use Remmina or FreeRDP:
> ```bash
> xfreerdp /u:<username> /p:<password> /v:<jump-host-ip>:3389 /dynamic-resolution
> ```

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

1. Open Chrome or Edge
2. Navigate to `https://<vcenter-fqdn>`
3. Accept the self-signed certificate warning
4. Log in with the credentials from Step 1.4 (username: `cloudowner@gve.local`)

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

### Step 3.2 — Configure DHCP on the T1 Gateway

In NSX-T Manager, DHCP is configured directly on the Tier-1 Gateway rather than as a
standalone server:

1. Navigate to **Networking** → **Tier-1 Gateways**
2. Locate your deployed Tier-1 Gateway and click the three-dot menu (⋯) → **Edit**
3. Under **DHCP Config**, click **Set**
4. Under **Type**, select **DHCP Server**
5. Click the three-dot menu next to **DHCP Server Profile** and select **Create New**
6. Configure the profile:
   - **Name**: `DHCP-Class`
   - **Server IP Address**: `172.21.0.5/24`
   - **Edge Cluster**: select `edge-cluster` from the dropdown
7. Click **Save**, then **Apply**, then **Save**, then **Close Editing**

> **Note:** The DHCP server IP (`172.21.0.5/24`) must be an address that does not conflict
> with your management CIDR or workload subnets. Adjust if needed for your deployment.

### Step 3.3 — Create a Workload Segment

In NSX-T Manager:

1. Navigate to **Networking** → **Segments**
2. Click **Add Segment**
3. Configure:
   - **Segment Name**: `workload-segment`
   - **Connected Gateway**: select your **Tier-1** gateway
   - **Transport Zone**: `TZ-OVERLAY | Overlay`
   - **Subnets** (Gateway IP/Prefix Length): `192.168.142.1/24`
4. Click **Set DHCP Config**:
   - **DHCP Type**: `Gateway DHCP Server`
   - **DHCP Range**: `192.168.142.10-192.168.142.50`, then press **Enter**
   - **DNS Servers**: enter the DNS IP from your Private Cloud details (typically `10.11.0.234`)
5. Click **Apply**, then **Save**
6. Click **No** in the pop-up prompt to continue editing if it appears

> The route to this new segment is automatically exported to the peered VPC network.

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

### Step 5.2 — Create a Network Policy

If no network policy exists yet (i.e., `enable_internet_access` and `enable_external_ip` were both
`false` at deployment time), create one now via the Cloud Console:

1. In the Google Cloud Console, navigate to **VMware Engine** → **Network Policies**
2. Click **Create**
3. Configure:
   - **Name**: `gcve-edge`
   - **VMware Engine Network**: select `global-vmware-engine-network` (or your network)
   - **Region**: your deployment region (e.g., `us-central1`)
   - **Internet access service**: `Enabled`
   - **External IP address service**: `Enabled`
   - **Edge services address range**: `10.11.2.0/26`
4. Click **Create**

> **Note:** Enabling internet access can take up to 15 minutes. The Network Policies page
> shows the service state.

If the policy was created by the module, verify or update it via CLI:

**gcloud:**
```bash
gcloud vmware network-policies describe "gcve-edge" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(internetAccess, externalIp)"
```

**REST API (update to enable internet access):**
```bash
NETWORK_POLICY="gcve-edge"

curl -s -X PATCH \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/networkPolicies/${NETWORK_POLICY}?updateMask=internet_access" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "internetAccess": {"enabled": true}
  }'
```

### Step 5.3 — Verify Internet Access is Active

After the network policy is enabled, confirm the state:

**gcloud:**
```bash
gcloud vmware network-policies list \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="table(name, internetAccess.enabled, externalIp.enabled, edgeServicesCidr)"
```

Expected output shows `internetAccess.enabled: true` and `externalIp.enabled: true` for `gcve-edge`.

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

## Exercise 6 — Deploy a Test Workload in vCenter

### Objective

Deploy a virtual machine in the GCVE private cloud to verify the full environment stack is
operational: vSphere compute, vSAN storage, NSX-T networking, DHCP assignment, and connectivity
from the jump host.

> **Prerequisite:** You will need a VM image (ISO or OVF/OVA) to deploy. Any minimal Linux
> distribution works (e.g., Alpine Linux, Ubuntu Server minimal). Download it to the jump host
> before starting this exercise.

### Step 6.1 — Upload an ISO to the vSAN Datastore

If using an ISO rather than an OVA:

1. In the vSphere Client, navigate to **Storage** in the left panel
2. Select **vsanDatastore**
3. Click the **Files** tab → **New Folder** → name it `ISOs`
4. Click **Upload Files** and upload your ISO

### Step 6.2 — Create a New Virtual Machine

1. In the vSphere Client, click **Menu** → **Inventory** → **VMs and Templates**
2. Expand the vCenter appliance and right-click **Datacenter** → **New Virtual Machine**
3. Follow the wizard:
   - **Creation type**: Create a new virtual machine
   - **Name**: `test-vm`
   - **Location**: select **Datacenter** (or a **Workload VMs** folder if present)
   - **Compute resource**: select the available cluster or host
   - **Storage**: select **vsanDatastore**
   - **Compatibility**: default (ESXi 7.0 or later)
   - **Guest OS family/version**: match your ISO (e.g., Linux / Ubuntu Linux 64-bit)
4. On the **Customize hardware** page:
   - **Network Adapter**: set to `workload-segment`
   - **New CD/DVD Drive**: select **Datastore ISO file** and browse to your uploaded ISO; check
     **Connect at power on**
5. Click **Finish**

### Step 6.3 — Power On and Verify DHCP Assignment

1. In **VMs and Templates**, right-click `test-vm` → **Power** → **Power On**
2. Click the VM name → **Summary** tab; wait for **VMware Tools** status or the guest IP to appear
3. Once booted, open the VM console and check the assigned IP:
   ```bash
   ip addr show
   ```
   The address should fall within the DHCP range `192.168.142.10–192.168.142.50`.

### Step 6.4 — Test Connectivity from the Jump Host

From the Windows jump host, open PowerShell:

```powershell
# Confirm the VM received an IP in the workload-segment range
Test-NetConnection -ComputerName 192.168.142.<vm-ip> -Port 22

# Verify the workload segment subnet is reachable
ping 192.168.142.1
```

A successful connection confirms that:
- vSAN provisioned the VM disk correctly
- NSX-T delivered DHCP to the workload segment
- VPC peering allows the jump host (in the peer VPC) to reach the NSX-T overlay network

### Step 6.5 — Verify Internet Access from the VM (optional)

If internet access was enabled in Exercise 5, test outbound connectivity from inside the VM:

```bash
curl -s --max-time 10 https://www.google.com -o /dev/null -w "%{http_code}"
# Expected: 200
```

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
- [VMware Engine node types](https://cloud.google.com/vmware-engine/docs/concepts-node-types)
- [VPC peering for VMware Engine](https://cloud.google.com/vmware-engine/docs/networking/vpc-network-peering)
- [GCVE security best practices](https://cloud.google.com/vmware-engine/docs/security/secure-your-private-cloud)
