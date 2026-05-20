# AKS Attached Clusters — Lab Guide

## Overview

This guide walks through the full GKE Attached Clusters lab using the `AKS_GKE`
Terraform module. The module automates all infrastructure provisioning: it
creates a Microsoft Azure Kubernetes Service (AKS) cluster, installs the
GKE Attached Clusters bootstrap components via Helm, and registers the cluster
as a fleet member in Google Cloud. All post-registration exploration and
workload operations are performed manually.

**Estimated time:** 45–60 minutes (includes ~15 minutes of background
provisioning)

### What Terraform Automates

- Enabling required GCP APIs
- Creating the Azure Resource Group
- Deploying the AKS cluster with OIDC issuer enabled
- Assigning the Network Contributor role to the AKS cluster identity
- Fetching the GKE Attached Clusters install manifest from Google Cloud
- Installing the bootstrap Helm chart onto the AKS cluster
- Registering the AKS cluster as a `google_container_attached_cluster`
  in GKE Hub with Cloud Logging and Managed Prometheus enabled
- Granting cluster-admin access to the listed trusted users

### What You Do Manually

- Verifying the attached cluster appears in the Google Cloud console
- Configuring `kubectl` to access the cluster via Connect Gateway
- Exploring fleet membership and cluster status
- Exploring Cloud Logging for system and workload logs
- Exploring Cloud Monitoring and Managed Prometheus metrics
- Deploying a sample workload to the AKS cluster
- Exploring Connect Gateway-based access control
- Reviewing advanced features: IAM roles, audit logs, cluster upgrades

---

## CLI and REST API Overview

Every action in this lab can be performed via the `gcloud` CLI or the GKE
Multi-Cloud REST API (`gkemulticloud.googleapis.com/v1`) and GKE Hub API
(`gkehub.googleapis.com/v1`) as alternatives to the Cloud Console UI. Both
`gcloud` and REST API equivalents are shown after each relevant step.

**Base URLs:**

```
https://REGION-gkemulticloud.googleapis.com/v1
https://gkehub.googleapis.com/v1
```

**Set these shell variables once before running any API command:**

```bash
export TOKEN=$(gcloud auth print-access-token)
export PROJECT="your-project-id"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format='value(projectNumber)')
export REGION="us-central1"
export CLUSTER="azure-aks-cluster"    # matches cluster_name_prefix
export MULTICLOUD_BASE="https://${REGION}-gkemulticloud.googleapis.com/v1"
export HUB_BASE="https://gkehub.googleapis.com/v1"
```

**All mutating operations return a long-running Operation. Poll for completion:**

```bash
curl -s "${MULTICLOUD_BASE}/projects/${PROJECT}/locations/${REGION}/operations/OPERATION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.done, .error'
```

`done: true` with no `error` means the operation succeeded.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| Azure CLI (`az`) | Authenticated with an account that can create AKS clusters |
| GCP Project | Must already exist with billing enabled |
| Azure Subscription | Active subscription with sufficient quota for AKS |
| Azure Service Principal | Must have Contributor access to the target subscription |
| Terraform resource provisioning Service Account | Must hold `roles/owner` on the target GCP project |
| Caller permissions | The identity running `tofu apply` must hold `roles/iam.serviceAccountTokenCreator` on the service account above |

### Azure Service Principal Setup

If you do not already have a service principal, create one with the Azure CLI:

```bash
az ad sp create-for-rbac \
  --name "aks-gke-lab-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --output json
```

This returns the `appId` (client_id), `password` (client_secret), and `tenant`
(tenant_id) values required by the module.

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/AKS_GKE
```

Create a `terraform.tfvars` file with the following inputs. All values shown are
the module defaults — override only what differs in your environment.

| Variable | Default | Description |
|---|---|---|
| `project_id` | *(required — no default)* | GCP project ID where the cluster is registered |
| `azure_region` | `westus2` | Azure region for the AKS cluster and Resource Group |
| `gcp_location` | `us-central1` | GCP region where the attached cluster resource is created |
| `cluster_name_prefix` | `azure-aks-cluster` | Prefix for all generated resource names |
| `node_count` | `3` | Number of nodes in the AKS default node pool |
| `k8s_version` | `1.34` | Kubernetes version for the AKS cluster |
| `platform_version` | `1.34.0-gke.1` | GKE Hub Attached Clusters platform version |
| `vm_size` | `Standard_D2s_v3` | Azure VM SKU for worker nodes (2 vCPU, 8 GB RAM) |
| `trusted_users` | `[]` | Google account emails granted cluster-admin access |
| `client_id` | *(required)* | Azure AD Application (Client) ID |
| `client_secret` | *(required)* | Azure AD Application Client Secret |
| `tenant_id` | *(required)* | Azure AD Tenant ID |
| `subscription_id` | *(required)* | Azure Subscription ID |

Minimum `terraform.tfvars` example:

```hcl
project_id = "your-project-id"
trusted_users       = ["your-email@example.com"]

