<!--
Target:   Dev.to
Audience: Cloud and infrastructure engineers curious about running real VMware on Google Cloud and lift-and-shift migration
Voice:    Hands-on, conversational, practical, show-don't-tell
Tags:     #googlecloud #vmware #gcve #cloudmigration #vsphere #devops
Goal:     Show that standing up a real vSphere/NSX-T SDDC on Google Cloud is approachable; CTA to deploy the VMware_Engine RAD module.
-->

# Run Real vSphere on Google Cloud: Lift-and-Shift Your VMware Estate Without Refactoring

Most "move to the cloud" advice assumes you're going to rewrite everything into containers, functions, and managed databases. That's great if you're starting fresh. It's a non-starter if you've got hundreds of VMs, a vCenter your team actually knows how to drive, NSX-T segments wired exactly the way the network team likes them, and zero appetite to refactor a working estate just to change where it runs.

Google Cloud VMware Engine (GCVE) is the escape hatch. It runs the **full VMware SDDC stack — vSphere, vSAN, NSX-T, and HCX — on dedicated, Google-managed bare metal**, inside your Google Cloud project. Same vCenter. Same tooling. Same operational muscle memory. You lift and shift VMs as-is, and you get GCP adjacency for free: low-latency, private-network access to BigQuery, Cloud SQL, Vertex AI, and the rest, without traversing the public internet.

The **VMware_Engine** RAD module stands the whole thing up end to end in a single deploy. Let's look at what actually lands and how to drive it.

## What you get

One apply provisions the complete environment, in dependency order:

- **A VMware Engine private cloud** — the SDDC itself: vCenter, vSAN, NSX-T, and HCX on bare-metal nodes. Defaults to a single-node `TIME_LIMITED` evaluation cloud (perfect for labs); flip to `STANDARD` (3+ nodes) for anything that has to persist.
- **A global VMware Engine network** — the Google-managed fabric the private cloud rides on. It is *not* a normal VPC and won't show up in the VPC console.
- **VPC peering** into a Google Cloud **peer VPC**, with custom-route import and export enabled, so NSX-T segments you create inside the SDDC are automatically advertised back to Google Cloud and vice versa.
- **A VMware Engine network policy** governing outbound internet and external-IP allocation for workload VMs, via an edge-services CIDR.
- **Default firewall rules** on the peer VPC — allow-internal, SSH, RDP, ICMP.
- **A Windows Server 2022 jump host** on the peer VPC. This is your workstation for reaching the management consoles.
- **A vCenter credential reset** — once the cloud is `ACTIVE`, the module resets the solution-user password and prints it to the deployment logs.

The whole point: every one of those is plumbing you'd otherwise wire by hand before you could even log into vCenter. The module does the boring ordering correctly.

## Why the jump host exists (and why you can't skip it)

Here's the thing that trips people up the first time. **vCenter, NSX-T, and HCX are private.** Their FQDNs resolve to private IPs reachable only from inside the VMware Engine network or a peered VPC — never directly from the public internet. That's not a misconfiguration to fix; it's the security posture.

So the module drops a Windows Server 2022 instance on the peer VPC, tagged `jump-host`, with an ephemeral external IP for RDP. You RDP into *that*, and from its browser you reach the management consoles over the private peering link.

