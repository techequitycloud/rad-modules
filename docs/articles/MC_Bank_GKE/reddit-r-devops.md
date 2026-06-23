<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that deploys Bank of Anthos active-active across two regions; spark discussion, link the module.
-->

# A reference module that deploys Bank of Anthos active-active across 2 GKE regions — fleet-wide mesh, multi-cluster ingress, one global IP, single-primary DB (and it's honest about that)

Sharing this because "active-active multi-region k8s" comes up here a lot and it's usually either hand-waved or a giant DIY plumbing exercise. This is a decent way to actually stand one up and poke at it without assembling the fleet/mesh/global-LB glue yourself. Not selling anything — educational OSS module in the RAD Lab catalog. Writeup + honest gotchas below.

**What it does**

One `tofu apply` (or the launcher) stands up, from a single config:

- **2 GKE Autopilot clusters in 2 regions** (defaults: `gke-cluster-1`/us-west1, `gke-cluster-2`/us-east1). Names are 1-indexed; `cluster1` is always the primary/config cluster.
- A **GKE Fleet** with both clusters registered as memberships
- **Fleet-wide multi-primary Cloud Service Mesh** (managed Istio, automatic management) — all clusters share one trust domain, so cross-cluster traffic is mutually authenticated
- **Multi-Cluster Services (MCS)** for cross-cluster service backends + **Multi-Cluster Ingress (MCI)** for a global external LB
- **Bank of Anthos** v0.6.7 — 9 microservices (Python + Java), 2 Postgres DBs, load generator
- One **global anycast IP**, app published at `https://boa.<GLOBAL_IP>.sslip.io` with an auto-provisioned Google-managed cert (no DNS zone needed — sslip.io resolves the IP)

**The part that's actually interesting**

The databases run on the **primary cluster only**. `accounts-db` / `ledger-db` StatefulSets are deployed just on `cluster1`. Non-primary clusters get the stateless services + the DB Services/ConfigMaps (so pods can resolve them) but not the DB pods — they reach the primary's databases across the fleet via MCS. So the stateless tier is genuinely active-active, the data tier is single-primary. You can see it directly:

```
kubectl --context cluster1 get statefulset -n bank-of-anthos   # accounts-db, ledger-db
kubectl --context cluster2 get statefulset -n bank-of-anthos   # none
gcloud container fleet mesh describe --project "$PROJECT"
```

**Gotchas / things I'd want to know first**

- **Single-primary data tier is the big caveat.** Lose the primary region (or scale it to zero) and the data tier goes offline for *every* cluster — the stateless frontends elsewhere stay reachable via the global LB but have no data. The module is upfront that it shows active-active *serving*, not active-active *data*. If you need real cross-region data, that's on you (Cloud SQL replicas / distributed DB / etc). Honestly I appreciated that it didn't pretend.
- **First deploy is 40–60 min.** Multiple clusters + fleet registration (polls until every membership is READY, ~10 min) + per-cluster managed mesh + global LB with a managed cert. Slow, but it's doing the ordering correctly. Don't assume a stall.
- **Managed cert takes 10–60 min to go Active.** HTTPS will warn/fail until then. Expected, not a deploy error.
- **`cluster_size = 1` defeats the purpose** — no MCI, no mesh span, no failover. Min 2. Likewise use ≥ 2 *distinct* regions or you've just got one failure domain.
- **Don't change `deployment_id` after first deploy** — forces recreation of VPC/clusters and nukes state.
- **The public URL isn't a TF output.** Pull it from the global address (`gcloud compute addresses list --global --filter="name~bank"`) or the MultiClusterIngress status.

**Why bother**

It's the least painful way I've found to get a *realistic* active-active multi-region system (polyglot services, single-primary DB reached cross-cluster, constant loadgen traffic) in front of you to break and inspect — combined mesh topology across clusters, global LB with per-region NEG health, the works. Good for learning fleet/MCS/MCI/multi-primary-mesh concepts, demos, or pressure-testing your mental model of where data lives in "active-active."

Genuinely curious what folks here think: for the cross-region *data* problem specifically, what are you actually running in prod — Cloud SQL cross-region replicas, a distributed DB like Spanner/Cockroach, app-level sharding by region? And does the single-global-IP + per-cluster-NEG failover model hold up for you at more than 2 regions, or do you end up reaching for traffic policies (VirtualService/DestinationRule) for locality routing?

Module + docs (deep-dive and a step-by-step lab) are in the RAD Lab `rad-modules` repo under `MC_Bank_GKE`.