client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_secret   = "your-client-secret"
tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
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
| API enablement | 1–2 minutes |
| Azure Resource Group creation | < 1 minute |
| AKS cluster provisioning | 5–10 minutes |
| Bootstrap Helm chart install | 1–2 minutes |
| GKE Hub cluster registration | 1–2 minutes |

> The `tofu apply` command will not return until all resources are fully
> provisioned, including the fleet registration.

### Step 1.3 — Note Key Identifiers

When `apply` completes, record the following values — you will use them
throughout the rest of the lab:

```bash
tofu show | grep -E "cluster_id|resource_group|oidc_issuer"
```

| Value | Where to find it | Used in |
|---|---|---|
| Cluster name | `var.cluster_name_prefix` + deployment ID suffix | All `kubectl` and API commands |
| Resource Group name | Azure portal or `tofu state show azurerm_resource_group.aks` | Azure console verification |
| OIDC Issuer URL | `tofu state show azurerm_kubernetes_cluster.aks` | Phase 2 verification |
| GCP Project ID | Your `project_id` variable | All GCP console and API steps |

---

## Phase 2 — Verify the Attached Cluster [MANUAL]

### Step 2.1 — View the Cluster in the Google Cloud Console

1. In the Google Cloud console, navigate to **Kubernetes Engine > Clusters**.
2. Confirm the cluster named **azure-aks-cluster** (or your `cluster_name_prefix`
   value) appears in the list.
3. Note the **Type** column shows **Attached** and the **Location** shows
   your `gcp_location` region.
4. Click the cluster name to open its details page.
5. Verify the **Status** is **Running**.

**Expected result:** The AKS cluster is visible in the GKE console alongside
any native GKE clusters in the project. The **Type: Attached** indicator
confirms it is an externally-managed cluster registered via GKE Hub.

> **gcloud equivalent — describe the attached cluster:**
> ```bash
> gcloud container attached clusters describe ${CLUSTER} \
>   --location=${REGION} \
>   --project=${PROJECT} \
>   --format='yaml(name,state,kubernetesVersion,platformVersion)'
> ```
>
> **REST API equivalent — describe the attached cluster:**
> ```bash
> curl -s \
>   "${MULTICLOUD_BASE}/projects/${PROJECT}/locations/${REGION}/attachedClusters/${CLUSTER}" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '{name: .name, state: .state, kubernetesVersion: .kubernetesVersion, platformVersion: .platformVersion}'
> ```

### Step 2.2 — View the Fleet Membership

1. In the Google Cloud console, navigate to **Kubernetes Engine > Fleets**.
2. Click the **Clusters** tab.
3. Confirm **azure-aks-cluster** appears with a **Registered** status.
4. Click the cluster name to view its fleet membership details.
5. Note the **Fleet project** and **Membership** fields.

**Expected result:** The AKS cluster is a registered member of the GKE Hub
fleet in your GCP project. Fleet membership enables centralized management,
logging, and access control across all clusters — both native GKE and
Attached — in the fleet.

> **gcloud equivalent — list fleet memberships:**
> ```bash
> gcloud container fleet memberships list \
>   --project=${PROJECT} \
>   --format='table(name,state.code,endpoint)'
> ```
>
> **REST API equivalent — list fleet memberships:**
> ```bash
> curl -s \
>   "${HUB_BASE}/projects/${PROJECT}/locations/global/memberships" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.resources[] | {name: .name, state: .state.code, endpoint: .endpoint}'
> ```

### Step 2.3 — Verify Installed Components

1. In the cluster details page in the Google Cloud console, click the
   **Details** tab.
2. Review the **Platform version** field — it should match the
   `platform_version` variable.
