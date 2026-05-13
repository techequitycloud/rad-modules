# EKS Attached Clusters — Lab Guide

## Overview

This guide walks through the full EKS Attached Clusters lab using the
`EKS_GKE` Terraform module. The module automates all AWS and Google Cloud
infrastructure setup, including creating an EKS cluster and registering it as
a GKE Attached Cluster in a Google Cloud Fleet. Exploration, observability
verification, and workload operations are performed manually against the running
cluster.

**Estimated time:** 45–75 minutes (includes ~20–30 minutes of background
provisioning)

### What Terraform Automates

- Enabling required GCP APIs (GKE Hub, GKE Multi-Cloud, Connect Gateway,
  Anthos, Managed Prometheus, and others)
- Creating an AWS VPC with DNS support enabled
- Creating public subnets (or private subnets with a NAT Gateway) across three
  availability zones
- Creating an Internet Gateway and route tables
- Creating AWS IAM roles for the EKS cluster control plane and worker nodes
  (with `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`,
  `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly`)
- Creating the EKS cluster and a managed node group
- Fetching the GKE Attached Clusters bootstrap install manifest and applying it
  to the EKS cluster via Helm
- Registering the EKS cluster as an Attached Cluster in GKE Hub
- Joining the cluster to the Google Cloud Fleet
- Enabling Cloud Logging for system components and workloads
- Enabling Managed Prometheus for cluster metrics
- Granting cluster-admin access to the specified trusted users

### What You Do Manually

- Configuring `kubectl` to reach the cluster via the Connect Gateway
- Exploring the cluster in the Google Cloud console (GKE Hub, Fleet, Logging,
  Monitoring)
- Deploying a sample workload and verifying it from the command line
- Inspecting centralized logs and Managed Prometheus metrics
- Exploring fleet membership status and access control settings
- Reviewing available platform versions and understanding the upgrade path
- Tearing down all resources with `tofu destroy`

---

## REST API Overview

Every action in this lab can be performed via the GKE Multi-Cloud REST API
(`gkemulticloud.googleapis.com/v1`) as an alternative to the Cloud Console UI
or `gcloud` CLI. API equivalents are shown after each relevant step.

**Base URL:** `https://gkemulticloud.googleapis.com/v1`

**Set these shell variables once before running any API command:**

```bash
export TOKEN=$(gcloud auth print-access-token)
export BASE="https://gkemulticloud.googleapis.com/v1"
export PROJECT="your-project-id"
export LOCATION="us-central1"
export CLUSTER="aws-eks-cluster"
```

**All mutating operations return a long-running Operation. Poll for
completion:**

```bash
curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/operations/OPERATION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.done, .error'
```

