<!--
Target:   Medium (general — personal blog / large tech publications)
Audience: Broad developer and cloud-practitioner audience who has heard "do the assessment first" and never actually done one
Voice:    Narrative, first-person, accessible, a realization/journey arc
Tags:     Google Cloud, Cloud Migration, Migration Center, TCO, FinOps, DevOps
Goal:     Tell the story of finally understanding migration assessment by running a real discovery + TCO; CTA to the Migration_Center module.
-->

# I Finally Understood Migration Assessment by Discovering a Fake Datacenter

For years, the advice "do the assessment phase first" sat in my head as something I was supposed to believe but had never actually done. I'd nod along in migration planning meetings. I knew the words — inventory, discovery, right-sizing, TCO. I could repeat the warning that you shouldn't lift-and-shift blind. But I had never run a real discovery against anything, so the whole phase stayed abstract — advice I agreed with the way you agree with "eat more vegetables."

What finally made it concrete wasn't another best-practices article. It was discovering a fake datacenter I'd just deployed.

## The thing I kept skipping

My problem with the assessment phase was never that I doubted it mattered. Of course it matters. You don't move what you don't understand. The problem was that *trying* it seemed to require having a real estate to point a discovery tool at — a datacenter full of VMs, the access to scan them, the time to set up the agent, the permissions, the network paths. I had none of that lying around, so I kept doing what everyone does: estimating from allocations, eyeballing instance sizes, and telling myself I'd "validate during the migration."

So I never practiced it. The classic move — agree the thing is important, then skip it because the on-ramp looks like work, then feel vaguely guilty in the next planning meeting.

## What I actually deployed

The on-ramp that worked was a reference module called **Migration_Center**. It deploys a complete Google Cloud **Migration Center** discovery and assessment environment — and crucially, it brings its *own* source workloads to discover. I pointed it at a project, ran one apply, and a few minutes later I had a fake datacenter to assess.

What landed: a Windows Server 2022 VM with the **MC Discovery Client (MCDCv6)** already installed, three Debian Linux VMs standing in for an on-prem fleet, a dedicated VPC wiring them together, a Cloud Storage bucket holding an SSH key, and the Migration Center service initialised for my region with a discovery source already registered. The Terraform part took maybe five to eight minutes; the Windows host finished installing Chrome and MCDCv6 in the background a few minutes after that.

For the first time, I had everything the assessment phase needs — a workstation, an agent, targets to scan, somewhere to send the results — without owning a single physical machine.

## The one part I had to do myself

The module automated almost all of it, but it was honest about the one thing it couldn't: the MCDCv6 Google sign-in. That's an interactive OAuth flow in a browser, and it genuinely cannot be scripted. So I RDP'd into the Windows VM, launched MCDCv6, and logged in by hand.

Then I did the rest of the dance the module had set up for me: I typed the discovery client name in *exactly* as configured so the client bound to the source that was already waiting for it, loaded the lab SSH key as a credential, pointed an IP scan range at the Linux VMs' internal addresses, and hit run.

And then I watched a thing I'd only ever read about happen in front of me.

## The moment it clicked

The Linux VMs started streaming into Migration Center as discovered assets. Not as inventory rows I'd typed into a spreadsheet — as *discovered* objects, each one carrying detail I hadn't entered: the OS, the installed software, running processes, network interfaces, open ports.

That was the click. I'd spent years sizing migrations off what a VM was *allocated*. What MCDCv6 handed me was what a VM actually *was* and actually *did*. The gap between those two things — between "this box has 16 vCPUs" and "this box is running these three processes and idling most of the time" — is the entire reason the assessment phase exists. I'd read that sentence a hundred times. This was the first time I'd seen the data that makes it true.

**Right-sizing stopped being a word and became the difference between two datasets I was looking at on the same screen.**

## Then I went looking, and it kept giving

Once I had a real inventory, the rest of the phase turned concrete one piece at a time.

I grouped the discovered assets, expressed some migration preferences, and generated a **TCO report** — a cost model for running these workloads on Google Cloud, built from the discovery rather than from a list price and a hopeful guess. The report was only as honest as the scan behind it, and feeling that coupling directly taught me more about why thin assessments produce wrong numbers than any cautionary blog post had.

I also tried the optional AWS path. With bootstrap credentials supplied, the module created a scoped, read-only IAM user and imported my live EC2 inventory right alongside the GCP scan. The contrast was its own lesson: the EC2 import gave me hardware and tags but no live OS detail, while the agent scan gave me the deep guest-OS picture. Two discovery depths, side by side, and suddenly I understood why real assessments use both — broad import to bound the estate, deep scanning to actually understand the workloads that matter.

## The honest caveats, because they taught me too

This is an *educational* module, and its edges were as instructive as its center.

The region Migration Center initialises into is **permanent** — all assessment data binds to one region and you can't change it without a new project. At first that felt like a gotcha; then I realized it was the phase's first irreversible decision, made explicit. The RDP credentials are hardcoded and the key lives in state and a bucket, so it's a throwaway lab, not something to leave exposed. And the single scan I ran was a *snapshot* — the module is upfront that real assessments run MCDCv6 for two to four weeks to build a utilisation history before you trust right-sizing. One scan was enough to learn the workflow and get a representative TCO, but it also taught me, in one honest sentence, why a single point-in-time reading understates real demand.

The assessment artifacts — the source, the import job, the groups and reports — aren't even Terraform-managed; they're created through the API and survive a `destroy` that tears down the VMs. That separation finally made sense to me too: my lab infrastructure and my assessment have different lifecycles, and treating them as the same thing was a mistake I'd have made by hand.

## What I'd tell past-me

If you've been agreeing that the assessment phase matters while quietly never running one — stop reading about it and go discover something. You don't need a real datacenter. You need a fake one you can scan, break, and re-scan.

Migration_Center was the version of that on-ramp where I never had to own a fleet to see what discovery does. One apply, a manual login, one scan, and then an inventory of things I hadn't typed — and a TCO report built from real measurement instead of a hopeful guess. The phase I'd skipped for years became obvious the moment I could watch it work.

Deploy it. Run the scan. Generate the TCO report. That's the moment "do the assessment first" stops being advice and starts being something you know how to do.

👉 **Migration_Center** is in the RAD Lab modules catalog. Start with the [module deep-dive](../../modules/Migration_Center.md) and the [hands-on lab guide](../../labs/Migration_Center.md).
