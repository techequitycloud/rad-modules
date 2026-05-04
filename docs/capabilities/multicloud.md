# Multicloud

The repo's `AKS_GKE` and `EKS_GKE` modules implement the canonical "register a non-GCP cluster as a first-class GCP fleet member" pattern, plus a VM-migration helper.

## GKE Attached Clusters

| Module | Cloud | What it provisions |
|---|---|---|
| `modules/AKS_GKE/` | Microsoft Azure | AKS cluster + Azure VNet (inline in `main.tf`) + GCP Fleet membership + GKE Connect agent via Helm |
| `modules/EKS_GKE/` | AWS | EKS cluster + AWS VPC (`vpc.tf`) + AWS IAM roles for EKS (`iam.tf`) + GCP Fleet membership + GKE Connect agent via Helm |

Both modules enable the same set of GCP APIs covering `gkemulticloud`, `gkeconnect`, `connectgateway`, `cloudresourcemanager`, `anthos`, `monitoring`, `logging`, `gkehub`, `opsconfigmonitoring`, and `kubernetesmetadata` (full list in `AGENTS.md` `/attached`).

The Fleet mechanics (Connect Agent installer submodule, Connect Gateway, ACM) are documented in [hybrid-cloud-fleet](./hybrid-cloud-fleet.md).

## Optional Anthos Service Mesh

`modules/AKS_GKE/modules/attached-install-mesh/` and the EKS equivalent install ASM on the attached cluster. Not invoked automatically — callers opt in. See [service-mesh](./service-mesh.md).

## Multi-cluster within GCP

`modules/MC_Bank_GKE/` is the GCP-only equivalent of the same pattern: multiple GKE clusters across regions, joined by fleet-wide Cloud Service Mesh, fronted by Multi-Cluster Ingress and Multi-Cluster Services behind a single global HTTPS LB. It is the reference for extending the same model to a true multi-cloud topology when combined with attached clusters.

## Resilience boundary

Attached clusters are independent Kubernetes clusters — if GCP control-plane connectivity is lost, the AKS or EKS workloads continue running. GCP-dependent features (Multi-Cluster Ingress health checks, Connect Gateway API access, ASM managed control-plane updates) will be degraded or unavailable until connectivity is restored, but in-cluster traffic and the local Kubernetes control plane are unaffected.

## Egress costs and latency

Cross-cloud traffic (e.g., a pod on EKS calling a service on GKE via MCS) traverses public internet paths and incurs egress charges from both AWS and GCP. For production multi-cloud topologies this cost can be significant. Use VPN or Direct Connect / Cloud Interconnect for predictable latency and to reduce egress fees. See [finops](../practices/finops.md).

## Credentials hygiene across clouds

`AGENTS.md` `/attached` rule: never put non-GCP credentials in Terraform defaults.

- Azure: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`
- AWS: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`

Sourced from the environment at apply time. See [devsecops](../practices/devsecops.md).

## VM-to-Container migration

`scripts/gcp-m2c-vm/gcp-m2c-vm.sh` walks through Migrate-to-Containers for a Linux VM workload. See [application-modernization](./application-modernization.md).

## Documentation depth

Each attached module ships its own deep-dive walkthrough:

- `modules/AKS_GKE/AKS_GKE.md` (~70KB)
- `modules/EKS_GKE/EKS_GKE.md` (~73KB)

These cover the Azure / AWS networking and IAM model required to attach the cluster, the Connect Gateway flow, and the operational equivalents to `gcloud container clusters get-credentials`.