3. Review the **Logging** and **Monitoring** sections — both should show
   as **Enabled**.

**Expected result:** The platform version, logging, and monitoring settings
match the Terraform configuration. The bootstrap Helm chart installed by
Terraform placed the GKE Hub agent onto the AKS cluster, enabling these
managed features.

---

## Phase 3 — Access the Cluster via Connect Gateway [MANUAL]

Connect Gateway lets you run `kubectl` commands against the AKS cluster
through Google Cloud's API, using your Google identity — without needing
direct network access to the AKS API server.

### Step 3.1 — Install Required Tools

Ensure the following are installed on your local machine:

```bash
# Install kubectl
gcloud components install kubectl

# Install the gke-gcloud-auth-plugin (required for Connect Gateway)
gcloud components install gke-gcloud-auth-plugin
```

### Step 3.2 — Configure kubectl via Connect Gateway

```bash
gcloud container fleet memberships get-credentials azure-aks-cluster \
  --project=YOUR_PROJECT_ID
```

This command writes a `kubeconfig` context that routes `kubectl` through the
Connect Gateway.

**Verify the context is set:**

```bash
kubectl config current-context
```

**Expected result:** The context name contains `connectgateway` and your
project and cluster identifiers, for example:
`connectgateway_your-project-id_global_azure-aks-cluster`.

### Step 3.3 — Verify Cluster Connectivity

```bash
kubectl cluster-info
```

**Expected result:** The output shows the Kubernetes control plane address
as a `connectgateway.googleapis.com` URL, confirming traffic is routed
through Connect Gateway.

```bash
kubectl get nodes
```

**Expected result:** The three AKS worker nodes appear with a **Ready**
status.

```bash
kubectl get pods --all-namespaces
```

**Expected result:** System pods are visible, including GKE Hub components
in the `gke-connect` namespace and any other system namespaces.

> **Note:** Connect Gateway requests are authenticated and authorized via
> Google Cloud IAM and the RBAC bindings configured in the attached cluster
> authorization block. The `trusted_users` variable grants cluster-admin
> to the listed identities.

---

## Phase 4 — Explore Fleet Management [MANUAL]

### Step 4.1 — View Fleet Feature Status

GKE Hub features provide centralized capabilities — such as logging,
monitoring, and service mesh — across all fleet members from a single
control plane.

1. In the Google Cloud console, navigate to **Kubernetes Engine > Features**.
2. Review the list of fleet features. Note which features are enabled
   for your fleet, including:
   - **Cloud Logging and Cloud Monitoring**
   - **Config Management**
   - **Service Mesh**

**Expected result:** The Logging and Monitoring feature shows as enabled,
consistent with the `logging_config` and `monitoring_config` blocks in
the Terraform resource.

> **gcloud equivalent — list fleet features:**
> ```bash
> gcloud container fleet features list \
>   --project=${PROJECT} \
>   --format='table(name,resourceState.state)'
> ```
>
> **REST API equivalent — list fleet features:**
> ```bash
> curl -s \
>   "${HUB_BASE}/projects/${PROJECT}/locations/global/features" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.resources[] | {name: .name, state: .state}'
> ```

### Step 4.2 — Inspect the GKE Connect Agent

The GKE Connect agent runs inside the AKS cluster and maintains the secure
tunnel to Google Cloud that enables Connect Gateway access.

```bash
kubectl get pods -n gke-connect
```

**Expected result:** A `gke-connect-agent-*` pod is running. This agent
establishes the outbound connection from the AKS cluster to Google's
Connect service, requiring no inbound firewall rules.

```bash
kubectl describe pod -n gke-connect -l app=gke-connect-agent | grep -E "Image:|Status:|Ready:"
```

**Expected result:** The pod is Running and Ready, using the GKE Connect
agent image version corresponding to your `platform_version`.

### Step 4.3 — Inspect the Managed Components Namespace

The bootstrap install manifest installed system components into the cluster.

```bash
kubectl get namespaces | grep -E "gke|anthos|cloud"
```

```bash
kubectl get pods -n gke-managed-system 2>/dev/null || \
  kubectl get pods -n gke-system 2>/dev/null || \
  kubectl get pods -n kube-system | grep -E "gke|anthos"
```

**Expected result:** GKE-managed system pods are visible, confirming the
Helm bootstrap chart was applied successfully during Terraform provisioning.

