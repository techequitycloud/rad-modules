<!--
Target:   Dev.to
Audience: Developers and platform engineers running Kubernetes on AWS, curious about managing it from Google Cloud
Voice:    Hands-on, conversational, practical, real commands, show-don't-tell
Tags:     #googlecloud #aws #eks #gke #kubernetes #multicloud #devops
Goal:     Show that running kubectl against an AWS EKS cluster with a Google identity is real and approachable; CTA to deploy the EKS_GKE RAD module.
-->

# Run `kubectl` Against an AWS EKS Cluster Using Your Google Identity — No AWS Keys, No VPN

Here's a thing that sounds like it shouldn't work: open Google Cloud Console, click into Kubernetes Engine, and see an **Amazon EKS** cluster sitting in the list next to your native GKE clusters. Then run `kubectl get nodes` against it from your laptop — authenticated with your Google account, no AWS credentials anywhere in the path, no bastion, no VPN.

That's what the **EKS_GKE** RAD module sets up. It provisions a real EKS cluster on AWS and registers it with Google Cloud as a **GKE Attached Cluster** — a member of a Google Cloud Fleet. The cluster keeps running entirely on AWS. Google Cloud just gains a management channel into it. You don't migrate the workload; you put a single pane of glass over it.

It's a standalone, educational module: one GCP project plus a set of AWS credentials, and you get the whole AWS-side cluster *and* its Fleet registration. Let's look at what actually lands and how to drive it.

## What you get

Two clouds' worth of resources, wired together:

**On AWS:**
- A real **Amazon EKS** cluster — the control plane is managed by AWS, not Google.
- A **managed node group** of EC2 workers (default 2, min 2, max 5) spread across three Availability Zones.
- A dedicated **VPC** (`10.0.0.0/16` by default) with subnets in three AZs, plus either an Internet Gateway (public-subnet mode) or a NAT Gateway with an Elastic IP (private-subnet mode).
- Two **IAM roles** — one assumed by the EKS service for the control plane, one assumed by the EC2 worker nodes (carrying the worker, CNI, and ECR-read-only managed policies).

**On Google Cloud:**
- The EKS cluster registered as a **GKE Attached Cluster** with distribution `eks` — it shows up as type **Attached** in the console.
- **Fleet (GKE Hub) membership**, which is the unlock for fleet-wide features (Policy Controller, Config Management, multi-cluster services, Cloud Service Mesh) and for Connect-gateway access.
- **Cloud Logging** receiving the cluster's `SYSTEM_COMPONENTS` and `WORKLOADS` logs — no log agent for you to run on AWS.
- **Cloud Monitoring + Managed Service for Prometheus** collecting metrics, surfacing in the same GKE dashboards you'd use for a native cluster.

The whole point: the workload never leaves AWS, but you operate it with Google Cloud's tooling, identity model, and observability.

## The trick that makes it work: an outbound-only agent

The piece that makes the single-pane-of-glass real is the **Connect Agent**. The module installs it into the EKS cluster (delivered as a Helm-managed install manifest fetched from Google Cloud), and the agent dials *out* to Google Cloud on port 443.

That direction matters. There are **no inbound AWS firewall rules to open** — Google isn't reaching into your VPC, your cluster is reaching out. This is exactly why it works the same whether your nodes are in public subnets or private ones behind a NAT Gateway.

On top of that sits **OIDC trust**. Each EKS cluster runs its own OIDC provider. The module registers that issuer URL with Google Cloud, so tokens issued by EKS can be verified by Google Cloud without static keys ever crossing between clouds — the same federated trust model native GKE uses for Workload Identity.

## Deploying it

The module ships in the RAD Lab catalog. Because it touches AWS, you supply **AWS credentials via the module's sensitive inputs** — never hardcoded in the repo. The provider reads `aws_access_key` / `aws_secret_key`, and these are stored sensitively and never printed to logs. (Standard `AWS_*` environment variables are the idiomatic way to feed AWS creds to a Terraform AWS provider — keep them out of version control.)

Non-interactively via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m EKS_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/EKS_GKE
tofu init
tofu apply \
  -var="project_id=my-gcp-project" \
  -var="aws_region=us-west-2" \
  -var="gcp_location=us-central1" \
  -var="k8s_version=1.34" \
  -var="platform_version=1.34.0-gke.1" \
  -var="aws_access_key=$AWS_ACCESS_KEY_ID" \
  -var="aws_secret_key=$AWS_SECRET_ACCESS_KEY"
