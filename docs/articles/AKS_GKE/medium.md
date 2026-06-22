<!--
Target:   Medium (general — personal blog / large tech publications)
Audience: Broad developer audience working across clouds, multicloud-curious or multicloud-skeptical
Voice:    Narrative, first-person, accessible, a "I finally got it" realization arc
Tags:     Google Cloud, Azure, AKS, GKE, Kubernetes, Multicloud, DevOps
Goal:     Tell the story of understanding fleet attachment by managing a real Azure cluster from Google Cloud; CTA to the AKS_GKE module.
-->

# I Stopped Believing in "Single Pane of Glass" — Then I Attached an Azure Cluster to Google Cloud

For a long time, "single pane of glass across clouds" lived in my head as a phrase salespeople used and engineers rolled their eyes at. I'd been on the receiving end of enough multicloud pitches to assume the truth was always uglier than the diagram: two consoles, two IAM models, two logging stacks, and a migration project lurking somewhere in the small print. Whenever someone said "manage all your clusters from one place," I heard "move all your clusters to our place."

What changed my mind wasn't another pitch. It was attaching a cluster I left exactly where it was.

## The thing I kept getting wrong

My mental model of multicloud Kubernetes had one fixed assumption baked into it: *where a cluster runs determines how you operate it.* If a cluster was in Azure, you operated it the Azure way — Azure identity, Azure kubeconfig, Azure portal, Azure Monitor. Unifying operations across clouds therefore meant either running parallel stacks forever or consolidating the clusters onto one cloud. Both options were bad, so I'd quietly concluded that real cross-cloud management was mostly aspirational.

The assumption I never questioned was that "runs in Azure" and "managed like Azure" were the same fact. They are not. That's the thing I had backwards.

## What I actually deployed

The reference module that fixed my thinking is called **AKS_GKE**. It does something I'd never quite seen end to end: it creates a Microsoft Azure **AKS** cluster, and then registers that cluster with Google Cloud as a **GKE Attached Cluster** — a real member of a **GKE Fleet**. The cluster runs entirely in Azure. Google Cloud just builds a management plane on top of it.

I had to bring credentials for both clouds — a Google Cloud project with billing, and an Azure subscription, with a service principal (`client_id`, `client_secret`, `tenant_id`, `subscription_id`) holding Contributor on the subscription, because the module creates the Azure Resource Group itself. I handed those over as sensitive inputs, pointed the module at my project, ran one apply, and walked away for about fifteen minutes while Azure built the cluster.

When it came back, there was an AKS cluster sitting in Azure `westus2`. Three nodes, its own Resource Group, a managed identity. Nothing surprising. The surprising part came next.

## The moment it clicked

I ran two commands I'd never run in this combination before:

```bash
gcloud container fleet memberships get-credentials azure-aks-cluster --project "$PROJECT"
kubectl get nodes -o wide
```

And the Azure nodes printed.

I want to be precise about why that landed. I wasn't using an Azure kubeconfig. I hadn't downloaded credentials from the Azure portal. There was no VPN onto the Azure network, and the AKS API server didn't even have a public endpoint I was routing to. I was authenticating with my *Google* identity, and `kubectl` was reaching an Azure cluster through something called the **Connect gateway** — a Google Cloud endpoint that proxies the request using Google Cloud IAM.

I checked the context to be sure I wasn't fooling myself:

```bash
kubectl config current-context   # connectgateway_<project>_global_<cluster>
```

`connectgateway`. Not an Azure context. A Google one, pointed at an Azure cluster.

That was the click. **"Where it runs" and "how I manage it" came apart in my hands.** The cluster was unambiguously Azure's. The operator experience was unambiguously Google Cloud's. The thing I'd assumed was one fact was actually two, and a fleet membership was the seam between them.

## Then I went looking, and the seam held everywhere

Once I had an Azure cluster answering to my Google identity, I started checking whether the unification was real or just a clever kubectl trick. It was real.

I opened **Kubernetes Engine → Clusters** in the Google Cloud Console, and there was the Azure cluster — Azure icon, type `Attached`, distribution `aks` — sitting in the same list a native GKE cluster would. One console, two clouds.

I opened **Logs Explorer**, and the AKS system and workload logs were there, in the *same schema* GKE uses. The log queries I already knew worked against a cluster that had never run on Google infrastructure.

I opened **Monitoring**, and the built-in GKE dashboards were populating — a Managed Prometheus collector on the AKS nodes was forwarding Kubernetes metrics to Cloud Monitoring without my asking. `kubectl top nodes`, through the gateway, just worked.

And the part I found genuinely elegant: I went looking for the shared secret that must be making all this possible, and there wasn't one. The trust runs on **OIDC federation** — Google Cloud validates tokens issued by the AKS OIDC issuer against its published public keys. No keys exchanged, no secrets copied between clouds. The whole bridge is built on a cryptographic relationship, not a password someone has to rotate. That detail was when I stopped being suspicious and started being impressed.

## The honest caveats, because they taught me the shape of it

This is an *educational* module, and its edges sharpened my understanding rather than dulling it.

It's genuinely two clouds, with two bills — Azure for the nodes, Google Cloud for fleet management and observability ingestion. Attachment unified my *operations*; it didn't make the Azure compute free, and it shouldn't pretend to.

The `platform_version` (the attached-component / Connect agent version) has to match the AKS `k8s_version` minor. Mismatch them and the cluster attaches but stays unmanageable — a clean lesson that the cluster and its attachment have a shared lifecycle, not independent ones.

The cluster name is used verbatim in both clouds with no random suffix, so changing `cluster_name_prefix` after the fact would recreate the cluster in *both* clouds and destroy the Azure workloads. That made me treat the name as identity, which is exactly what it is when it's anchoring a cross-cloud relationship.

And a service mesh sub-module ships with it but isn't installed automatically — attachment gave me management and visibility, not an east-west security mesh. Knowing where the out-of-the-box story stopped told me precisely what attachment is and isn't.

## What I'd tell past-me

If you've been quietly cynical about "single pane of glass" because every version of it you'd seen came with a migration attached — go attach a cluster that doesn't move. Not a slide. A real Azure cluster you stand up, leave in Azure, and then operate from Google Cloud with your own identity.

AKS_GKE was the version of that experience where I never had to relocate a workload to see cross-cloud management actually work. One apply, fifteen minutes, and then Azure nodes printing under a Google `connectgateway` context. The phrase I'd dismissed for years turned out to mean something specific and real — I just had to see a cluster answer to the wrong cloud before I believed it.

Deploy it. Run `get-credentials` against the Azure cluster, then `kubectl get nodes`. Watch the Azure nodes show up under a Google context. That's the moment "single pane of glass" stops being a phrase and becomes a terminal you're looking at.

👉 **AKS_GKE** is in the RAD Lab modules catalog. Start with the [module deep-dive](../../modules/AKS_GKE.md) and the [hands-on lab guide](../../labs/AKS_GKE.md).
