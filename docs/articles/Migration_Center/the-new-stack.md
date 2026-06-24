<!--
Target:   The New Stack
Audience: Architects, migration leads, FinOps and platform decision-makers planning a cloud or datacenter-exit migration
Voice:    Opinionated architect thought-leadership — an argument about why the assessment phase is the one that determines migration outcomes
Tags:     google-cloud, cloud-migration, migration-center, assessment, tco, finops, discovery, datacenter-exit
Goal:     Argue that disciplined discovery + TCO assessment is the highest-leverage, most-skipped phase of a migration; CTA to the Migration_Center reference architecture.
-->

# The Migration Phase That Decides the Outcome Is the One Teams Skip

Every migration post-mortem I have read tells the same story from the same starting point: the cutover. The runbook, the maintenance window, the rollback that did or didn't work. What almost none of them examine is the decision that actually determined whether the migration succeeded — the one made weeks earlier, when someone estimated *what was being moved, what it did, and what it would cost to run on the other side*.

That is the assessment phase. It is unglamorous, it produces a spreadsheet rather than a deploy, and it is routinely compressed into "we'll figure out sizing as we go." That compression is where migrations go wrong. You can recover from a botched cutover with a rollback. You cannot recover from migrating a fleet you never understood — you just discover, line item by line item, in the first cloud bill.

The clearest way to internalize why this phase carries so much weight is to run it on a realistic system end to end. The **Migration_Center** module does exactly that: it stands up a working Google Cloud **Migration Center** discovery and assessment environment — sample source workloads included — so the assessment phase stops being a slide and becomes something you operate.

## Assessment is a measurement problem, and most teams guess instead

The core failure mode of migration planning is substituting estimation for measurement. Someone looks at a VM, sees 16 vCPUs and 64 GB allocated, and sizes the cloud equivalent at 16 vCPUs and 64 GB. The allocation was never the demand. The machine has been idling at 8% CPU for two years. You just paid to migrate slack.

Migration Center is built around the opposite premise: discover the real shape of the estate, then reason about it. The module makes that concrete with the **MC Discovery Client (MCDCv6)** running on a Windows host, scanning a set of Debian Linux targets over SSH. What MCDCv6 collects is not an inventory line — it is a guest-OS-level profile: hardware, OS details, installed software, running processes, network interfaces, open ports. That depth is the whole point. You are not migrating "a VM"; you are migrating a thing that runs specific software, talks to specific ports, and consumes specific resources, and only measurement tells you which.

The architectural claim worth holding onto: **the quality of every downstream migration decision — wave sequencing, right-sizing, TCO, the go/no-go itself — is bounded by the fidelity of the discovery underneath it.** Cheap discovery produces confident-looking plans built on allocation figures and tribal knowledge. That is the most expensive kind of plan, because its errors don't surface until you're committed.

## Two discovery depths, and the gap between them is the lesson

The module deliberately gives you two sources of inventory, and the contrast is instructive rather than incidental. MCDCv6 produces deep, live, guest-OS detail. The optional AWS path — supply bootstrap credentials and the module provisions a scoped, read-only IAM user and imports live EC2 inventory — produces hardware and tag inventory in CSV form, but *no live OS detail*.

That gap is the architecture lesson. CSV import is fast, broad, and shallow; agent-based discovery is slower, narrower per pass, and deep. Real assessments use both — broad import to bound the estate, deep scanning to understand the workloads that matter — and an architect's job is to know which questions each can answer. Sizing a database tier off tag inventory is how you end up with the idling-at-8% problem. Knowing *why* one source can answer "what's actually running" and the other can't is more valuable than either dataset alone.

## TCO is the output that makes the phase pay for itself

Discovery is the input; **Total Cost of Ownership** is the output that justifies the whole exercise to the people funding the migration. Migration Center's TCO reporting turns the measured inventory into a defensible cost model on Google Cloud — the artifact that answers "what does this actually cost over there" with evidence instead of a vendor's list price multiplied by optimism.

The reason to practice generating a TCO report against *real* discovered assets, rather than reading about the feature, is that the report is only as honest as its inputs — and the module lets you feel that coupling directly. Run a thin scan, get a thin report. This is also why the module is deliberate about *not* pre-creating asset groups, preference sets, or reports: generating them before discovery data arrives would produce empty or misleading output. The sequencing — discover first, then group, then express migration preferences, then report — is the discipline encoded into the workflow. You build the report from the assessment; you do not start with the conclusion.

## The honesty in the design is where the real guidance lives

A reference architecture earns trust by being explicit about its constraints, and Migration_Center's constraints map almost one-to-one onto decisions a real migration program has to make consciously.

- **The region is permanent.** When Migration Center initialises, it binds all assessment data to a single region, and you cannot change it without a new project. That is not a module quirk — it is a forcing function. The first irreversible decision in your assessment is *where the assessment lives*, and the module makes you make it deliberately.
- **One step stays manual on purpose.** The MCDCv6 Google sign-in is an interactive OAuth flow that cannot be scripted. The module automates service initialisation, source registration, sample workloads, and the AWS import — and then stops at the human-in-the-loop boundary. That boundary is honest: discovery in the real world is not a fire-and-forget pipeline, and pretending otherwise is how teams skip the thinking.
- **A single scan is a snapshot, and the module says so.** Production assessments run MCDCv6 for two to four weeks to build a utilisation history before trusting right-sizing recommendations. One scan populates the inventory and yields a representative TCO — enough to learn the workflow — but the module is explicit that single-scan right-sizing understates real demand. That caveat *is* the right-sizing lesson.
- **The assessment artifacts are not infrastructure.** The discovery source, import jobs, groups, preferences, and reports are created through Migration Center's API, not tracked in Terraform state. They survive a `destroy` that removes the VMs, VPC, and bucket. The separation is correct: your *assessment* and your *lab infrastructure* have different lifecycles, and conflating them is a category error.

Read those constraints as a checklist for any real assessment: choose the data residency boundary deliberately, keep a human in the discovery loop, collect long enough to trust the utilisation data, and treat the assessment output as a durable artifact distinct from the scaffolding that produced it.

## The takeaway for migration and platform leads

The reason to deploy Migration_Center is not to scan three sample Linux VMs. It is to internalize, on a realistically-shaped exercise, the thing that determines migration outcomes: **assessment is measurement, not estimation; the fidelity of discovery bounds the honesty of every plan built on it; and TCO is the artifact that converts that measurement into a defensible decision.** Those are the substance of the phase your migration's success actually rides on — and they are far easier to grasp against a running discovery than a planning template.

The cutover gets the war stories. The assessment gets the credit it's owed only in the migrations that went well. Practice the one that decides.

👉 Explore the **Migration_Center** reference architecture in the RAD Lab modules catalog: the [module deep-dive](../../modules/Migration_Center.md) and the [end-to-end lab guide](../../labs/Migration_Center.md).
