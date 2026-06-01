---
title: "VMware Engine Module Documentation"
sidebar_label: "VMware Engine"
---

# VMware Engine Module

## Overview

The VMware Engine module provisions a complete **Google Cloud VMware Engine (GCVE)** private
cloud environment. GCVE is Google Cloud's fully managed service that runs the entire VMware
Software-Defined Data Centre (SDDC) stack — vSphere, vSAN, and NSX-T — on dedicated
bare-metal hardware within Google Cloud. Unlike virtualisation-based alternatives, GCVE gives
you the identical VMware tooling and operational model you already use on-premises, with no
hypervisor layer changes and no application refactoring required.

This module is designed as a hands-on environment for cloud architects, VMware administrators,
and migration specialists who want to experience GCVE provisioning and day-two operations without
the overhead of manual setup. All infrastructure — the VMware Engine Network, private cloud,
VPC peering, network policies, firewall rules, and Windows jump host — is provisioned by
Terraform. Users connect via RDP to the pre-configured jump host and explore vCenter and NSX-T
immediately after deployment completes.

By deploying this module, you gain direct experience with:

- **GCVE private cloud provisioning** — the `google_vmwareengine_private_cloud` resource that
  creates the full SDDC stack (vCenter, NSX-T, vSAN, HCX) on dedicated bare-metal nodes
- **VMware Engine Network** — the managed fabric that connects the GCVE private cloud to Google
  Cloud VPC networks via VMware Engine-native peering
- **VPC Network Peering** — the `google_vmwareengine_network_peering` resource that bridges the
  VMware Engine Network and a standard GCP VPC, enabling jump host and workload connectivity
- **NSX-T networking** — creating DHCP servers, workload segments, and tier-1 gateway
  configuration inside the private cloud
- **Network policies** — enabling internet egress and external IP allocation for VMware
  workloads via the GCVE edge services CIDR
- **Jump host access** — connecting to vCenter and NSX-T Manager consoles via a Windows Server
  2022 VM over RDP
- **Credential management** — the vCenter solution user credential reset workflow used when
  connecting third-party tools to the private cloud

The module provisions in approximately **30–90 minutes** for a `TIME_LIMITED` single-node
private cloud. `STANDARD` private clouds (3+ nodes) take **2–4 hours** for the initial
bare-metal provisioning cycle.

---

## What Gets Deployed

**Google Cloud infrastructure:**

| Resource | Name Pattern | Purpose |
|---|---|---|
| VMware Engine Network | `altostrat-{id}-ven` | Managed network fabric connecting private cloud to Google Cloud |
| GCVE Private Cloud | `altostrat-{id}-private-cloud` | Full SDDC: vCenter, NSX-T, vSAN, HCX on bare-metal nodes |
| VMware Engine Network Peering | `altostrat-{id}-vpc-ven` | Bridges the VMware Engine Network and the peer VPC |
| Network Policy | `altostrat-{id}-edge-policy` | Controls internet access and external IP allocation for workload VMs |
| Peer VPC Network | `altostrat-{id}-vpc` | GCP VPC for the jump host and peering anchor |
| Firewall rules | `altostrat-{id}-allow-*` | RDP, SSH, HTTP, ICMP, and internal traffic on the peer VPC |
| Windows Server 2022 VM | `altostrat-{id}-jump-host` | RDP workstation for accessing vCenter and NSX-T consoles |
| vCenter credentials reset | (null\_resource) | Automated reset of the vCenter solution user password post-provisioning |

**GCVE private cloud components (provisioned inside the private cloud):**