---

## Phase 5 — Explore Cloud Logging [MANUAL]

The attached cluster is configured to forward both **system component** and
**workload** logs to Cloud Logging. This provides a centralized log view
across all fleet clusters without requiring in-cluster log aggregation.

### Step 5.1 — View System Component Logs

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query builder, enter the following query and click **Run Query**:

```
resource.type="k8s_cluster"
resource.labels.cluster_name="azure-aks-cluster"
log_name=~"system"
```

3. Expand individual log entries and review the `resource.labels` fields,
   including `cluster_name`, `location`, and `project_id`.

**Expected result:** Log entries from AKS system components (scheduler,
controller-manager, API server) appear in Cloud Logging, streaming from the
AKS cluster through the GKE Hub agent — no separate log forwarder required.

### Step 5.2 — View Workload Logs

The module enables `WORKLOADS` logging, which captures logs from all
user-deployed containers.

1. In **Logs Explorer**, run the following query:

```
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"
```

**Expected result:** Container logs from all namespaces on the AKS cluster
appear alongside logs from any other GKE clusters in the same project,
providing a unified multi-cloud logging view.

### Step 5.3 — Verify Log Ingestion for a Specific Namespace

Deploy a temporary pod to generate a workload log entry:

```bash
kubectl run log-test --image=busybox --restart=Never \
  -- sh -c 'echo "AKS-GKE lab log entry $(date)" && sleep 5'
```

Wait 60 seconds, then query for the log:

```bash
# View the pod log locally first
kubectl logs log-test
```

2. In **Logs Explorer**, run:

```
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"
resource.labels.pod_name="log-test"
```

**Expected result:** The `AKS-GKE lab log entry` message appears in Cloud
Logging, confirming that workload log forwarding is active for the cluster.

Clean up:

```bash
kubectl delete pod log-test
```

> **gcloud equivalent — query logs via the CLI:**
> ```bash
> gcloud logging read \
>   "resource.type=k8s_container AND resource.labels.cluster_name=${CLUSTER} AND resource.labels.pod_name=log-test" \
>   --project=${PROJECT} \
>   --limit=5 \
>   --format='table(timestamp,textPayload)'
> ```
>
> **REST API equivalent — query logs via the Logging API:**
> ```bash
> curl -s -X POST \
>   "https://logging.googleapis.com/v2/entries:list" \
>   -H "Authorization: Bearer $TOKEN" \
>   -H "Content-Type: application/json" \
>   -d "{
>     \"resourceNames\": [\"projects/${PROJECT}\"],
>     \"filter\": \"resource.type=k8s_container resource.labels.cluster_name=${CLUSTER}\",
>     \"orderBy\": \"timestamp desc\",
>     \"pageSize\": 5
>   }" | jq '.entries[] | {timestamp: .timestamp, message: .textPayload}'
> ```

---

## Phase 6 — Explore Cloud Monitoring [MANUAL]

The module enables **Managed Prometheus** for the attached cluster. Google
Cloud Managed Service for Prometheus scrapes metrics from the AKS cluster
and makes them available in Cloud Monitoring without requiring a self-managed
Prometheus stack.

### Step 6.1 — View Cluster Metrics in Metrics Explorer

1. In the Google Cloud console, navigate to **Monitoring > Metrics Explorer**.
2. Click **Select a metric**.
3. In the search box, type `kubernetes` and select the metric resource type
   **Kubernetes Container**.
4. Select the metric **CPU request utilization**.
5. In the **Filter** section, add a filter for
   `resource.labels.cluster_name = azure-aks-cluster`.
6. Click **Apply**.

**Expected result:** A time-series chart appears showing CPU request
utilization for containers running on the AKS cluster. Metrics stream into
Cloud Monitoring via the Managed Prometheus collector installed as part of
the platform version bootstrap.

### Step 6.2 — Explore the Kubernetes Engine Dashboard

1. In the Google Cloud console, navigate to **Monitoring > Dashboards**.
2. Click **All Dashboards** and search for **Kubernetes Engine**.
3. Open the **Kubernetes Engine Overview** dashboard.
4. Scroll to find the **azure-aks-cluster** entry under the cluster list.
5. Review the node, pod, and container metrics displayed.

