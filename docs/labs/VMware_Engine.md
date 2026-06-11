# Google Cloud VMware Engine — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/VMware_Engine)**

## Overview

**Estimated time:** 90–150 minutes (most of it waiting — private-cloud creation alone can take **~2 hours** for larger types; a single-node `TIME_LIMITED` cloud is usually ready in 30–90 minutes).

Google Cloud VMware Engine (GCVE) runs a complete VMware Software-Defined Data Center — vSphere, vSAN, NSX-T, and HCX — on Google-managed bare-metal hardware, so your existing VMware tooling and skills carry over unchanged. This lab takes you through the full operational lifecycle of the **VMware Engine** module: deploy it, confirm the private cloud comes up and reach vCenter through the jump host, operate the environment day-to-day, observe it, diagnose common problems, and tear it down.

The lab focuses on operating the **module and the Google Cloud platform**, not on VMware product internals. For the full list of provisioned services and every configuration input (organised by group), see the [Configuration Guide](https://docs.radmodules.dev/docs/modules/VMware_Engine) — this lab deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate the resources it provisions.
- Confirm the private cloud reaches `ACTIVE` and retrieve the vCenter credentials.
- Reach the vCenter, NSX-T, and HCX consoles through the Windows jump host.
- Perform day-2 operations — explore vCenter, manage the private cloud and its networking.
- Observe the environment with Cloud Logging and Cloud Monitoring.
- Diagnose and resolve the most common deployment and runtime issues.
- Tear the deployment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled** and **VMware Engine node quota** in the target zone (at least 1 node for `TIME_LIMITED`).
- **gcloud CLI** installed; `gcloud auth login` and `gcloud auth application-default login` completed.
- An **RDP client** (built-in on Windows; **Windows App** on macOS; Remmina/FreeRDP on Linux) and a web browser for the management consoles.
- **Project Owner** (or equivalent VMware Engine + Compute admin) IAM on the project.
- **RAD platform access** with permission to deploy modules into the project.

> **Cost note:** a VMware Engine node bills at a high hourly rate. Prefer a single-node `TIME_LIMITED` private cloud for this lab and tear it down promptly when finished.

Set these shell variables once; every task below reuses them:

```bash
export PROJECT="<your-gcp-project-id>"
export REGION="us-west2"        # the region you deploy into
export ZONE="us-west2-a"        # the zone you deploy into (must be within REGION)
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **VMware Engine** from the **Platform Modules** list to start configuration, set `project_id`, and review the inputs. Configure only what you need — the [Configuration Guide](https://docs.radmodules.dev/docs/modules/VMware_Engine) documents every input by group, with defaults. For a lab, keep `private_cloud_type = TIME_LIMITED` and `node_count = 1`. Review the estimated cost (if credits are enabled) and click **Deploy**, which opens the deployment status page with real-time logs.

2. The platform provisions the VMware Engine network, the private cloud (vCenter, vSAN, NSX-T, HCX), VPC peering into a Google Cloud peer VPC, the network policy, firewall rules, and a Windows Server 2022 jump host, then resets and prints the vCenter credentials. **Private-cloud creation dominates the time** — expect 30–90 minutes for a single-node `TIME_LIMITED` cloud, and up to **~2 hours** for larger types. The deployment will appear to sit still during this window; that is expected — do not interrupt it.

3. While it runs, you can watch the private cloud come up:

   ```bash
   PC=$(gcloud vmware private-clouds list --location="$ZONE" --project="$PROJECT" \
     --format="value(name)" --limit=1)
   gcloud vmware private-clouds describe "$PC" --location="$ZONE" --project="$PROJECT" \
     --format="value(state)"    # CREATING → ACTIVE
   ```

---

## Task 2 — Access & verify [Manual]

1. **Confirm the private cloud is `ACTIVE`** and capture the console FQDNs:

   ```bash
   gcloud vmware private-clouds describe "$PC" --location="$ZONE" --project="$PROJECT" \
     --format="yaml(state, vcenter.fqdn, nsx.fqdn, hcx.fqdn)"
   ```

2. **Retrieve the vCenter credentials.** The deployment logs print them after the reset; you can also fetch them on demand:

   ```bash
   gcloud vmware private-clouds vcenter credentials describe \
     --private-cloud="$PC" --username="solution-user-01@gve.local" \
     --location="$ZONE" --project="$PROJECT"
   ```

3. **Generate a Windows password and find the jump host's external IP:**

   ```bash
   JUMP=$(gcloud compute instances list --filter="name~jump-host" --project="$PROJECT" \
     --format="value(name)")
   gcloud compute instances list --filter="name~jump-host" --project="$PROJECT" \
     --format="table(name, status, networkInterfaces[0].accessConfigs[0].natIP)"
   gcloud compute reset-windows-password "$JUMP" --zone="$ZONE" --project="$PROJECT"
   ```

4. **RDP into the jump host** at `<external-ip>:3389` with the generated username/password, then open a browser inside the session and navigate to `https://<vcenter-fqdn>`. Accept the self-signed certificate and sign in with the vCenter credentials. (On macOS use **Windows App**: `brew install --cask windows-app`. On Linux: `xfreerdp /u:<user> /p:<pass> /v:<ip>:3389`.) The consoles are reachable only from the jump host, not from your workstation.

---

## Task 3 — Operate & keep it running (Day-2) [Manual]

1. **Explore vCenter** from the jump host browser — Hosts and Clusters (the management cluster and its nodes), Storage (the vSAN datastore), and Networking. Sign in to NSX-T Manager at `https://<nsx-fqdn>` to view segments, DHCP, and routing.

2. **Manage the private cloud** from the CLI — inspect its clusters and subnets, and (on `STANDARD` clouds) add workload clusters:

   ```bash
   gcloud vmware private-clouds clusters list --private-cloud="$PC" \
     --location="$ZONE" --project="$PROJECT"
   gcloud vmware private-clouds subnets list --private-cloud="$PC" \
     --location="$ZONE" --project="$PROJECT"
   ```

3. **Review networking** — VPC peering and the network policy that controls internet / external-IP access:

   ```bash
   gcloud vmware network-peerings list --location=global --project="$PROJECT" \
     --format="table(name, state)"
   gcloud vmware network-policies list --location="$REGION" --project="$PROJECT" \
     --format="table(name, internetAccess.enabled, externalIp.enabled, edgeServicesCidr)"
   ```

4. **Change configuration through the platform.** To adjust the network policy, node count (`STANDARD`), firewall rules, or jump-host sizing, edit the inputs and click **Update** on the deployment details page — the module owns these resources, so configuration changes should go through the platform rather than ad-hoc console edits. Note that `management_cidr`, `private_cloud_type`, and `deployment_id` cannot be changed in place.

5. **Refresh vCenter credentials** if they expire (re-run the reset):

   ```bash
   gcloud vmware private-clouds vcenter credentials reset \
     --private-cloud="$PC" --username="solution-user-01@gve.local" \
     --location="$ZONE" --project="$PROJECT" --no-async
   ```

---

## Task 4 — Observe: Logging & Monitoring [Manual]

1. **VMware Engine audit logs** — every private-cloud, peering, and policy operation:

   ```bash
   gcloud logging read 'protoPayload.serviceName="vmwareengine.googleapis.com"' \
     --project="$PROJECT" --limit=20 \
     --format='value(timestamp, protoPayload.methodName, protoPayload.authenticationInfo.principalEmail)'
   ```

2. **Jump host metrics and logs** — open Monitoring → Dashboards for the Compute Engine instance (CPU, memory, disk), and Logging → Logs Explorer filtered to `resource.type="gce_instance"` for system logs.

3. **Console views** — VMware Engine → Resources shows private-cloud health, and the vCenter/NSX-T consoles (via the jump host) expose vSAN health and cluster status.

---

## Task 5 — Troubleshoot & debug [Manual]

Durable techniques for the failure modes you are most likely to hit. These are platform-level diagnostics and do not change with GCVE releases.

- **Deployment "stuck" for an hour or more:** this is almost always normal — private-cloud provisioning is slow (the resource carries a 180-minute timeout). Confirm progress with `gcloud vmware private-clouds describe ... --format="value(state)"` (`CREATING` → `ACTIVE`). Do not interrupt the deployment.
- **`Resource for the given network already exists` (network policy):** GCVE allows only one network policy per VMware Engine network. A leftover policy from a prior failed run blocks re-creation — list it with `gcloud vmware network-policies list --location="$REGION"` and delete it, then redeploy.
- **Cannot reach vCenter/NSX-T from your laptop:** the FQDNs resolve to private IPs reachable only from the peer VPC. Always open them from inside the jump host RDP session.
- **vCenter login rejected:** the solution-user password may have expired or the reset was skipped (no `gcloud` in the runner). Re-run the reset command from Task 3, then describe to read the new password.
- **Peering shows `CREATING`/`INACTIVE`:** peering only goes `ACTIVE` after the private cloud finishes provisioning — wait for the cloud to reach `ACTIVE` first.
- **Node-type or quota errors at creation:** node types are zone-dependent and require quota. Verify availability with `gcloud vmware node-types list --location="$ZONE"` and request quota under IAM & Admin → Quotas.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**). Delete runs `terraform destroy` and is irreversible — it removes the private cloud (and **every VM and all data inside it**), the VMware Engine network and peering, the network policy, the peer VPC and firewall rules, and the jump host. The deletion is ordered correctly (policy and peering before the network) and is **slow** — deprovisioning bare metal can take a long time, so let it run to completion.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual console changes that conflict with the Terraform state), use **Purge** instead — it removes the deployment from RAD's records **without** destroying the cloud resources (RAD forgets the project, but the GCVE private cloud and everything else keep running and keep billing). After a Purge, clean up the resources manually.

> **Back up first.** Private-cloud deletion permanently destroys all VMs and data in the SDDC. Migrate or back up any workloads before tearing down.

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module provisions the VMware Engine network, private cloud, peering, policy, firewall, and jump host |
| 2 — Access & verify | Manual | Private cloud is `ACTIVE`; vCenter credentials retrieved; consoles reached via the jump host |
| 3 — Operate | Manual | Explore vCenter/NSX-T; manage the private cloud and networking; refresh credentials |
| 4 — Observe | Manual | Query VMware Engine audit logs; review jump-host metrics and console health |
| 5 — Troubleshoot | Manual | Diagnose slow provisioning, orphaned policies, console access, and quota issues |
| 6 — Tear down | Automated | Delete (Trash) destroys all resources; Purge removes from RAD without destroying |
