<!--
Target:   The New Stack
Audience: Architects, infrastructure leads, and decision-makers facing data-center exit and VMware migration
Voice:    Opinionated thought-leadership on lift-and-shift vs refactor for VMware estates
Tags:     google-cloud, vmware, gcve, vsphere, nsx, cloud-migration, data-center-exit, hybrid-cloud, infrastructure
Goal:     Argue that lift-and-shift onto a native VMware SDDC changes the migration calculus; CTA to the VMware_Engine reference architecture.
-->

# Lift-and-Shift Isn't a Compromise: What a VMware SDDC on Google Cloud Teaches About Data-Center Exit

Every data-center exit discussion eventually collides with the same wall. Someone draws the target-state architecture — everything containerized, stateless, managed-service-backed — and someone else, usually the person who owns the VMware estate, asks the question that ends the meeting: *and who refactors the three hundred VMs we can't touch?*

The cloud-native orthodoxy has an answer for that, and it's the wrong one for most enterprises: refactor everything, eventually, on a roadmap that outlives the data-center lease. The honest reality is that a large VMware estate is not a backlog of refactoring candidates. It's a running business, encoded in vSphere semantics, NSX-T topology, and a decade of operational knowledge that lives in your team's hands, not in a wiki.

The interesting development is that "lift and shift unchanged" has stopped being the embarrassing compromise and become a legitimate destination architecture. Google Cloud VMware Engine (GCVE) runs the complete VMware Software-Defined Data Center — vSphere, vSAN, NSX-T, and HCX — on dedicated, Google-managed bare metal *inside your Google Cloud project*. The clearest way to see why that changes the calculus is to look at a concrete reference architecture that provisions one end to end. The **VMware_Engine** module does exactly that, and the design decisions it encodes are the argument.

## The workload model is "your estate, unchanged"

The premise of refactor-first migration is that the application's current form is a liability to be eliminated. The premise of GCVE is the opposite: the application's current form is an asset to be preserved, because reproducing its behavior in a different runtime is where migrations go to die.

GCVE is the same vSphere, the same NSX-T, the same HCX you run on-premises. A VM that runs in your data center runs in GCVE without an OS change, an application change, or a re-platforming exercise. Your vCenter is your vCenter. Your network team's NSX-T segments come across via HCX. The skills your team already has — the entire reason your estate is operable at all — transfer intact instead of being written off.

That is the shape of the migration most enterprises are actually living through, and the documented results are not marginal. One enterprise case study (BHP) reports infrastructure provisioning time falling from six months to six days after replacing a legacy VMware vRA environment with GCVE. The savings aren't from rewriting workloads; they're from no longer running the metal.

## Adjacency is the real prize, and it's an architecture decision

If lift-and-shift only relocated your VMs, it would be a real-estate transaction with no strategic upside. The reason it's more than that is adjacency — and the reference architecture makes the adjacency mechanism explicit rather than aspirational.

The VMware_Engine module peers the VMware Engine network into a Google Cloud **peer VPC**, with custom-route import and export enabled. That peering is not a checkbox; it is the bridge. NSX-T segments defined inside the SDDC are automatically advertised to the peer VPC, and Google Cloud routes propagate back. The consequence is that a VM running unmodified vSphere can reach BigQuery, Cloud SQL, or Vertex AI over private networking, without traversing the public internet.

This is the part architects should internalize: **lift-and-shift and modernization stop being sequential phases.** The legacy estate runs as-is on day one, *and* it sits one private hop from every native Google Cloud service. You don't have to finish the migration before you start consuming managed analytics and AI. The estate becomes a platform you incrementally hollow out — moving a database to Cloud SQL here, a pipeline to BigQuery there — at the pace the business tolerates, not the pace a big-bang refactor demands.

## The private-by-default posture is the point, not an inconvenience

A detail in the module that looks like friction is actually a security stance worth defending. vCenter, NSX-T, and HCX are **never reachable from the public internet**. Their management endpoints resolve to private IPs inside the VMware Engine network, reachable only from the peered VPC. The module deploys a Windows Server 2022 jump host on the peer VPC specifically to bridge that gap — you RDP to the jump host, and reach the consoles from there.

It would have been easier to expose the consoles publicly. It would also have been wrong. A control plane that can provision and destroy your entire estate has no business being internet-facing, and the reference architecture refuses to make that compromise convenient. For regulated domains — financial services, healthcare, manufacturing, exactly the sectors driving GCVE adoption — a private management plane isn't a nice-to-have; it's the difference between a migration that passes a security review and one that doesn't.

## The provisioning model is honest about physics

The module's first apply does not finish quickly. A single-node evaluation cloud takes 30 to 90 minutes to reach `ACTIVE`; a production-grade `STANDARD` cloud (three or more nodes) can take two to four hours. The private-cloud resource carries 180-minute timeouts to accommodate it.

This is not a defect to optimize away — it is bare metal being honest about itself. Google is allocating and configuring physical servers before the SDDC software installs. Any tool that claimed to provision a vSAN-backed vSphere cluster in five minutes would be lying about what's happening underneath. The architectural lesson is the same one that bites teams who underestimate GCVE: this is infrastructure with the cost structure and lifecycle of hardware, wrapped in an API. You provision deliberately, you size for persistence (`STANDARD`, not `TIME_LIMITED`, for anything real), and you treat teardown — which is equally slow and *irreversibly* destroys every VM and all data in the cloud — as a decision, not a cleanup step.

That honesty extends to immutability. The `management_cidr` is fixed at creation; choosing it wrong means a multi-hour destroy-and-recreate. The reference architecture surfaces these constraints instead of papering over them, which is precisely what you want from something you'll model a real migration on.

## Where the reference architecture draws its boundary

A reference architecture earns trust by being explicit about what it is. VMware_Engine provisions the SDDC, the network fabric, the peering, the policy, the jump host, and a vCenter credential reset — the substrate on which a migration runs. It deliberately stops short of running the migration itself: HCX is present and ready, but the actual workload mobility, the cutover sequencing, the application validation are yours.

The single-node `TIME_LIMITED` option is the tell. It exists so teams can validate connectivity, peering, console access, and HCX readiness — the entire operational on-ramp — before committing to the cost of a `STANDARD` production cloud. That is the right boundary for an *educational* artifact: it shows the lift-and-shift platform pattern cleanly, lets you rehearse the operations, and leaves the irreversible, expensive, estate-specific decisions where they belong — with the architect making them deliberately.

## The takeaway for infrastructure leads

The reason to stand up VMware_Engine is not to run a lab vCenter. It is to internalize, against a real SDDC, what native VMware on Google Cloud does to the data-center-exit decision: **the estate migrates unchanged, the skills transfer intact, the management plane stays private, and the whole thing lands one private hop from every Google Cloud service you'll eventually modernize into.** Lift-and-shift stops being the thing you apologize for and becomes the thing you build on. That shift is far easier to evaluate against a running SDDC than a migration slide — and a single-node evaluation cloud is a cheap way to have the argument with reality instead of a whiteboard.

👉 Explore the **VMware_Engine** reference architecture in the RAD Lab modules catalog: the [module deep-dive](../../modules/VMware_Engine.md) and the [end-to-end lab guide](../../labs/VMware_Engine.md).