The module does **not** set a Windows password (it can't, safely). You generate one yourself:

```bash
# Find the jump host and its external IP
gcloud compute instances list --filter="name~jump-host" --project "$PROJECT" \
  --format="table(name, zone, status, networkInterfaces[0].accessConfigs[0].natIP)"

# Generate RDP credentials
gcloud compute reset-windows-password <jump-host-name> \
  --zone "$ZONE" --project "$PROJECT"
```

Then RDP to `<external-ip>:3389`. On macOS, `brew install --cask windows-app`; on Linux, `xfreerdp /u:<user> /p:<pass> /v:<ip>:3389 /dynamic-resolution`.

## Getting into vCenter

The vCenter, NSX-T, and HCX FQDNs come out as Terraform outputs (`vcenter_fqdn`, `nsx_fqdn`, `hcx_fqdn`). To actually sign in you need the solution-user credentials. The module resets these after the cloud is `ACTIVE` and prints them to the deployment logs — **they are not a Terraform output**, on purpose. Capture them from the logs, or re-run the describe:

```bash
gcloud vmware private-clouds vcenter credentials describe \
  --private-cloud=<private-cloud-name> --username=solution-user-01@gve.local \
  --location "$ZONE" --project "$PROJECT"

# Expired? Reset them:
gcloud vmware private-clouds vcenter credentials reset \
  --private-cloud=<private-cloud-name> --username=solution-user-01@gve.local \
  --location "$ZONE" --project "$PROJECT" --no-async
```

From the jump host browser, open `https://<vcenter-fqdn>`, accept the self-signed cert, and you're in the vSphere Client — the exact UI your team already knows.

## Deploying it

The module ships in the RAD Lab catalog. Non-interactively via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m VMware_Engine -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/VMware_Engine
tofu init
tofu apply -var="project_id=my-gcp-project"
```

A minimal `tfvars` for a lab:

```hcl
project_id         = "my-gcp-project"
private_cloud_type = "TIME_LIMITED"
node_count         = 1
create_jump_host   = true
```

## The big honest warning: this is slow and expensive

Read this part before you hit apply. Two realities of bare-metal GCVE that no automation can hide:

- **Provisioning is slow by design.** Google has to allocate and configure physical servers before the SDDC software even installs. A single-node `TIME_LIMITED` cloud typically reaches `ACTIVE` in **30–90 minutes**; a `STANDARD` (3+ node) cloud can take **2–4 hours**. The private-cloud resource carries 180-minute create/update/delete timeouts. During this window the deploy looks like it's hanging. **It isn't — do not interrupt it.** Teardown is slow for the same reason.

- **A node is expensive.** GCVE bills per bare-metal node at a substantial hourly rate. Use `TIME_LIMITED` (one node) for labs, and **tear it down promptly** when you're done. `STANDARD` with 3 nodes multiplies that, so only reach for it when the workload must survive.

Check progress without babysitting the terminal:

```bash
gcloud vmware private-clouds describe <private-cloud-name> \
  --location "$ZONE" --project "$PROJECT" --format="value(state)"
```

## More gotchas worth knowing

- **`management_cidr` is immutable.** You can't change it after the cloud is created. Pick a `/24` that doesn't overlap the peer VPC or the `edge_services_cidr` — a wrong choice means a full destroy/recreate (hours) and loses every VM.
- **Use the API node-type form.** It's `standard-72`, not the UI label `ve1-standard-72`. The wrong string is a hard API error during creation. Availability is zone-dependent too.
- **`TIME_LIMITED` + 1 node, or `STANDARD` + 3 nodes** — those are the only valid pairs. A mismatch is rejected by the API *after* the long provisioning attempt, which is a painful way to learn it.
- **Only one network policy per VMware Engine network.** A leftover policy from a failed run blocks re-creation with `Resource for the given network already exists`. List and delete the orphan, then redeploy:
  ```bash
  gcloud vmware network-policies list --location "$REGION" --project "$PROJECT"
  gcloud vmware network-policies delete <policy-name> \
    --location "$REGION" --project "$PROJECT" --quiet
  ```
- **`TIME_LIMITED` clouds are reclaimed.** Google takes them back after the evaluation window, VMs and all. Don't put anything you care about in one.
- **Private-cloud deletion is irreversible** and destroys every VM and all data inside. Migrate or back up first.

## Why it's a great thing to deploy

If you've heard "you can run VMware natively on Google Cloud" and wanted to actually *see* it — not read a datasheet — this is the fastest path to a real vCenter you can log into, with NSX-T, vSAN, and HCX all present and peered into a GCP VPC you control. The migration story (lift and shift, keep your tooling, gain GCP adjacency) stops being a slide and becomes a thing running in your project.

Stand it up, RDP into the jump host, open the vSphere Client, and you're looking at the same VMware you run today — just on Google's bare metal, one peering hop from BigQuery.

👉 **VMware_Engine** lives in the RAD Lab modules catalog. Explore the [module deep-dive](../../modules/VMware_Engine.md) and the [hands-on lab guide](../../labs/VMware_Engine.md).
