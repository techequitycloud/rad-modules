<!--
Target:   The New Stack
Audience: Architects, platform leads, multi-cloud decision-makers
Voice:    Opinionated thought-leadership on multi-cloud Kubernetes management and the attach-don't-migrate pattern
Tags:     google-cloud, aws, eks, gke, kubernetes, multicloud, fleet, attached-clusters, platform-engineering
Goal:     Argue that "attach, don't migrate" changes the multi-cloud management calculus; CTA to the EKS_GKE reference architecture.
-->

# Attach, Don't Migrate: What an EKS Cluster on a Google Cloud Fleet Teaches About Multi-Cloud

Every multi-cloud strategy meeting eventually collides with the same false binary. Either you standardize — pick one cloud's control plane and grind toward it, accepting a migration project measured in quarters — or you accept fragmentation: two consoles, two identity models, two observability stacks, two on-call runbooks, and an org chart that quietly splits along cloud lines. Both options are expensive, and both are usually chosen by exhaustion rather than design.

There is a third option that has matured to the point of being boring, in the best sense: **attach the cluster where it already runs, and unify the management plane instead of the infrastructure.** The clearest way to see what that actually buys you is to stand up a concrete reference architecture that does it end to end. The **EKS_GKE** module is exactly that — it provisions a real Amazon EKS cluster on AWS and registers it with Google Cloud as a **GKE Attached Cluster**, a member of a Google Cloud Fleet. The workload never leaves AWS. The management plane moves.

## The architectural claim: management is separable from infrastructure

Here is the idea worth internalizing: **where a Kubernetes cluster's control plane runs and where it is operated from are independent decisions.**

We have spent a decade conflating them. "Run on AWS" came bundled with "managed via AWS IAM, observed via CloudWatch, accessed via AWS auth." EKS_GKE pries those apart. The EKS control plane stays managed by AWS. The EC2 worker nodes stay in an AWS VPC. But the *operation* of that cluster — who can reach it, where its logs and metrics land, which fleet-wide policies apply to it — becomes a Google Cloud concern. The cluster shows up in Kubernetes Engine as type **Attached**, distribution **EKS**, next to native GKE clusters, and is operated through the same console, the same `gcloud`, the same identity model.

That separation is not a convenience feature. It is the architectural premise of multi-cloud done deliberately rather than accidentally. You are no longer choosing a cloud and inheriting its entire operational surface. You are choosing where infrastructure runs and, separately, where it is governed from.

## The unlock is fleet membership, and the mechanism is an outbound agent

Two details in EKS_GKE are load-bearing, and both are easy to skim past.

The first: the cluster is registered as a **GKE Fleet (Hub) membership**. That membership — not the attachment alone — is the prerequisite for everything fleet-level: Policy Controller, Config Management, multi-cluster services, Cloud Service Mesh. The same membership model that brings one EKS cluster under Google Cloud governance here is the model that brings twenty under it across clouds and regions. Designing for fleet membership means the one-cluster case and the many-cluster case stop being different problems.

The second: connectivity is **outbound-only**. The module installs a **Connect Agent** into the EKS cluster — delivered as a Helm-managed install manifest fetched from Google Cloud — and that agent dials out to Google Cloud on port 443. Google never reaches into the AWS VPC. There are no inbound firewall rules to negotiate with a security team, no peering, no bastion. This is why the pattern works identically whether the nodes sit in public subnets behind an Internet Gateway or in private subnets behind a NAT Gateway. The hardest political problem in multi-cloud connectivity — "open a path from *their* cloud into *our* network" — simply doesn't arise, because the path runs the other way.

For an architect, those two facts reframe the connectivity and governance conversation entirely. The unit of capability is the fleet, and the cost of joining it is an egress connection, not an ingress exception.

## Identity is federated, not shared

The part that usually makes security review nervous about cross-cloud management is credentials. If Google Cloud is going to authenticate access to an AWS cluster, where do the AWS keys live, and who holds them?

