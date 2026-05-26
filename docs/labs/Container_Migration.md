# Google Cloud Migrate to Containers — Lab Guide

📖 **[Configuration Guide](https://github.com/techequitycloud/rad-modules/blob/main/modules/Container_Migration/LAB_GUIDE.md)**

This lab guide walks you through containerising VM-based workloads using **Google Cloud
Migrate to Containers (M2C)** and deploying the migrated containers to **Google Kubernetes
Engine (GKE)**. You will use the `mcdc` CLI to assess source VMs, the `m2c` CLI to copy
filesystems and generate Kubernetes manifests, and Skaffold to build, push, and deploy
the migrated containers.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Lab Setup](#4-lab-setup)
5. [Exercise 1 — Assess Workloads for Containerisation](#exercise-1--assess-workloads-for-containerisation)
6. [Exercise 2 — Migrate the PostgreSQL VM to a Container](#exercise-2--migrate-the-postgresql-vm-to-a-container)
7. [Exercise 3 — Migrate the Tomcat VM to a Container](#exercise-3--migrate-the-tomcat-vm-to-a-container)
8. [Exercise 4 — Deploy Migrated Containers to GKE](#exercise-4--deploy-migrated-containers-to-gke)
9. [Exercise 5 — Scale and Update the Tomcat Deployment](#exercise-5--scale-and-update-the-tomcat-deployment)
10. [Cleanup](#10-cleanup)
11. [Reference](#11-reference)

---

## 1. Overview

### What Is Google Cloud Migrate to Containers?

**Migrate to Containers (M2C)** is a Google Cloud tool that automates the replatforming
of Linux VM workloads to containers. It copies the VM filesystem, analyses it with the
`mcdc` CLI, generates Dockerfiles and Kubernetes manifests, and migrates persistent
data to GKE PersistentVolumes — all without requiring changes to application source code.

### Use Cases

| Use Case | Description |
|---|---|
| **VM-to-container replatforming** | Containerise Linux VMs automatically without code changes |
| **Stateful database migration** | Migrate PostgreSQL data directories to GKE PersistentVolumes |
| **CI/CD modernisation** | Use generated Skaffold manifests as the foundation for pipelines |
| **Horizontal pod autoscaling** | Scale migrated workloads automatically based on CPU demand |
| **Zero-downtime updates** | Configure rolling update strategies for migrated deployments |

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GCP Project                           │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │  mig-{id}-   │  │  mig-{id}-   │  │  mig-{id}-m2c │ │
│  │  postgres VM │  │   tomcat VM  │  │      VM       │ │
│  │ PostgreSQL14 │  │  Tomcat 10   │  │ m2c + Docker  │ │
│  │              │  │  PetClinic   │  │ kubectl+skaf. │ │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘ │
│         │ m2c copy        │ m2c copy          │         │
│         └─────────────────┴───────────────────┘         │
│                           │ skaffold run                 │
│                    ┌──────▼───────┐                      │
│                    │  GKE Cluster │                      │
│                    │ mig-{id}-gke │                      │
│                    │  3x e2-med   │                      │
│                    └─────────────┘                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │    mig-{id}-vpc  +  Firewall Rules               │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| `gcloud` CLI | Authenticated with `gcloud auth login` |
| GCP Project | Must exist with billing enabled |
| Service Account | Must hold `roles/owner` on the target project |

---

## 4. Lab Setup

Deploy the module to provision all infrastructure:

```bash
cd modules/Container_Migration
tofu init && tofu apply
```

Capture the VM and cluster names from outputs:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=$(tofu output -raw gke_cluster_location)
export POSTGRES_VM=$(tofu output -raw postgres_vm_name)
export TOMCAT_VM=$(tofu output -raw tomcat_vm_name)
export M2C_VM=$(tofu output -raw m2c_cli_vm_name)
export GKE_CLUSTER=$(tofu output -raw gke_cluster_name)
```

---

## Exercise 1 — Assess Workloads for Containerisation

Use the `mcdc` CLI on each source VM to determine containerisation suitability.

**PostgreSQL VM:**

```bash
gcloud compute ssh $POSTGRES_VM --project $PROJECT_ID --zone $ZONE_ID
sudo /assess_mcdc.sh
exit
```

**Tomcat VM:**

```bash
gcloud compute ssh $TOMCAT_VM --project $PROJECT_ID --zone $ZONE_ID
sudo /assess_mcdc.sh
exit
```

---

## Exercise 2 — Migrate the PostgreSQL VM to a Container

From the m2c-cli VM, copy the PostgreSQL filesystem, customise the migration plan,
migrate the data volume, and generate Kubernetes artifacts.

```bash
gcloud compute ssh $M2C_VM --project $PROJECT_ID --zone $ZONE_ID
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=<your-zone>
gcloud container clusters get-credentials $GKE_CLUSTER --zone=$ZONE_ID --project=$PROJECT_ID
mkdir ~/m2c-petclinic/postgresql && cd ~/m2c-petclinic/postgresql
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID -n $POSTGRES_VM -o postgres-fs --filters ~/filters.txt
m2c analyze -s postgres-fs -p linux-vm-container -o ./migration
sed -i 's/linux-system/postgres/g' migration/config.yaml
# Add endpoint and dataConfig.yaml — see full LAB_GUIDE.md
m2c migrate-data -i migration -n default
m2c generate -i ./migration -o ./artifacts
```

See [LAB_GUIDE.md](../../modules/Container_Migration/LAB_GUIDE.md) for complete step-by-step instructions.

---

## Exercise 3 — Migrate the Tomcat VM to a Container

```bash
mkdir ~/m2c-petclinic/tomcat && cd ~/m2c-petclinic/tomcat
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID -n $TOMCAT_VM -o tomcat-fs --filters ~/filters.txt
m2c analyze -s tomcat-fs -p linux-vm-container -o ./migration
sed -i 's/linux-system/tomcat/g' migration/config.yaml
# Add endpoint — see full LAB_GUIDE.md
m2c generate -i ./migration -o ./artifacts
```

---

## Exercise 4 — Deploy Migrated Containers to GKE

```bash
cd ~/m2c-petclinic/postgresql/artifacts
bash /postgres_deployment_fix.sh
skaffold run -d gcr.io/$PROJECT_ID

cd ~/m2c-petclinic/tomcat/artifacts
skaffold run -d gcr.io/$PROJECT_ID
kubectl get service
```

---

## Exercise 5 — Scale and Update the Tomcat Deployment

**Manual scale to 3 replicas:**

```bash
# Edit deployment_spec.yaml: replicas: 3
skaffold run -d gcr.io/$PROJECT_ID
kubectl get pods
```

**Horizontal Pod Autoscaler:**

```bash
kubectl autoscale deployment tomcat --cpu-percent=50 --min=2 --max=8
kubectl get hpa
```

**Rolling update strategy** — see [LAB_GUIDE.md](../../modules/Container_Migration/LAB_GUIDE.md).

---

## 10. Cleanup

```bash
cd modules/Container_Migration
tofu destroy
```

Manually delete container images in `gcr.io/$PROJECT_ID` if no longer needed.

---

## 11. Reference

- [Migrate to Containers docs](https://cloud.google.com/migrate/containers/docs)
- [m2c CLI reference](https://cloud.google.com/migrate/containers/docs/m2c-cli-reference)
- [Spring PetClinic](https://github.com/spring-petclinic/spring-framework-petclinic)
- [Skaffold docs](https://skaffold.dev/docs/)
- [GKE docs](https://cloud.google.com/kubernetes-engine/docs)
