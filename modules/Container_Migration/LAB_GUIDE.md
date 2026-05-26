# Migrate to Containers — Lab Guide

## Overview

This guide walks through the full Migrate to Containers (M2C) lab using the
`Container_Migration` Terraform module. The module automates all Google Cloud
infrastructure setup. The assessment, migration, and deployment steps are performed
manually to provide hands-on experience with the M2C toolchain.

**Estimated time:** 2–3 hours (includes build and container push time)

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

---

## Prerequisites

| Requirement | Detail |
|---|---|
| OpenTofu / Terraform | >= 1.3 |
| Google Cloud SDK (`gcloud`) | Authenticated and configured |
| GCP Project | Must already exist with billing enabled |
| Service Account | Must hold `roles/owner` on the target project |

---

## Phase 1 — Deploy Infrastructure with Terraform [AUTOMATED]

### Step 1.1 — Configure Variables

Navigate to the module directory:

```bash
cd modules/Container_Migration
```

Create a `terraform.tfvars` file:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"
```

All other variables use sensible defaults. See `variables.tf` for the full list.

### Step 1.2 — Deploy

```bash
tofu init
tofu apply
```

Deployment takes approximately 10–15 minutes (GKE cluster provisioning dominates).

### Step 1.3 — Capture Outputs

After `tofu apply` completes, note the key outputs:

```bash
tofu output
```

Key values you will use throughout the lab:

| Output | Description |
|---|---|
| `postgres_vm_name` | PostgreSQL source VM instance name |
| `tomcat_vm_name` | Tomcat source VM instance name |
| `m2c_cli_vm_name` | m2c CLI VM instance name |
| `gke_cluster_name` | GKE cluster name |
| `gke_cluster_location` | GKE cluster zone |
| `petclinic_url` | URL to browse the PetClinic app |

Set shell variables for use in subsequent steps:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=$(tofu output -raw gke_cluster_location)
export POSTGRES_VM=$(tofu output -raw postgres_vm_name)
export TOMCAT_VM=$(tofu output -raw tomcat_vm_name)
export M2C_VM=$(tofu output -raw m2c_cli_vm_name)
export GKE_CLUSTER=$(tofu output -raw gke_cluster_name)
```

### Step 1.4 — Verify the PetClinic Application

Open the PetClinic URL in your browser to confirm Tomcat is running:

```bash
tofu output petclinic_url
```

You should see the Spring PetClinic application home page.

---

## Phase 2 — Assess Your Workloads for Containerisation [MANUAL]

The Migration Center discovery client CLI (`mcdc`) assesses whether a Linux VM is
suitable for containerisation. It collects runtime data from the VM and produces
an HTML report.

### Step 2.1 — Assess the PostgreSQL VM

SSH into the PostgreSQL VM:

```bash
gcloud compute ssh $POSTGRES_VM --project $PROJECT_ID --zone $ZONE_ID
```

Run the assessment script:

```bash
sudo /assess_mcdc.sh
```

Expected output:

```
Collected info saved to:
mcdc-collect-<vm-name>-<timestamp>.tar
[✓] Collection completed.
[✓] Assessment complete.
```

The script saves discovery data to `/var/m4a/`. This directory is used by Migrate
to Containers during the migration phase for automated service and port discovery.

Disconnect from the SSH session:

```bash
exit
```

### Step 2.2 — Assess the Tomcat VM

SSH into the Tomcat VM:

```bash
gcloud compute ssh $TOMCAT_VM --project $PROJECT_ID --zone $ZONE_ID
```

Run the assessment script:

```bash
sudo /assess_mcdc.sh
```

Disconnect from the SSH session:

```bash
exit
```

---

## Phase 3 — Migrate Your VMs to Containers [MANUAL]

### Step 3.1 — Prepare the GKE Environment

In Cloud Shell or your local terminal, authenticate and connect to the GKE cluster:

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

### Step 3.2 — Prepare the m2c-cli Workspace

SSH into the m2c-cli VM:

```bash
gcloud compute ssh $M2C_VM --project $PROJECT_ID --zone $ZONE_ID
```

Set environment variables:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export ZONE_ID=us-central1-a   # replace with your zone
```

Verify pre-installed tools:

```bash
/install_container_tools.sh
```

Authenticate Docker with Google Cloud:

```bash
gcloud auth configure-docker --quiet
```

Connect to the GKE cluster:

```bash
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

The filters file is used during `m2c copy` to exclude irrelevant directories and
reduce filesystem copy time.

### Step 3.3 — Migrate the PostgreSQL VM to a Container

Create a directory for PostgreSQL migration artifacts:

```bash
mkdir postgresql
cd postgresql
```

**Copy the source VM filesystem:**

