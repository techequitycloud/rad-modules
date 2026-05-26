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

### What Terraform Automates

- Enabling required GCP APIs
- Creating the VPC network and firewall rules
- Deploying the PostgreSQL source VM (Ubuntu 22.04, PostgreSQL 14 pre-installed)
- Deploying the Tomcat source VM (Ubuntu 22.04, Tomcat 10 + PetClinic WAR pre-deployed)
- Deploying the m2c-cli VM (Ubuntu 22.04, m2c CLI + Docker + kubectl + Skaffold pre-installed)
- Creating the GKE cluster and node pool

### What You Do Manually

- Assess source VMs using the `mcdc` CLI
- Copy VM filesystems using `m2c copy`
- Analyse filesystems and customise migration plans
- Migrate PostgreSQL data to a GKE PersistentVolume
- Generate Kubernetes deployment artifacts
- Deploy migrated containers to GKE using Skaffold
- Scale and configure rolling updates for the Tomcat deployment

**Estimated time:** 2–3 hours (includes build and container push time)

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GCP Project                           │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │  petclinic-  │  │   tomcat-    │  │   m2c-cli     │ │
│  │  postgres VM │  │ petclinic VM │  │      VM       │ │
│  │ PostgreSQL14 │  │  Tomcat 10   │  │ m2c + Docker  │ │
│  │              │  │  PetClinic   │  │ kubectl+skaf. │ │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘ │
│         │ m2c copy        │ m2c copy          │         │
│         └─────────────────┴───────────────────┘         │
│                           │ skaffold run                 │
│                    ┌──────▼───────┐                      │
│                    │  GKE Cluster │                      │
│                    │  m2c-guide   │                      │
│                    │  3x e2-med   │                      │
│                    └─────────────┘                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │           Auto-mode VPC + Firewall Rules          │   │
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
```

Create a `terraform.tfvars` file with your project settings:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"
```

All other variables use sensible defaults. See `variables.tf` for the full list.

```bash
tofu init && tofu apply
```

Deployment takes approximately 10–15 minutes (GKE cluster provisioning dominates).

After `tofu apply` completes, review the key outputs:

```bash
tofu output
```

| Output | Description |
|---|---|
| `postgres_vm_name` | PostgreSQL source VM instance name |
| `tomcat_vm_name` | Tomcat source VM instance name |
| `m2c_cli_vm_name` | m2c CLI VM instance name |
| `gke_cluster_name` | GKE cluster name |
| `gke_cluster_location` | GKE cluster zone |
| `petclinic_url` | URL to browse the PetClinic app |

Capture the VM and cluster names from outputs:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=$(tofu output -raw gke_cluster_location)
export POSTGRES_VM=$(tofu output -raw postgres_vm_name)
export TOMCAT_VM=$(tofu output -raw tomcat_vm_name)
export M2C_VM=$(tofu output -raw m2c_cli_vm_name)
export GKE_CLUSTER=$(tofu output -raw gke_cluster_name)
```

Verify the PetClinic application is running on the source Tomcat VM:

```bash
tofu output petclinic_url
```

Open the URL in your browser — you should see the Spring PetClinic application home page.

---

## Exercise 1 — Assess Workloads for Containerisation

The Migration Center discovery client CLI (`mcdc`) assesses whether a Linux VM is
suitable for containerisation. It collects runtime data from the VM and produces
an HTML report. The assessment script saves discovery data to `/var/m4a/`, which
is used by Migrate to Containers during the migration phase for automated service
and port discovery.

Before assessing, authenticate and connect to the GKE cluster from Cloud Shell or
your local terminal:

```bash
gcloud auth login
gcloud container clusters get-credentials $GKE_CLUSTER \
  --zone=$ZONE_ID --project=$PROJECT_ID
```

Verify the cluster is reachable:

```bash
gcloud container clusters list
kubectl get nodes
```

**PostgreSQL VM:**

```bash
gcloud compute ssh $POSTGRES_VM --project $PROJECT_ID --zone $ZONE_ID
sudo /assess_mcdc.sh
exit
```

Expected output:

```
Collected info saved to:
mcdc-collect-<vm-name>-<timestamp>.tar
[✓] Collection completed.
[✓] Assessment complete.
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

