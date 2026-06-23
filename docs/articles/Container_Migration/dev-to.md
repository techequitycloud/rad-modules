<!--
Target:   Dev.to
Audience: Developers and platform engineers who own VM fleets and want to try VM-to-container modernization hands-on
Voice:    Hands-on, conversational, practical, show-don't-tell, real commands
Tags:     #googlecloud #gke #containers #migration #devops
Goal:     Show that practicing VM-to-container migration end-to-end is approachable in a sandbox; CTA to deploy the Container_Migration RAD module.
-->

# Practice VM-to-Container Migration for Real — Two Live Apps, Google's M2C Toolchain, and a GKE Cluster Waiting for Them

"Migrate your VMs to containers" is one of those phrases that sounds like a slide and feels like a quarter of work. There's a tool for it — Google Cloud **Migrate to Containers (M2C)** — but reading the docs for `mcdc` and `m2c` only gets you so far. What you actually want is a couple of real VMs running real apps, a workstation with the toolchain already on it, and a cluster to land the result on, so you can *do* the migration instead of theorizing about it.

That's exactly what the **Container_Migration** RAD module stands up. One apply, and you get a self-contained sandbox to take a VM-based Linux workload all the way to a running container on GKE — **without touching the application source code**. Let's look at what lands and how you drive it.

## What you get

The module is standalone — it builds its own VPC, VMs, workstation, and target cluster. On apply:

- **A PostgreSQL 14 source VM** (Ubuntu 22.04, tagged `postgres`) with a pre-seeded `petclinic` database. A real, stateful workload.
- **A Tomcat 10 source VM** (Ubuntu 22.04, tagged `tomcat`) running the **Spring PetClinic** app — built from source by Maven at first boot, served on port 8080, talking to the Postgres VM over the internal network. You can browse it *before* you migrate anything.
- **An M2C CLI workstation VM** (`e2-standard-4`, 200 GB disk by default) preloaded with the `m2c` CLI, Docker, `kubectl`, Skaffold, and the GKE auth plugin.
- **A zonal, standard GKE cluster** — 3 `e2-medium` nodes by default — ready to receive the migrated containers.
- **A VPC + firewall rules**: allow-internal (so the workstation can copy source filesystems), SSH, ICMP, and a Tomcat rule on 8080 so PetClinic is browsable.

Everything shares a `mig-<id>-` prefix, e.g. `mig-8b56-postgres`, `mig-8b56-tomcat`, `mig-8b56-m2c`, `mig-8b56-gke-cluster`, `mig-8b56-vpc`.

The key thing: **the module provisions the environment, not the migration.** You do the migration by hand on the workstation. That's the whole point — this is a place to practice the M2C lifecycle, not a button that does it for you.

## Deploying it

From the RAD Lab catalog, non-interactively via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m Container_Migration -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/Container_Migration
tofu init
tofu apply -var="project_id=my-gcp-project"
```

**Heads-up: give the VMs 5–10 minutes after apply finishes.** The startup scripts do real work — PostgreSQL setup and seeding, a Maven build of PetClinic, and downloading the `mcdc`/`m2c`/`kubectl`/Skaffold toolchain from public release endpoints. The Terraform apply returning is *not* the same as the tools being ready. Check before you start:

```bash
gcloud compute ssh <vm-name> --project "$PROJECT" --zone "$ZONE" \
  --command 'tail -5 /var/log/startup-script.log'