**Expected result:** The AKS cluster appears alongside native GKE clusters
in the Kubernetes Engine dashboard, providing a unified multi-cloud
monitoring view from a single pane of glass.

### Step 6.3 — View Node-Level Metrics

```bash
kubectl top nodes
```

**Expected result:** CPU and memory utilization is shown per node. This
data flows from the Managed Prometheus collector on the cluster to Cloud
Monitoring.

```bash
kubectl top pods --all-namespaces
```

**Expected result:** Per-pod resource utilization is visible, consistent
with the metrics shown in Cloud Monitoring.

> **gcloud equivalent — list available metric descriptors for the cluster:**
> ```bash
> gcloud monitoring metrics list \
>   --filter="metric.type:kubernetes.io/node" \
>   --project=${PROJECT} \
>   --format='table(metric.type)'
> ```
> Note: Reading time-series data points is not supported by the `gcloud` CLI;
> use the REST API or Metrics Explorer in the console for that purpose.
>
> **REST API equivalent — query metrics via the Monitoring API:**
> ```bash
> START=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
>         date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)
> END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
> curl -s \
>   "https://monitoring.googleapis.com/v3/projects/${PROJECT}/timeSeries?filter=metric.type%3D%22kubernetes.io%2Fnode%2Fcpu%2Fallocatable_utilization%22%20AND%20resource.labels.cluster_name%3D%22${CLUSTER}%22&interval.startTime=${START}&interval.endTime=${END}" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.timeSeries[] | {node: .resource.labels.node_name, points: (.points | length)}'
> ```

---

## Phase 7 — Deploy a Sample Workload [MANUAL]

### Step 7.1 — Deploy the Sample Application

Deploy a simple nginx workload to validate that `kubectl apply` works end-to-end
through Connect Gateway:

```bash
kubectl create namespace lab-workload

kubectl apply -n lab-workload -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  labels:
    app: nginx-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "250m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo
spec:
  selector:
    app: nginx-demo
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF
```

### Step 7.2 — Verify the Deployment

```bash
kubectl get deployment -n lab-workload nginx-demo
```

Wait for the deployment to be ready:

```bash
kubectl rollout status deployment/nginx-demo -n lab-workload
```

**Expected result:** `deployment "nginx-demo" successfully rolled out`

### Step 7.3 — Verify Pod Distribution Across Nodes

```bash
kubectl get pods -n lab-workload -o wide
```

**Expected result:** Two nginx pods are Running and spread across different
AKS nodes (the `NODE` column). The pods are scheduled by the AKS control
plane; Connect Gateway routes the `kubectl` requests to it transparently.

### Step 7.4 — Retrieve the External IP

Azure provisions a load balancer for the `LoadBalancer` Service type. This
may take 1–2 minutes:

```bash
kubectl get service -n lab-workload nginx-demo --watch
```

Press **Ctrl+C** once an `EXTERNAL-IP` appears (not `<pending>`).

**Expected result:** An Azure public IP address is assigned to the Service.
Open `http://EXTERNAL-IP` in a browser to see the nginx welcome page,
confirming end-to-end connectivity to the workload on AKS.

### Step 7.5 — Verify Workload Logs Appear in Cloud Logging

1. Generate some traffic to the nginx service:

```bash
EXTERNAL_IP=$(kubectl get service -n lab-workload nginx-demo \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
for i in $(seq 1 10); do curl -s "http://${EXTERNAL_IP}" > /dev/null; done
```

2. In **Cloud Logging > Logs Explorer**, run:

```
resource.type="k8s_container"
resource.labels.cluster_name="azure-aks-cluster"
resource.labels.namespace_name="lab-workload"
resource.labels.container_name="nginx"
```

**Expected result:** Nginx access log entries appear in Cloud Logging within
1–2 minutes of the traffic being generated, confirming that workload logs
from the `lab-workload` namespace are forwarded to Cloud Logging.

---

## Phase 8 — Explore Access Control [MANUAL]

### Step 8.1 — Understand the Authorization Model

GKE Attached Clusters uses a two-layer authorization model:

1. **Connect Gateway IAM** — Controls who can send `kubectl` requests to the
   cluster through the Connect Gateway API. Requires the
   `roles/gkehub.gatewayEditor` (or `gatewayAdmin`) role.