| Component | Access | Purpose |
|---|---|---|
| vCenter Server (VCSA) | `https://<vcenter-fqdn>` | vSphere management console — cluster, VM, and storage operations |
| NSX-T Manager | `https://<nsx-fqdn>` | Network virtualisation — segments, DHCP, routing, security |
| HCX Manager | `https://<hcx-fqdn>` | VMware Hybrid Cloud Extension appliance for workload mobility |
| vSAN Datastore | (within vCenter) | All-NVMe distributed storage for VM disks |
| Management cluster | (within vCenter) | Bare-metal node pool running the VMware management plane |

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          VMware Engine Module                                │
│                                                                              │
│   Google Cloud Project                                                       │
│   ──────────────────────────────────────────────────────────────────────     │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │  VMware Engine Network (global, Google-managed)                      │   │
│   │                                                                      │   │
│   │  ┌──────────────────────────────────────────────────────────────┐   │   │
│   │  │  GCVE Private Cloud (bare-metal SDDC)                        │   │   │
│   │  │  • vCenter Server                    (management_cidr /24)  │   │   │
│   │  │  • NSX-T Manager                     172.20.1.0/24          │   │   │
│   │  │  • HCX appliance                                            │   │   │
│   │  │  • vSAN datastore (all-NVMe)                                │   │   │
│   │  │  • Node type: standard-72  (1 node TIME_LIMITED,            │   │   │
│   │  │                             3+ nodes STANDARD)              │   │   │
│   │  └──────────────────────────────────────────────────────────┘   │   │
│   │                          │                                       │   │
│   │            VPC Peering (VMware ↔ GCP)                           │   │
│   └──────────────────────────│───────────────────────────────────────┘   │
│                              │                                            │
│   ┌──────────────────────────▼───────────────────────────────────────┐   │
│   │  Peer VPC Network                                                 │   │
│   │                                                                   │   │
│   │  ┌──────────────────────────────┐                                │   │
│   │  │  Windows Server 2022 VM      │                                │   │
│   │  │  • e2-medium                 │                                │   │
│   │  │  • RDP port 3389             │                                │   │
│   │  │  • External IP (ephemeral)   │                                │   │
│   │  └──────────────────────────────┘                                │   │
│   │  Firewall: allow-rdp · allow-ssh · allow-icmp · allow-internal   │   │
│   │           · allow-http                                           │   │
│   └──────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│   Network Policy                                                           │
│   • Internet access (outbound via edge CIDR)                               │
│   • External IP allocation (NSX-T NAT rules)                               │
│   • Edge services CIDR: 10.11.3.0/26                                       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

Deployment sequence:
  1. Enable GCP APIs (vmwareengine, vmmigration, compute, cloudresourcemanager, iam, iamcredentials)
  2. Create VMware Engine Network (global, type STANDARD)
  3. Create GCVE private cloud — this triggers Google to provision bare-metal nodes,
     install vSphere/vSAN/NSX-T/HCX, and configure the management cluster
     (TIME_LIMITED: 30–90 min; STANDARD: 2–4 hours)
  4. Create peer VPC network
  5. Create 5 firewall rules (RDP, SSH, ICMP, internal, HTTP)
  6. Create VMware Engine Network Peering (bridges VMware fabric ↔ peer VPC)
  7. Create Network Policy (internet access + external IP via edge services CIDR)
  8. Deploy Windows Server 2022 jump host on the peer VPC
  9. Reset vCenter solution user credentials (null_resource: gcloud vmware ... reset)
```

---

## VMware Engine Network

The **VMware Engine Network** is a Google-managed network fabric that underpins the GCVE
private cloud. It is distinct from a standard GCP VPC — it is not configured by customers
and does not appear in the VPC console. The VMware Engine Network carries all management and
workload traffic within the private cloud and exposes it to Google Cloud via peering.

The module creates a `STANDARD` type VMware Engine Network scoped globally. A single VMware
Engine Network can host multiple private clouds and multiple peering connections.

```bash
# Inspect the VMware Engine Network
gcloud vmware networks describe "${VMWARE_ENGINE_NETWORK_ID}" \
  --project="${PROJECT_ID}" \
  --location=global \
  --format="yaml(name, state, type)"

