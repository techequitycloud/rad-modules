# Migrate to Containers on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Container_Migration)**

## Overview

**Estimated time:** 90–150 minutes

**Migrate to Containers (M2C)** is the Google Cloud path for replatforming VM-based Linux
workloads to containers on Google Kubernetes Engine without modifying application source code.
This lab takes you through the full lifecycle of the **Migrate to Containers on GKE** module:
deploy the environment, access and verify it, run an actual migration day-to-day, observe the
results, diagnose common problems, and tear it down.

The module is a **standalone migration sandbox**. It provisions two source VMs running real
applications (a PostgreSQL 14 database and an Apache Tomcat 10 server hosting the Spring
PetClinic app), a migration workstation VM pre-loaded with the M2C toolchain, and a GKE cluster
ready to receive migrated workloads. The migration itself is performed by you, by hand, on the
workstation VM.

This lab focuses on operating the **module and the Google Cloud platform**. For the complete
list of provisioned services and every configuration input (organised by group), see the
[Configuration Guide](https://docs.radmodules.dev/docs/modules/Container_Migration) — this lab
deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the migration environment from the RAD platform and locate the resources it provisions.
- Connect to the source VMs, the workstation, and the GKE cluster, and confirm the tooling is ready.
- Run a migration end-to-end: assess a VM, copy and analyse it, migrate data, generate manifests, and deploy to GKE.
- Observe the source workloads and migrated containers with Cloud Logging and Cloud Monitoring.
- Diagnose and resolve the most common migration and deployment issues.
- Tear the environment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled**.
- **gcloud CLI** and **kubectl** installed; `gcloud auth login` and
  `gcloud auth application-default login` completed.
- **Project Owner** (or equivalent) IAM on the project.
- **RAD platform access** with permission to deploy modules into the project.

Set these shell variables once; the tasks below reuse them:

```bash
export PROJECT="<your-gcp-project-id>"
export REGION="us-central1"           # the region you deploy into
export ZONE="us-central1-a"           # must lie within REGION
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **Migrate to Containers (GKE)**
   from the **Platform Modules** list to start configuration, set `project_id`, and review the
   inputs. Configure only what you need — the
   [Configuration Guide](https://docs.radmodules.dev/docs/modules/Container_Migration)
   documents every input by group, with defaults. Review the estimated cost (if credits are
   enabled) and click **Deploy**, which opens the deployment status page with real-time logs.

2. The platform creates the VPC and firewall rules, the two source VMs (PostgreSQL and
   Tomcat/PetClinic), the migration workstation VM, and the GKE cluster. Each VM then runs a
   first-boot startup script that installs and configures its software (PostgreSQL setup, a
   Maven build of PetClinic, and downloading the migration toolchain). First deploys take
   roughly **15–25 minutes**, after which allow a further **5–10 minutes** for the VM startup
   scripts to finish.

3. Capture the key resource names from the deployment **Outputs** (shown on the deployment
   details page): `postgres_vm_name`, `tomcat_vm_name`, `m2c_cli_vm_name`,
   `gke_cluster_name`, and `petclinic_url`.

---

## Task 2 — Access & verify [Manual]

1. Confirm all three VMs exist and are running:

   ```bash
   gcloud compute instances list --project "$PROJECT" --filter="name~mig-"
   ```

2. Confirm the source application works **before** migrating anything — open the
   `petclinic_url` from the Outputs in a browser (the Tomcat VM's external IP on port 8080).
   The Spring PetClinic app should load and read from the PostgreSQL VM.

3. SSH into the workstation VM and verify the migration toolchain is installed:

   ```bash
   M2C_VM=$(gcloud compute instances list --project "$PROJECT" \
     --filter="name~mig- AND name~m2c" --format="value(name)" --limit=1)
   gcloud compute ssh "$M2C_VM" --project "$PROJECT" --zone "$ZONE" \
     --command 'sudo /install_container_tools.sh'
   ```

   Every line should report `[✓]` for `m2c`, `kubectl`, `skaffold`, `gke-gcloud-auth-plugin`,
   and Docker. If any shows `[✗]`, wait two minutes (the startup script may still be running)
   and re-run.

4. Confirm the GKE cluster is ready to receive workloads:

   ```bash
   CLUSTER=$(gcloud container clusters list --project "$PROJECT" --format="value(name)" --limit=1)
   gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE" --project "$PROJECT"
   kubectl get nodes
   ```

---

## Task 3 — Operate: run a migration (Day-2) [Manual]

This is the core of the lab — performed by hand on the workstation VM. The steps below are
the migration **workflow**; the exact command flags and manifest edits are in the
[Configuration Guide](https://docs.radmodules.dev/docs/modules/Container_Migration) and the
Migrate to Containers documentation. SSH into the workstation VM for all of these steps:

```bash
gcloud compute ssh "$M2C_VM" --project "$PROJECT" --zone "$ZONE"
```

1. **Assess** each source VM. Run the supplied helper on the PostgreSQL and Tomcat VMs to
   collect system data with `mcdc` and produce a containerisation suitability report. Note the
   ports each workload uses (PostgreSQL 5432, Tomcat 8080) — you will declare them as container
   endpoints later.

2. **Copy** a source VM's filesystem to the workstation with `m2c copy`. This uses rsync over
   SSH; the source VM keeps running and is never modified. The workstation's `filters.txt`
   excludes ephemeral paths (`/proc`, `/sys`, `/dev`, logs) from the copy.

3. **Analyse** the copy with `m2c analyze` to produce a migration plan, then customise it: set a
   meaningful container image name, declare the service endpoint(s), and (for the stateful
   PostgreSQL workload) confirm the data-directory path that will become a PersistentVolume.

4. **Migrate data** for the stateful PostgreSQL workload with `m2c migrate-data`, which creates
   and populates a GKE PersistentVolumeClaim. Confirm it reaches `Bound`:

   ```bash
   kubectl get pvc -n default
   ```

5. **Generate** the Dockerfile, Kubernetes manifests, and Skaffold config with `m2c generate`.
   The PostgreSQL workload generates a StatefulSet; the stateless Tomcat workload generates a
   Deployment with a LoadBalancer Service.

6. **Deploy** each workload to GKE with `skaffold run`, deploying PostgreSQL first so the
   database is available before PetClinic starts. Then browse the migrated PetClinic via the
   Tomcat Service's external IP:

   ```bash
   kubectl get pods,svc,pvc -n default
   ```

7. **Day-2 operations.** Once migrated, the workloads are managed with native Kubernetes —
   scale the Tomcat Deployment, attach a Horizontal Pod Autoscaler, and configure a rolling
   update strategy, all against the GKE cluster.

---

## Task 4 — Observe: Logging & Monitoring [Manual]

1. **Source VM startup** — confirm each VM's first-boot script completed:

   ```bash
   for VM in $(gcloud compute instances list --project "$PROJECT" \
     --filter="name~mig-" --format="value(name)"); do
     echo "== $VM =="
     gcloud compute ssh "$VM" --project "$PROJECT" --zone "$ZONE" \
       --command 'tail -3 /var/log/startup-script.log'
   done
   ```

2. **Migrated workloads** — view pod logs and events from the GKE cluster:

   ```bash
   kubectl get pods -n default
   kubectl logs <pod-name> -n default --tail=50
   ```

3. **Cloud Monitoring** — open the Compute Engine and GKE / Kubernetes dashboards to review VM
   and node CPU/memory utilisation, and the migrated workloads' restart counts and request
   metrics. Logs are also available in **Logging → Logs Explorer**.

---

## Task 5 — Troubleshoot & debug [Manual]

Durable techniques for the failure modes you are most likely to hit:

- **Toolchain shows `[✗]`:** the startup script fetches `m2c`/`kubectl`/Skaffold from public
  endpoints at boot. Wait a couple of minutes and re-run `/install_container_tools.sh`; check
  `/var/log/startup-script.log` on the workstation VM for the failed download.
- **`m2c copy` fails (SSH/rsync error):** confirm the workstation and source VMs are in the same
  VPC, the allow-internal firewall rule exists, and the source VM is running
  (`gcloud compute instances list --filter="status=RUNNING"`).
- **PVC stuck in `Pending` after data migration:** check `kubectl get storageclass` and
  `kubectl describe pvc -n default` for the cause (often a missing default StorageClass).
- **Migrated pod in `CrashLoopBackOff`:** inspect logs and events, and for PostgreSQL confirm
  the PVC holds the expected data directory:
  ```bash
  kubectl logs <pod> -n default --previous
  kubectl describe pod <pod> -n default
  ```
- **PetClinic cannot reach PostgreSQL:** verify the PostgreSQL Service exists in the cluster and
  the app's database hostname matches it.
- **Skaffold Docker auth error:** re-run `gcloud auth configure-docker` on the workstation VM.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**).
Delete runs `terraform destroy` and is irreversible (the deployment record is retained for
history). This removes everything the module created — the two source VMs, the migration
workstation VM, the GKE cluster and node pool, the firewall rules, and the VPC.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual
changes that conflict with the Terraform state), use **Purge** instead — it removes the
deployment from RAD's records **without** destroying the cloud resources (it makes RAD forget
the project).

Two things are **not** removed automatically and should be cleaned up by hand if you no longer
need them: any container images you pushed to Artifact Registry / Container Registry during the
lab, and any PersistentVolumeClaims (these go away when the cluster is destroyed, but must be
deleted manually if you keep the cluster).

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module provisions the VPC, two source VMs, the migration workstation, and the GKE cluster |
| 2 — Access & verify | Manual | Source PetClinic app loads; workstation toolchain reports `[✓]`; GKE cluster reachable |
| 3 — Operate | Manual | Run a migration: assess, copy, analyse, migrate data, generate manifests, deploy to GKE |
| 4 — Observe | Manual | Confirm VM startup; review migrated-workload logs and Cloud Monitoring metrics |
| 5 — Troubleshoot | Manual | Diagnose toolchain, copy, PVC, pod, connectivity, and Skaffold-auth issues |
| 6 — Tear down | Automated | Delete (Trash) removes all module resources; clean up lab-built images/PVCs by hand |
