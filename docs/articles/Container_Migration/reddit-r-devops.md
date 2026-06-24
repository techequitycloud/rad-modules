<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that builds a VM-to-container (M2C) migration sandbox; spark discussion, link the module.
-->

# A reference module that spins up a full VM-to-container migration sandbox — two real source apps, Google's M2C toolchain, and a GKE cluster to land them on

Posting this because "replatform the VMs to containers" comes up here a lot and the usual answer is "well, there's Migrate to Containers" followed by nobody having actually tried it on anything realistic. This is a way to try it without spending a day building a believable source environment first. Not selling anything — it's an educational OSS module in the RAD Lab catalog. Writeup + honest gotchas below.

**What it does**

One `tofu apply` stands up a self-contained sandbox (its own VPC, no shared foundation):

- **PostgreSQL 14 source VM** (Ubuntu 22.04) with a seeded `petclinic` DB — a real stateful workload
- **Tomcat 10 source VM** running **Spring PetClinic**, built from source by Maven at boot, talking to the Postgres VM over the internal network, served on :8080 so you can browse it before migrating
- **M2C CLI workstation VM** preloaded with `m2c`, Docker, `kubectl`, Skaffold, GKE auth plugin (200 GB disk by default to hold copied filesystems)
- **Multi-node GKE cluster** (zonal, standard, 3x e2-medium default) to receive the migrated containers
- Firewall rules: allow-internal (so the workstation can copy source filesystems), SSH, ICMP, Tomcat:8080

Everything is `mig-<id>-` prefixed.

**The migration part**

Two CLIs. `mcdc` runs on each source VM and scores containerization suitability across GKE/Autopilot/Cloud Run/Compute Engine. `m2c` runs on the workstation and does the actual work: `copy` (rsync of the source filesystem — source VM keeps running, never modified), `analyze` (→ editable migration plan), `migrate-data` (→ populates a GKE PVC from the DB data dir), `generate` (→ Dockerfiles + k8s manifests + Skaffold), then `skaffold run`. End result: a VM app running as a pod on GKE, data on a PV, **without touching the app source**.

```
sudo /assess_mcdc.sh                 # on each source VM
sudo /install_container_tools.sh     # on the workstation, verify the toolchain
m2c copy ... ; m2c analyze ... ; m2c migrate-data ... ; m2c generate ...
skaffold run
```

**Gotchas / things I'd want to know first**

- **The module builds the environment, not the migration.** Every M2C step is manual. That's the point (it's a lab), but don't expect a one-click migrate. Budget time to actually drive it.
- **Give the VMs 5–10 min after apply.** Startup scripts do real work: Postgres seed, a Maven build of PetClinic, downloading the toolchain. `terraform apply` returning ≠ tools ready. Check `/var/log/startup-script.log`.
- **Toolchain is pulled from public endpoints at boot.** If one's briefly down, an install step can be skipped *silently*. Run `/install_container_tools.sh` before you start instead of assuming it's all there. Bit me once.
- **Don't shrink the workstation disk.** 200 GB default isn't padding — `m2c copy` has to hold the source filesystems plus working space, and it fails partway through if it runs out.
- **Cluster is zonal, single node pool.** No regional option in this module. Keep `zone` inside `region` or the apply fails.
- **SSH (22) and Tomcat (8080) are open to 0.0.0.0/0** by default. Fine for a throwaway lab, tighten the ranges in anything shared/long-lived.
- **Cleanup isn't total.** Destroy takes the VMs/cluster/VPC/firewall. It does NOT delete images you pushed to Artifact/Container Registry during the lab — those keep costing you until you remove them. PVCs go with the cluster.
- **Transient DB error right after deploy is expected** — PetClinic self-heals its DB connection once Postgres finishes init.

**Why bother**

It's the least painful way I've found to actually practice the M2C lifecycle on a *realistic* case — a stateful database plus an app server that depends on it, which is the scenario that actually stalls real migrations, not a stateless toy. Good for learning the assess→copy→analyze→migrate-data→generate→deploy flow, demos, or sanity-checking whether automated replatforming is viable for your fleet before you commit engineer-quarters to it.

Curious what folks here think: for a mixed VM estate, do you trust automated replatforming (M2C-style filesystem copy + generated manifests) for stateful workloads, or do you draw the line at stateless tiers and rebuild the data layer cloud-native by hand? And has anyone run `mcdc` assessments across a real fleet — was the suitability scoring actually useful for triage, or did you end up overriding it everywhere?

Module + docs (deep-dive and a step-by-step lab) are in the RAD Lab `rad-modules` repo under `Container_Migration`.
