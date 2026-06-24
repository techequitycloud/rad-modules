<!--
Target:   Medium (general — personal blog / large tech publications)
Audience: Broad infrastructure and cloud audience, migration-curious, VMware practitioners eyeing the cloud
Voice:    Narrative, first-person, accessible, a "I stopped fearing the migration" arc
Tags:     Google Cloud, VMware, GCVE, vSphere, Cloud Migration, Data Center, DevOps
Goal:     Tell the story of realizing lift-and-shift is legitimate by deploying a real VMware SDDC on Google Cloud; CTA to the VMware_Engine module.
-->

# I Stopped Believing "Cloud Migration Means Refactor Everything" the Day I Logged Into vCenter on Google Cloud

For most of my career, "moving VMware to the cloud" carried a quiet shame with it. The cloud-native crowd had made the message clear: if you're lifting and shifting VMs, you're doing it wrong. Real modernization means containers, managed databases, stateless services, the whole catechism. Lift-and-shift was the thing you did because you'd run out of time, budget, or courage to do it properly.

I believed that. And so every time I looked at the VMware estate I was responsible for — vCenter we knew cold, NSX-T segments the network team had tuned over years, hundreds of VMs nobody wanted to touch — I felt a low-grade dread. The cloud was where this was supposed to go, and getting it there apparently meant rewriting all of it.

What changed my mind wasn't an argument. It was logging into a vSphere Client that happened to be running on Google's bare metal.

## The thing I kept getting stuck on

My problem was never the cloud. It was the implied price of admission. Every migration story I'd absorbed assumed the workloads themselves had to change — re-architected, re-platformed, re-validated — before they were "allowed" in. For an estate that *worked*, that was an enormous, risky, multi-year tax to pay for the privilege of changing where the metal lived.

So the estate stayed where it was. The classic move: avoid the migration because the on-ramp looked like a rewrite, then feel vaguely guilty for running a data center in the year I was running one.

What I didn't really understand — what no diagram had made concrete for me — was that there was a path where the workloads *don't* change at all. Where vCenter is still vCenter, NSX-T is still NSX-T, and the only thing that's different is the floor the servers sit on.

## What I actually deployed

The on-ramp that worked was a reference module called **VMware_Engine**. It deploys Google Cloud VMware Engine — GCVE — which runs the full VMware stack (vSphere, vSAN, NSX-T, HCX) on dedicated, Google-managed bare metal inside a Google Cloud project. I pointed it at a project, kicked off a single-node evaluation cloud, and walked away.

For a long time. This is the first thing nobody quite prepares you for: it's *slow*, and deliberately so. A single-node `TIME_LIMITED` cloud takes somewhere between 30 and 90 minutes to come up; the production-grade ones can take hours. Google is allocating actual physical servers and installing a software-defined data center on them before anything is reachable. The deploy looks like it's hung. It isn't — it's doing the one thing five-minute cloud provisioning can never do, which is stand up real hardware. I learned to check state from the side and leave the terminal alone:

```bash
gcloud vmware private-clouds describe <private-cloud-name> \
  --location "$ZONE" --project "$PROJECT" --format="value(state)"
```

While it built, the module quietly wired up everything around the SDDC: a global VMware Engine network, VPC peering into a Google Cloud VPC, a network policy, firewall rules, and — the piece I'd end up grateful for — a Windows Server 2022 jump host.

## The moment it clicked

When the cloud finally went `ACTIVE`, I wanted into vCenter. And here's where the architecture taught me something before I'd even logged in: I *couldn't* reach it directly. vCenter, NSX-T, and HCX all live on private IPs, reachable only from inside the peered network. There is no public door. That's not a bug to route around; it's the posture.

That's what the jump host is for. I generated a Windows password for it, RDP'd in, and from that machine's browser opened `https://<vcenter-fqdn>` — using the solution-user credentials the module had reset and dropped into the deployment logs.

```bash
gcloud compute reset-windows-password <jump-host-name> --zone "$ZONE" --project "$PROJECT"
```

And there it was. The vSphere Client. The exact UI I'd been driving for years, the same panels, the same cluster view — except this cluster was running on Google's bare metal, one network hop from BigQuery.

That was the click. **The migration I'd been dreading didn't require changing a single workload.** The thing that had read as "rewrite everything or stay put" turned out to have a third option I'd never let myself see: bring the estate as-is, keep the tooling, keep the skills, and just change the floor.

## Then I went looking, and it kept giving

Once I had a real SDDC running, the abstract migration story turned concrete one piece at a time.

I looked at the peering and understood the actual prize. The module enables custom-route import and export, so NSX-T segments I'd create inside the private cloud get advertised straight into the Google Cloud VPC and back. Which means a VM running unmodified vSphere can reach Cloud SQL or Vertex AI over private networking. The "modernize later" path I'd assumed had to come *after* a finished migration was sitting right there, available on day one. Lift-and-shift and modernization weren't sequential phases. They were the same environment.

I poked at the network policy controlling whether workload VMs get internet and external IPs. I read through the firewall rules on the peer VPC. None of it was exotic. All of it was the ordinary plumbing I'd have spent days assembling by hand before I could even attempt a login.

The realization that hour gave me was bigger than the tooling: lift-and-shift wasn't the compromise. It was a legitimate destination, with a built-in on-ramp to everything the cloud-native crowd had told me I'd have to refactor for first.

## The honest caveats, because they taught me too

This is an *educational* module, and its hard edges were as instructive as its center.

It is **expensive**. GCVE bills per bare-metal node at a serious hourly rate, and that meter runs whether you're using the cloud or not. The single-node `TIME_LIMITED` type exists precisely so you can validate the whole pattern — connectivity, peering, console access, HCX readiness — without paying for a production cloud. I tore mine down promptly, which is the right instinct.

And teardown is its own lesson. It's slow, for the same bare-metal reasons, and it's **irreversible**: deleting the private cloud destroys every VM and all the data in it. Some settings, like the `management_cidr`, are immutable from creation — pick wrong and your only fix is a multi-hour destroy-and-recreate. The module surfaces these constraints instead of hiding them, which is exactly what I wanted from something I was using to model a real migration. The friction is the truth.

## What I'd tell past-me

If you've been carrying quiet guilt about an estate you "should have moved to the cloud by now," and you've been assuming that move means a rewrite — stop assuming. Go stand up a real one. Not a slide, not a diagram. An actual vCenter, on actual Google bare metal, peered into an actual VPC.

VMware_Engine was the version of that on-ramp where I never had to refactor anything to see what native VMware on Google Cloud actually is. One deploy, a patient wait, and then a vSphere Client that finally meant something: the same estate, the same skills, a new floor, and a private hop to the rest of the cloud. The migration I'd feared for years turned out to be a thing I could log into.

Deploy it. Wait for `ACTIVE`. RDP the jump host. Open the vSphere Client. That's the moment lift-and-shift stops feeling like a compromise — and you don't get that moment from a diagram.

👉 **VMware_Engine** is in the RAD Lab modules catalog. Start with the [module deep-dive](../../modules/VMware_Engine.md) and the [hands-on lab guide](../../labs/VMware_Engine.md).
