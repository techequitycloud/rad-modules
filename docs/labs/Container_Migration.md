# Google Cloud Migrate to Containers — Lab Guide

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
10. [Troubleshooting](#10-troubleshooting)
11. [Cleanup](#11-cleanup)
12. [Reference](#12-reference)

---

## 1. Overview

### What Is Google Cloud Migrate to Containers?

**Migrate to Containers (M2C)** is a Google Cloud tool that automates the replatforming
of Linux VM workloads to containers. It copies the VM filesystem, analyses it to create a
migration plan, generates Dockerfiles and Kubernetes manifests, and migrates persistent
data to GKE PersistentVolumes — all without requiring changes to application source code.

### The Two CLIs

| CLI | Purpose |
|---|---|
| `mcdc` | **Assessment** — runs on the source VM to collect system data and generate a containerisation suitability report |
| `m2c` | **Migration** — runs on the migration workstation to copy filesystems, analyse workloads, customise migration plans, and generate Kubernetes artifacts |

### Three-Phase Migration Lifecycle

Migrate to Containers structures the modernisation journey into three phases:

| Phase | Steps |
|---|---|
| **1. Transformation** | Copy the source VM filesystem → analyse to create a migration plan → customise the plan → generate Dockerfiles and Kubernetes manifests |
| **2. Workload Deployment** | Build container images → push to a registry → deploy to GKE using Skaffold |
| **3. Maintenance** | Operate migrated workloads using native Kubernetes: scaling, rolling updates, and Horizontal Pod Autoscaling |

This lab covers all three phases end-to-end across two representative workloads: a stateful
PostgreSQL database and a stateless Apache Tomcat application server.

### Use Cases

| Use Case | Description |
|---|---|
| **VM-to-container replatforming** | Containerise Linux VMs automatically without code changes |
| **Stateful database migration** | Migrate PostgreSQL data directories to GKE PersistentVolumes |
| **CI/CD modernisation** | Use generated Skaffold manifests as the foundation for pipelines |
| **Horizontal pod autoscaling** | Scale migrated workloads automatically based on CPU demand |
| **Zero-downtime updates** | Configure rolling update strategies for migrated deployments |

### What You Will Learn

By the end of this lab you will be able to:

- Use `mcdc` to assess source VMs and interpret containerisation suitability reports
- Use `m2c copy` to extract a VM filesystem for analysis without disrupting the source VM
- Use `m2c analyze` to create a migration plan (`config.yaml`)
- Customise the migration plan with endpoint and persistent volume configuration
- Use `m2c migrate-data` to migrate stateful data to a GKE PersistentVolume
- Use `m2c generate` to produce Dockerfiles, Kubernetes manifests, and Skaffold configs
- Deploy migrated containers to GKE using Skaffold
- Configure Horizontal Pod Autoscaling and rolling update strategies on migrated workloads

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

The `m2c` CLI VM uses `rsync` over SSH (via `gcloud compute ssh`) to copy source VM filesystems
locally. Analysis runs entirely against the local copy — the source VM is **never modified or
stopped** during the migration process.

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

Allow 3–5 minutes for all VM startup scripts to complete before proceeding.

### Verify Tools on the m2c CLI VM

SSH into the migration workstation and confirm all required tools are installed:

```bash
gcloud compute ssh $M2C_VM --project $PROJECT_ID --zone $ZONE_ID
sudo /install_container_tools.sh
```

Expected output confirms `kubectl`, `skaffold`, `gke-gcloud-auth-plugin`, `m2c`, and `Docker`
are all present with `[✓]`. If any shows `[✗]`, wait a further 2 minutes and re-run — the
startup script may still be downloading tool binaries.

Exit the VM when done:

```bash
exit
```

---

## Exercise 1 — Assess Workloads for Containerisation

**Objective:** Use the `mcdc` CLI to collect system data from each source VM and generate
a containerisation suitability report before performing any migration work.

### How mcdc works

`mcdc` runs two steps on the source VM:

1. **Collect** — scans the running system for installed packages, active services, open ports,
   filesystem layout, and process configuration. Results are saved as a `.tar` archive under
   `/var/m4a/`.
2. **Analyse** — reads the archive and generates a suitability report (HTML) scoring each VM
   against migration journeys: GKE, GKE Autopilot, Cloud Run, and Compute Engine.

The `/assess_mcdc.sh` convenience script deployed to each source VM runs both steps automatically.

### What to look for in the report

The HTML report (`~/m2c/mcdc-report.html`) contains:

| Section | What it tells you |
|---|---|
| **Fit score** | Per-journey suitability rating (e.g. GKE, Cloud Run, Compute Engine) |
| **Blockers** | Issues that must be resolved before migration can succeed |
| **Risks** | Areas requiring attention after migration |
| **Detected services** | Running processes and their listening ports |

For this lab, both VMs should show no blockers for GKE containerisation. Pay attention to
the **detected ports** in the report — you will need them when configuring container endpoints
in Exercises 2 and 3.

### Assess the PostgreSQL VM

```bash
gcloud compute ssh $POSTGRES_VM --project $PROJECT_ID --zone $ZONE_ID
sudo /assess_mcdc.sh
```

Review the console output. You should see confirmation that data was collected and the
assessment report was written to `~/m2c/mcdc-report.html`. Note that PostgreSQL is detected
as listening on **port 5432** — you will configure this as the container endpoint in Exercise 2.

```bash
exit
```

### Assess the Tomcat VM

```bash
gcloud compute ssh $TOMCAT_VM --project $PROJECT_ID --zone $ZONE_ID
sudo /assess_mcdc.sh
```

Note that Tomcat is detected as listening on **port 8080** — for the container endpoint in
Exercise 3.

```bash
exit
```

---

## Exercise 2 — Migrate the PostgreSQL VM to a Container

**Objective:** Copy the PostgreSQL VM filesystem to the m2c CLI VM, analyse it to create a
migration plan, configure the database endpoint and persistent storage, migrate the data
volume to a GKE PersistentVolume, and generate Kubernetes deployment artifacts.

### Step 1 — Connect to the m2c CLI VM

```bash
gcloud compute ssh $M2C_VM --project $PROJECT_ID --zone $ZONE_ID
```

Set the required environment variables inside the VM session:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=<your-zone>                     # e.g. us-central1-a
export POSTGRES_VM=<your-postgres-vm-name>     # from: tofu output postgres_vm_name
export GKE_CLUSTER=<your-gke-cluster-name>    # from: tofu output gke_cluster_name
```

Authenticate `kubectl` against the GKE cluster:

```bash
gcloud container clusters get-credentials $GKE_CLUSTER --zone=$ZONE_ID --project=$PROJECT_ID
kubectl get nodes   # confirm the cluster is reachable before proceeding
```

### Step 2 — Copy the PostgreSQL filesystem

The `filters.txt` file on the m2c CLI VM lists directories to exclude from the copy operation
(ephemeral paths such as `/proc`, `/boot`, `/sys`, `/dev`, and `/var/log`). This reduces
transfer size and prevents migration of content that is irrelevant to the containerised workload.

```bash
cat ~/filters.txt   # review the exclusion list
mkdir -p ~/m2c-petclinic/postgresql && cd ~/m2c-petclinic/postgresql
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID -n $POSTGRES_VM -o postgres-fs --filters ~/filters.txt
```

`m2c copy` uses `rsync` over SSH to stream the filesystem to the local `postgres-fs/` directory.
The source VM continues running normally throughout this step. Expect the copy to take 2–4
minutes.

### Step 3 — Analyse the copied filesystem

```bash
m2c analyze -s postgres-fs -p linux-vm-container -o ./migration
```

The `linux-vm-container` plugin inspects the copied filesystem and creates the `migration/`
directory with two files:

| File | Purpose |
|---|---|
| `config.yaml` | The **migration plan** — defines the container image name, exposed endpoints, and data path configuration |
| `dataConfig.yaml` | **PersistentVolume configuration** — specifies which detected filesystem paths to migrate to GKE PersistentVolumeClaims |

Inspect both generated files before editing:

```bash
cat migration/config.yaml
cat migration/dataConfig.yaml
```

### Step 4 — Customise the migration plan

**Rename the container image** from the generic default to a meaningful name:

```bash
sed -i 's/linux-system/postgres/g' migration/config.yaml
```

**Add the PostgreSQL service endpoint.** The `endpoints` section in `config.yaml` defines
which ports the container exposes and how Kubernetes Services are created for the workload.
Open the migration plan:

```bash
nano migration/config.yaml
```

Locate the `endpoints` field and add the PostgreSQL port configuration:

```yaml
endpoints:
- port: 5432
  protocol: TCP
  name: postgres
```

Save and close (`Ctrl+O`, `Enter`, `Ctrl+X`).

### Step 5 — Configure the persistent data volume

`m2c analyze` auto-generates `dataConfig.yaml` when it detects stateful data directories.
This file determines which filesystem paths are moved to a GKE PersistentVolumeClaim rather
than baked into the container image.

```bash
nano migration/dataConfig.yaml
```

Review the auto-detected paths and ensure the PostgreSQL data directory
(`/var/lib/postgresql`) is included and configured with sufficient storage. The relevant
section should specify `ReadWriteOnce` access mode and at least `10Gi` of storage capacity.
Adjust the storage value if needed, then save and close.

### Step 6 — Migrate the data volume to GKE

`m2c migrate-data` creates the PersistentVolumeClaim in the target GKE cluster and copies
the PostgreSQL data directory into it. This is a live data migration — the PVC is bound and
populated before any container is deployed.

```bash
m2c migrate-data -i migration -n default
```

Verify the PVC was created and is bound:

```bash
kubectl get pvc -n default
```

The PostgreSQL PVC should show `Bound` status before you proceed to artifact generation.

### Step 7 — Generate Kubernetes artifacts

```bash
m2c generate -i ./migration -o ./artifacts
```

Inspect the generated artifacts:

```bash
ls artifacts/
cat artifacts/deployment_spec.yaml
cat artifacts/skaffold.yaml
```

The `artifacts/` directory contains:

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the container image from the copied filesystem |
| `deployment_spec.yaml` | Kubernetes StatefulSet and Service manifests |
| `skaffold.yaml` | Build and deploy configuration for Skaffold |

---

## Exercise 3 — Migrate the Tomcat VM to a Container

**Objective:** Copy the Tomcat VM filesystem, generate a migration plan, configure the HTTP
endpoint, and generate Kubernetes artifacts. No data migration is required — Tomcat serving
the Spring PetClinic WAR is stateless; persistent state lives in PostgreSQL.

### Step 1 — Create the Tomcat workspace

Continue inside the m2c CLI VM session (or SSH in again, re-exporting variables from
Exercise 2, Step 1):

```bash
mkdir -p ~/m2c-petclinic/tomcat && cd ~/m2c-petclinic/tomcat
```

### Step 2 — Copy the Tomcat filesystem

```bash
export TOMCAT_VM=<your-tomcat-vm-name>   # from: tofu output tomcat_vm_name
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID -n $TOMCAT_VM -o tomcat-fs --filters ~/filters.txt
```

### Step 3 — Analyse the Tomcat filesystem

```bash
m2c analyze -s tomcat-fs -p linux-vm-container -o ./migration
```

Inspect the generated migration plan:

```bash
cat migration/config.yaml
```

Note that `dataConfig.yaml` may not be generated for the Tomcat VM because the application
files under `/opt/tomcat` are part of the container image rather than a separate persistent
volume — this is the correct behaviour for a stateless web application.

### Step 4 — Customise the migration plan

**Rename the container image:**

```bash
sed -i 's/linux-system/tomcat/g' migration/config.yaml
```

**Add the Tomcat HTTP endpoint:**

```bash
nano migration/config.yaml
```

Add the HTTP service endpoint in the `endpoints` section:

```yaml
endpoints:
- port: 8080
  protocol: TCP
  name: http
```

Save and close.

### Step 5 — Generate Kubernetes artifacts

```bash
m2c generate -i ./migration -o ./artifacts
```

Inspect the artifacts:

```bash
ls artifacts/
cat artifacts/deployment_spec.yaml
```

Unlike the PostgreSQL migration, the generated `deployment_spec.yaml` uses a Kubernetes
**Deployment** (not a StatefulSet) and a **LoadBalancer Service** exposing port 8080 —
appropriate for a stateless, horizontally scalable web application.

---

## Exercise 4 — Deploy Migrated Containers to GKE

**Objective:** Build container images using Skaffold, push them to Container Registry, and
deploy both the PostgreSQL StatefulSet and the Tomcat Deployment to GKE.

### Step 1 — Deploy PostgreSQL

Navigate to the PostgreSQL artifacts and run the deployment validation script before deploying:

```bash
cd ~/m2c-petclinic/postgresql/artifacts
bash /postgres_deployment_fix.sh
```

The `postgres_deployment_fix.sh` script validates the generated `deployment_spec.yaml` to
ensure the StatefulSet selector labels are consistent with the pod template labels — a common
issue with auto-generated manifests.

Build the container image, push it to Container Registry, and deploy to GKE:

```bash
skaffold run -d gcr.io/$PROJECT_ID
```

Verify the PostgreSQL pod is running and the PVC is attached:

```bash
kubectl get pods -n default
kubectl get pvc -n default
```

Wait until the PostgreSQL pod shows `Running` status before deploying Tomcat — the
PetClinic application requires the database to be available on startup.

### Step 2 — Deploy Tomcat (PetClinic)

```bash
cd ~/m2c-petclinic/tomcat/artifacts
skaffold run -d gcr.io/$PROJECT_ID
```

Verify both workloads are running:

```bash
kubectl get pods -n default
kubectl get services -n default
```

### Step 3 — Access the Spring PetClinic application

Retrieve the external IP address of the Tomcat LoadBalancer service:

```bash
kubectl get service tomcat -n default
```

The `EXTERNAL-IP` column shows the provisioned load balancer address. Allow 1–2 minutes for
the IP to be assigned. Once available, open the following URL in your browser:

```
http://<EXTERNAL-IP>:8080/petclinic
```

The Spring PetClinic application should load, reading from and writing to the containerised
PostgreSQL database — both workloads were migrated from running VMs without any source code
changes.

---

## Exercise 5 — Scale and Update the Tomcat Deployment

**Objective:** Apply Kubernetes Day 2 operations to the migrated Tomcat workload: manual
scaling, Horizontal Pod Autoscaling (HPA), and a zero-downtime rolling update strategy.

### Manual scaling to 3 replicas

Edit the generated Tomcat deployment manifest to increase the replica count:

```bash
cd ~/m2c-petclinic/tomcat/artifacts
nano deployment_spec.yaml
```

Locate the `replicas` field in the Deployment spec and set it to `3`:

```yaml
spec:
  replicas: 3
```

Re-deploy with Skaffold and observe the pods being scheduled:

```bash
skaffold run -d gcr.io/$PROJECT_ID
kubectl get pods -n default -w
```

Press `Ctrl+C` once all three Tomcat pods reach `Running` status.

### Horizontal Pod Autoscaler

Remove the manual replica count and let GKE manage scaling automatically based on CPU
utilisation:

```bash
kubectl autoscale deployment tomcat \
  --cpu-percent=50 \
  --min=2 \
  --max=8 \
  --namespace=default

kubectl get hpa -n default
```

The HPA maintains between 2 and 8 replicas, scaling out when average CPU utilisation exceeds
50%. Allow ~90 seconds for metrics to populate, then observe the `TARGETS` column showing
current versus target CPU utilisation.

### Rolling update strategy

Configure a zero-downtime rolling update strategy so that new deployments replace pods
incrementally. Open `deployment_spec.yaml`:

```bash
nano deployment_spec.yaml
```

Add or update the `strategy` section within the Deployment `spec`:

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

| Field | Effect |
|---|---|
| `maxSurge: 1` | Allows one additional pod above the desired count during an update |
| `maxUnavailable: 0` | Ensures no existing pod is terminated until its replacement is healthy |

Apply the updated strategy and monitor the rollout:

```bash
skaffold run -d gcr.io/$PROJECT_ID
kubectl rollout status deployment/tomcat -n default
```

A successful rollout message confirms that all pods were replaced without downtime.

---

## 10. Troubleshooting

### m2c copy fails with an SSH or rsync error

Confirm the m2c CLI VM and source VMs are in the same VPC, the `allow-internal` firewall
rule is present, and the source VM is running:

```bash
gcloud compute instances list --project $PROJECT_ID --filter="status=RUNNING"
```

### m2c analyze produces no dataConfig.yaml for PostgreSQL

`dataConfig.yaml` is only auto-generated when the plugin detects stateful data directories.
If absent, create it manually in `migration/dataConfig.yaml` following the structure described
in Exercise 2, Step 5, specifying `/var/lib/postgresql` as the data path.

### PVC remains in Pending state after m2c migrate-data

Check for StorageClass availability and look at the PVC events for the root cause:

```bash
kubectl get storageclass
kubectl describe pvc -n default
```

If no default StorageClass is configured, specify `standard` explicitly in `dataConfig.yaml`.

### Skaffold fails with a Docker authentication error

Re-configure Docker credentials for Container Registry:

```bash
gcloud auth configure-docker
```

### PostgreSQL pod is in CrashLoopBackOff

View pod logs and events to identify the startup failure:

```bash
kubectl logs <postgres-pod-name> -n default
kubectl describe pod <postgres-pod-name> -n default
```

Verify that the PVC contains the expected PostgreSQL data directory:

```bash
kubectl exec -it <postgres-pod-name> -n default -- ls /var/lib/postgresql
```

### Tomcat cannot connect to PostgreSQL

Verify the PostgreSQL Service is reachable within the cluster and that the service name
matches the hostname configured in the application (`petclinic-postgres`):

```bash
kubectl get service -n default
kubectl exec -it <tomcat-pod-name> -n default -- \
  curl -s --connect-timeout 3 http://petclinic-postgres:5432 2>&1 | head -2
```

---

## 11. Cleanup

Destroy all provisioned infrastructure:

```bash
cd modules/Container_Migration
tofu destroy
```

Manually delete container images from Container Registry:

```bash
gcloud container images list --repository=gcr.io/$PROJECT_ID
gcloud container images delete gcr.io/$PROJECT_ID/postgres --force-delete-tags --quiet
gcloud container images delete gcr.io/$PROJECT_ID/tomcat --force-delete-tags --quiet
```

Remove any PersistentVolumes not deleted by `tofu destroy`:

```bash
kubectl get pvc -n default
kubectl delete pvc --all -n default
```

---

## 12. Reference

- [Migrate to Containers overview](https://cloud.google.com/migrate/containers/docs/getting-started)
- [m2c CLI architecture](https://cloud.google.com/migrate/containers/docs/m2c-cli/architecture)
- [m2c CLI Linux reference](https://cloud.google.com/migrate/containers/docs/m2c-cli-reference-linux)
- [Customise migration plan for Linux VMs](https://cloud.google.com/migrate/containers/docs/m2c-cli/linux/customizing-a-migration-plan)
- [Migrate data to PersistentVolumes](https://cloud.google.com/migrate/containers/docs/m2c-cli/migrate-data)
- [Spring PetClinic](https://github.com/spring-petclinic/spring-framework-petclinic)
- [Skaffold docs](https://skaffold.dev/docs/)
- [GKE docs](https://cloud.google.com/kubernetes-engine/docs)
