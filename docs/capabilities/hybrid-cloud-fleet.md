# Hybrid Cloud, Fleet, and Anthos

Anthos / GKE Hub / Fleet are the substrate that lets a single control plane manage GKE, AKS, and EKS clusters. This page covers the Fleet primitives the modules use.

## GKE Hub membership

Every cluster the modules provision becomes a Fleet member:

- `modules/Bank_GKE/hub.tf` — `google_gke_hub_membership` for a single GKE cluster.
- `modules/MC_Bank_GKE/hub.tf` — one membership per cluster (`for_each`).
- `modules/AKS_GKE/main.tf` and `modules/EKS_GKE/main.tf` — attached cluster registration via `google_container_attached_cluster`.

## Fleet features

- **Service Mesh** — `google_gke_hub_feature "service_mesh"` enables managed Istio across the fleet (`modules/Bank_GKE/asm.tf`, `modules/MC_Bank_GKE/asm.tf`). See [service-mesh](./service-mesh.md).
- **Multi-Cluster Ingress** — `google_gke_hub_feature "multiclusteringress_feature"` in `modules/MC_Bank_GKE/deploy.tf` enables MCI/MCS routing across the fleet.
- **Anthos Config Management** — optional flag in `modules/Bank_GKE/`, installed via a `null_resource` following the existing pattern (`AGENTS.md` `/bank` workflow).

## Anthos Config Management and GitOps

ACM provides two capabilities when enabled:

1. **Config Sync** — continuously syncs Kubernetes manifests from a Git repository to fleet clusters. This is the GitOps on-ramp: a commit to the config repo becomes a cluster state change without a manual `kubectl apply`.
2. **Policy Controller** — enforces `OPA Gatekeeper`-based policies (based on Constraint Framework) across all fleet clusters from a single policy repository. Violations are reported centrally in Cloud Console.

In this repo ACM is opt-in for `Bank_GKE`. Enabling it for `MC_Bank_GKE` would allow fleet-wide policy enforcement across all regions from a single Git source of truth.

## Workload Identity Federation across clouds

For attached clusters (`AKS_GKE`, `EKS_GKE`), the Connect Agent provides the channel back to GCP, but workload identity operates differently per cloud:

- **GKE** — native Workload Identity binds a Kubernetes SA to a GCP SA via `workload_identity_config`.
- **AKS** — Azure AD Workload Identity (OIDC federation) or the Connect Agent's impersonation path; credentials are sourced from `ARM_*` environment variables at apply time.
- **EKS** — IAM Roles for Service Accounts (IRSA) handles the AWS side; `AWS_*` environment variables supply the GCP-side credentials at apply time.

The deep-dive walkthroughs in `modules/AKS_GKE/AKS_GKE.md` and `modules/EKS_GKE/EKS_GKE.md` document the cloud-specific steps for each path.

## Connect Agent installer

Attached clusters need the GKE Connect agent installed inside the cluster to talk back to GCP. `modules/AKS_GKE/modules/attached-install-manifest/` and the EKS equivalent:

1. Fetch the bootstrap manifest via `data "google_container_attached_install_manifest"`.
2. Write it as a Helm chart (`local_file`).
3. Apply it via `helm_release`.

Once this finishes, the cluster appears in the GCP Console under *Kubernetes Engine > Clusters* alongside native GKE clusters.

## Connect Gateway

Cluster API access for attached clusters goes through Connect Gateway rather than exposing the AKS / EKS API endpoint publicly. The `gcloud container attached clusters get-credentials ...` command in the attached-cluster READMEs returns a kubeconfig that uses Connect Gateway as the API server proxy.

## Why this matters

Combining MCI / MCS fleet features (`MC_Bank_GKE`) with attached cluster registration (`AKS_GKE`, `EKS_GKE`) is the pattern for hybrid / multi-cloud Kubernetes from a single GCP control plane. The repo ships each piece independently but the combined topology is documented in `MC_Bank_GKE.md` and the attached-cluster deep-dives.
