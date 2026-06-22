<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that attaches AWS EKS to a Google Cloud Fleet; spark discussion, link the module.
-->

# A reference module that registers an AWS EKS cluster into a Google Cloud Fleet — manage EKS from the GCP console, no AWS keys for kubectl, no VPN

Sharing this because the "should we be multi-cloud" debate here almost always assumes multi-cloud = migration, and this is a clean way to try the *other* version: leave the cluster on AWS, attach it to Google Cloud's fleet, and operate it from there. Not selling anything — it's an educational OSS module in the RAD Lab catalog. Writeup + honest gotchas below.

**What it does**

One `tofu apply` provisions, across two clouds:

- A real **Amazon EKS** cluster on AWS — control plane stays AWS-managed
- A **managed node group** (2 desired / 2 min / 5 max EC2 workers) across 3 AZs
- A dedicated **VPC** (10.0.0.0/16), public subnets behind an IGW by default, or private subnets behind a NAT Gateway if you flip `enable_public_subnets=false`
- Two **IAM roles** (EKS control plane + worker nodes, with the worker/CNI/ECR-read-only managed policies)
- Registration of that EKS cluster as a **GKE Attached Cluster** (distribution `eks`) — it shows up as type **Attached** in the GCP console next to native GKE clusters
- **Fleet (GKE Hub) membership**, plus `SYSTEM_COMPONENTS`/`WORKLOADS` logs to Cloud Logging and Managed Prometheus metrics to Cloud Monitoring

**The part that's actually nice**

A **Connect Agent** (Helm install manifest pulled from Google) gets installed in the cluster and dials *out* to Google on 443. So:

- **No inbound AWS firewall rules.** Works the same in public or private subnets.
- `kubectl` against EKS uses your **Google identity** through the Connect gateway — no AWS keys, no VPN, no bastion.
- OIDC trust: each EKS cluster's own OIDC issuer is registered with GCP, so no static keys cross between clouds. Same model as GKE Workload Identity.

```
gcloud container attached clusters get-credentials "$NAME" --location "$GCP_REGION" --project "$PROJECT"
kubectl get nodes -o wide        # AWS nodes, Google login
gcloud container attached clusters list --location=- --project "$PROJECT"
```

**Gotchas / things I'd want to know first**

- **`k8s_version` and `platform_version` MUST match.** EKS minor (e.g. `1.34`) and the GKE Attached Clusters version (e.g. `1.34.0-gke.1`) have to correspond — GCP validates at registration. Mismatch = EKS cluster builds on AWS but never attaches. `gcloud container attached get-server-config --location "$GCP_REGION"` lists valid platform versions.
- **The Fleet/console name is `cluster_name_prefix` verbatim.** AWS resources get a random suffix, the attachment doesn't. Two deploys sharing a prefix in the same project collide on the GCP side. Keep it unique.
- **`node_group_max_size` is just a ceiling.** Nothing scales out past desired unless you install a cluster autoscaler — this module doesn't. Raising the max alone does nothing.
- **Adding access later is two layers.** A GCP IAM role for gateway traversal (`roles/gkehub.gatewayReader`/`gatewayEditor`) AND a k8s RBAC binding. Deployer + `trusted_users` get `cluster-admin` automatically; everyone else needs both layers or they're locked out.
- **Teardown needs the same network path as deploy** — destroy has to reach the EKS API server to uninstall the Connect Agent. If the cluster's unreachable, teardown stalls.
- **Two clouds, two bills.** AWS for the EKS control plane + EC2 + (private mode) NAT Gateway; GCP for fleet/logging/monitoring. Enabled GCP APIs are intentionally NOT disabled on teardown so you don't break other workloads in the project.
- **Provisioning needs AWS creds** (`aws_access_key`/`aws_secret_key`, sensitive, never in logs) — those are build-time only, idiomatically fed via `AWS_*` env vars, not a runtime bridge. Don't commit them.
- **No app, no DB, no autoscaler, no fleet features deployed for you.** It registers + observes the cluster. Policy Controller / Config Management / CSM are yours to enable from Feature Manager afterward.

**Why bother**

It's the least painful way I've found to actually *see* the attach-don't-migrate pattern: a real EKS cluster that never leaves AWS, operated from GCP — single console, single identity model, logs and metrics in the same pane as native GKE. Good for learning multi-cloud fleet/Connect-gateway concepts, demos, or evaluating whether unified management is worth it before committing to anything.

Curious what folks here think: for an AWS-first shop, is attaching EKS to a GCP fleet for unified management/observability actually worth it, or is it just adding a second control plane's quirks on top of EKS? And for anyone running attached clusters in anger — does the Connect-gateway access model (IAM + RBAC, two layers) hold up day-to-day, or does it get annoying fast?

Module + docs (deep-dive and a step-by-step lab) are in the RAD Lab `rad-modules` repo under `EKS_GKE`.