# REST API
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/vmwareEngineNetworks" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.vmwareEngineNetworks[] | {name, state, type}'
```

---

## Private Cloud

The **GCVE private cloud** is the core resource created by this module. It provisions a
complete VMware SDDC on dedicated bare-metal hardware managed by Google. The private cloud
contains:

- **vCenter Server Appliance (VCSA)** — the vSphere management endpoint, accessible at an
  FQDN of the form `vcsa-xxx.yyy.REGION.gve.goog`
- **NSX-T Manager** — the network virtualisation plane for segments, DHCP, routing, and
  distributed firewall, accessible at `nsx-xxx.yyy.REGION.gve.goog`
- **HCX appliance** — VMware Hybrid Cloud Extension for live VM mobility and network extension
  between on-premises VMware and GCVE
- **vSAN datastore** — all-NVMe distributed storage pool; capacity scales with node count
- **Management cluster** — the bare-metal compute pool hosting the SDDC management components

### Private Cloud Types

| Type | Nodes | Provisioning Time | Lifespan | Use Case |
|---|---|---|---|---|
| `TIME_LIMITED` | 1 | 30–90 minutes | 72 hours | Evaluation, lab, proof-of-concept |
| `STANDARD` | 3+ | 2–4 hours | Indefinite | Production workloads |

> **TIME_LIMITED note:** The 72-hour clock starts when the private cloud reaches `ACTIVE`
> state. After expiry, the private cloud is automatically deleted with all VMs it contains.
> It cannot be extended; use `STANDARD` for longer evaluations.

### Management CIDR

The `management_cidr` variable (default `172.20.1.0/24`) reserves an IP range for GCVE
management infrastructure — vCenter, NSX-T, HCX, and ESXi management interfaces. This CIDR:

- **Cannot be changed after private cloud creation.** Choose carefully before deploying.
- Must not overlap with the peer VPC subnets or the edge services CIDR.
- `/24` is the minimum; larger ranges support larger management clusters.

```bash
# Check private cloud state and management details
gcloud vmware private-clouds describe "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(state, vcenter, nsx, hcx, managementCluster)"

# REST API
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/privateClouds/${PRIVATE_CLOUD_NAME}" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '{name, state, vcenter: .vcenter.fqdn, nsx: .nsx.fqdn, hcx: .hcx.fqdn}'
```

### Node Types

| Node Type | vCPUs | RAM | vSAN Capacity | Best For |
|---|---|---|---|---|
| `standard-72` | 72 | 768 GB | ~36 TB NVMe | General workloads |
| `highmem-72` | 72 | 1,536 GB | ~36 TB NVMe | Memory-intensive (databases, SAP) |
| `standard-32` | 32 | 384 GB | ~18 TB NVMe | Smaller deployments |

> **API naming:** The UI displays node types as `ve1-standard-72`, but the Terraform resource
> and `gcloud` CLI use the shorter form `standard-72`. Always use the shorter form in the
> `node_type_id` variable.

---

## VPC Peering

VPC peering bridges the VMware Engine Network and a standard GCP VPC, enabling:

- The jump host VM to reach vCenter, NSX-T, and VMware workloads via their internal IPs
- VMware workloads to consume GCP services (Cloud SQL, BigQuery, Vertex AI) without traversing
  the internet
- Route export — workload segment CIDRs created in NSX-T are automatically advertised to the
  peered VPC

The module creates a `google_vmwareengine_network_peering` resource that links the VMware Engine
Network to the `peer-network` VPC. This is distinct from a standard `google_compute_network_peering`
— it uses the VMware Engine API and handles the necessary route table entries automatically.

```bash
# Inspect the VMware Engine peering
gcloud vmware network-peerings list \
  --project="${PROJECT_ID}" \
  --location=global

# View routes exported from GCVE to the peer VPC
gcloud compute routes list \
  --project="${PROJECT_ID}" \
  --format="table(name, network, destRange, nextHopGateway, priority)"

