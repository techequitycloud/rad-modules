# Multicloud

The repository's `AKS_GKE` and `EKS_GKE` modules implement the canonical "register a non-GCP cluster as a first-class GCP fleet member" pattern, plus a VM-migration helper. This is the foundation for unified multicloud Kubernetes management from a single GCP control plane.

## GKE Attached Clusters via Fleet

Both attached-cluster modules register a cluster on another cloud as a **GKE Attached Cluster**, so it appears in the GCP Console under *Kubernetes Engine > Clusters* alongside native GKE clusters and can be managed by the same Fleet APIs (`AGENTS.md` `/attached` workflow).

| Module | Cloud | What it provisions |
|---|---|---|
| `modules/AKS_GKE/` | Microsoft Azure | AKS cluster + Azure VNet (inline in `main.tf`) + GCP Fleet membership + GKE Connect agent via Helm |
| `modules/EKS_GKE/` | AWS | EKS cluster + AWS VPC (`vpc.tf`) + AWS IAM roles for EKS (`iam.tf`) + GCP Fleet membership + GKE Connect agent via Helm |

Both modules enable the same set of GCP APIs (`AGENTS.md` `/attached` workflow):

```
gkemulticloud.googleapis.com
gkeconnect.googleapis.com
connectgateway.googleapis.com
cloudresourcemanager.googleapis.com
anthos.googleapis.com
monitoring.googleapis.com
logging.googleapis.com
gkehub.googleapis.com
opsconfigmonitoring.googleapis.com
kubernetesmetadata.googleapis.com
```

## Connect agent installer

Each attached-cluster module wraps a nested submodule, `modules/AKS_GKE/modules/attached-install-manifest/` (and the EKS equivalent), that:

1. Fetches the GKE Attached Cluster bootstrap manifest via `data "google_container_attached_install_manifest"`.
2. Writes it as a Helm chart (`local_file`).
3. Applies it to the attached cluster via `helm_release`.

Once this finishes, the cluster appears in the GCP Console and can be reached through Connect Gateway without exposing a public Kubernetes API endpoint.

## Optional Anthos Service Mesh on attached clusters

`modules/AKS_GKE/modules/attached-install-mesh/` and the EKS equivalent install ASM on the attached cluster. Per `AGENTS.md` `/attached`: *"Not invoked by the parent module automatically. Invoke it from your own root module if you want ASM on the attached cluster."* This keeps the base offering minimal and lets adopters layer mesh on demand.

## Multi-cluster routing within GCP

`modules/MC_Bank_GKE/` is the same pattern within GCP — multiple GKE clusters across regions, joined by fleet-wide Cloud Service Mesh, fronted by a Multi-Cluster Ingress / Multi-Cluster Services pair behind a single global HTTPS load balancer (`modules/MC_Bank_GKE/glb.tf`, `modules/MC_Bank_GKE/mcs.tf`, `modules/MC_Bank_GKE/asm.tf`). It is the reference for how to extend the same "single mesh, many clusters" model to a true multi-cloud topology when combined with attached clusters.

## Credentials hygiene across clouds

`AGENTS.md` `/attached` workflow rule: **never** put non-GCP credentials in Terraform defaults.

- Azure: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`
- AWS: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`

Credentials are sourced from the environment so the same module source is portable across deployment environments without per-environment forks.

## VM-to-Container migration helper

`scripts/gcp-m2c-vm/gcp-m2c-vm.sh` is a hands-on lab for **Migrate to Containers**, walking through migration of a Linux VM workload from another environment into a containerized form runnable on GKE. This is the on-ramp for teams whose multicloud strategy includes lifting and shifting VM workloads to a unified Kubernetes target.

## Documentation surface

Each attached module ships its own deep-dive walkthrough:

- `modules/AKS_GKE/AKS_GKE.md` (~70KB)
- `modules/EKS_GKE/EKS_GKE.md` (~73KB)

These cover the Azure / AWS networking and IAM model required to attach the cluster, the Connect Gateway flow, and the operational equivalents to `gcloud container clusters get-credentials` (which becomes `gcloud container attached clusters get-credentials <cluster> --location=<region> --project=<project-id>`).
