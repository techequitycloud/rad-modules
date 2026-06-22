<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that stands up a full VMware SDDC on Google Cloud; spark discussion, link the module.
-->

# A reference module that stands up a full VMware SDDC (vSphere/vSAN/NSX-T/HCX) on Google Cloud — lift-and-shift without refactoring, jump host included

Posting this because data-center exit comes up here a lot and it usually splits into "refactor everything into containers" vs "you can't, we have 300 VMs nobody will touch." GCVE is the third option and I'd never actually tried it until this module. Not selling anything — it's an educational OSS module in the RAD Lab catalog. Writeup + honest gotchas below.

**What it does**

One deploy stands up Google Cloud VMware Engine (GCVE) end to end:

- A **VMware Engine private cloud** — the actual SDDC: vCenter, vSAN, NSX-T, HCX on Google-managed bare metal. Single-node `TIME_LIMITED` by default, or `STANDARD` (3+ nodes) for prod.
- A global **VMware Engine network** (not a normal VPC, won't show in the VPC console) + **VPC peering** into a peer VPC, custom-route import/export on, so NSX-T segments advertise both ways.
- A **network policy** (internet + external-IP for workload VMs via an edge-services CIDR), default firewall rules, and a **Windows Server 2022 jump host**.
- A **vCenter solution-user credential reset** after the cloud goes ACTIVE.

**The part that's actually the point**

Your VMs come over unchanged. Same vCenter, same NSX-T, same skills — no OS or app refactor. And the peering means a lifted VM sits one private hop from BigQuery/Cloud SQL/Vertex AI, so "modernize later" is available day one instead of after a finished migration. That's the whole pitch and it mostly delivers.

```
gcloud vmware private-clouds describe <pc-name> --location "$ZONE" --project "$PROJECT" --format="value(state)"
gcloud compute reset-windows-password <jump-host> --zone "$ZONE" --project "$PROJECT"   # then RDP, browse to vcenter_fqdn
```

**Gotchas / things I'd want to know first**

- **It's SLOW.** Single-node `TIME_LIMITED` takes ~30–90 min to hit ACTIVE; `STANDARD` can be 2–4 hours. It's real bare metal being allocated, the resource has 180-min timeouts. The deploy looks hung during this — it isn't, don't interrupt. Teardown is slow too.
- **It's expensive.** GCVE bills per bare-metal node at a serious hourly rate, running or not. Use `TIME_LIMITED` (1 node) for labs and tear it down promptly. `STANDARD`+3 nodes multiplies it.
- **Consoles are private, by design.** vCenter/NSX-T/HCX resolve to private IPs reachable only from the peered VPC. That's why the jump host exists — RDP in, browse from there. Direct access from your laptop just times out.
- **vCenter creds are NOT a TF output.** The reset prints them to the deploy logs. Grab them from there or re-run `gcloud vmware private-clouds vcenter credentials describe`. The solution-user password also expires — re-reset when it does.
- **`management_cidr` is immutable.** Pick a `/24` that doesn't overlap the peer VPC or `edge_services_cidr`. Wrong choice = full destroy/recreate (hours) and you lose every VM.
- **Valid pairs only:** `TIME_LIMITED`+1 node or `STANDARD`+3 nodes. Mismatch gets rejected by the API *after* the long provisioning attempt. Painful way to find out.
- **`node_type_id` is the API form** `standard-72`, not the UI label `ve1-standard-72`. Wrong string = hard error at creation. Availability is zone-dependent.
- **One network policy per VMware Engine network.** A leftover from a failed run blocks re-create with `Resource for the given network already exists` — list + delete the orphan, then redeploy. Burned time on this.
- **`TIME_LIMITED` clouds get reclaimed** by Google after the eval window, VMs and all. And private-cloud deletion is irreversible — destroys every VM and all data. Back up first.

**Why bother**

It's the least painful way I've found to get a *real* VMware SDDC running on GCP to actually poke at — log into vCenter, look at the NSX-T peering, see the GCP adjacency — without standing up the network fabric, peering, jump host, and credential plumbing by hand. Good for evaluating data-center-exit/lift-and-shift, validating HCX/connectivity before committing to a STANDARD cloud, or just understanding what GCVE actually is instead of reading the datasheet.

Genuinely curious what folks here think: for an estate you can't refactor, is lift-and-shift onto GCVE (or AVS/VMC) a legit destination, or just kicking the modernization can down the road on more expensive metal? And anyone running GCVE in anger — does the per-node cost actually pencil out vs keeping the on-prem VMware, or is the win mostly the data-center exit itself?

Module + docs (deep-dive and a step-by-step lab) are in the RAD Lab `rad-modules` repo under `VMware_Engine`.