```bash
m2c copy gcloud -p $PROJECT_ID -z $ZONE_ID \
  -n $POSTGRES_VM \
  -o petclinic-postgres-fs \
  --filters ~/filters.txt
```

The `m2c copy` command uses rsync over SSH to copy the VM filesystem. It may take
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
```

View the generated artifacts:

```bash
ls artifacts
```

The `artifacts/` directory contains:
- `Dockerfile` — builds the container image from the VM filesystem
- `deployment_spec.yaml` — Kubernetes StatefulSet and Service manifest
- `services-config.yaml` — enable/disable services discovered on the source VM
- `skaffold.yaml` — Skaffold configuration for build and deploy

### Step 3.4 — Migrate the Tomcat VM to a Container

Return to the workspace root and create a directory for Tomcat migration artifacts:

```bash
cd ~/m2c-petclinic
mkdir tomcat
cd tomcat
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

## Phase 4 — Deploy Migrated Workloads to GKE [MANUAL]

### Step 4.1 — Deploy the Containerised PostgreSQL

```bash
cd ~/m2c-petclinic/postgresql/artifacts
bash /postgres_deployment_fix.sh
skaffold run -d gcr.io/$PROJECT_ID
```

Skaffold builds the container image, pushes it to the registry, and deploys the
StatefulSet and Service to the GKE cluster.

Check the service status:

```bash
kubectl get service
kubectl get pods
```

Wait for `petclinic-postgres-0` to reach `Running` status before proceeding.

### Step 4.2 — Deploy the Containerised Tomcat

```bash
cd ~/m2c-petclinic/tomcat/artifacts
skaffold run -d gcr.io/$PROJECT_ID
```

This command deploys a Kubernetes Deployment with 1 pod and both a ClusterIP
service and a LoadBalancer service. External IP provisioning may take 1–2 minutes.

Check the service status:

```bash
kubectl get service
```

Once the `tomcat-petclinic-lb` service shows an external IP, open the application:

```bash
kubectl get svc tomcat-petclinic-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Browse to `http://<EXTERNAL_IP>:8080/petclinic/` to verify the migrated application
connects to the migrated PostgreSQL database.

---

## Phase 5 — Scale the Tomcat Deployment [MANUAL]

### Step 5.1 — Manual Scaling

Navigate to the Tomcat artifacts directory:

```bash
cd ~/m2c-petclinic/tomcat/artifacts
```

Edit `deployment_spec.yaml` and change `replicas: 1` to `replicas: 3` under `spec`:

```yaml
spec:
  replicas: 3
```

Apply the change:

```bash
skaffold run -d gcr.io/$PROJECT_ID
```

Verify the pods:

```bash
kubectl get pods
```

You should see three `tomcat-petclinic` pods running.

### Step 5.2 — Horizontal Pod Autoscaler

Configure automatic scaling based on CPU usage:

```bash
kubectl autoscale deployment tomcat-petclinic --cpu-percent=50 --min=2 --max=8
```

This configures GKE to scale the deployment from 2 to 8 pods when CPU usage
exceeds 50%.

Verify the HPA:

```bash
kubectl get hpa
```

---

## Phase 6 — Rolling Update Strategy [MANUAL]

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

## Cleanup

To destroy all module-managed resources:

```bash
cd modules/Container_Migration
tofu destroy
```

This removes all GCE VMs, the GKE cluster, VPC, and firewall rules.

**Manual cleanup required:**
- Container images in `gcr.io/$PROJECT_ID` — delete via Console or `gcloud container images delete`
- Kubernetes PVCs created by `m2c migrate-data` (if cluster is retained)

---

## Troubleshooting

| Issue | Resolution |
|---|---|
| Startup script still running | Check `/var/log/startup-script.log` on the VM |
| `m2c copy` SSH key error | Ensure `gcloud` has OS Login or project SSH keys configured |
| Tomcat not reachable on port 8080 | Verify the `allow-tomcat` firewall rule targets the `tomcat` network tag |
| PetClinic shows DB error | Confirm `petclinic-postgres` service is running in GKE: `kubectl get svc` |
| `skaffold run` fails on image push | Run `gcloud auth configure-docker` on the m2c-cli VM |
| GKE node not ready | Check node pool status: `kubectl get nodes` |

---

## Reference

- [Migrate to Containers documentation](https://cloud.google.com/migrate/containers/docs)
- [m2c CLI reference](https://cloud.google.com/migrate/containers/docs/m2c-cli-reference)
- [Spring PetClinic](https://github.com/spring-petclinic/spring-framework-petclinic)
- [Skaffold documentation](https://skaffold.dev/docs/)
- [GKE documentation](https://cloud.google.com/kubernetes-engine/docs)
