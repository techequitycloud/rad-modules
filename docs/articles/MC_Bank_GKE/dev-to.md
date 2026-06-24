<!--
Target:   Dev.to
Audience: Developers and platform engineers curious about multi-cluster GKE, fleets, and global load balancing
Voice:    Hands-on, conversational, practical, show-don't-tell
Tags:     #googlecloud #kubernetes #gke #multicluster #servicemesh #istio #devops
Goal:     Show that an active-active, multi-region banking app behind one global IP is approachable; CTA to deploy the MC_Bank_GKE RAD module.
-->

# Run One Bank Across Two Regions: Multi-Cluster GKE with a Fleet-Wide Mesh and a Single Global IP

Single-cluster Kubernetes is a solved problem for most of us. "What happens when that cluster's region goes away?" is where things get interesting — and where most demos quietly stop. Multi-cluster usually means you become a part-time operator of cross-cluster service discovery, fleet plumbing, and a global load balancer you wire by hand.

The **MC_Bank_GKE** RAD module skips the plumbing. From one Terraform config it builds a VPC, spins up **two GKE clusters in two regions**, registers them both into a **GKE Fleet**, turns on a **fleet-wide multi-primary Cloud Service Mesh**, wires up **Multi-Cluster Services (MCS)** and **Multi-Cluster Ingress (MCI)**, and deploys [Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos) across all of it — fronted by a **single global anycast IP** that routes each user to the nearest healthy cluster. It's the multi-region evolution of the single-cluster Bank_GKE.

It's standalone and educational: one GCP project with billing, and you get the whole active-active stack. Let's look at what actually lands.

## What you get

- **Two GKE Autopilot clusters in two regions** — with the defaults, `gke-cluster-1` in `us-west1` and `gke-cluster-2` in `us-east1`. Cluster names are 1-indexed, and `cluster1` is always the primary/config cluster in `available_regions[0]`.
- **A GKE Fleet** — every cluster registered as a membership (membership ID = cluster name). The fleet is what makes the mesh, MCS, and MCI span clusters at all.
- **Multi-primary Cloud Service Mesh** — enabled fleet-wide in automatic-management mode. Google runs an Istio control plane for *each* cluster, and all clusters share one trust domain (`<project>.svc.id.goog`), so sidecars in any cluster mutually authenticate.
- **Multi-Cluster Services + Multi-Cluster Ingress** — MCS lets a Service have backends across clusters; MCI provisions a global external Application Load Balancer whose backends span every cluster.
- **One global IP, one domain** — a single global address is reserved and the app is published at `https://boa.<GLOBAL_IP>.sslip.io`, with a Google-managed TLS cert auto-provisioned. `sslip.io` resolves any `<ip>.sslip.io` to that IP, so you need no DNS zone.
- **Bank of Anthos v0.6.7** — 9 microservices (Python + Java), two PostgreSQL databases, and a load generator producing constant traffic so the mesh dashboards have live data immediately.

## The part that makes multi-cluster click: where the data lives

Here's the design decision worth internalizing, because it's the whole shape of an active-active topology.

**The databases live on the primary cluster only.** The `accounts-db` and `ledger-db` PostgreSQL StatefulSets are deployed *only* on `gke-cluster-1`. Every other cluster runs the stateless services plus the database *Services* and *ConfigMaps* — but not the database pods. Those non-primary clusters reach the primary's databases across the fleet via Multi-Cluster Services.

You can see it directly. Set up a context per cluster first:

```bash
export PROJECT="<your-project-id>"
export REGION1="us-west1"   # available_regions[0] — primary/config cluster
export REGION2="us-east1"

gcloud container clusters get-credentials gke-cluster-1 --region "$REGION1" --project "$PROJECT"
gcloud container clusters get-credentials gke-cluster-2 --region "$REGION2" --project "$PROJECT"
kubectl config rename-context "gke_${PROJECT}_${REGION1}_gke-cluster-1" cluster1
kubectl config rename-context "gke_${PROJECT}_${REGION2}_gke-cluster-2" cluster2
```

Now compare the two clusters:

```bash
kubectl --context cluster1 get deploy,statefulset,svc -n bank-of-anthos
kubectl --context cluster2 get deploy,statefulset,svc -n bank-of-anthos   # note: no DB StatefulSets here
```

`cluster1` has the `accounts-db` and `ledger-db` StatefulSets. `cluster2` doesn't — just the stateless services and the DB Services that resolve back to the primary across the fleet. That asymmetry *is* the lesson: stateless services go everywhere, the data tier stays put.