# REST API
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/networkPeerings" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.networkPeerings[] | {name, state, vmwareEngineNetwork, peerNetwork}'
```

---

## Jump Host

The **Windows Server 2022 jump host** is the interactive workstation for all GCVE console
access. Because vCenter and NSX-T are only accessible at internal FQDNs within the VMware
Engine Network, the jump host — which sits in the peered GCP VPC — acts as the network bridge
between the operator's machine and the VMware management plane.

### Why a Dedicated Jump Host

vCenter and NSX-T management endpoints are not reachable from the public internet. They are
only reachable from within the VMware Engine Network or from a peered VPC. The jump host sits
in the peer VPC and can reach both consoles at their internal FQDNs over the VPC peering.

### Jump Host Configuration

| Parameter | Value | Rationale |
|---|---|---|
| Machine type | `e2-medium` (2 vCPU, 4 GB RAM) | Sufficient for browser-based console access; configurable via `jump_host_machine_type` |
| Boot disk | 50 GB, `pd-balanced` | Windows Server 2022 minimum recommendation |
| Image | `windows-server-2022-dc-core-v*` | Latest Windows Server 2022 Datacenter from the public Google image family |
| External IP | Yes (ephemeral) | Required for RDP access from the operator's machine |

### Connecting via RDP

Before connecting, generate a Windows password:

```bash
JUMP_HOST=$(gcloud compute instances list \
  --filter="name~jump-host" \
  --project="${PROJECT_ID}" \
  --format="value(name)")

gcloud compute reset-windows-password "${JUMP_HOST}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"
```

Then connect using your RDP client:

```
Host:     <jump-host-external-ip>:3389
Username: <username from gcloud output>
Password: <password from gcloud output>
```

> **macOS:** Microsoft Remote Desktop has been discontinued. Use **Windows App** instead:
> `brew install --cask windows-app`, then open it with `open -a "Windows App.app"` and add a
> new PC using the IP, username, and password above.

> **Linux:** `xfreerdp /u:<username> /p:<password> /v:<ip>:3389 /dynamic-resolution`

```bash
# Get the jump host external IP
gcloud compute instances list \
  --filter="name~jump-host" \
  --project="${PROJECT_ID}" \
  --format="table(name, zone, status, networkInterfaces[0].accessConfigs[0].natIP)"
```

---

## Network Policy

The **VMware Engine Network Policy** controls how workload VMs inside the private cloud
communicate with the internet and with Google Cloud external IPs. It operates at the VMware
Engine Network level, not the individual VM level, and applies to all workloads in the GCVE
private cloud.

Two services are governed by the network policy:

| Service | Module Default | Description |
|---|---|---|
| Internet access | `true` | Allows outbound internet traffic from VMware workload VMs via NSX-T edge services |
| External IP | `true` | Allows NSX-T to allocate public IPs for NAT rules, enabling inbound internet access to workload VMs |

Both services route through the **edge services CIDR** (default `10.11.3.0/26`), which must
be a `/26` block that does not overlap with the management CIDR or the peer VPC subnets.

```bash
# View network policies
gcloud vmware network-policies list \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="table(name, internetAccess.enabled, externalIp.enabled, edgeServicesCidr)"

# REST API
curl -s \
  "https://vmwareengine.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/networkPolicies" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  | jq '.networkPolicies[] | {name, internet: .internetAccess.enabled, externalIp: .externalIp.enabled, edgeCidr: .edgeServicesCidr}'
```

> **Propagation time:** Enabling internet access or external IP for the first time can take
> up to 15 minutes. The Network Policies page in the Cloud Console shows the current service
> state.

---

## Firewall Rules

Five firewall rules are created on the peer VPC to support jump host access and internal
communication:

| Rule | Source | Ports | Purpose |
|---|---|---|---|
| `allow-internal` | `10.128.0.0/9` | All | Unrestricted traffic between VMs on the same VPC |
| `allow-ssh` | `0.0.0.0/0` | TCP 22 | SSH access to Linux VMs on the peer VPC |
| `allow-rdp` | `0.0.0.0/0` | TCP 3389 | RDP access to the Windows jump host |
| `allow-icmp` | `0.0.0.0/0` | ICMP | Ping for connectivity testing |
| `allow-http` | `0.0.0.0/0` | TCP 80, 443 | HTTP/HTTPS access to jump-host-tagged instances |

```bash
gcloud compute firewall-rules list \
  --project="${PROJECT_ID}" \
  --format="table(name, direction, sourceRanges, allowed)"
```

---

## vCenter Credentials Reset

After the private cloud is provisioned, the vCenter **solution user** credentials
(`solution-user-01@gve.local` by default) must be reset before they can be used by
third-party tools. When `reset_vcenter_credentials = true`, the module runs this reset
automatically via a `null_resource` local-exec provisioner.

The credentials are retrieved and stored in the Terraform outputs.

### Manual Reset

To reset manually or retrieve current credentials:

```bash
# Reset credentials
gcloud vmware private-clouds vcenter credentials reset \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --username="solution-user-01@gve.local" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --no-async