```

The apply order is: enable the Google Cloud APIs, build the AWS VPC and routing, create the IAM roles, create the EKS cluster and node group, install the Connect Agent, then register the cluster as an Attached Cluster (passing the OIDC issuer URL, the Fleet project, logging/monitoring config, and the admin-user list).

## Get a kubeconfig and poke at it

Here's the payoff command. Grab credentials through the Connect gateway — **no AWS credentials needed**:

```bash
export PROJECT=my-gcp-project
export GCP_REGION=us-central1
export CLUSTER_NAME=aws-eks-cluster   # = your cluster_name_prefix

gcloud container attached clusters get-credentials "$CLUSTER_NAME" \
  --location "$GCP_REGION" --project "$PROJECT"
```

Now plain `kubectl` works against EKS, proxied through the Connect Agent using your Google identity:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl top nodes        # metrics via the gateway
```

Confirm it's really registered on the Google side:

```bash
gcloud container attached clusters list --location=- --project "$PROJECT"
gcloud container fleet memberships list --project "$PROJECT"
```

And confirm the EKS cluster is exactly what you think it is, on the AWS side:

```bash
aws eks describe-cluster --name "$CLUSTER_NAME" --region us-west-2
aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "${CLUSTER_NAME}-node-group" --region us-west-2
```

Then go look at what the Fleet gives you for free: **Logging → Logs Explorer** (resource type *Kubernetes Cluster*, your cluster) shows EKS logs flowing into Cloud Logging, and **Monitoring → Dashboards → GKE** shows EKS metrics in the same panes as native GKE.

## Who gets access — and how you add people

The Google identity that runs the deploy is automatically granted Kubernetes `cluster-admin`. Anyone you list in `trusted_users` (must be real, unique, non-blank Google emails) gets the same.

Adding *more* people later takes **two layers**, which trips people up:

1. A Google Cloud IAM role for traversing the gateway (e.g. `roles/gkehub.gatewayReader` or `gatewayEditor`).
2. A Kubernetes RBAC binding for what they can actually do once they're through.

One without the other doesn't work. The IAM role gets them to the door; RBAC decides what's behind it.

## Things worth knowing before you rely on it

This is an **education and demo** module, not a production multi-cloud platform. The honest edges:

- **Two clouds, two bills.** AWS charges for the EKS control plane, the EC2 workers, and (in private-subnet mode) the NAT Gateway plus data transfer. Google Cloud charges for Fleet, logging, and monitoring.
- **`k8s_version` and `platform_version` must match.** The EKS minor (`k8s_version=1.34`) and the GKE Attached Clusters platform version (`platform_version=1.34.0-gke.1`) have to correspond. Google validates this at registration — mismatch it and your EKS cluster gets built on AWS but **never attaches to the Fleet**. Use `gcloud container attached get-server-config --location "$GCP_REGION"` to see valid platform versions.
- **The Fleet/console name is exactly `cluster_name_prefix`.** AWS resources get a random suffix too, but the attached-cluster registration and Fleet membership use the prefix *verbatim*. Two deployments sharing a prefix in the same project will collide on the Google side. Keep it unique.
- **`node_group_max_size` is just a ceiling.** Raising it does nothing on its own — actual scale-out beyond the desired count needs a cluster autoscaler, which this module does **not** install.
- **Teardown needs the same network path as deploy.** Destroy has to reach the EKS API server to uninstall the Connect Agent. If the cluster is unreachable, teardown stalls.
- **No managed database, storage, or secrets.** Unlike the application modules, this provisions only the cluster, its networking, and the Fleet registration. Bring your own workloads.
- **Upgrading means bumping both versions together.** One deploy, matching `k8s_version` and `platform_version`.

## Why it's a great thing to deploy

If you want to actually *understand* multi-cloud Kubernetes management — not read about it — this is one of the fastest ways to get a real AWS EKS cluster under Google Cloud's management plane in front of you. The hard parts (OIDC federation, the outbound Connect Agent, the two-layer gateway access model, version pinning) are handled, so you can spend your time on the concept: a workload that lives on AWS, operated from Google Cloud.

Deploy it, run `gcloud container attached clusters get-credentials`, then `kubectl get nodes`, and watch an AWS cluster answer to your Google login. That's the moment multi-cloud management stops being a slide.

👉 **EKS_GKE** lives in the RAD Lab modules catalog. Grab it, deploy it, and explore the [module deep-dive](../../modules/EKS_GKE.md) and the [hands-on lab guide](../../labs/EKS_GKE.md).
