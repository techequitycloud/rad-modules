<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas of a migration assessment lab
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that stands up a Google Cloud Migration Center discovery + TCO lab; spark discussion, link the module.
-->

# A reference module that stands up a Google Cloud Migration Center discovery + TCO lab — sample workloads included, so you can actually practice the assessment phase

Sharing this because every time "do the discovery/assessment phase first" comes up it's treated as obvious-but-nobody-does-it, usually because you need a real estate to point a tool at. This module brings its own fake datacenter to scan, so you can run the phase end-to-end without one. Not selling anything — it's an educational OSS module in the RAD Lab catalog. Writeup + honest gotchas below.

**What it does**

One `tofu apply` stands up a complete Google Cloud **Migration Center** assessment environment:

- Windows Server 2022 VM with the **MC Discovery Client (MCDCv6)** pre-installed (startup script does Chrome + MCDCv6 install, enables RDP)
- 3x Debian 12 Linux VMs as sample source workloads, scanned by MCDCv6 over SSH
- Dedicated auto-mode VPC + firewall rules (internal/ssh/rdp/icmp/http)
- 4096-bit RSA keypair: pubkey on the Linux VMs, privkey in a private GCS bucket so MCDCv6 can load it as an SSH credential
- Migration Center service **initialised** for your region with a discovery source **registered** automatically
- Optional: supply AWS bootstrap creds and it creates a scoped read-only IAM user and imports live **EC2 inventory** alongside the GCP scan

Migration Center itself is Google's free assessment-phase tool — discover workloads, build inventory, estimate **TCO** on GCP, plan waves.

**The part that's actually useful**

You get to practice discovery → inventory → TCO against real-ish workloads. MCDCv6 does guest-OS-level scanning (installed software, processes, ports), the AWS path does CSV import (hardware/tags, no live OS detail). Seeing both depths side by side is genuinely the lesson — it's why real assessments use broad import + deep scanning together. Terraform part is fast, ~5–8 min; Windows host finishes installing in the background a few min later.

**Gotchas / things I'd want to know first**

- **The MCDCv6 Google login is manual.** It's an interactive OAuth flow, can't be scripted. Everything else is automated, but you WILL be RDP'ing in to click through a browser sign-in. Module is upfront about it.
- **The region is PERMANENT.** Migration Center binds all assessment data to one region on init (`region`, default `us-central1`). Can't change it without a new project. Pick deliberately.
- **The discovery client name must match verbatim.** `mc_discovery_client_name` has to be typed into MCDCv6 exactly, case-sensitive. Mismatch = a second unregistered source and your scan results silently never reach the one you expected. Easy to faceplant on.
- **AWS is both-or-neither and needs IAM write.** Leave the key empty to skip AWS entirely. If you set it, the bootstrap creds need IAM write (`iam:CreateUser`/`CreatePolicy`/`AttachUserPolicy`/`CreateAccessKey` + deletes) because it provisions a scoped EC2-read-only user and runs discovery under THAT. Read-only bootstrap creds fail at the IAM step. `aws` CLI must be in the exec env.
- **Single scan = snapshot.** Real assessments run MCDCv6 for 2–4 weeks for a utilisation history before trusting right-sizing. One scan is fine to learn the flow + get a representative TCO, but don't trust single-scan right-sizing for actual planning.
- **Lab creds are hardcoded** (RDP user/pass) and `allow-rdp` is open to `0.0.0.0/0`. Privkey lives in state + the bucket. Throwaway lab only — restrict + rotate for anything real.
- **Migration Center objects aren't in TF state.** Source, import jobs, groups, preferences, reports = API-created, not Terraform-managed. `destroy` kills the VMs/VPC/bucket but the MC objects survive. Clean up via console/API or delete the project.

**Why bother**

It's the least painful way I've found to actually *run* the assessment phase — discover real workloads, see deep-scan vs CSV-import depth, and generate a TCO report from real data instead of eyeballing instance sizes. Good for learning the discovery/inventory/TCO workflow, demos, or evaluating Migration Center before a real datacenter-exit.

Curious what folks here actually do for the assessment phase in practice — do you run agent-based discovery (MCDCv6 / equivalent) for the long utilisation window, or do you mostly lift inventory from CMDB/tags and call it good? And for anyone who's done a real datacenter exit: how much did skipping or rushing discovery cost you downstream?

Module + docs are in the RAD Lab `rad-modules` repo under `Migration_Center` — the [module deep-dive](../../modules/Migration_Center.md) and a step-by-step [lab guide](../../labs/Migration_Center.md).