# Retrieve credentials
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --username="solution-user-01@gve.local" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}"
```

> **Why credentials expire:** vCenter solution user passwords have a built-in expiry policy.
> If your deployment is long-running, re-run the reset command to refresh them before
> connecting any integration that uses `solution-user-01@gve.local`.

---

## Configuration Reference

### Private Cloud

| Variable | Default | Description |
|---|---|---|
| `private_cloud_type` | `TIME_LIMITED` | `TIME_LIMITED` (1-node, 72-hour eval) or `STANDARD` (production) |
| `node_count` | `1` | 1 for `TIME_LIMITED`; minimum 3 for `STANDARD` |
| `node_type_id` | `standard-72` | Node hardware type — use the API short form, not the UI display name |
| `management_cidr` | `172.20.1.0/24` | CIDR for GCVE management infrastructure — **immutable after creation** |
| `reset_vcenter_credentials` | `true` | Auto-reset vCenter solution user credentials after provisioning |
| `vcenter_solution_user` | `solution-user-01@gve.local` | vCenter solution user account to reset |

### Networking

| Variable | Default | Description |
|---|---|---|
| `create_vpc` | `true` | Create the peer VPC; set `false` to use an existing VPC |
| `edge_services_cidr` | `10.11.3.0/26` | CIDR for GCVE edge services (internet + external IP routing) |
| `enable_internet_access` | `true` | Enable outbound internet from VMware workload VMs |
| `enable_external_ip` | `true` | Enable external IP allocation for NSX-T NAT rules |
| `internal_traffic_cidr` | `10.128.0.0/9` | Source CIDR for the allow-internal firewall rule |
| `create_default_firewall_rules` | `true` | Create RDP, SSH, ICMP, internal, and HTTP firewall rules |

### Jump Host

| Variable | Default | Description |
|---|---|---|
| `create_jump_host` | `true` | Deploy the Windows Server 2022 jump host |
| `jump_host_machine_type` | `e2-medium` | Machine type for the jump host |
| `jump_host_boot_disk_size_gb` | `50` | Boot disk size in GB (minimum 50 for Windows Server 2022) |
| `jump_host_subnetwork` | `""` | Subnetwork for custom-mode VPCs; leave blank for auto-selection |

### Platform Metadata

| Variable | Default | Description |
|---|---|---|
| `region` | — | GCP region (required) |
| `zone` | — | GCP zone (required) |
| `project_id` | — | GCP project ID (required) |
| `deployment_id` | `null` | Optional suffix for resource names; auto-generated by the platform |
| `resource_creator_identity` | `""` | Service account for Terraform impersonation |
| `credit_cost` | `500` | Platform credit cost for deployment |

---

## Default Behaviours

Understanding the module's defaults avoids surprises when deploying or modifying the
environment.

**Internet access and external IP are enabled by default.** Both `enable_internet_access` and
`enable_external_ip` default to `true`. This means workload VMs can reach the internet and
NSX-T can assign public IPs out of the box. Set both to `false` if you want a fully isolated
private cloud.

**The peer VPC is created by default.** `create_vpc = true` creates a new VPC named
`{id}-peer-network`. If you want to attach the private cloud peering to an existing VPC
(such as the `default` network), set `create_vpc = false` and configure the peering manually.

**vCenter credentials are reset automatically.** `reset_vcenter_credentials = true` runs a
`gcloud vmware ... credentials reset` call after the private cloud is provisioned. This is
required before connecting any tool that uses `solution-user-01@gve.local`. If you have a
pipeline that rotates credentials separately, set this to `false`.

**TIME_LIMITED private clouds expire after 72 hours.** The clock starts when the private cloud
first reaches `ACTIVE` state. After expiry, Google automatically deletes the private cloud and
all VMs inside it without warning. There is no extension option — migrate to `STANDARD` for
longer evaluations.

**The management CIDR is immutable.** `management_cidr` cannot be changed after the private
cloud is created. If you need a different CIDR, destroy the private cloud and create a new one.
This operation is irreversible and deletes all VMs in the private cloud.

**Provisioning is slow by design.** Google must physically allocate and cable bare-metal
servers before the SDDC software can be installed. Terraform `apply` blocks until the private
cloud reaches `ACTIVE` state, which takes 30–90 minutes for `TIME_LIMITED` and 2–4 hours for
`STANDARD`. This is normal — there is no way to accelerate it.

**Private cloud deletion is irreversible.** Running `terraform destroy` (or clicking Undeploy
in the RAD UI) permanently deletes the private cloud and all VMs it contains. Ensure all
workloads are backed up or migrated before destroying.

**GCP APIs are protected from accidental deletion.** The `google_project_service` resources
have `lifecycle { prevent_destroy = true }`. Running `terraform destroy` does not disable
`vmwareengine.googleapis.com` or the other enabled APIs. To disable APIs, remove the lifecycle
block and re-run `tofu plan` before `tofu destroy`.

---

## Prerequisites

### Google Cloud

- A GCP project with billing enabled and a quota allocation for VMware Engine nodes
- The following APIs are enabled automatically on first deployment:

```
vmwareengine.googleapis.com
vmmigration.googleapis.com
compute.googleapis.com
cloudresourcemanager.googleapis.com
iam.googleapis.com
iamcredentials.googleapis.com
```

> **VMware Engine quota:** Single-node `TIME_LIMITED` private clouds require a quota of at
> least 1 `standard-72` node in the target zone. STANDARD private clouds require 3+ nodes.
> Request quota increases via the Cloud Console under **IAM & Admin → Quotas** if needed.

```bash
# Verify API enablement after deployment
gcloud services list \
  --filter="config.name~vmwareengine OR config.name~compute" \
  --project="${PROJECT_ID}" \
  --format="table(config.name, state)"