## Confirm the mesh is multi-primary

Each app pod runs `2/2` (app + Envoy sidecar) on every cluster, because the `bank-of-anthos` namespace carries `istio.io/rev=asm-managed` everywhere:

```bash
kubectl --context cluster1 get pods -n bank-of-anthos
kubectl --context cluster2 get pods -n bank-of-anthos
gcloud container fleet mesh describe --project "$PROJECT"   # per-membership control/data plane state
```

Want proof the clusters actually share a trust domain? Pull the SPIFFE identity out of a sidecar cert:

```bash
POD=$(kubectl --context cluster1 get pod -n bank-of-anthos -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl --context cluster1 exec "$POD" -n bank-of-anthos -c istio-proxy -- \
  cat /var/run/secrets/workload-spiffe-credentials/certificates.pem \
  | openssl x509 -noout -text | grep -E "URI:"
```

## Deploying it

The module ships in the RAD Lab catalog. Non-interactively via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m MC_Bank_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/MC_Bank_GKE
tofu init
tofu apply -var="project_id=my-gcp-project"
```

**Heads-up: first deploys take 40–60 minutes, by design.** Creating multiple clusters, registering the fleet (the module polls until every membership reaches `READY`, up to ~10 minutes), provisioning the managed mesh per membership, then bringing up the global load balancer with a managed certificate is inherently slow. The ordering is the module doing the hard happens-before relationships so you don't have to.

## Find the global IP and poke at it

The public address isn't a Terraform output — pull it from the reserved global address or the MultiClusterIngress status:

```bash
gcloud compute addresses list --global --project "$PROJECT" --filter="name~bank"
kubectl --context cluster1 get multiclusteringress -n bank-of-anthos
```

Then browse to `https://boa.<GLOBAL_IP>.sslip.io`. Check the managed cert status while you wait:

```bash
kubectl --context cluster1 get managedcertificate -n bank-of-anthos \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.certificateStatus}{"\n"}{end}'
```

And confirm each cluster's NEG is a healthy backend behind the one global LB:

```bash
BACKEND=$(gcloud compute backend-services list --global --project "$PROJECT" \
  --filter="name~bank-of-anthos" --format="value(name)" | head -1)
gcloud compute backend-services get-health "$BACKEND" --global --project "$PROJECT"
```

The Service Mesh view in the Console (Kubernetes Engine → Service Mesh) shows the combined topology and mTLS status across *both* clusters at once.

## Things worth knowing before you rely on it

This is an **education and demo** module, not a production banking system. Honest edges:

- **Losing the primary region takes the data tier offline.** Because `accounts-db` and `ledger-db` run only on `cluster1`, scaling the primary to zero or losing its region affects every cluster's data. The stateless frontends on other clusters stay reachable through the global LB, but they depend on the primary for data. That's a known limitation of this topology, not a bug — true active-active *data* is a much harder problem the module deliberately doesn't pretend to solve.
- **The managed certificate provisions asynchronously** and can take 10–60 minutes to go `Active`. Until then, `https://boa.<IP>.sslip.io` may show TLS warnings. That's expected during provisioning, not a deploy failure.
- **`cluster_size = 1` defeats the point.** Minimum 2 for a meaningful demo — with one cluster there's no multi-cluster ingress, no mesh span, no failover.
- **Use ≥ 2 distinct regions.** A single region in `available_regions` removes the geo-redundancy the whole module exists to show; all clusters share one failure domain.
- **Don't change `deployment_id` after first deploy** — it forces recreation of named resources (VPC, clusters) and destroys running state.

## Why it's a great thing to deploy

If you've wanted to *understand* fleets, multi-primary mesh, MCS, and global load balancing — not just read about them — this is one of the fastest ways to get a real, multi-region, mTLS-encrypted system in front of you that you can break, inspect, and fail over. The hard parts (fleet registration ordering, per-cluster mesh readiness, cross-cluster discovery, global LB wiring) are handled, so you spend your time on the concepts.

Deploy it, diff `cluster1` against `cluster2`, watch the data tier live only on the primary, then open the global LB and see two regional NEGs behind one anycast IP. That's the moment multi-cluster stops being abstract.

👉 **MC_Bank_GKE** lives in the RAD Lab modules catalog. Grab it, deploy it, and explore the [module deep-dive](../../modules/MC_Bank_GKE.md) and the [hands-on lab guide](../../labs/MC_Bank_GKE.md).