```

## Sanity-check it before migrating

Confirm PetClinic is actually up — the `petclinic_url` output gives you the full URL (the Tomcat VM's external IP on `:8080`):

```bash
terraform output petclinic_url
# open it in a browser — you should get a working vet clinic app backed by Postgres
```

Seeing the source app run first is worth the two minutes. It's what makes the "I didn't change the code and it still works in a container" payoff land later.

## The migration lifecycle, by hand

This is the part you came for. SSH to the workstation and the source VMs and walk the M2C flow. Two CLIs do the work: **`mcdc`** runs on each source VM to assess containerization suitability; **`m2c`** runs on the workstation to copy, analyze, migrate data, and generate artifacts.

**1. Assess each source VM with `mcdc`.** The module drops an `/assess_mcdc.sh` helper on the Postgres and Tomcat VMs. It produces a suitability report scoring the workload across GKE, GKE Autopilot, Cloud Run, and Compute Engine journeys, and tells you which ports the workload uses.

```bash
gcloud compute ssh <tomcat-vm> --project "$PROJECT" --zone "$ZONE"
sudo /assess_mcdc.sh
```

**2. Verify the toolchain on the workstation**, then copy a source filesystem. `m2c copy` uses rsync over SSH — the source VM keeps running and is never modified.

```bash
gcloud compute ssh <m2c-cli-vm> --project "$PROJECT" --zone "$ZONE"
sudo /install_container_tools.sh        # checks m2c, kubectl, skaffold, docker, auth plugin
m2c version

m2c copy gcloud -p "$PROJECT" -z "$ZONE" -n <source-vm> -o <out-dir> --filters ~/filters.txt
```

**3. Analyze the copy into a migration plan**, then customize it (image name, exposed endpoints, persistent-volume paths):

```bash
m2c analyze -s <copied-fs> -p linux-vm-container -o ./migration
```

**4. Migrate the stateful data.** For Postgres, `m2c migrate-data` creates and populates a GKE PersistentVolumeClaim from the source data directory:

```bash
m2c migrate-data -i migration -n default
```

**5. Generate the artifacts** — Dockerfiles, Kubernetes manifests, and a Skaffold config:

```bash
m2c generate -i ./migration -o ./artifacts
```

**6. Deploy to GKE with Skaffold**, then operate it with plain Kubernetes:

```bash
gcloud container clusters get-credentials <cluster-name> --zone "$ZONE" --project "$PROJECT"
skaffold run
kubectl get pods,svc,pvc -n default     # migrated workloads land in the default namespace
```

That's a VM-based app now running as a container on GKE, with its data on a PersistentVolume, and you never opened the application's source.

## Things worth knowing before you rely on it

This is an **educational/demo** environment, not a production migration pipeline. The honest edges:

- **The module does the infra; you do the migration.** Nothing is orchestrated for you — `copy`, `analyze`, `migrate-data`, `generate`, and `skaffold run` are all manual. That's intentional, but it means budget time to actually drive it.
- **The toolchain is fetched at boot.** If a public release endpoint is briefly unavailable, an install step can be skipped *silently*. Always run `/install_container_tools.sh` before starting — don't assume.
- **Don't undersize the workstation disk.** `m2c_disk_size_gb` defaults to 200 GB for a reason: it has to hold copies of the source filesystems plus working space. Too small and `m2c copy` fails partway through.
- **The GKE cluster is zonal.** It's created in your configured `zone` with one node pool — there's no regional option in this module. Keep `zone` inside `region`.
- **SSH (22) and Tomcat (8080) are open to `0.0.0.0/0`** by default. Fine for a short-lived lab; tighten the source ranges in shared or long-lived projects.
- **Cleanup isn't total.** Destroy removes the VMs, cluster, firewall rules, and VPC. It does *not* delete container images you pushed to Artifact/Container Registry during the lab — remove those by hand or keep paying for the storage. PVCs go when the cluster does.
- **Expect a transient DB error right after deploy.** PetClinic self-heals its database connection once Postgres finishes initializing, so a connection error in the first moments is expected, not broken.

## Why deploy it

If "replatform VMs to containers" has been an abstract line item, this is the fastest way to make it concrete. You get two genuinely real workloads — one stateful database, one JVM web app reaching across the network to it — and you run the actual Google tooling end to end: assess, copy, analyze, migrate data, generate, deploy. The hard part (a realistic source environment plus a target cluster, all wired together) is done, so you can spend your time learning what M2C actually does to a workload.

Deploy it, browse PetClinic on the source VM, then watch the same app come up as a pod on GKE with its Postgres data on a PV. That's the moment VM-to-container modernization stops being a slide.

👉 **Container_Migration** lives in the RAD Lab modules catalog. Grab it and explore the [module deep-dive](../../modules/Container_Migration.md) and the [hands-on lab guide](../../labs/Container_Migration.md).