```

### Permissions

The service account running the module (`resource_creator_identity`) requires:

- `roles/owner` (or at minimum):
  - `roles/vmwareengine.admin` — create and manage private clouds, networks, policies, peerings
  - `roles/compute.admin` — create VPC, firewall rules, and the jump host VM
  - `roles/iam.serviceAccountUser` — impersonate the provisioning service account

### Local Tools

No local tools are required for the RAD UI deployment path. For manual exploration:

- `gcloud` CLI (v480.0.0 or later, authenticated)
- `curl` and `jq` for REST API calls
- An RDP client: Windows App (macOS), Remmina or FreeRDP (Linux), or the built-in client (Windows)

---

## Deploying the Module

### Via RAD UI

1. Navigate to the RAD UI and select the `VMware Engine` module
2. Fill in the required variables:
   - `project_id` — your GCP project ID
   - `region` — GCP region (e.g., `us-central1`)
   - `zone` — GCP zone (e.g., `us-central1-a`)
   - `private_cloud_type` — `TIME_LIMITED` for evaluation or `STANDARD` for production
   - `node_count` — `1` for `TIME_LIMITED`, `3` for `STANDARD`
   - Leave all other variables at their defaults
3. Click **Deploy** and wait for provisioning to complete (30–90 min for `TIME_LIMITED`)

### Verify Deployment

```bash
# Confirm private cloud is ACTIVE
gcloud vmware private-clouds describe "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="value(state)"
# Expected: ACTIVE

# Confirm jump host is running
gcloud compute instances list \
  --filter="name~jump-host" \
  --project="${PROJECT_ID}" \
  --format="table(name, status, zone, networkInterfaces[0].accessConfigs[0].natIP)"

# Confirm VPC peering is active
gcloud vmware network-peerings list \
  --project="${PROJECT_ID}" \
  --location=global \
  --format="table(name, state)"

# Retrieve vCenter and NSX-T FQDNs
gcloud vmware private-clouds describe "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(vcenter, nsx, hcx)"
```

### Cleaning Up

Use the RAD UI **Undeploy** button to remove all Terraform-managed resources. The deletion
order matters — the private cloud must be deleted before the VMware Engine Network peering
can be removed.

If cleaning up manually:

```bash
# 1. Delete any additional clusters created during lab exercises
gcloud vmware private-clouds clusters delete "workload-cluster" \
  --private-cloud="${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet

