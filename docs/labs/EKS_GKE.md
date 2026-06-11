# AWS EKS attached to a Google Cloud Fleet — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/EKS_GKE)**

## Overview

**Estimated time:** 45–90 minutes

This module provisions a complete Amazon EKS cluster on AWS and registers it with Google Cloud as a **GKE Attached Cluster** — a member of a Google Cloud Fleet. Once attached, the EKS cluster shows up in the Google Cloud console next to any native GKE clusters, can be reached with `kubectl` through the **Connect gateway** using your Google identity (no AWS credentials), and streams its logs and metrics into Cloud Logging and Cloud Monitoring.

This lab walks the full operational lifecycle of the module: deploy it, access and verify it, run it day-to-day, observe it, diagnose common problems, and tear it down. It focuses on operating the **module and the two cloud platforms** rather than on Kubernetes itself. For the complete list of provisioned services and every configuration input (organised by group), see the [Configuration Guide](https://docs.radmodules.dev/docs/modules/EKS_GKE) — this lab deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate what it provisions on both AWS and Google Cloud.
- Confirm the EKS cluster is registered in the Fleet and reach it through the Connect gateway.
- Perform day-2 operations — inspect the cluster, scale the node group, upgrade versions, and grant access.
- Observe the EKS cluster with Cloud Logging and Cloud Monitoring.
- Diagnose and resolve the most common deployment and runtime issues.
- Tear the deployment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled**.
- An **AWS account** and an IAM user/role permitted to create VPC, EKS, EC2, and IAM resources. Have its **Access Key ID** and **Secret Access Key** ready — both are required module inputs.
- **gcloud CLI**, **kubectl**, and the **`aws` CLI** installed; `gcloud auth login` and `gcloud auth application-default login` completed.
- **Project Owner** (or equivalent) IAM on the Google Cloud project.
- **RAD platform access** with permission to deploy modules into the project.

Set these shell variables once; every task below reuses them:

```bash
export PROJECT="<your-gcp-project-id>"
export GCP_REGION="us-central1"        # Fleet location (gcp_location)
export AWS_REGION="us-west-2"          # AWS region for EKS (aws_region)
export CLUSTER_NAME="aws-eks-cluster"  # equals cluster_name_prefix
gcloud config set project "$PROJECT"
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **AWS EKS on GKE Fleet (EKS_GKE)** from the **Platform Modules** list to start configuration, and set the required inputs:
   - `project_id` — your Google Cloud project
   - `aws_access_key` and `aws_secret_key` — your AWS credentials (stored sensitively)
   - optionally `trusted_users` — Google emails to grant cluster-admin

   Configure only what you need — the [Configuration Guide](https://docs.radmodules.dev/docs/modules/EKS_GKE) documents every input by group, with defaults. Review the estimated cost (if credits are enabled) and click **Deploy**, which opens the deployment status page with real-time logs.

2. The platform enables the required Google Cloud APIs, creates the AWS VPC and subnets across three Availability Zones, the IAM roles, the EKS cluster and its managed node group, installs the Connect Agent into the cluster, and finally registers it as a GKE Attached Cluster in the Fleet. Deploys typically take **20–30 minutes** (EKS cluster creation dominates).

3. Once it completes, configure `kubectl` through the Connect gateway — no AWS credentials needed:

   ```bash
   gcloud container attached clusters get-credentials "$CLUSTER_NAME" \
     --location "$GCP_REGION" --project "$PROJECT"
   kubectl get nodes -o wide
   ```

---

## Task 2 — Access & verify [Manual]

1. **Confirm Fleet registration** on the Google Cloud side:

   ```bash
   gcloud container attached clusters list --location=- --project "$PROJECT"
   gcloud container fleet memberships list --project "$PROJECT"
   ```

   In the console, Kubernetes Engine → Clusters shows the cluster with **Type = Attached** and distribution **EKS**.

2. **Reach the cluster through the Connect gateway** and confirm your admin access:

   ```bash
   kubectl cluster-info        # control plane URL is connectgateway.googleapis.com/...
   kubectl get pods -A
   kubectl auth can-i '*' '*' --all-namespaces   # expect: yes
   ```

3. **Cross-check the EKS side in AWS:**

   ```bash
   aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
     --query 'cluster.{name:name,status:status,version:version}' --output table
   ```

4. **Confirm the Connect Agent is connected** (outbound channel healthy):

   ```bash
   kubectl get pods -n gke-connect
   ```

---

## Task 3 — Operate (Day-2) [Manual]

1. **Inspect the cluster and node group:**

   ```bash
   kubectl get nodes --label-columns topology.kubernetes.io/zone
   aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" \
     --nodegroup-name "${CLUSTER_NAME}-node-group" --region "$AWS_REGION" \
     --query 'nodegroup.scalingConfig'
   ```

2. **Scale the node group** by changing the min/desired/max instance inputs and clicking **Update** on the deployment details page — the module owns the node-group spec, so scaling is a configuration change, not a manual AWS edit (a manual change would be reverted on the next apply). Note that scale-out beyond the desired count needs a cluster autoscaler, which this module does not install.

3. **Upgrade the Kubernetes version** by changing **both** `k8s_version` and `platform_version` to matching values in the same **Update** — Google Cloud rejects a mismatch at registration.

4. **Grant a colleague access** (two layers — Google Cloud IAM for gateway traversal, plus Kubernetes RBAC for what they may do):

   ```bash
   gcloud projects add-iam-policy-binding "$PROJECT" \
     --member="user:colleague@example.com" --role="roles/gkehub.gatewayReader"
   kubectl create clusterrolebinding colleague-view \
     --clusterrole=view --user="colleague@example.com"
   ```

   For cluster-admin access, add the colleague to `trusted_users` and **Update** instead.

---

## Task 4 — Observe [Manual]

1. **Logs** — system-component and workload logs flow to Cloud Logging via the Connect Agent:

   ```bash
   gcloud logging read \
     'resource.type="k8s_container" resource.labels.cluster_name="'"$CLUSTER_NAME"'"' \
     --project "$PROJECT" --limit 20
   ```

   Or open Logging → Logs Explorer and select resource **Kubernetes Cluster** → your cluster.

2. **Metrics** — Managed Prometheus collection is enabled on the attached cluster. Open Monitoring → Dashboards → **GKE** and select the cluster, or run `kubectl top nodes` through the gateway. The same Kubernetes-aware dashboards used for native GKE apply to the attached EKS cluster.

---

## Task 5 — Troubleshoot [Manual]

Durable techniques for the failure modes you are most likely to hit. These are platform-level diagnostics and do not change with module releases.

- **Cluster created on AWS but not in the Fleet:** almost always a `k8s_version` / `platform_version` mismatch. Check `gcloud container attached get-server-config --location "$GCP_REGION"` for valid platform versions and re-deploy with matching minors.
- **Connect Agent not connected / `kubectl` via gateway fails:** confirm the agent pods are running and the cluster has outbound egress to Google Cloud:
  ```bash
  kubectl get pods -n gke-connect
  ```
  In private-subnet mode this depends on the NAT Gateway; in public-subnet mode on the Internet Gateway.
- **Locked out via the gateway:** confirm your email is in the cluster's admin list (the deployer is always added; others need `trusted_users` or an RBAC binding) and that you hold a `roles/gkehub.gateway*` IAM role.
- **API-not-enabled errors during deploy:** the required Google Cloud APIs can take time to propagate; re-apply after a short wait.
- **Subnet/VPC creation errors:** check that `subnet_availability_zones` count matches the CIDR lists and that the AZs belong to `aws_region`.
- **Audit who accessed the cluster:**
  ```bash
  gcloud logging read \
    'protoPayload.serviceName="connectgateway.googleapis.com"' \
    --project "$PROJECT" --limit 20
  ```

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**). Delete runs `terraform destroy` and is irreversible (the deployment record is retained for history). Teardown uninstalls the Connect Agent from EKS, removes the Fleet registration, then deletes the EKS node group and cluster and the AWS VPC and IAM roles. The Google Cloud APIs enabled by the module are intentionally left in place so other workloads are not disrupted.

> Teardown needs the same network path to the EKS API server that deployment had (to uninstall the Connect Agent). If the cluster is no longer reachable, destroy can stall.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual changes that conflict with state), use **Purge** instead — it removes the deployment from RAD's records **without** destroying the cloud resources (it makes RAD forget the deployment). After a Purge you must clean up the AWS and Google Cloud resources yourself.

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module creates the AWS VPC, IAM, EKS cluster + node group, and registers it in the Google Cloud Fleet |
| 2 — Access & verify | Manual | Cluster registered as Attached; reachable via Connect gateway with cluster-admin |
| 3 — Operate | Manual | Inspect the cluster, scale the node group, upgrade versions, grant access |
| 4 — Observe | Manual | Query EKS logs in Cloud Logging; review metrics in Cloud Monitoring / Managed Prometheus |
| 5 — Troubleshoot | Manual | Diagnose version-mismatch, Connect Agent, access, API-propagation, and subnet issues |
| 6 — Tear down | Automated | Delete (Trash) destroys all module resources; Purge removes from RAD without destroying |
