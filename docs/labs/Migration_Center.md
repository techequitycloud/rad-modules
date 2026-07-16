# Migration Center — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Migration_Center)**

## Overview

**Estimated time:** 60–120 minutes

Google Cloud Migration Center is Google Cloud's free platform for the *assessment phase* of a
migration — discovering existing workloads, building an inventory, estimating their cost on
Google Cloud, and planning migration waves. This lab takes you through the full operational
lifecycle of the **Migration Center** module: deploy it, access and verify the sample source
workloads, run discovery and build a TCO report (day-2 operations), observe it, diagnose common
problems, and tear it down.

The lab focuses on **operating the module and the Migration Center service**, not on every
product feature. For the complete list of provisioned services and every configuration input
(organised by group), see the
[Configuration Guide](https://docs.radmodules.dev/docs/modules/Migration_Center) — this lab
deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate the resources it provisions.
- Confirm the Migration Center service and the sample source VMs (Windows MCDCv6 host + Linux
  targets) exist and that discovery data is arriving.
- Run and inspect discovery and assessment — scan the Linux targets, review imported AWS data,
  and generate a TCO report from asset groups and migration preferences.
- Observe discovery progress and resource health with the Console and the REST API.
- Diagnose and resolve the most common deployment and runtime issues.
- Tear the deployment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled**.
- **gcloud CLI** installed; `gcloud auth login` and `gcloud auth application-default login`
  completed.
- An **RDP client** (Microsoft Remote Desktop on Windows/macOS, or Remmina/FreeRDP on Linux).
- **Project Owner** (or equivalent) IAM on the project. The Google account you use for the
  MCDCv6 sign-in needs **Migration Center Admin** on the project.
- **RAD platform access** with permission to deploy modules into the project.
- **(Optional) AWS** — only if you want live EC2 inventory imported automatically: a set of
  **bootstrap AWS credentials with IAM write permissions** (the module creates a scoped,
  read-only IAM user from them) and the **`aws` CLI** available in the deployment environment.
  Leave the AWS inputs empty to skip AWS entirely and import a pre-staged sample CSV instead.

Set these shell variables once; every task below reuses them:

```bash
export PROJECT="<your-gcp-project-id>"
export REGION="us-central1"           # the region you deploy into — permanent for Migration Center
export ZONE="us-central1-a"
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **Migration Center** from the
   **Platform Modules** list to start configuration, set `project_id`, and review the inputs.
   Configure only what you need — the
   [Configuration Guide](https://docs.radmodules.dev/docs/modules/Migration_Center) documents
   every input by group, with defaults. To import live AWS EC2 inventory, supply
   `aws_access_key_id`, `aws_secret_access_key`, and `aws_region`; otherwise leave them blank.
   Review the estimated cost (if credits are enabled) and click **Deploy**, which opens the
   deployment status page with real-time logs.

2. The platform provisions a dedicated VPC and firewall rules, a Windows Server 2022 MCDCv6
   host, the Debian Linux scan targets, a Cloud Storage bucket holding the SSH key, then
   initialises the Migration Center service for `REGION` and registers a discovery source.
   If AWS credentials were supplied, it also creates a scoped IAM user and imports EC2
   inventory. Terraform finishes in roughly **5–8 minutes**; the Windows startup script
   (Chrome + MCDCv6 install) runs in the background for a further **3–5 minutes**.

3. Confirm the core resources came up:

   ```bash
   gcloud compute instances list --filter="name~migcenter" --project="$PROJECT" \
     --format="table(name, status, networkInterfaces[0].accessConfigs[0].natIP, networkInterfaces[0].networkIP)"

   curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/sources" \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     | jq '.sources[] | {id: (.name|split("/")|last), displayName, type}'
   ```

---

## Task 2 — Access & verify [Manual]

1. **Confirm the sample source VMs exist** and capture their addresses:

   ```bash
   WINDOWS_VM=$(gcloud compute instances list --filter="name~migcenter AND name~winvm" \
     --project="$PROJECT" --format="value(name)")
   gcloud compute instances describe "$WINDOWS_VM" --zone="$ZONE" --project="$PROJECT" \
     --format="value(networkInterfaces[0].accessConfigs[0].natIP)"     # RDP target

   gcloud compute instances list --filter="name~migcenter AND name~linvm" \
     --project="$PROJECT" --format="table(name, networkInterfaces[0].networkIP)"
   ```

2. **RDP into the Windows VM** using the external IP and `windows_vm_password` output from step 1:

   ```
   Username: migrationcenter
   Password: <your-windows_vm_password-output>
   ```

   Inside the VM, confirm **MCDCv6** and **Google Chrome** are installed and that
   `C:\Users\migrationcenter\Downloads\vm-aws-import-files\` exists (the pre-staged sample CSVs).
   If RDP refuses the connection, the startup script is probably still running — wait a few
   minutes and check `gcloud compute instances get-serial-port-output "$WINDOWS_VM" --zone="$ZONE" --project="$PROJECT" | tail`.

3. **Verify discovery data will be able to arrive** — confirm the discovery source is registered
   (Task 1, step 3) and that, if you supplied AWS credentials, an import job exists:

   ```bash
   curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/importJobs" \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     | jq '.importJobs[] | {displayName, state}'
   ```

---

## Task 3 — Operate & keep it running (Day-2) [Manual]

This is the heart of the lab — run discovery and produce an assessment.

1. **Complete the MCDCv6 Google sign-in (the one manual step).** On the Windows VM launch
   **Migration Center Discovery Client**, click **Sign in with Google**, authenticate with an
   account that has Migration Center Admin on the project, select the project, and when prompted
   for a discovery client name enter the value of the `mc_discovery_client_name` output
   (default `mc-discovery-client`) **exactly** — this binds MCDCv6 to the source the module
   pre-registered.

2. **Load the SSH credential.** Download `lab-ssh-key.pem` from the SSH-key bucket and add it in
   MCDCv6 as a credential named `Lab-key`, type *SSH private key*, username `migrationcenter`:

   ```bash
   BUCKET=$(gcloud storage buckets list --filter="name~migcenter" --project="$PROJECT" --format="value(name)")
   gcloud storage cp "gs://$BUCKET/lab-ssh-key.pem" ./lab-ssh-key.pem --project="$PROJECT"
   ```

3. **Run the discovery scan.** In MCDCv6 add a Linux/Windows data source, set the IP scan range
   to cover the `linux_vm_internal_ips` (e.g. start `10.128.0.1`, end `10.128.0.10`), select the
   `Lab-key` credential, and run the collection. It completes in a few minutes; the Linux assets
   then appear in Migration Center.

4. **Review the inventory and (optionally) AWS data.** In the Console (output
   `migration_center_url`) open **Assets → Virtual machines**. You should see the Debian VMs
   from the live scan and, if configured, the imported AWS instances. If you did not provide AWS
   credentials, import the pre-staged sample CSVs from the Windows VM via **Data sources → Add
   source → Uploads → AWS VM export**.

   ```bash
   curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/assets" \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     | jq '.assets[] | {name: (.name|split("/")|last), os: .machineDetails.guestOsDetails.osName}'
   ```

5. **Build groups, preferences, and a TCO report.** In the Console: create asset groups under
   **Groups**, create migration preference sets under **Migration preferences** (model machine
   series, sizing strategy, and commitment term), then under **Reports** create a report
   configuration mapping groups to preference sets and generate a **Total Cost of Ownership**
   report. Generation takes a few minutes; review the per-VM machine-type recommendations,
   storage and licence modelling, and the cost range across your preference scenarios.

---

## Task 4 — Observe [Manual]

1. **Discovery progress** — watch the asset count grow as scans/imports land:

   ```bash
   curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/assets" \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" | jq '.assets | length'
   ```

2. **Import-job status** — confirm AWS/sample imports completed:

   ```bash
   curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/importJobs" \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     | jq '.importJobs[] | {displayName, state}'
   ```

3. **VM health** — confirm the source VMs stay `RUNNING`, and use the Windows VM serial-port
   output to observe the startup script. In the Console, Compute Engine surfaces CPU/network
   metrics per VM, and Migration Center → Reports shows report-generation state.

---

## Task 5 — Troubleshoot [Manual]

Durable techniques for the failure modes you are most likely to hit.

- **RDP cannot connect:** the Windows startup script is probably still installing MCDCv6/Chrome.
  Wait 3–5 minutes after deploy and re-check the serial-port output.
- **MCDCv6 sign-in fails:** the Google account lacks Migration Center Admin on the project —
  grant `roles/migrationcenter.admin` and retry.
- **Scan results don't appear in the expected source:** the discovery client name entered in
  MCDCv6 didn't match `mc_discovery_client_name` (case-sensitive). Re-enter it exactly.
- **Linux scan shows "Access Denied":** the credential must use username `migrationcenter` with
  `lab-ssh-key.pem`. Verify SSH manually with the key (see the Configuration Guide).
- **Linux VMs not discovered:** the MCDCv6 IP scan range is too narrow — widen it to cover all
  `linux_vm_internal_ips`.
- **AWS import did not run or failed:** confirm both AWS inputs were set, the bootstrap key has
  IAM write permissions, the `aws` CLI is available in the deployment environment, and
  `aws_region` matches where your EC2 instances live. With no credentials, import the pre-staged
  sample CSVs manually instead.
- **TCO report stuck generating:** reports take a few minutes; poll the report state via the
  REST API until it reports `SUCCEEDED`.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**).
Delete runs `terraform destroy` and is irreversible (the deployment record is retained for
history). This removes everything the module created in state: the Windows and Linux VMs, the
VPC and firewall rules, the Cloud Storage bucket (and the SSH key in it), and — when AWS was
enabled — the scoped AWS IAM user, policy, and access key.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual
changes that conflict with the Terraform state), use **Purge** instead — it removes the
deployment from RAD's records **without** destroying the cloud resources (it makes RAD forget
the project).

> **Migration Center objects are not deleted by destroy.** The discovery source, import jobs,
> and any asset groups, preference sets, and reports you created are not tracked in Terraform
> state and survive teardown. Remove them via the Migration Center console or REST API, or
> delete the project. The enabled APIs are also left enabled so a shared project is not
> disrupted.

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module provisions the VPC, sample source VMs, SSH-key bucket, and initialises Migration Center + a discovery source (and optional AWS import) |
| 2 — Access & verify | Manual | RDP into the Windows MCDCv6 host; confirm sample VMs and the registered source exist |
| 3 — Operate | Manual | Complete the MCDCv6 sign-in, run the Linux scan, review AWS data, and generate a TCO report |
| 4 — Observe | Manual | Track asset count, import-job status, and VM/report health via Console and REST API |
| 5 — Troubleshoot | Manual | Diagnose RDP, OAuth, source-name, SSH, scan-range, AWS-import, and report issues |
| 6 — Tear down | Automated | Delete (Trash) removes all module resources; Migration Center objects cleaned up manually |
