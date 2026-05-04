# Kubernetes / Container Platform

Three of five modules deploy GKE; two register a non-GCP Kubernetes cluster into a GCP fleet. This page covers the Kubernetes-specific configuration common to all of them.

## Cluster modes

- **GKE Standard** — `modules/Istio_GKE/gke.tf`, `modules/MC_Bank_GKE/gke.tf`, and `modules/Bank_GKE/gke.tf` (Standard config).
- **GKE Autopilot** — `modules/Bank_GKE/gke.tf` (toggle via variable). Pods bill per-second; node-pool sizing is managed by Google.
- **AKS** — `modules/AKS_GKE/main.tf` (Azure Kubernetes Service).
- **EKS** — `modules/EKS_GKE/main.tf` + `vpc.tf` + `iam.tf` (AWS EKS).

`var.create_cluster = false` (Bank_GKE) reads `data "google_container_cluster.existing_cluster"` and skips creating the cluster, so the module installs onto an existing one.

## Release channels

GKE clusters set `release_channel`, allowing continuous delivery of GKE control-plane upgrades by Google. The `/maintain` workflow in `AGENTS.md` covers promoting between channels (`REGULAR` → `STABLE`).

## Node pool service accounts

Node pools in `modules/Istio_GKE/gke.tf`, `modules/Bank_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf` use a dedicated service account with only:

- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`
- `roles/monitoring.viewer`
- `roles/stackdriver.resourceMetadata.writer`
- `roles/artifactregistry.reader`

Not the Compute Engine default SA, and explicitly not `roles/owner` or `roles/editor`. The [devsecops](../practices/devsecops.md) practice page audits exactly this list.

## Node hardening

The modules do not currently enable Shielded Nodes (Secure Boot, vTPM, integrity monitoring) or Binary Authorization. These are deliberate omissions for lab simplicity — a production hardening path would add `shielded_instance_config` blocks to `gke.tf` and a `google_binary_authorization_policy` resource. See [security](./security.md) for the full hardening checklist.

Pod Security Admission (the PSP replacement in Kubernetes 1.25+) is not configured in the current modules. The namespace-level `PodSecurity` labels would be applied via a `kubernetes_manifest` resource following the existing workload-deploy pattern.

## VPC-native networking

GKE clusters use IP alias ranges via `ip_allocation_policy` in `gke.tf`, with secondary ranges defined in `network.tf` for pods and services. See [networking-zero-trust](./networking-zero-trust.md).

## Workload Identity

Bank_GKE and MC_Bank_GKE enable Workload Identity via a `dynamic "workload_identity_config"` block in `gke.tf`. This allows Bank of Anthos pods to reach Cloud Spanner / Cloud SQL without mounting service-account key files — the pod's Kubernetes SA is mapped to a GCP SA at the IAM level. The `/security` workflow in `AGENTS.md` flags this as a verification step.

## Multi-cluster

`modules/MC_Bank_GKE/gke.tf` declares `google_container_cluster.gke_cluster` with `for_each = local.cluster_configs` (up to 4 clusters). The four `kubernetes` provider aliases (`cluster1`–`cluster4`) are statically defined. Adding a fifth cluster requires adding a new alias because OpenTofu does not support `for_each`-generated provider configurations. The practical workaround is to pre-define a maximum number of provider aliases (e.g., 6) with conditional activation, accepting that unused aliases are no-ops.

## Spot VMs in lab clusters

`scripts/gcp-istio-security/` and `scripts/gcp-istio-traffic/` default to Spot-backed node pools — ~70% cheaper, interruption-tolerant, appropriate for ephemeral training. See [finops](../practices/finops.md).

## Cluster credentials

Every GKE module emits a copy-pastable `cluster_credentials_cmd` output (`SKILLS.md` §3.5). Attached clusters document the equivalent `gcloud container attached clusters get-credentials ...` in their module READMEs.