`done: true` with no `error` means the operation succeeded.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| AWS CLI | Installed and configured (used for initial `kubeconfig` generation) |
| `kubectl` | Any recent version; used to interact with the cluster |
| `helm` | v3.x; used internally by the module to apply the bootstrap manifest |
| GCP Project | Must already exist with billing enabled |
| GCP Service Account | Must hold `roles/owner` on the target project |
| AWS IAM User / Role | Must have permissions to create EKS clusters, VPCs, IAM roles, and subnets |
| AWS Access Key & Secret | Required inputs to the module; stored as sensitive values |

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/EKS_GKE
```

Create a `terraform.tfvars` file with the following inputs. All values shown
are the module defaults — override only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `existing_project_id` | *(required — no default)* | GCP project ID where the EKS cluster will be registered |
| `aws_access_key` | *(required — no default)* | AWS Access Key ID (sensitive) |
| `aws_secret_key` | *(required — no default)* | AWS Secret Access Key (sensitive) |
| `aws_region` | `us-west-2` | AWS region for EKS cluster and VPC |
| `gcp_location` | `us-central1` | GCP region for GKE Hub registration |
| `cluster_name_prefix` | `aws-eks-cluster` | Prefix for all cluster and resource names |
| `k8s_version` | `1.34` | Kubernetes version for the EKS cluster |
| `platform_version` | `1.34.0-gke.1` | GKE Attached Clusters platform version |
| `node_group_desired_size` | `2` | Desired number of EKS worker nodes |
| `node_group_max_size` | `5` | Maximum number of EKS worker nodes |
| `node_group_min_size` | `2` | Minimum number of EKS worker nodes |
| `subnet_availability_zones` | `["us-west-2a", "us-west-2b", "us-west-2c"]` | AZs for VPC subnets |
| `vpc_cidr_block` | `10.0.0.0/16` | CIDR block for the AWS VPC |
| `public_subnet_cidr_blocks` | `["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]` | Public subnet CIDRs |
| `enable_public_subnets` | `true` | `true` for public subnets; `false` for private with NAT Gateway |
| `trusted_users` | `[]` | Google accounts granted cluster-admin on the attached cluster |
| `resource_creator_identity` | *(platform default SA)* | Terraform service account for provisioning |

Minimum `terraform.tfvars` example:

```hcl
existing_project_id = "your-project-id"
aws_access_key      = "AKIAIOSFODNN7EXAMPLE"
aws_secret_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
trusted_users       = ["you@example.com"]
```

### Step 1.2 — Initialise and Deploy

```bash
tofu init
tofu validate
tofu plan -out=plan.tfplan
tofu apply plan.tfplan
```

**Expected duration:**

| Resource | Typical time |
|---|---|
| GCP API enablement | 1–2 minutes |
| AWS VPC, subnets, and routing | 1–2 minutes |
| AWS IAM roles | < 1 minute |
| EKS cluster control plane | 10–15 minutes |
| EKS managed node group | 3–5 minutes |
| Bootstrap manifest install (Helm) | 1–2 minutes |
| GKE Hub registration (`google_container_attached_cluster`) | 1–3 minutes |

> The `tofu apply` command will not return until the EKS cluster, node group,
> and GKE Hub registration are all complete. Allow up to 30 minutes.

### Step 1.3 — Confirm Deployment Succeeded

After `apply` completes, verify the key resources exist:

**GCP side — confirm the Attached Cluster is registered:**

```bash
gcloud container attached clusters describe aws-eks-cluster \
  --location=us-central1 \
  --project=your-project-id
```

**AWS side — confirm the EKS cluster is active:**

```bash
aws eks describe-cluster \
  --name aws-eks-cluster \
  --region us-west-2 \
  --query "cluster.status"
```

**Expected result:** The GCP command returns cluster details including
`state: RUNNING`. The AWS command returns `"ACTIVE"`.

> **REST API equivalent — get the attached cluster:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters/$CLUSTER" \
>   -H "Authorization: Bearer $TOKEN" | jq '{name, state, distribution, platformVersion}'
> ```

---

## Phase 2 — Explore the Attached Cluster in the Google Cloud Console [MANUAL]

### Step 2.1 — View the Cluster in GKE Hub

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**.
2. Locate the cluster named **aws-eks-cluster** in the cluster list.
3. Note the **Type** column shows **Attached** and the **Location** column
   shows the GCP region (e.g. `us-central1`).
4. Click the cluster name to open its detail page.
5. Review the **Details** tab — note the Kubernetes version, platform version,
   OIDC issuer URL, and fleet project.

**Expected result:** The cluster detail page loads showing the EKS cluster
registered as an Attached Cluster. The **Status** field shows **Running**.

> **REST API equivalent — list all attached clusters:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.attachedClusters[] | {name, state, distribution, kubernetesVersion}'
> ```

### Step 2.2 — View Fleet Membership

1. In the Google Cloud console, navigate to
   **Kubernetes Engine > Clusters** and click the cluster name.
2. On the cluster detail page, note the **Fleet** section showing the fleet
   project the cluster belongs to.
3. Navigate to **Kubernetes Engine > Fleet** (or search for **Fleet** in the
   console search bar).
4. Confirm **aws-eks-cluster** appears in the fleet member list with a
   **Registered** status.

**Expected result:** The cluster appears as a fleet member. The fleet view
shows it alongside any other registered clusters (GKE, Anthos on-prem, etc.),
giving a unified multi-cluster view.

> **gcloud equivalent — describe fleet membership:**
> ```bash
> gcloud container fleet memberships describe aws-eks-cluster \
>   --project=your-project-id
> ```

### Step 2.3 — Review Cluster Authorization Settings

The `trusted_users` variable in the module sets which Google accounts receive
`cluster-admin` access on the attached cluster.

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**
   and click **aws-eks-cluster**.
2. Click the **Details** tab and scroll to the **Authorization** section.
3. Confirm your account email (from `trusted_users`) is listed under
   **Admin users**.

**Expected result:** The admin users list contains the email addresses
specified in `trusted_users` at deploy time. These accounts can connect to
the cluster via the Connect Gateway without any additional RBAC configuration
in the cluster itself.

> **REST API equivalent — view authorization config:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters/$CLUSTER" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.authorization'
> ```

---

## Phase 3 — Connect to the EKS Cluster via Connect Gateway [MANUAL]

The Connect Gateway allows you to use `kubectl` against the EKS cluster without
direct network access to the AWS VPC. All traffic is proxied through the GKE
Connect agent installed by the bootstrap manifest.

### Step 3.1 — Obtain Connect Gateway Credentials

Run the following command to configure `kubectl` to talk to the EKS cluster
through the Connect Gateway:

```bash
gcloud container fleet memberships get-credentials aws-eks-cluster \
  --project=your-project-id
```

> If you used a non-default `gcp_location`, add `--location=<location>`.

**Expected result:** A new `kubeconfig` context is added and set as the active
context. The context name will be in the form
`connectgateway_your-project-id_global_aws-eks-cluster`.

### Step 3.2 — Verify Cluster Connectivity

```bash
kubectl get nodes
```

**Expected result:** A list of the EKS worker nodes is returned. With the
default `node_group_desired_size` of 2, you should see two nodes in
`Ready` status:

```
NAME                                       STATUS   ROLES    AGE   VERSION
ip-10-0-101-xxx.us-west-2.compute.internal Ready    <none>   Xm    v1.34.x-eks-...
ip-10-0-102-xxx.us-west-2.compute.internal Ready    <none>   Xm    v1.34.x-eks-...
```

### Step 3.3 — Explore Cluster Namespaces and System Components

View the namespaces created by the bootstrap manifest:

```bash
kubectl get namespaces
```

Inspect the GKE Connect agent pods installed by the bootstrap manifest:

```bash
kubectl get pods -n gke-connect
kubectl get pods -n gke-managed-metrics-server
kubectl get pods -n gke-managed-system
```

**Expected result:** The `gke-connect` namespace contains the Connect agent
pod. The `gke-managed-metrics-server` and `gke-managed-system` namespaces
contain the managed system components installed by the Attached Clusters
platform.

### Step 3.4 — Inspect Node Details

```bash
kubectl describe node <node-name>
```

Review the node labels and annotations. Note labels added by EKS (e.g.
`node.kubernetes.io/instance-type`, `topology.kubernetes.io/zone`) and
annotations added by the GKE Attached Clusters components.

**Expected result:** Node descriptions show both EKS-native labels and
Attached Clusters management labels, confirming that the cluster is jointly
managed.

---

## Phase 4 — Deploy a Sample Workload [MANUAL]

### Step 4.1 — Deploy nginx

Deploy a simple nginx workload to verify that the cluster can schedule and run
pods:

```bash
kubectl create deployment nginx --image=nginx --replicas=2
kubectl expose deployment nginx --port=80 --type=ClusterIP
```

### Step 4.2 — Verify Pods Are Running

```bash
kubectl get pods -l app=nginx -o wide
kubectl get service nginx
```

**Expected result:** Two `nginx` pods are in `Running` state, scheduled across
the worker nodes. The ClusterIP service is created with a virtual IP address.

### Step 4.3 — Exec into a Pod and Test Connectivity

```bash
kubectl exec -it $(kubectl get pod -l app=nginx -o name | head -1) \
  -- curl -s http://nginx/
```

**Expected result:** The nginx welcome page HTML is returned, confirming
intra-cluster DNS and networking are working correctly.

### Step 4.4 — Generate Log Traffic for Observability

Run a command that produces log output so you can find it in Cloud Logging
during Phase 5:

```bash
kubectl exec -it $(kubectl get pod -l app=nginx -o name | head -1) \
  -- sh -c "for i in \$(seq 1 20); do curl -s http://nginx/ > /dev/null; done"
```

**Expected result:** The command completes without error. Log entries are
produced in the nginx pods and will appear in Cloud Logging within 1–2
minutes.

---

## Phase 5 — Explore Centralized Logging [MANUAL]

The module enables Cloud Logging for both `SYSTEM_COMPONENTS` and `WORKLOADS`.
All pod stdout/stderr and Kubernetes system events are streamed to Cloud
Logging automatically.

### Step 5.1 — View System Component Logs

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query editor, enter:

```
resource.type="k8s_container"
resource.labels.cluster_name="aws-eks-cluster"
resource.labels.namespace_name="kube-system"
```

3. Click **Run Query**.
4. Expand individual log entries and review the fields — note
   `resource.labels.pod_name`, `resource.labels.container_name`, and the
   structured log payload.

**Expected result:** Log entries from system pods (e.g. `coredns`,
`kube-proxy`, `aws-node`) appear in Logs Explorer within a few minutes of
cluster creation. The `cluster_name` label identifies which cluster each log
came from.

### Step 5.2 — View Workload Logs

Filter for nginx workload logs:

```
resource.type="k8s_container"
resource.labels.cluster_name="aws-eks-cluster"
resource.labels.namespace_name="default"
resource.labels.container_name="nginx"
```

**Expected result:** Access log entries from the `nginx` containers appear,
including the requests made in Step 4.4. This confirms that workload logs from
the EKS cluster are flowing into Cloud Logging with no additional configuration
needed.

### Step 5.3 — View Kubernetes Events

Events (pod scheduling, image pulls, container starts) are also captured:

```
resource.type="k8s_event"
resource.labels.cluster_name="aws-eks-cluster"
```

**Expected result:** Kubernetes events from the EKS cluster appear in Logs
Explorer, including events for the nginx deployment created in Phase 4.

### Step 5.4 — Create a Log-Based Metric (Optional)

1. From the query in Step 5.2, click **Create metric** (top right of the query
   bar).
2. Name the metric `nginx_requests_eks`.
3. Leave all other settings at their defaults and click **Create metric**.

**Expected result:** The metric is created and will accumulate a count of
nginx log entries from the EKS cluster. It becomes available in Cloud
Monitoring after a few minutes.

> **Tip:** Log-based metrics let you build alerts on workload activity without
> installing any agents on the cluster — the Attached Clusters logging
> integration handles the collection automatically.

---

## Phase 6 — Explore Managed Prometheus Metrics [MANUAL]

The module enables Managed Prometheus (`managed_prometheus_config.enabled =
true`). The GKE-managed metrics server installed by the bootstrap manifest
scrapes cluster metrics and forwards them to Google Cloud Managed Service for
Prometheus.

### Step 6.1 — Query Cluster Metrics in Cloud Monitoring

1. In the Google Cloud console, navigate to
   **Monitoring > Metrics Explorer**.
2. In the **Select a metric** field, search for `kubernetes.io/container/cpu`.
3. Select **Kubernetes Container > CPU request utilization**.
4. Under **Filters**, add a filter:
   - Resource label: `cluster_name` = `aws-eks-cluster`
5. Click **Apply** and review the time-series graph.

**Expected result:** CPU utilization metrics appear for the containers running
in the EKS cluster, including both system components and the nginx workload
deployed in Phase 4.

### Step 6.2 — Explore the GKE Dashboard

1. In the Google Cloud console, navigate to **Monitoring > Dashboards**.
2. Search for **GKE** in the dashboard list.
3. Open the **GKE** dashboard.
4. In the cluster filter at the top, select **aws-eks-cluster**.

**Expected result:** The GKE dashboard populates with node, pod, and container
metrics from the EKS cluster. Resource utilization, restart counts, and
scheduling statistics are all visible — the same dashboard used for native GKE
clusters applies identically to Attached Clusters.

### Step 6.3 — Query Prometheus Metrics via gcloud (Optional)

You can query Managed Prometheus directly using the Cloud Monitoring API:

```bash
gcloud monitoring query \
  --project=your-project-id \
  --query='fetch k8s_container
  | metric "kubernetes.io/container/uptime"
  | filter resource.cluster_name == "aws-eks-cluster"
  | within 5m'
```

**Expected result:** Uptime values are returned for containers running in the
EKS cluster, confirming that Managed Prometheus is collecting and storing
metrics.

---

## Phase 7 — Manage Fleet Access Control [MANUAL]

### Step 7.1 — Understand the Authorization Model

EKS Attached Clusters uses Google Cloud Identity for authentication. The
`trusted_users` (and optionally `admin_groups`) set during module deployment
are mapped to `cluster-admin` ClusterRoleBindings inside the cluster. This
means:

- Users log in with `gcloud container fleet memberships get-credentials` — no
  AWS credentials are needed to use `kubectl`.
- The Google identity is validated by the Connect Agent using OIDC.
- Additional users or groups can be granted access by updating the cluster
  without touching AWS IAM.

### Step 7.2 — Grant Access to an Additional User

To add another Google account as a cluster admin, update the attached cluster:

```bash
gcloud container attached clusters update aws-eks-cluster \
  --location=us-central1 \
  --project=your-project-id \
  --admin-users=new-user@example.com
```

> This is an additive update — the new user is added to the existing list.
> Omitting `--admin-users` replaces the list. Confirm the current list first
> with `describe` before updating.

**Expected result:** The command completes and the new user can now run
`gcloud container fleet memberships get-credentials` and use `kubectl` against
the cluster.

> **REST API equivalent — update admin users:**
> ```bash
> curl -s -X PATCH \
>   "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters/$CLUSTER?updateMask=authorization" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{
>     "authorization": {
>       "adminUsers": [
>         {"username": "you@example.com"},
>         {"username": "new-user@example.com"}
>       ]
>     }
>   }' | jq '{operation: .name}'
> ```

### Step 7.3 — Verify RBAC Bindings Inside the Cluster

The authorization settings are reflected as ClusterRoleBindings inside the
EKS cluster:

```bash
kubectl get clusterrolebindings \
  -l "managed-by=gke-attached-clusters" -o wide
```

**Expected result:** One or more ClusterRoleBindings are listed, binding the
trusted user accounts to `cluster-admin`. These bindings are managed by the
GKE Attached Clusters platform and are reconciled automatically.

### Step 7.4 — View Audit Logs for Cluster Access

Every `kubectl` call through the Connect Gateway is recorded in Cloud Audit
Logs:

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. Enter the following query:

```
resource.type="k8s_cluster"
resource.labels.cluster_name="aws-eks-cluster"
protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"
```

3. Expand a log entry and review the `authenticationInfo.principalEmail` field
   to see which Google identity made the request.

**Expected result:** Audit log entries appear for `kubectl` calls made during
the lab. The `principalEmail` field shows the Google account that authenticated
via the Connect Gateway, providing a full audit trail tied to Google identity.

---

## Phase 8 — Platform Version Management [MANUAL]

### Step 8.1 — List Available Platform Versions

The `platform_version` input controls which version of the managed components
is installed on the EKS cluster. Run the following to see all currently
supported versions:

```bash
gcloud container attached get-server-config \
  --location=us-central1 \
  --project=your-project-id
```

**Expected result:** A list of valid platform versions is returned. Each
version is compatible with a range of Kubernetes minor versions. Choose a
platform version whose `validVersions` range includes your EKS cluster's
Kubernetes version.

> **REST API equivalent — get server config:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedServerConfig" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.validVersions[] | {version, kubernetesVersions}'
> ```

### Step 8.2 — Understand the Upgrade Process

To upgrade the platform version (the managed components on the EKS cluster),
update the `platform_version` variable in `terraform.tfvars` and re-apply:

```hcl
platform_version = "1.34.1-gke.1"   # example new version
```

```bash
tofu apply
```

Terraform will:
1. Fetch a new install manifest from the Attached Clusters service.
2. Use Helm to upgrade the `attached-bootstrap` chart on the EKS cluster.
3. Update the `google_container_attached_cluster` resource with the new
   platform version.

> **Note:** Platform version upgrades do not affect the EKS control plane
> or worker node Kubernetes version. EKS Kubernetes version upgrades are
> managed separately through AWS (update `k8s_version` and re-apply).

### Step 8.3 — Verify the Current Platform Version

Confirm which platform version is currently active on the cluster:

```bash
gcloud container attached clusters describe aws-eks-cluster \
  --location=us-central1 \
  --project=your-project-id \
  --format="value(platformVersion)"
```

**Expected result:** The platform version string (e.g. `1.34.0-gke.1`) is
returned, matching the value of `platform_version` in your `terraform.tfvars`.

> **REST API equivalent:**
> ```bash
> curl -s "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters/$CLUSTER" \
>   -H "Authorization: Bearer $TOKEN" | jq -r '.platformVersion'
> ```

---

## Phase 9 — Advanced Features [MANUAL]

### Step 9.1 — Use the Connect Gateway with the Kubernetes API Directly

The Connect Gateway exposes a standard Kubernetes API endpoint rooted at:

```
https://connectgateway.googleapis.com/v1/projects/PROJECT_NUMBER/locations/global/memberships/aws-eks-cluster
```

You can call this endpoint directly with a Bearer token:

```bash
export PROJECT_NUMBER=$(gcloud projects describe your-project-id \
  --format="value(projectNumber)")

curl -s \
  "https://connectgateway.googleapis.com/v1beta1/projects/$PROJECT_NUMBER/locations/global/memberships/aws-eks-cluster/api/v1/namespaces" \
  -H "Authorization: Bearer $TOKEN" | jq '.items[].metadata.name'
```

**Expected result:** A list of Kubernetes namespace names is returned. This
demonstrates that any tool capable of making HTTPS requests with a Google
Bearer token can interact with the EKS cluster through the Connect Gateway —
no direct network connectivity to AWS is required.

### Step 9.2 — Enable Private Subnets (Awareness)

By default, the module places EKS worker nodes in public subnets
(`enable_public_subnets = true`). For production workloads, set:

```hcl
enable_public_subnets = false
```

When `enable_public_subnets = false`, the module instead creates:
- Private subnets using `private_subnet_cidr_blocks`
- An Elastic IP and NAT Gateway for outbound internet access
- Route tables routing private subnet traffic through the NAT Gateway

> **Note:** Changing `enable_public_subnets` after the initial deployment
> requires destroying and recreating the VPC, subnets, and EKS cluster. Plan
> the subnet topology before the first `tofu apply`.

### Step 9.3 — Explore IAM Roles Created by the Module

Review the AWS IAM roles Terraform created:

```bash
aws iam get-role --role-name aws-eks-cluster-eks-role \
  --query "Role.AssumeRolePolicyDocument"

aws iam list-attached-role-policies \
  --role-name aws-eks-cluster-node-group-role \
  --query "AttachedPolicies[].PolicyName"
```

**Expected result:**
- The EKS cluster role has a trust relationship with `eks.amazonaws.com` and
  the `AmazonEKSClusterPolicy` managed policy attached.
- The node group role has `AmazonEKSWorkerNodePolicy`,
  `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly` attached,
  which are the minimum permissions required for EKS worker nodes to join
  the cluster and pull container images.

### Step 9.4 — Verify the GKE Hub OIDC Integration

The Attached Clusters registration works by configuring GKE Hub to trust the
EKS cluster's OIDC issuer. View the issuer URL that was registered:

```bash
aws eks describe-cluster \
  --name aws-eks-cluster \
  --region us-west-2 \
  --query "cluster.identity.oidc.issuer" \
  --output text
```

Compare this to what is recorded in the GKE Hub registration:

```bash
gcloud container attached clusters describe aws-eks-cluster \
  --location=us-central1 \
  --project=your-project-id \
  --format="value(oidcConfig.issuerUrl)"
```

**Expected result:** Both commands return the same OIDC issuer URL
(e.g. `https://oidc.eks.us-west-2.amazonaws.com/id/XXXXXXXXXX`). This URL is
the trust anchor — GKE Hub validates tokens signed by this issuer to
authenticate Connect agent connections and kubectl requests through the
Connect Gateway.

---

## Phase 10 — Clean Up [AUTOMATED]

When you have finished the lab, destroy all resources to avoid ongoing AWS and
GCP charges.

### Step 10.1 — Remove the Sample Workload

Before destroying infrastructure, delete the workload deployed in Phase 4:

```bash
kubectl delete deployment nginx
kubectl delete service nginx
```

### Step 10.2 — Destroy All Infrastructure

```bash
tofu destroy
```

Terraform destroys resources in the correct dependency order:

1. `google_container_attached_cluster` (detaches from GKE Hub)
2. Helm release `attached-bootstrap` (uninstalls bootstrap manifest from EKS)
3. `aws_eks_node_group` (terminates EC2 worker nodes)
4. `aws_eks_cluster` (deletes EKS control plane)
5. AWS IAM role policy attachments and IAM roles
6. AWS VPC subnets, route tables, and Internet Gateway
7. AWS VPC

> **Note:** The `attached-install-manifest` module installs a `cleanup` hook
> that removes the bootstrap components from the EKS cluster before Terraform
> deletes the node group. Destroying in a different order (e.g. deleting the
> node group via the AWS console before running `tofu destroy`) may cause
> the destroy to fail. Always use `tofu destroy` rather than deleting resources
> individually.

**Expected duration:**

| Resource | Typical time |
|---|---|
| GKE Hub detach | 1–2 minutes |
| EKS node group termination | 3–5 minutes |
| EKS cluster deletion | 10–15 minutes |
| VPC and networking cleanup | 1–2 minutes |

> **REST API equivalent — delete the attached cluster registration:**
> ```bash
> curl -s -X DELETE \
>   "$BASE/projects/$PROJECT/locations/$LOCATION/attachedClusters/$CLUSTER" \
>   -H "Authorization: Bearer $TOKEN" | jq '{operation: .name}'
> ```
> Note: This only removes the GKE Hub registration. The EKS cluster itself
> must be deleted separately via AWS.

---

## Summary

The table below recaps every action in the lab, its phase, and whether it is
automated by the `EKS_GKE` Terraform module or performed manually.

| Action | Phase | Automated |
|---|---|---|
| Enable GCP APIs | 1 | Yes — `main.tf` |
| Create AWS VPC with DNS support | 1 | Yes — `vpc.tf` |
| Create public subnets across 3 AZs | 1 | Yes — `vpc.tf` |
| Create Internet Gateway and route tables | 1 | Yes — `vpc.tf` |
| Create NAT Gateway (private subnet mode) | 1 | Yes — `vpc.tf` |
| Create EKS cluster IAM role | 1 | Yes — `iam.tf` |
| Create EKS node group IAM role with required policies | 1 | Yes — `iam.tf` |
| Create EKS cluster | 1 | Yes — `main.tf` |
| Create EKS managed node group | 1 | Yes — `main.tf` |
| Fetch GKE Attached Clusters install manifest | 1 | Yes — `modules/attached-install-manifest/main.tf` |
| Apply bootstrap manifest to EKS cluster via Helm | 1 | Yes — `modules/attached-install-manifest/main.tf` |
| Register EKS cluster as Attached Cluster in GKE Hub | 1 | Yes — `main.tf` |
| Join cluster to Google Cloud Fleet | 1 | Yes — `main.tf` |
| Enable Cloud Logging (system + workloads) | 1 | Yes — `main.tf` |
| Enable Managed Prometheus | 1 | Yes — `main.tf` |
| Grant cluster-admin to trusted users | 1 | Yes — `main.tf` |
| Confirm EKS cluster is ACTIVE (AWS) | 1 | No — `aws eks describe-cluster` |
| Confirm Attached Cluster is RUNNING (GCP) | 1 | No — `gcloud` or console |
| View cluster in GKE Hub console | 2 | No — console exploration |
| View fleet membership | 2 | No — console exploration |
| Review cluster authorization settings | 2 | No — console exploration |
| Configure kubectl via Connect Gateway | 3 | No — `gcloud container fleet memberships get-credentials` |
| Verify cluster connectivity (`kubectl get nodes`) | 3 | No — `kubectl` |
| Explore GKE-managed system namespaces | 3 | No — `kubectl` |
| Inspect node labels and annotations | 3 | No — `kubectl` |
| Deploy nginx workload | 4 | No — `kubectl` |
| Verify pods running | 4 | No — `kubectl` |
| Test intra-cluster connectivity | 4 | No — `kubectl exec` |
| Generate log traffic | 4 | No — `kubectl exec` |
| View system component logs in Cloud Logging | 5 | No — Logs Explorer |
| View nginx workload logs in Cloud Logging | 5 | No — Logs Explorer |
| View Kubernetes events in Cloud Logging | 5 | No — Logs Explorer |
| Create log-based metric | 5 | No — Logs Explorer (optional) |
| Query CPU metrics in Metrics Explorer | 6 | No — Cloud Monitoring |
| Explore GKE Monitoring dashboard | 6 | No — Cloud Monitoring |
| Query Managed Prometheus via gcloud | 6 | No — optional `gcloud monitoring query` |
| Add additional admin user | 7 | No — `gcloud container attached clusters update` |
| Verify RBAC bindings inside cluster | 7 | No — `kubectl get clusterrolebindings` |
| View Connect Gateway audit logs | 7 | No — Logs Explorer |
| List available platform versions | 8 | No — `gcloud container attached get-server-config` |
| Understand upgrade process (awareness) | 8 | No — reference only |
| Verify current platform version | 8 | No — `gcloud` or REST API |
| Call Kubernetes API via Connect Gateway endpoint | 9 | No — `curl` |
| Review private subnet mode (awareness) | 9 | No — reference only |
| Inspect AWS IAM roles | 9 | No — `aws iam` commands |
| Verify OIDC issuer registration | 9 | No — `aws eks describe-cluster` + `gcloud` |
| Delete nginx workload before destroy | 10 | No — `kubectl delete` |
| Destroy all infrastructure | 10 | Yes — `tofu destroy` |