# 2. Delete the private cloud (irreversible — deletes all VMs)
gcloud vmware private-clouds delete "${PRIVATE_CLOUD_NAME}" \
  --location="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet

# 3. Delete the jump host
gcloud compute instances delete "${JUMP_HOST}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --quiet

# 4. Delete the peer VPC network
gcloud compute networks delete "peer-network" \
  --project="${PROJECT_ID}" \
  --quiet
```

> **Warning:** Private cloud deletion is irreversible. All VMs and data inside the private
> cloud are permanently destroyed. Ensure workloads are migrated or backed up before deleting.

---

## Further Learning

### Google Cloud VMware Engine
- [GCVE overview](https://cloud.google.com/vmware-engine/docs/overview)
- [Private cloud provisioning](https://cloud.google.com/vmware-engine/docs/private-cloud/provision-private-cloud)
- [VMware Engine node types](https://cloud.google.com/vmware-engine/docs/concepts-node-types)
- [NSX-T network configuration in GCVE](https://cloud.google.com/vmware-engine/docs/networking/nsx-t-configuration)
- [VPC peering for VMware Engine](https://cloud.google.com/vmware-engine/docs/networking/vpc-network-peering)
- [Network policies (internet and external IP access)](https://cloud.google.com/vmware-engine/docs/networking/network-policies)
- [GCVE security best practices](https://cloud.google.com/vmware-engine/docs/security/secure-your-private-cloud)
- [VMware Engine REST API reference](https://cloud.google.com/vmware-engine/docs/reference/rest)

### VMware Documentation
- [VMware NSX-T Data Center documentation](https://docs.vmware.com/en/VMware-NSX-T-Data-Center/)
- [vSphere documentation](https://docs.vmware.com/en/VMware-vSphere/)
- [HCX user guide](https://docs.vmware.com/en/VMware-HCX/)

### Migration and Modernisation
- [Google Cloud Adoption Framework](https://cloud.google.com/adoption-framework)
- [GCVE use cases: data center exit, DR, and VDI](https://cloud.google.com/vmware-engine/docs/concepts-use-cases)

---

## Common Issues and Variable Dependencies

### Variables That Depend on Each Other

- **`private_cloud_type` and `node_count`**: `TIME_LIMITED` private clouds require exactly 1 node. `STANDARD` private clouds require a minimum of 3 nodes. Specifying `private_cloud_type = "STANDARD"` with `node_count = 1` will be rejected by the VMware Engine API. Conversely, `TIME_LIMITED` with `node_count > 1` is also invalid. Always set `node_count = 1` for `TIME_LIMITED` and `node_count >= 3` for `STANDARD`.

- **`management_cidr` and `edge_services_cidr`**: These two CIDRs must not overlap with each other or with the peer VPC subnet ranges. The VMware Engine API validates CIDR allocations at creation time and will reject overlapping ranges. The default `management_cidr = "172.20.1.0/24"` and `edge_services_cidr = "10.11.3.0/26"` are pre-validated non-overlapping ranges. If customizing either, verify that they do not conflict with auto-mode VPC subnets (which use `10.128.0.0/9`).

- **`create_vpc` and `create_default_firewall_rules`**: Firewall rules are created on the peer VPC. If `create_vpc = false`, firewall rules still attempt to reference the expected VPC by the computed name `altostrat-<deployment-id>-vpc`. There is no variable to specify a custom VPC name; this name is hardcoded in `locals`. If `create_vpc = false`, a VPC with that exact name must already exist in the project.

- **`create_jump_host` and `jump_host_subnetwork`**: When `create_jump_host = true` and `jump_host_subnetwork = ""` (default), GCP auto-selects a subnet in the jump host's region. For custom-mode VPCs (i.e., if `create_vpc = false`), auto-selection may fail because no auto-mode subnet exists. In that case, set `jump_host_subnetwork` to the self-link or name of an existing subnet.

- **`reset_vcenter_credentials` and gcloud availability**: The vCenter credential reset runs a `gcloud vmware private-clouds vcenter credentials reset` command via a `null_resource` provisioner. This requires `gcloud` to be available in the Terraform execution environment. If deploying from a workstation without `gcloud` installed, set `reset_vcenter_credentials = false` and reset credentials manually from the Cloud Console after deployment.

### Mutually Exclusive Variable Combinations

- **`private_cloud_type = "TIME_LIMITED"` is evaluation-only**: TIME_LIMITED private clouds have a maximum lifetime enforced by Google Cloud and are not suitable for production use. They exist for lab and demo purposes. Switching between `TIME_LIMITED` and `STANDARD` is not supported in-place; it requires destroying and recreating the private cloud.

- **`node_type_id` availability is zone-dependent**: The API identifier `standard-72` (displayed as `ve1-standard-72` in the console) may not be available in all zones. Before changing `node_type_id`, verify availability in the target zone with `gcloud vmware node-types list --location=<zone>`. Using an unavailable node type causes a hard API error during private cloud creation.

### Variables That Affect Other Variables' Behavior

- **`region` and `zone`**: The VMware Engine private cloud is created in `var.zone`, and the network policy is scoped to `var.region`. The `zone` must be within `region` (e.g., `zone = "us-west2-a"` with `region = "us-west2"`). If they are inconsistent, the network policy creation will fail.

- **`deployment_id`**: All resource names follow the pattern `altostrat-<id>-<suffix>` (e.g. `altostrat-<id>-ven`, `altostrat-<id>-private-cloud`, `altostrat-<id>-vpc`). Changing `deployment_id` after deployment forces recreation of the private cloud (a 3-hour operation) and all associated resources. Never change `deployment_id` on an existing deployment.

- **`enable_internet_access` and `enable_external_ip`**: These are independent boolean flags on the `google_vmwareengine_network_policy` resource. Both can be `true` simultaneously. Disabling `enable_internet_access` while keeping `enable_external_ip = true` prevents outbound internet traffic but still allows external IP assignment within the VMware environment.

### Common Pitfalls

1. **Private cloud provisioning takes 2–4 hours**: The `google_vmwareengine_private_cloud` resource has create/update/delete timeouts of 180 minutes. This is a hard infrastructure provisioning delay and cannot be shortened. The Terraform apply will appear to hang for 2–4 hours while GCVE provisions VMware infrastructure. Do not interrupt `terraform apply` during this period.

2. **TIME_LIMITED private clouds have an expiry**: TIME_LIMITED private clouds created for labs are automatically decommissioned by Google Cloud after a fixed trial period (typically 60 days). Once expired, the private cloud is deleted and cannot be recovered. Do not use TIME_LIMITED for workloads that need to persist beyond the trial period.

3. **management_cidr cannot be changed after creation**: The `management_cidr` is baked into the VMware Engine network fabric at provisioning time. If the wrong CIDR is specified, the private cloud must be destroyed and recreated (2–4 hours). Verify CIDR ranges do not conflict with existing network infrastructure before running `terraform apply`.

4. **VPC peering state depends on private cloud state**: The `network_peering_state` output reflects the current state of the VPC peering between the peer VPC and the VMware Engine network. Peering only becomes `ACTIVE` after the private cloud is fully provisioned. During the 2–4 hour provisioning window, the peering state will remain `INACTIVE` or `CREATING`. This is expected behavior.

5. **vCenter FQDN is only reachable from the jump host**: The `vcenter_fqdn`, `nsx_fqdn`, and `hcx_fqdn` outputs resolve to internal VMware Engine management IP addresses that are only reachable through the peer VPC peering. Access these URLs only via RDP to the jump host (or any VM on the peer VPC), never directly from a workstation. Direct access from outside the peer VPC will time out.

6. **`enable_services = false` with VMware Engine APIs**: The module enables `vmwareengine.googleapis.com` and `vmmigration.googleapis.com` in addition to common APIs. These are specialized APIs that are not enabled by default in new projects. Setting `enable_services = false` on a new project without these APIs will cause hard failures at resource creation time.

---
