<!--
Target:   Dev.to
Audience: Developers, cloud engineers, and FinOps-curious folks who want to practice the migration assessment phase before moving any workloads
Voice:    Hands-on, conversational, practical, real commands, show-don't-tell
Tags:     #googlecloud #cloudmigration #finops #devops
Goal:     Show that running a real Migration Center discovery + TCO assessment is approachable and worth practicing; CTA to deploy the Migration_Center RAD module.
-->

# Practice the Migration Phase Everyone Skips: Discovery & TCO on Google Cloud Migration Center

Most migration stories start at the exciting part — "we lifted-and-shifted 200 VMs to the cloud." Nobody talks about the boring, load-bearing phase that happens *before* that: figuring out what you actually have, what it really does, and what it would cost to run somewhere else.

That's the **assessment phase**, and it's the one that quietly de-risks the whole migration. Skip it and you find out three months in that you over-provisioned everything, missed a dependency, and your "savings" evaporated.

Google Cloud **Migration Center** is Google's free, unified platform for exactly this phase: discover workloads, build an inventory, estimate **Total Cost of Ownership (TCO)** on Google Cloud, and plan migration waves. The **Migration_Center** RAD module stands up a complete, hands-on discovery environment so you can run a realistic end-to-end assessment — *without needing a real datacenter to point it at*.

Let's look at what actually lands.

## What you get

It's a standalone, educational module — one GCP project, one apply — and it provisions a full lab so you can practice the discovery → inventory → TCO workflow:

- **A Windows Server 2022 MCDCv6 host** (`migcenter-<id>-winvm01`) — the discovery agent. A PowerShell startup script creates the lab user, enables RDP, installs Chrome (needed for the OAuth flow), silently installs the **MC Discovery Client (MCDCv6)**, and stages a sample AWS CSV import zip in Downloads.
- **Three Debian 12 Linux VMs** (`migcenter-<id>-linvm-1…3`) — sample source workloads that MCDCv6 scans over SSH. Think of them as the stand-in for your on-prem fleet.
- **A 4096-bit RSA keypair** — public key pushed to each Linux VM, private key (`lab-ssh-key.pem`) stored in a private Cloud Storage bucket (`migcenter-<id>-mc-keys`) so you can load it into MCDCv6 as an SSH credential.
- **A dedicated auto-mode VPC** + firewall rules (allow-internal, ssh, rdp, icmp, http) so MCDCv6 can reach the Linux targets over their internal IPs and reach Google APIs outbound.
- **The Migration Center service initialised** for your region, with a **discovery source** registered automatically so MCDCv6 has somewhere to send results.
- **Optional: live AWS EC2 inventory.** Supply AWS bootstrap credentials and the module creates a scoped, read-only IAM user and imports your real EC2 instances alongside the GCP scan results.

The contrast between the two discovery depths is part of the fun: MCDCv6 gives you guest-OS-level detail (installed software, running processes, open ports), while the AWS CSV import gives you hardware/tag inventory but no live OS detail.

## The one step you have to do by hand

Here's the honest bit most "fully automated" tools hide: **the MCDCv6 Google sign-in (OAuth) cannot be scripted.** It needs an interactive browser session. Everything else — service init, source registration, sample VMs, the optional AWS import — is automated.

So the workflow after `apply` is:

1. RDP into the Windows VM.
2. Launch MCDCv6, complete the Google login (the manual step).
3. Select your project and type the discovery client name **verbatim** so MCDCv6 binds to the pre-registered source.
4. Load `lab-ssh-key.pem` as the `Lab-key` SSH credential (user `migrationcenter`).
5. Set an IP scan range covering the Linux VMs' internal IPs and run the collection.
6. Build asset groups + migration preference sets and generate a TCO report from the console.

That's it. The module gets you to "service initialised, source registered, sample workloads ready, AWS imported (if configured)" and hands you the interesting part.

## Deploying it

Straight OpenTofu/Terraform from the module directory:

```bash
cd modules/Migration_Center
cat > terraform.tfvars <<EOF
project_id = "my-gcp-project"
region     = "us-central1"
zone       = "us-central1-a"
EOF
tofu init && tofu apply
```

