<!--
Target:   The New Stack
Audience: Architects, platform leads, and engineering decision-makers running multicloud Kubernetes
Voice:    Opinionated architect thought-leadership — an argument, not a tutorial
Tags:     google-cloud, azure, aks, gke, kubernetes, multicloud, fleet, anthos, connect-gateway, platform-engineering
Goal:     Argue that fleet attachment decouples "where a cluster runs" from "how it's governed", changing the multicloud build/buy calculus; CTA to the AKS_GKE reference architecture.
-->

# Multicloud Kubernetes Doesn't Require Migration — and an Attached AKS Cluster Proves It

The default architecture response to "we're on two clouds now" is a migration plan. The workloads picked Azure once; the new mandate favors Google Cloud; therefore something must move. This instinct is expensive and, more often than not, wrong. The thing that actually needs to be unified across clouds is rarely the *workload* — it's the *control plane around the workload*: identity, access, policy, logging, metrics, and the single list of "every cluster we operate." Those are governance concerns, and governance does not require relocation.

The clearest way to make that argument concrete is a reference architecture that does exactly one thing: takes a cluster running in one cloud and brings it under another cloud's management without moving it. The **AKS_GKE** module is that artifact. It provisions a Microsoft Azure AKS cluster, then registers it with Google Cloud as a **GKE Attached Cluster** — a first-class member of a **GKE Fleet**. The cluster keeps running in Azure. Google Cloud gains a management plane over it. Nothing migrates.

## The architectural claim: decouple where a cluster runs from how it's governed

Here is the idea worth internalizing: **with fleet attachment, the location of a cluster and the governance of a cluster become independent variables.** A cluster's compute, networking, and control plane can live in Azure while its identity model, access path, and observability live in Google Cloud. You are no longer forced to choose one cloud's *operational surface* by virtue of having chosen its *infrastructure*.

That decoupling is the whole game, and it inverts a tradeoff teams usually accept as fixed. The conventional assumption is that managing Kubernetes across two clouds means either (a) running two parallel operational stacks — two IAM models, two logging pipelines, two consoles, two on-call mental models — or (b) consolidating onto one cloud by moving the workloads there. Attachment offers a third option: one operational stack, two clouds of infrastructure, zero migrations. For a platform lead staring at an Azure estate and a Google Cloud mandate, that third option is frequently the only economically sane one.

## How the trust actually works — and why it's not a hack

Skepticism here is healthy: "managing an Azure cluster from Google Cloud" sounds like it should require either a VPN, a shared secret, or an exposed API server. AKS_GKE uses none of those, and the mechanism is the part architects should study.

Two properties carry the design. First, the AKS cluster has its **OIDC issuer enabled**, and Google Cloud establishes trust by validating Kubernetes-issued tokens against that issuer's published public keys. This is **OIDC federation** — there are no service-account keys, no shared credentials, nothing copied from one cloud to the other. Trust is a verifiable cryptographic relationship, not an exchanged secret. Second, the **GKE Connect agent** — installed onto the cluster via Helm — maintains a *persistent, encrypted, outbound* connection from AKS to Google Cloud. The cluster dials out; Google never dials in. Consequently the AKS API server needs no public endpoint, and Azure needs no inbound firewall rules or VPN.

Those two facts together dismantle the usual objection. The reason this isn't a security hole is that the data flow is outbound-only and the trust is federated, not bearer-token-shared. An architect evaluating any cross-cloud management story should check for exactly these two properties; their absence is where the real risk lives.

## Connect gateway turns identity into the access boundary

The operator-facing payoff of attachment is the **Connect gateway**. Once the cluster is a fleet member, engineers run `kubectl` against the Azure cluster using their *Google Cloud* identity — no Azure kubeconfig distribution, no per-engineer Azure credentials, no VPN onto the Azure network. The kubeconfig entry points at Google's gateway endpoint, not the AKS API server.

