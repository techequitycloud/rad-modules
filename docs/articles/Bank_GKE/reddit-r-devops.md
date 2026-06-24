<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that deploys Bank of Anthos + managed mesh; spark discussion, link the module.
-->

# A reference module that deploys Bank of Anthos on GKE with a *managed* service mesh — mTLS everywhere, SLO per service, no istiod to babysit

Sharing this because every time service mesh comes up here it turns into "is it worth the operational cost," and this is a decent way to actually try one without signing up to operate the control plane. Not selling anything — it's an educational OSS module in the RAD Lab catalog. Writeup + honest gotchas below.

**What it does**

One `tofu apply` stands up:

- GKE **Autopilot** cluster (or Standard with a 2-node Spot pool if you flip a var)
- Dedicated VPC, subnet w/ VPC-native secondary ranges, Cloud Router + NAT, firewall rules
- **Cloud Service Mesh** (Google-managed Istio) enabled as a *fleet feature* with `MANAGEMENT_AUTOMATIC` — control plane runs on Google's side, **no `istiod` in your cluster**
- **Bank of Anthos** v0.6.7 — 9 microservices (Python + Java), 2 Postgres StatefulSets, a load generator
- Per-workload Cloud Monitoring service + SLO, Managed Prometheus, Cloud Trace from the sidecars

**The mesh part that's actually nice**

Namespace gets labeled `istio.io/rev=asm-managed`, injection is automatic, every pod comes up `2/2` (app + envoy), all in-namespace traffic is mTLS. You don't install or upgrade a control plane. That's the whole pitch and it mostly delivers — the operational tax of mesh is the part it removes.

```
kubectl get pods -n bank-of-anthos   # everything 2/2
gcloud container fleet mesh describe --project "$PROJECT"
```

**Gotchas / things I'd want to know first**

- **First deploy is ~30–45 min.** It's deliberately mesh-first: registers fleet membership, enables the mesh feature, then *polls until membership + control plane are ACTIVE* before deploying the app. Slow, but it's avoiding the classic "pods come up before injection is ready → no sidecars" race. I'd rather it wait.
- **Frontend is plain HTTP on a public LoadBalancer IP.** Internal traffic is mTLS; the front door is not. It reserves a static IP and enables Gateway API but does NOT wire up HTTPS/cert/domain/IAP. That's on you. Fine for a demo, don't expose it as-is.
- **Fleet membership is a hard prereq for the mesh feature** — worth understanding because it's also how the multi-cluster story works later. Not optional.
- **Deploying into a trial/lab project?** The Anthos/Fleet/mesh API family can require accepting the Cloud ToS first, and the deploying identity needs `roles/owner`. If an apply face-plants early on `serviceusage`/API enablement with a 390003 error, that's the ToS, not the module. Burned time on this; flagging it.
- **`enable_config_management` is currently a no-op** (inputs exist, nothing wired). Leave it off.
- **Databases are ephemeral**, deleted with the cluster. It's a demo bank, not a bank.

**Why bother**

It's the least painful way I've found to get a *realistic* meshed system (polyglot, multiple stateful backends, cross-service JWT auth, constant traffic from the loadgen) in front of you to break and inspect — topology graph, traces, and a real SLO framework included. Good for learning mesh/fleet/SRE concepts, demos, or evaluating whether managed mesh changes your build-vs-operate math.

Curious what folks here think about managed mesh vs self-hosted Istio for the mTLS-between-services problem specifically — is offloading the control plane lifecycle worth the lock-in, or do you'd rather keep istiod in-cluster? And anyone running CSM at multi-cluster scale, does the fleet-feature model hold up?

Module + docs (deep-dive and a step-by-step lab) are in the RAD Lab `rad-modules` repo under `Bank_GKE`.
