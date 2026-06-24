<!--
Target:   Medium (general — personal blog / large tech publications)
Audience: Broad developer audience, migration-curious or migration-intimidated, learning cloud-native modernization
Voice:    Narrative, first-person, accessible, a "I finally got it" arc
Tags:     Google Cloud, Kubernetes, GKE, Containers, Migration, Modernization, DevOps
Goal:     Tell the story of understanding VM-to-container migration by doing one; CTA to the Container_Migration module.
-->

# I Finally Understood VM-to-Container Migration by Actually Migrating One

For a couple of years, "migrate the VMs to containers" lived in my head as a task I was supposed to be able to do but had never really done. I'd read about Google's **Migrate to Containers**. I knew the words — assess, copy, analyze, generate, PersistentVolume. I could nod through a modernization planning meeting. But I had never taken a single VM-based app all the way to a running container with my own hands, and so the whole thing stayed theoretical, the way a recipe stays theoretical until you've actually burned something.

What changed it wasn't another doc page. It was migrating a small, slightly annoying app — on purpose.

## The thing I kept getting stuck on

My problem with VM-to-container migration was never the goal. Fewer VMs to patch, higher density, a path to CI/CD, all without rewriting code I didn't write — obviously good. My problem was the on-ramp. Every time I went to *try* it, I hit the same wall: I didn't have a realistic thing to migrate.

The tutorials migrate a stateless toy. But the workloads that scare you in real life aren't stateless toys. They're a database with data you can't lose, and an app server that talks to that database over the network, and the moment you containerize one you have to think about the other. I didn't want to migrate a hello-world. I wanted to migrate something with a *database attached*. And building that realistic source environment myself — two VMs, real apps, a workstation with the toolchain, a cluster to land on — was enough friction that I just... kept not doing it.

The classic move: avoid the thing because setting up to try it is half the work, then feel vaguely behind about it.

## What I actually deployed

The on-ramp that finally worked was a reference module called **Container_Migration**. One apply, and it stood up the whole awkward scenario for me:

- a **PostgreSQL 14** VM with a real seeded database,
- a **Tomcat 10** VM running **Spring PetClinic** — a genuine JVM web app, built from source by Maven at first boot, reaching across the network to that Postgres VM,
- a **workstation VM** with the `m2c` toolchain, Docker, `kubectl`, and Skaffold already installed, and
- a **multi-node GKE cluster** sitting there empty, waiting for whatever I migrated.

I pointed it at a project, ran the apply, and gave the VMs about ten minutes — they were busy installing Postgres, running a Maven build, and pulling down the migration tools. Then I did the thing I'd never done before: I opened the source app in a browser. A working little vet clinic, backed by a database, running on a VM. *This* was my "before."

That mattered more than I expected. Seeing the app actually run as a VM is what made the rest land.

## The moment it clicked

I SSH'd into the source VM and ran the assessment tool, `mcdc`. It looked at the running workload and told me — in a report, with scores — how suitable it was for containerization, across GKE, Autopilot, Cloud Run, and Compute Engine, and which ports it actually used. That was the first small click: *the tool inspects the real thing and tells you whether to bother, before you build anything.* I'd always imagined migration as "convert and hope." It's the opposite. It starts with a verdict.

Then I moved to the workstation and ran `m2c copy`. And here's where it really landed for me. The copy is an **rsync of the source VM's filesystem** — the source VM keeps running, completely untouched, the entire time. I wasn't *converting* the VM. I was taking a copy of its filesystem and transforming *that*. The original app never noticed.

`m2c analyze` turned the copied filesystem into a migration plan I could actually edit — image name, exposed ports, persistent paths. For the Postgres workload, `m2c migrate-data` took the source data directory and populated a **GKE PersistentVolumeClaim** with it. Then `m2c generate` produced the Dockerfiles, the Kubernetes manifests, and a Skaffold config. I ran `skaffold run`, and a minute later:

```bash
kubectl get pods,svc,pvc -n default
```

There it was. The same app I'd been browsing on a VM, now a pod on GKE, its database data sitting on a PersistentVolume. **And I had never once opened the application's source code.**

That was the click. *Containerizing a VM workload stopped being a rewrite and became a transformation of its filesystem and its data.* The thing I'd been intimidated by turned out to be, from my side of it, five commands and a plan I could read.

## Then I went looking, and it kept teaching

Once I'd done it the easy way, I started doing it the deliberate way — breaking things to see what the steps were really for.

I undersized the workstation disk on a second run and watched `m2c copy` fail partway through, which is exactly what the generous 200 GB default is quietly protecting you from: the copy has to *hold* the source filesystem.

I learned why the assessment step is separate from everything else — it's the gate. You're supposed to find out a workload is a bad container *before* you've migrated it, not after.

And I sat with the data migration step the longest. Moving a database's data directory onto a PersistentVolume is the part where "just containerize it" usually falls apart, and doing it by hand — rather than watching a button do it — is what taught me that the tool moves the bytes but the operational ownership of that data is still mine to design.

## The honest caveats, because they taught me too

This is an *educational* sandbox, and its edges were as instructive as its center.

The module provisions the environment but **not the migration** — every M2C step is mine to run. At first that felt like unfinished work; then I realized it *is* the work, and hiding it behind automation would have taught me nothing. The toolchain is downloaded at boot, so if a release endpoint hiccups an install can be skipped silently — I learned to run the `/install_container_tools.sh` check first instead of assuming. The cluster is zonal and the source apps are demo-grade; the data disappears on teardown, and it tells you so. And cleanup isn't total — images I pushed to the registry and any PVCs I kept outlived the destroy, which is a small, honest reminder that the artifacts have a lifecycle I own.

## What I'd tell past-me

If you've been nodding along in modernization conversations while quietly hoping nobody asks you to actually migrate something — stop reading about it and go migrate one. Not a stateless toy. Something with a database attached and an app that depends on it, because that's the case that's been scaring you, and it's the case the tooling is actually for.

Container_Migration was the version of that on-ramp where I didn't have to spend a day building a realistic source environment before I could even start. One apply gave me two real apps, a loaded toolchain, and an empty cluster. An hour later I had a VM workload running as a container on GKE, its data on a PersistentVolume, and a real understanding of how it got there.

Deploy it. Browse the app on the VM. Then watch the same app come up as a pod. That's the moment migration stops being a slide — and you don't get that moment from a diagram.

👉 **Container_Migration** is in the RAD Lab modules catalog. Start with the [module deep-dive](../../modules/Container_Migration.md) and the [hands-on lab guide](../../labs/Container_Migration.md).