The answer in this architecture is: **nowhere shared.** Each EKS cluster runs its own OIDC provider. The module registers that issuer URL with Google Cloud, and Google Cloud verifies tokens issued by EKS against it — the same federated-trust model native GKE uses for Workload Identity. No static AWS keys cross between clouds to enable the management channel. The AWS credentials the module *does* require are needed only to *provision* the EKS cluster in the first place, and they are held sensitively and never surfaced in logs — they are a build-time input, not a runtime bridge.

The access model that results is worth studying because it is honest about its layers. Authorized Google identities — the deployer, plus anyone in `trusted_users` — are granted Kubernetes `cluster-admin` and reach the cluster through the **Connect gateway**: Google Cloud authenticates the identity, checks it against the cluster's admin list, and proxies the request through the Connect Agent to the EKS API server. Granting access to additional people deliberately takes *two* layers: a Google Cloud IAM role for traversing the gateway (e.g. `roles/gkehub.gatewayReader` or `gatewayEditor`), and a Kubernetes RBAC binding for what they may do once through. That two-layer model is not friction for its own sake; it is the correct separation between "may you reach this cluster at all" and "what may you do inside it" — a distinction that single-cloud setups frequently collapse and later regret.

## Observability arrives with the attachment, not after it

Because the Connect Agent is already in the cluster, the observability story is mostly already paid for. The attached cluster forwards `SYSTEM_COMPONENTS` and `WORKLOADS` logs to Cloud Logging — with no log agent for anyone to operate on the AWS side — and Managed Service for Prometheus collection is enabled, so EKS metrics surface in the same Kubernetes-aware Cloud Monitoring dashboards used for native GKE.

The architectural point is the same one that separates a platform from a pile of tools: the EKS cluster's telemetry lands in the *same* place as your GKE clusters' telemetry, queryable with the same PromQL, visible on the same GKE dashboards. Multi-cloud observability is usually a stitching project — two metric stores, two query languages, two dashboard conventions, a correlation problem at 3 a.m. Here it collapses into one pane because the attachment carried the telemetry pipe with it.

## Where the reference architecture stops — and why that boundary is the lesson

A reference architecture earns trust by being explicit about its edges. EKS_GKE deliberately does not:

- **Install a cluster autoscaler.** `node_group_max_size` is a ceiling, not a behavior. The managed node group handles scale-out and AMI updates during upgrades, but actual autoscaling beyond the desired count is left to you. Raising the max alone does nothing — an honest reminder that "max nodes" is a permission, not a mechanism.
- **Deploy your applications or enable fleet features for you.** Registration and observation are in scope; Policy Controller, Config Management, and Cloud Service Mesh are yours to turn on from the Fleet Feature Manager once the cluster is a member. (An Anthos Service Mesh helper exists as a separate sub-component and is explicitly *not* part of the core apply.)
- **Pretend version skew is forgiving.** `k8s_version` (the EKS minor) and `platform_version` (the GKE Attached Clusters version) must correspond, and Google validates the pair at registration. Mismatch them and the EKS cluster is created on AWS but never attaches — a failure mode the architecture surfaces loudly rather than hiding.

Read those boundaries as guidance. They are precisely the decisions — autoscaling policy, which fleet features to adopt, version lifecycle discipline, application deployment — that a real multi-cloud platform must make explicitly rather than inherit. The module shows the *attachment* pattern cleanly without pretending to be the whole platform.

## The takeaway for platform leads

The reason to deploy EKS_GKE is not to run a spare EKS cluster. It is to internalize, against real infrastructure spanning two clouds, what the attach-don't-migrate pattern does to your operating model: **management becomes separable from infrastructure, fleet membership becomes the unit of capability, cross-cloud connectivity becomes an outbound egress rather than an inbound exception, identity becomes federated rather than shared, and observability arrives with the attachment instead of as a stitching project.**

Those shifts are the substance of the multi-cloud management decision — and they are far easier to evaluate against a running AWS cluster answering to a Google login than against another vendor diagram. The migration project you were dreading may be the wrong project. The cluster can stay where it is. The control plane is the thing that moves.

👉 Explore the **EKS_GKE** reference architecture in the RAD Lab modules catalog: the [module deep-dive](../../modules/EKS_GKE.md) and the [end-to-end lab guide](../../labs/EKS_GKE.md).