**Prepare the m2c-cli workspace:**

```bash
gcloud compute ssh $M2C_VM --project $PROJECT_ID --zone $ZONE_ID
```

Inside the VM, set environment variables and verify pre-installed tools:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=us-central1-a   # replace with your zone
/install_container_tools.sh
```

Authenticate Docker and connect to the GKE cluster:

```bash
gcloud auth configure-docker --quiet
gcloud container clusters get-credentials $GKE_CLUSTER \
  --zone=$ZONE_ID --project=$PROJECT_ID
```

Create the workspace directory and filters file:

```bash
mkdir -p ~/m2c-petclinic
cd ~/m2c-petclinic

cat > ~/filters.txt << EOF
- /proc/*
- /boot/*
- /sys/*
- /dev/*
- /home/*
- /snap/*
- /var/cache/*
- /var/backups/*
- /var/log/*
EOF
```

The filters file excludes irrelevant directories from the filesystem copy to reduce
migration time.

**Copy the source VM filesystem:**

```bash
mkdir postgresql && cd postgresql
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID \
  -n $POSTGRES_VM \
  -o petclinic-postgres-fs \
  --filters ~/filters.txt
```

The `m2c copy` command uses rsync over SSH to copy the VM filesystem. This may take
several minutes depending on disk usage.

**Analyse the filesystem and generate a migration plan:**

```bash
m2c analyze -s petclinic-postgres-fs -p linux-vm-container -o ./migration
```

Review the generated migration plan:

```bash
cat migration/config.yaml
```

**Customise the migration plan:**

Rename the migration from the default `linux-system` to `petclinic-postgres`:

```bash
sed -i 's/linux-system/petclinic-postgres/g' migration/config.yaml
```

Add a Kubernetes service endpoint to expose PostgreSQL port 5432:

```bash
cat >> ./migration/config.yaml << EOF
endpoints:
- name: petclinic-postgres
  port: 5432
  protocol: TCP
EOF
```

**Configure a PersistentVolume for the database data directory:**

```bash
cat > ./migration/dataConfig.yaml << 'EOF'
volumes:
- deploymentPvcName: petclinic-db-pvc
  folders:
  - /var/lib/postgresql/14/main
  newPvc:
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10G
EOF
```

**Migrate the data into a PersistentVolume:**

```bash
m2c migrate-data -i migration -n default
```

This command creates a PVC in the GKE cluster and copies the PostgreSQL data
directory into it.

**Generate Kubernetes artifacts:**

```bash
m2c generate -i ./migration -o ./artifacts
ls artifacts
```

The `artifacts/` directory contains:
- `Dockerfile` — builds the container image from the VM filesystem
- `deployment_spec.yaml` — Kubernetes StatefulSet and Service manifest
- `services-config.yaml` — enable/disable services discovered on the source VM
- `skaffold.yaml` — Skaffold configuration for build and deploy

---

## Exercise 3 — Migrate the Tomcat VM to a Container

Return to the workspace root and create a directory for Tomcat migration artifacts:

```bash
cd ~/m2c-petclinic
mkdir tomcat && cd tomcat
```

**Copy the source VM filesystem:**

```bash
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID \
  -n $TOMCAT_VM \
  -o tomcat-petclinic-fs \
  --filters ~/filters.txt
```

**Analyse and generate a migration plan:**

```bash
m2c analyze -s tomcat-petclinic-fs -p linux-vm-container -o ./migration
```

**Customise the migration plan:**

```bash
sed -i 's/linux-system/tomcat-petclinic/g' migration/config.yaml

cat >> ./migration/config.yaml << 'EOF'
endpoints:
- name: tomcat-petclinic
  port: 8080
  protocol: TCP
EOF
```

**Generate Kubernetes artifacts:**

```bash
m2c generate -i ./migration -o ./artifacts
```

**Add a LoadBalancer service for external access:**

```bash
cd ~/m2c-petclinic/tomcat/artifacts

cat >> deployment_spec.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  name: tomcat-petclinic-lb
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  type: LoadBalancer
  selector:
    app: tomcat-petclinic
status:
  loadBalancer: {}
EOF
```

---

## Exercise 4 — Deploy Migrated Containers to GKE

**Deploy the containerised PostgreSQL:**

```bash
cd ~/m2c-petclinic/postgresql/artifacts
bash /postgres_deployment_fix.sh
skaffold run -d gcr.io/$PROJECT_ID
```

Skaffold builds the container image, pushes it to the registry, and deploys the
StatefulSet and Service to the GKE cluster.

Check the service and pod status:

```bash
kubectl get service
kubectl get pods
```

Wait for `petclinic-postgres-0` to reach `Running` status before proceeding.

**Deploy the containerised Tomcat:**

```bash
cd ~/m2c-petclinic/tomcat/artifacts
skaffold run -d gcr.io/$PROJECT_ID
```

This deploys a Kubernetes Deployment with 1 pod and both a ClusterIP service and
a LoadBalancer service. External IP provisioning may take 1–2 minutes.

Check the service status:

```bash
kubectl get service
```

Once the `tomcat-petclinic-lb` service shows an external IP, retrieve it:

```bash
kubectl get svc tomcat-petclinic-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Browse to `http://<EXTERNAL_IP>:8080/petclinic/` to verify the migrated application
connects to the migrated PostgreSQL database.

---

## Exercise 5 — Scale and Update the Tomcat Deployment

Navigate to the Tomcat artifacts directory:

```bash
cd ~/m2c-petclinic/tomcat/artifacts
```

**Manual scale to 3 replicas:**

Edit `deployment_spec.yaml` and change `replicas: 1` to `replicas: 3` under `spec`:

```yaml
spec:
  replicas: 3
```

Apply the change:

```bash
skaffold run -d gcr.io/$PROJECT_ID
kubectl get pods
```

You should see three `tomcat-petclinic` pods running.

**Horizontal Pod Autoscaler:**

Configure automatic scaling based on CPU usage:

```bash
kubectl autoscale deployment tomcat-petclinic --cpu-percent=50 --min=2 --max=8
kubectl get hpa
```

This configures GKE to scale the deployment from 2 to 8 pods when CPU usage
exceeds 50%.

**Rolling update strategy:**

Edit `deployment_spec.yaml` to add a rolling update strategy and reset replicas to 1:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  replicas: 1
```

Apply the change:

```bash
skaffold run -d gcr.io/$PROJECT_ID
```

Monitor the rollout:

```bash
watch kubectl get pods
```

The rolling update strategy ensures that at most 1 pod is unavailable at any time
during updates, with up to 2 additional pods created to maintain availability.

---

## 10. Cleanup

```bash
cd modules/Container_Migration
tofu destroy
```

This removes all GCE VMs, the GKE cluster, VPC, and firewall rules.

**Manual cleanup required:**
- Container images in `gcr.io/$PROJECT_ID` — delete via Console or `gcloud container images delete`
- Kubernetes PVCs created by `m2c migrate-data` (if cluster is retained)

---

## 11. Troubleshooting

| Issue | Resolution |
|---|---|
| Startup script still running | Check `/var/log/startup-script.log` on the VM |
| `m2c copy` SSH key error | Ensure `gcloud` has OS Login or project SSH keys configured |
| Tomcat not reachable on port 8080 | Verify the `allow-tomcat` firewall rule targets the `tomcat` network tag |
| PetClinic shows DB error | Confirm `petclinic-postgres` service is running in GKE: `kubectl get svc` |
| `skaffold run` fails on image push | Run `gcloud auth configure-docker` on the m2c-cli VM |
| GKE node not ready | Check node pool status: `kubectl get nodes` |

---

## 12. Reference

- [Migrate to Containers docs](https://cloud.google.com/migrate/containers/docs)
- [m2c CLI reference](https://cloud.google.com/migrate/containers/docs/m2c-cli-reference)
- [Spring PetClinic](https://github.com/spring-petclinic/spring-framework-petclinic)
- [Skaffold docs](https://skaffold.dev/docs/)
- [GKE docs](https://cloud.google.com/kubernetes-engine/docs)
