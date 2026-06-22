<!--
Target:   Medium (general — personal blog / large tech publications)
Audience: Broad developer/platform audience, multi-cloud-curious, learning cloud-native patterns
Voice:    Narrative, first-person, accessible, a "I assumed the hard part, and it wasn't there" arc
Tags:     Google Cloud, AWS, EKS, GKE, Kubernetes, Multicloud, DevOps
Goal:     Tell the story of realizing you can manage AWS Kubernetes from Google Cloud without migrating; CTA to the EKS_GKE module.
-->

# I Stopped Believing Multi-Cloud Had to Mean Migration

For a long time, "multi-cloud" lived in my head as a synonym for "a migration you haven't started yet." Every conversation about running on more than one cloud seemed to bottom out in the same place: pick a winner, then spend the next year dragging everything onto it. The alternative — actually operating workloads on two clouds at once — sounded like signing up to maintain two of everything forever. Two consoles, two IAM models, two ways to get a `kubectl` context, two dashboards I'd have to mentally diff at 2 a.m.

So I did what a lot of people do. I nodded along when multi-cloud came up, quietly assumed it meant pain, and never actually tried the version that wasn't.

What changed my mind wasn't an argument. It was watching an AWS cluster answer to my Google login.

## The assumption I was carrying

My mental model had one bug in it, and it was a big one. I assumed that *where a cluster runs* and *where you manage it from* were the same decision. If it was on AWS, then obviously you managed it with AWS tools, reached it with AWS auth, watched it with CloudWatch. That bundling felt like a law of physics rather than a choice.

And because I believed that, "use Google Cloud for this AWS workload" could only mean one thing: move the workload to Google Cloud. Which is a migration. Which is the thing I was avoiding.

It never occurred to me that you could leave the cluster exactly where it was — control plane on AWS, nodes in an AWS VPC, nothing relocated — and just *change where it's operated from.*

## What I actually deployed

The thing that broke the assumption was a reference module called **EKS_GKE**. It does something that sounds, on paper, like it shouldn't be allowed: it provisions a genuine **Amazon EKS** cluster on AWS, and then registers that cluster with Google Cloud as a **GKE Attached Cluster** — a member of a Google Cloud Fleet.

I gave it a GCP project and a set of AWS credentials (sensitive inputs, never hardcoded — the AWS keys it needs are only to *build* the cluster), pointed it at `us-west-2`, and ran one apply. It stood up the AWS side properly — a dedicated VPC across three Availability Zones, an EKS cluster, a managed node group of EC2 workers, the IAM roles for the control plane and the nodes. Then it did the part I'd never seen before: it installed an agent into the cluster and registered the whole thing with my Google Cloud project.

The agent is the quiet hero here. It's a **Connect Agent**, delivered as a Helm install manifest pulled from Google Cloud, and the thing I kept re-reading until it sank in is the *direction* it talks: **outbound only.** It dials out to Google on port 443. Google never reaches into the AWS network. There was nothing to open, no inbound rule, no peering, no bastion. The cluster phones home, and that's the entire connection.

## The moment it clicked

When the apply finished, I opened the Google Cloud Console, went to Kubernetes Engine, and there it was in the cluster list: my EKS cluster, marked **Attached**, distribution **EKS**, sitting next to clusters that had never been anywhere near AWS.

Then I ran the command that actually rearranged my brain:

```bash
gcloud container attached clusters get-credentials aws-eks-cluster \
  --location us-central1 --project my-gcp-project

kubectl get nodes -o wide
```

And the EC2 nodes answered. From my laptop. Authenticated with my Google account. **No AWS credentials anywhere in that path.**

I'd typed `kubectl get nodes` ten thousand times. This time the nodes were on AWS, and I'd reached them by being logged into Google. The request went out through the Connect gateway, Google authenticated *me*, checked I was on the cluster's admin list, and proxied the call through the agent to the EKS API server. No VPN. No keys. No bastion.

That was the click. **Where the cluster runs and where I manage it from came apart in my hands.** The bundling I'd treated as a law turned out to be a default I'd never questioned.

## Then I kept pulling the thread

Once an AWS cluster was under Google Cloud's management plane, the things I'd assumed I'd have to stitch together myself were just... there.

I opened **Logging → Logs Explorer**, picked the Kubernetes Cluster resource, and found my EKS cluster's system and workload logs flowing into Cloud Logging — no log agent that I'd installed or had to babysit on the AWS side. I opened **Monitoring → Dashboards → GKE** and there were the EKS cluster's metrics, in the same Kubernetes-aware panes I use for native GKE, because the module had Managed Service for Prometheus collecting on the attached cluster. The multi-cloud observability problem I'd been dreading — two metric stores, two query languages — collapsed into one pane because the attachment had quietly carried the telemetry pipe along with it.

And the access model turned out to be the well-designed part I didn't expect. The identity that ran the deploy (mine) got `cluster-admin` automatically. Anyone I'd listed in `trusted_users` would too. To add more people later, I learned, you grant two things on purpose: a Google Cloud IAM role to traverse the gateway, and a Kubernetes RBAC binding for what they can do once inside. Two layers — one for *may you reach it*, one for *what may you do* — which is exactly the distinction I'd seen single-cloud setups smear together and regret.

The whole thing rests on OIDC, by the way. Each EKS cluster runs its own OIDC provider; the module registers that issuer with Google Cloud, and Google verifies EKS-issued tokens against it. No static keys cross between clouds. The same federated trust that powers GKE Workload Identity, pointed at an AWS cluster.

## The honest caveats, because they taught me too

This is an *educational* module, and its edges were as instructive as its center.

It's two clouds, so it's two bills — AWS for the EKS control plane, the EC2 workers, and (if you choose private subnets) a NAT Gateway; Google Cloud for Fleet, logging, and monitoring. The `node_group_max_size` I bumped hopefully turned out to be just a ceiling: nothing autoscales until you install a cluster autoscaler, which this module doesn't. The Kubernetes version and the GKE platform version have to *match* — get them out of sync and the EKS cluster builds fine on AWS but silently never attaches, which taught me to respect version pinning the hard way. And the Fleet name is the `cluster_name_prefix` verbatim, so two deploys sharing a prefix in one project collide on the Google side. None of these are bugs; they're the module being honest about exactly the decisions a real multi-cloud setup has to own.

## What I'd tell past-me

If "multi-cloud" makes you flinch because you've quietly defined it as "migration," go deploy one attached cluster and watch the assumption fall apart. Not a slide. A real AWS EKS cluster, still on AWS, answering to your Google login.

EKS_GKE was the version of that on-ramp where I never had to move a workload to learn what unified management feels like. One apply, a cluster that stayed exactly where it was, and a `kubectl get nodes` that reached across a cloud boundary on the strength of who I am, not what keys I'm holding. The thing I'd been avoiding for years turned out not to require the migration I'd been dreading — because the cluster never had to move at all.

Deploy it. Run `get-credentials`, then `kubectl get nodes`. Watch an AWS cluster answer to Google. That's the moment multi-cloud stops meaning migration — and you don't get that moment from a diagram.

👉 **EKS_GKE** is in the RAD Lab modules catalog. Start with the [module deep-dive](../../modules/EKS_GKE.md) and the [hands-on lab guide](../../labs/EKS_GKE.md).