Terraform provisioning is fast — roughly **5–8 minutes**. The Windows startup script (Chrome + MCDCv6 install) runs in the background and is usually ready a further 3–5 minutes later. You can watch it land:

```bash
gcloud compute instances get-serial-port-output migcenter-<id>-winvm01 \
  --zone "$ZONE" --project "$PROJECT" | grep -Ei "mcdc|chrome|lab setup"
```

## Poke at it

Grab the RDP target and the values you'll feed into MCDCv6:

```bash
# RDP target — Username: migrationcenter  Password: m1grat10nc#nt#r
gcloud compute instances describe migcenter-<id>-winvm01 --zone "$ZONE" --project "$PROJECT" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# Internal IPs to set as the MCDCv6 scan range
gcloud compute instances list --filter="name~migcenter AND name~linvm" --project "$PROJECT" \
  --format="table(name, zone, status, networkInterfaces[0].networkIP)"

# Download the SSH key MCDCv6 needs
gcloud storage cp "gs://migcenter-<id>-mc-keys/lab-ssh-key.pem" ./lab-ssh-key.pem --project "$PROJECT"
chmod 600 ./lab-ssh-key.pem
```

Once a scan has run, you don't even need the console to confirm it worked — the Migration Center REST API will show your assets:

```bash
TOKEN=$(gcloud auth print-access-token)
# Discovery sources
curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/sources" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.sources[] | {id: (.name|split("/")|last), displayName, type}'
# Discovered/imported assets
curl -s "https://migrationcenter.googleapis.com/v1/projects/$PROJECT/locations/$REGION/assets" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.assets[] | {name: (.name|split("/")|last), os: .machineDetails.guestOsDetails.osName}'
```

Then jump to the console via the `migration_center_url` output and walk through **Assets → Groups → Migration preferences → Reports** to generate your TCO.

## Things worth knowing before you rely on it

This is an **education and demo** module. A few honest edges:

- **The region is permanent.** When Migration Center first initialises, it commits all assessment data to a single region (`region`, default `us-central1`). You can't change it later without a new project. Pick it deliberately.
- **The discovery client name must match exactly.** `mc_discovery_client_name` (default `mc-discovery-client`) has to be typed **verbatim, case-sensitive** into MCDCv6. A mismatch silently creates a *second, unregistered* source and your scan results never reach the one you expected.
- **AWS is both-or-neither, and the bootstrap key needs IAM write.** Leave `aws_access_key_id` empty to skip AWS entirely (no AWS calls, no AWS resources). When you do supply credentials, they must be **bootstrap credentials with IAM write permissions** — the module creates a scoped EC2-read-only IAM user and runs discovery under *that* key. EC2-read-only bootstrap creds fail at the IAM-provisioning step. The `aws` CLI also has to be present in the execution environment.
- **The RDP creds are hardcoded and `allow-rdp` is open to `0.0.0.0/0`.** Username `migrationcenter`, password `m1grat10nc#nt#r` — fine for a throwaway lab, but restrict the source range and rotate for anything else. The RSA private key also lives in state *and* the bucket; lock both down.
- **A single scan is a snapshot.** Real assessments run MCDCv6 for 2–4 weeks to build a utilisation history for accurate right-sizing. One scan is enough to populate the inventory and produce a representative TCO, but don't trust single-scan right-sizing for production planning.
- **Migration Center objects aren't Terraform-managed.** The source, import jobs, and any groups/preferences/reports you create are made via REST API calls, *not* tracked in state. `destroy` removes the VMs, VPC, firewall, and bucket — but the Migration Center objects survive. Clean them up via the console/API or by deleting the project.

## Why it's a great thing to deploy

If you've only ever read about migration assessment, this is the fastest way to actually *do* it: discover real workloads, see the difference between deep agent scanning and CSV import, and produce a TCO report you can defend in a planning meeting. The assessment phase is the one that de-risks everything downstream — and here you get to practice it end-to-end without touching production.

Deploy it, run a scan, generate a TCO report, and you'll never look at "let's just lift-and-shift" the same way again.

👉 **Migration_Center** lives in the RAD Lab modules catalog. Grab it and explore the [module deep-dive](../../modules/Migration_Center.md) and the [hands-on lab guide](../../labs/Migration_Center.md).
