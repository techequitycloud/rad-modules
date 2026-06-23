<!--
Target:   The New Stack
Audience: Architects, platform leads, and modernization decision-makers with VM estates to migrate
Voice:    Opinionated thought-leadership on VM-to-container replatforming and migration economics
Tags:     google-cloud, gke, kubernetes, containers, migration, modernization, m2c, devops, replatforming
Goal:     Argue that automated replatforming changes the rewrite-vs-migrate calculus; CTA to the Container_Migration reference architecture.
-->

# What a Two-VM Migration Sandbox Teaches About Replatforming Without a Rewrite

Every fleet-modernization program eventually collides with the same wall: a few hundred Linux VMs running applications nobody on the current team wrote, no appetite to rewrite them, and a mandate to "get to Kubernetes." The instinct in the room is binary — either rewrite the workload cloud-native (expensive, slow, risky) or lift-and-shift the VM and call it progress (cheap, fast, and you've changed nothing that matters). Both answers are wrong often enough that the more interesting question is the one most teams skip: *what can be replatformed as-is, and what does that path actually cost?*

Automated replatforming — Google Cloud's **Migrate to Containers (M2C)** is the concrete instance here — is the answer that splits the difference, and the clearest way to reason about it is to drive it end to end on a realistic workload. The **Container_Migration** module is built for exactly that: a self-contained sandbox with two live source VMs, the M2C toolchain on a workstation, and a GKE cluster waiting to receive the result. It is not a product demo. It is a place to develop an opinion about a migration strategy by performing one.

## The workload is deliberately the awkward case

The sandbox does not migrate a hello-world container. It runs **two real, coupled applications**: a PostgreSQL 14 database VM with a seeded `petclinic` schema, and an Apache Tomcat 10 VM serving **Spring PetClinic**, a JVM web app built from source by Maven at first boot that reaches across the internal network to that database. Both are Ubuntu 22.04 VMs that started life as VMs — not containers retrofitted to look like VMs.

That shape is the point. A stateless web tier is the easy half of any migration; the database, the persistent data directory, and the cross-service network dependency are where replatforming programs actually stall. By giving you a *stateful* workload and a *stateful-plus-stateless pair* with a real dependency between them, the sandbox forces you to confront the parts of M2C that matter — data migration to a PersistentVolume, port discovery, service wiring — rather than the parts that always work.

## The architectural claim: containerization becomes a copy, not a rewrite

Here is the thesis worth internalizing. **With automated replatforming, moving a Linux workload to a container becomes a transformation of its filesystem, not a transformation of its code.**

M2C splits the job across two CLIs, and the split is the design. The **`mcdc`** CLI runs *on the source VM* and produces a suitability assessment — scoring the workload across GKE, GKE Autopilot, Cloud Run, and Compute Engine journeys and surfacing the ports it actually listens on. The **`m2c`** CLI runs *on a separate workstation* and does the transformation: it copies the source VM's filesystem over rsync (the source keeps running, untouched), analyzes that copy with a workload-specific plugin into a migration plan you can edit, migrates persistent data into a GKE PersistentVolumeClaim, and generates the Dockerfiles, Kubernetes manifests, and Skaffold config that deploy it.

Notice what is *absent* from that pipeline: opening the application's source tree. The unit of work is the filesystem and the data, not the program. For an architect, that reframes the cost model. A rewrite is priced in engineer-quarters and carries the risk that the new system behaves differently from the old one. An automated replatform is priced in migration runs and carries a different, smaller risk: that the workload was a poor fit for containerization in the first place — which is precisely what the `mcdc` assessment exists to tell you *before* you commit.

## Assessment-first is the discipline most migrations skip

The ordering M2C enforces is itself a lesson. You assess with `mcdc` before you copy with `m2c`. That sequencing encodes a truth fleet-migration programs routinely violate: **not every VM should become a container, and the cheapest time to discover that is before you've built anything.**

The suitability report is not decoration. It scores a workload across multiple migration journeys and emits its findings in machine- and human-readable formats, which means a migration program can triage a fleet — these go to GKE, these are better on Cloud Run, these stay on Compute Engine for now — on evidence rather than on whoever shouts loudest in planning. An architecture that treats assessment as a gate, not an afterthought, is one that avoids the most expensive failure mode in modernization: discovering a workload was a bad container *after* you've migrated it.

## Stateful data is where the strategy is proven or disproven

Most migration demos quietly avoid state. This one centers it. The PostgreSQL VM exists so you have to run `m2c migrate-data`, which creates and populates a GKE PersistentVolumeClaim from the source data directory. That single step is where the replatforming-without-rewrite thesis is actually tested, because a database is the workload where "just containerize it" most often falls apart.

The architectural takeaway is not "M2C handles databases, problem solved." It is the opposite and more useful: replatforming gives you a *mechanically faithful* copy of the data on Kubernetes-native storage, and from there the durability, backup, and operational-ownership questions are yours to answer deliberately. The tool moves the bytes; it does not absolve you of designing how that data is operated in its new home. A reference architecture that makes you perform the data migration by hand is one that makes that boundary impossible to ignore.

## "The module provisions the environment, not the migration" is the honest design

It would be easy to build a one-click "migrate this VM" demo. This module deliberately does not. It stands up the VPC, the source VMs, the workstation, and the target cluster — and then *you* run `copy`, `analyze`, `migrate-data`, `generate`, and `skaffold run` yourself.

That choice is correct for an educational artifact, and it mirrors reality. Replatforming a fleet is not a single automated act; it is a repeated operator-driven lifecycle with judgment calls at every step — which plugin, which exposed endpoints, which persistent paths, which journey. A sandbox that hands you the machinery and the decisions, rather than hiding both behind a button, teaches the actual shape of the work. The friction is the curriculum.

## Where the sandbox stops — and why those are the real decisions

A reference architecture earns trust by being explicit about its edges, and this one's boundaries map cleanly onto the decisions a real migration must own:

- **It is zonal and ephemeral by design.** The GKE cluster is single-zone with one node pool; the source apps and their data are demo-grade and disappear on teardown. Production replatforming has to answer for multi-zone resilience and durable storage — the sandbox does not pretend otherwise.
- **The front door is open.** SSH and the Tomcat port are reachable from anywhere by default. Acceptable for a short-lived lab; in a shared or long-lived project, network scoping is your job.
- **Cleanup is not total.** Images you push to Artifact or Container Registry during the lab, and any PVCs you retain, outlive a destroy. The tool replatforms; lifecycle ownership of the artifacts is yours.

Read those boundaries as guidance. Edge exposure, data durability, image lifecycle, and cluster topology are exactly the decisions automated replatforming *doesn't* make for you — and seeing where the tool stops is how you learn where your architecture has to start.

## The takeaway for platform leads

The reason to deploy Container_Migration is not to containerize a fake vet clinic. It is to internalize, on a workload with the awkward properties real migrations have, what automated replatforming does to your modernization economics: **containerization becomes a filesystem transformation rather than a code rewrite, assessment becomes a gate that triages a fleet on evidence, stateful data becomes a migrated PersistentVolume you then own operationally, and the migration becomes a repeatable operator lifecycle rather than a heroic one-off.** Those four shifts are the substance of the rewrite-versus-migrate decision for a VM estate — and they are far easier to evaluate against a workload you've actually migrated than against a vendor diagram.

👉 Explore the **Container_Migration** reference architecture in the RAD Lab modules catalog: the [module deep-dive](../../modules/Container_Migration.md) and the [end-to-end lab guide](../../labs/Container_Migration.md).