2. **Kubernetes RBAC** — Controls what operations an authenticated identity
   can perform on Kubernetes resources. The `trusted_users` variable binds
   the listed identities to the `cluster-admin` ClusterRole automatically.

### Step 8.2 — View the Current RBAC Bindings

```bash
kubectl get clusterrolebindings | grep -E "NAME|cluster-admin|gke"
```

```bash
kubectl describe clusterrolebinding cluster-admin-binding 2>/dev/null || \
  kubectl get clusterrolebinding -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects: .subjects}'
```

**Expected result:** A cluster-admin binding exists for the identities listed
in `trusted_users`. These users can perform all Kubernetes operations through
Connect Gateway.

### Step 8.3 — Grant Connect Gateway Access to a Team Member

To allow another Google identity to access the cluster via `kubectl`, two
things are needed: a GCP IAM binding and a Kubernetes RBAC binding.

**Step A — Grant GCP IAM access (Connect Gateway editor):**

1. In the Google Cloud console, navigate to **IAM & Admin > IAM**.
2. Click **Grant Access**.
3. Enter the team member's email address.
4. Add the role **GKE Hub Gateway Editor**
   (`roles/gkehub.gatewayEditor`).
5. Click **Save**.

**gcloud equivalent:**
```bash
gcloud projects add-iam-policy-binding ${PROJECT} \
  --member="user:team-member@example.com" \
  --role="roles/gkehub.gatewayEditor"
```

**Step B — Grant Kubernetes RBAC access:**

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: team-member-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: User
  name: team-member@example.com
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Expected result:** The team member can authenticate via `gcloud` and run
read-only `kubectl` commands against the AKS cluster through Connect Gateway,
without needing direct network access to the Azure API server.

### Step 8.4 — Verify Your Own Admin Access

```bash
kubectl auth can-i create deployment --namespace lab-workload
kubectl auth can-i delete pod --namespace lab-workload
kubectl auth can-i get secret --all-namespaces
```

**Expected result:** All three commands return `yes`, confirming that your
identity has cluster-admin access granted by the `trusted_users` binding.

> **gcloud equivalent — check fleet membership IAM policy:**
> ```bash
> gcloud container fleet memberships get-iam-policy ${CLUSTER} \
>   --project=${PROJECT} \
>   --format='yaml(bindings)'
> ```
>
> **REST API equivalent — check fleet membership IAM policy:**
> ```bash
> curl -s -X POST \
>   "${HUB_BASE}/projects/${PROJECT}/locations/global/memberships/${CLUSTER}:getIamPolicy" \
>   -H "Authorization: Bearer $TOKEN" \
>   | jq '.bindings[] | {role: .role, members: .members}'
> ```

---

## Phase 9 — Advanced Features [MANUAL]

### Step 9.1 — Verify the OIDC Federation

The AKS cluster's OIDC issuer is the trust anchor for the GKE Attached
Clusters registration. Terraform enables `oidc_issuer_enabled = true`
on the AKS cluster so that Google Cloud can fetch the public JWKS directly
from the AKS OIDC endpoint.

**View the configured OIDC issuer URL:**

```bash
# gcloud
gcloud container attached clusters describe ${CLUSTER} \
  --location=${REGION} \
  --project=${PROJECT} \
  --format='yaml(oidcConfig)'

# REST API
curl -s \
  "${MULTICLOUD_BASE}/projects/${PROJECT}/locations/${REGION}/attachedClusters/${CLUSTER}" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.oidcConfig'
```

**Expected result:** The `issuerUrl` field matches the AKS OIDC issuer URL
(format: `https://oidc.prod-aks.azure.com/<tenant-id>/<cluster-id>/`).
Google Cloud uses this URL to validate tokens issued by the AKS API server,
enabling Connect Gateway to verify the identity of `kubectl` callers.

### Step 9.2 — List Available Platform Versions

Before upgrading the cluster, check which platform versions are available
for the target Kubernetes version:

```bash
# gcloud
gcloud container attached get-server-config \
  --location=${REGION} \
  --project=${PROJECT} \
  --format='yaml(validVersions)'

# REST API
curl -s \
  "${MULTICLOUD_BASE}/projects/${PROJECT}/locations/${REGION}:getServerConfig" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.attachedClusterVersions[] | select(.version | startswith("1.")) | {version: .version, eolDate: .endOfLifeDate}'
```