The access model is deliberately two-layered, and the layering is the lesson. A **Google Cloud IAM** role on the project (`gatewayReader` / `gatewayEditor` / `gatewayAdmin`) authorizes traversal of the gateway; **Kubernetes RBAC** on the cluster authorizes the specific API actions. Authentication is centralized in Google Cloud IAM; authorization remains where Kubernetes already keeps it. This is what "single pane of glass" should mean architecturally — not a unified dashboard, but a *unified identity boundary*. The cluster runs in Azure, yet the question "who is allowed to touch it" is answered by your Google Cloud IAM policy. Centralizing the *authentication* surface across clouds, while leaving fine-grained *authorization* to each cluster's RBAC, is a defensible and auditable split.

## Observability that follows the cluster across the cloud boundary

The governance argument extends past access into telemetry. On attachment, AKS system-component and workload logs flow into the destination project's **Cloud Logging** — using the same schema as native GKE, so existing GKE log queries work unchanged against an Azure cluster. **Managed Service for Prometheus** runs a collector on the AKS nodes and forwards Kubernetes metrics to **Cloud Monitoring**, where the built-in GKE dashboards populate automatically.

The architectural point is subtle but important: the observability story is keyed to *fleet membership*, not to the cluster's cloud. Because the Azure cluster is a fleet member emitting GKE-schema telemetry, your dashboards, log queries, and alerting policies don't fork by provider. You maintain one observability practice that happens to span two clouds, rather than two observability practices you have to keep in sync. That is the difference between multicloud as a unified discipline and multicloud as a permanent integration tax.

## The boundaries are the honest part

A reference architecture earns trust by naming its edges, and these edges are exactly the decisions a real multicloud program must own.

- **It is a two-cloud module with two cost centers.** Azure bills the AKS nodes; Google Cloud bills fleet management and observability ingestion. Attachment removes operational duplication, not infrastructure spend — the workload still costs what it costs in Azure.
- **`platform_version` must track `k8s_version`.** The attached-component / Connect agent version must be compatible with the AKS Kubernetes minor. This is a real lifecycle coupling: upgrading the cluster and upgrading its attachment are related operations, not independent ones, and an incompatible pairing leaves the cluster registered but unmanageable.
- **The cluster name is identity, not a label to churn.** `cluster_name_prefix` is used verbatim across both clouds with no deployment-ID suffix; changing it after first deploy recreates the cluster in *both* clouds, destroying the AKS workloads. Naming is a one-time architectural decision here, as it should be for anything that anchors cross-cloud identity.
- **Service mesh is available but not automatic.** A Cloud Service Mesh / Istio sub-module ships alongside but is a deliberate manual follow-up — attachment gives you management and observability, not an east-west security mesh, out of the box.

Read those boundaries as guidance: credentials lifecycle, version coupling, naming as identity, and where the mesh story begins are precisely the things a multicloud platform must decide explicitly rather than inherit.

## The takeaway for platform leads

The reason to stand up AKS_GKE is not to run an Azure cluster you could have run anyway. It is to internalize, against real infrastructure in two clouds, the shift that fleet attachment represents: **the cloud a cluster runs on and the cloud that governs it no longer have to be the same cloud.** Identity, access, logging, and metrics consolidate onto Google Cloud's fleet while the workload stays put in Azure, with trust established by OIDC federation and access flowing outbound-only through the Connect gateway.

That shift quietly removes "migrate the workloads" from the list of things multicloud forces you to do — and replaces it with a configuration decision. For most organizations carrying an Azure estate into a Google Cloud future, that is the more honest, and far cheaper, architecture. It is also one you can evaluate against a running cluster in an afternoon rather than a quarter.

👉 Explore the **AKS_GKE** reference architecture in the RAD Lab modules catalog: the [module deep-dive](../../modules/AKS_GKE.md) and the [end-to-end lab guide](../../labs/AKS_GKE.md).