**Expected result:** A list of supported platform versions appears, each
with an optional end-of-life date. Use this output to plan upgrades before
a version reaches end of life.

### Step 9.3 — Configure IAM Roles for Least-Privilege Access

In production, restrict access to attached cluster operations using these
purpose-built roles:

| Role | Purpose |
|---|---|
| `roles/gkemulticloud.viewer` | Read-only view of attached cluster resources |
| `roles/gkemulticloud.editor` | Create and update attached clusters |
| `roles/gkemulticloud.admin` | Full control including delete |
| `roles/gkehub.viewer` | View fleet memberships |
| `roles/gkehub.editor` | Manage fleet memberships |
| `roles/gkehub.gatewayViewer` | Read-only Connect Gateway access |
| `roles/gkehub.gatewayEditor` | Read-write Connect Gateway access |
| `roles/gkehub.gatewayAdmin` | Full Connect Gateway access |

**Grant a read-only fleet viewer role:**

1. In the Google Cloud console, navigate to **IAM & Admin > IAM**.
2. Click **Grant Access**.
3. Enter the user or service account email.
4. Add the roles **GKE Multi-Cloud Viewer** and **GKE Hub Viewer**.
5. Click **Save**.

**gcloud equivalent:**
```bash
gcloud projects add-iam-policy-binding ${PROJECT} \
  --member="user:USER_EMAIL" \
  --role="roles/gkemulticloud.viewer"

gcloud projects add-iam-policy-binding ${PROJECT} \
  --member="user:USER_EMAIL" \
  --role="roles/gkehub.viewer"
```

**Expected result:** The user can view the attached cluster in the console
and via API but cannot modify the registration, trigger upgrades, or
access the cluster via Connect Gateway.

### Step 9.4 — Review Audit Logs for Cluster Operations

Every API call to `gkemulticloud.googleapis.com` and `gkehub.googleapis.com`
generates an entry in Cloud Audit Logs.

1. In the Google Cloud console, navigate to **Logging > Logs Explorer**.
2. In the query editor, enter:

```
protoPayload.serviceName=("gkemulticloud.googleapis.com" OR "gkehub.googleapis.com")
```

3. Click **Run Query**.

**gcloud equivalent:**
```bash
gcloud logging read \
  'protoPayload.serviceName=("gkemulticloud.googleapis.com" OR "gkehub.googleapis.com")' \
  --project=${PROJECT} \
  --limit=10 \
  --format='table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail,protoPayload.status.code)'
```

4. Expand individual entries and review:
   - `protoPayload.methodName` — the API method called (e.g.
     `google.cloud.gkemulticloud.v1.AttachedClusters.CreateAttachedCluster`)
   - `protoPayload.authenticationInfo.principalEmail` — the caller identity
   - `resource.labels.cluster_name` — the cluster affected
   - `timestamp` and `protoPayload.status`

**Expected result:** Audit entries are visible for the Terraform provisioning
operations (cluster registration, feature enablement), confirming that all
control-plane operations are logged automatically with no additional
configuration.

### Step 9.5 — Import an Existing Cluster

If you already have an AKS cluster and want to register it without recreating
it, GKE Attached Clusters supports an import flow. The import manifest
installs the bootstrap components onto the existing cluster:

```bash
# Generate an import manifest for an existing cluster
gcloud container attached clusters generate-install-manifest \
  --location="${REGION}" \
  --platform-version="1.34.0-gke.1" \
  --cluster=existing-aks-cluster \
  --format=json \
  --project="${PROJECT}" \
  | jq -r '.manifest' > install-manifest.yaml

# Apply the manifest to the existing cluster (using its own kubeconfig)
kubectl apply --kubeconfig=existing-cluster.kubeconfig -f install-manifest.yaml
```

After the manifest is applied, register the cluster:

```bash
gcloud container attached clusters register existing-aks-cluster \
  --location="${REGION}" \
  --platform-version="1.34.0-gke.1" \
  --distribution=aks \
  --oidc-issuer-url="https://oidc.prod-aks.azure.com/TENANT_ID/CLUSTER_ID/" \
  --project="${PROJECT}" \
  --fleet-project="${PROJECT}"
```

**Expected result:** The existing cluster appears in the GKE Clusters view
with **Type: Attached** without any disruption to workloads running on it.

### Step 9.6 — Clean Up the Lab Workload

When you have finished exploring, remove the sample workload:

```bash
kubectl delete namespace lab-workload
```

**Expected result:** The `lab-workload` namespace and all its resources
(Deployment, Service, pods) are deleted. The Azure load balancer is released.

---

## Phase 10 — Destroy Infrastructure [AUTOMATED]

When the lab is complete, destroy all resources to avoid ongoing charges in
both Azure and Google Cloud:

```bash
cd modules/AKS_GKE
tofu destroy
```

**Expected destruction order:**

| Resource | Typical time |
|---|---|
| GKE Hub fleet registration | 1–2 minutes |
| Bootstrap Helm chart uninstall | 1–2 minutes |
| AKS cluster deletion | 5–10 minutes |
| Azure Resource Group deletion | 1–2 minutes |

> **Note:** `tofu destroy` will prompt for confirmation before deleting
> resources. Type `yes` to proceed. All Azure and GCP resources created
> by the module are removed; your GCP project and Azure subscription
> themselves are not affected.

---

## Summary

The table below recaps every action in the lab, its phase, and whether it is
automated by the `AKS_GKE` Terraform module or performed manually.

| Action | Phase | Automated |
|---|---|---|
| Enable GCP APIs (gkemulticloud, gkeconnect, connectgateway, anthos, logging, monitoring, gkehub) | 1 | Yes — `main.tf` |
| Create Azure Resource Group | 1 | Yes — `main.tf` |
| Deploy AKS cluster with OIDC issuer | 1 | Yes — `main.tf` |
| Assign Network Contributor role to AKS identity | 1 | Yes — `main.tf` |
| Fetch GKE Attached Clusters install manifest | 1 | Yes — `attached-install-manifest` module |
| Install bootstrap Helm chart onto AKS cluster | 1 | Yes — `attached-install-manifest` module |
| Register AKS cluster in GKE Hub as attached cluster | 1 | Yes — `main.tf` |
| Enable Cloud Logging (system components + workloads) | 1 | Yes — `main.tf` |
| Enable Managed Prometheus monitoring | 1 | Yes — `main.tf` |
| Grant cluster-admin to trusted_users | 1 | Yes — `main.tf` |
| Verify cluster appears in GKE console | 2 | No — console verification |
| Verify fleet membership | 2 | No — console verification |
| Verify logging and monitoring enabled in cluster details | 2 | No — console verification |
| Install kubectl and gke-gcloud-auth-plugin | 3 | No — local tool installation |
| Configure kubectl via Connect Gateway | 3 | No — `gcloud` command |
| Verify cluster connectivity and list nodes | 3 | No — `kubectl` commands |
| View fleet feature status | 4 | No — console verification |
| Inspect GKE Connect agent pod | 4 | No — `kubectl` commands |
| Inspect managed components namespace | 4 | No — `kubectl` commands |
| View system component logs in Cloud Logging | 5 | No — Logs Explorer |
| View workload logs in Cloud Logging | 5 | No — Logs Explorer |
| Verify log ingestion with a test pod | 5 | No — `kubectl` and Logs Explorer |
| View cluster metrics in Metrics Explorer | 6 | No — Cloud Monitoring console |
| Explore Kubernetes Engine dashboard | 6 | No — Cloud Monitoring console |
| View node and pod resource utilization | 6 | No — `kubectl top` commands |
| Deploy nginx workload via Connect Gateway | 7 | No — `kubectl apply` |
| Verify workload pods and external IP | 7 | No — `kubectl` commands |
| Verify workload logs appear in Cloud Logging | 7 | No — Logs Explorer |
| Review authorization model and RBAC bindings | 8 | No — `kubectl` and console |
| Grant Connect Gateway access to a team member | 8 | No — IAM and `kubectl` |
| Verify admin access with `kubectl auth can-i` | 8 | No — `kubectl` command |
| Verify OIDC federation configuration | 9 | No — API inspection |
| List available platform versions | 9 | No — API query |
| Configure IAM roles for least-privilege access | 9 | No — IAM & Admin console |
| Review audit logs for cluster operations | 9 | No — Cloud Logging |
| Import an existing cluster (awareness) | 9 | No — reference only |
| Delete lab workload namespace | 9 | No — `kubectl delete` |
| Destroy all Terraform-managed resources | 10 | Yes — `tofu destroy` |
