# Serverless

The repository's serverless coverage is concentrated in two places: a Cloud Run + Cloud Service Mesh lab, and the Cloud Build pipelines that deliver every module without any operator-managed runners.

## Cloud Run on Cloud Service Mesh

`scripts/gcp-cr-mesh/gcp-cr-mesh.sh` is an interactive lab that automates the steps from <https://cloud.google.com/service-mesh/docs/configure-cloud-service-mesh-for-cloud-run> to put a Cloud Run service behind Cloud Service Mesh. The seven menu options are (`scripts/gcp-cr-mesh/README.md`):

1. **Enable APIs** — `run`, `dns`, `networkservices`, `networksecurity`, `trafficdirector`.
2. **Configure IAM Policies** — grants the caller `roles/run.developer` and the project's compute SA `roles/trafficdirector.client`, `roles/cloudtrace.agent`, `roles/run.admin`.
3. **Configure Service Mesh** — writes `mesh.yaml` (`name: $MESH_NAME`) and imports it via `gcloud network-services meshes import`.
4. **Deploy Destination Service** — `gcloud run deploy` with `--no-allow-unauthenticated` and grants `roles/run.invoker` to the caller's compute SA.
5. **Configure Destination Service Mesh Networking** — creates a serverless NEG pointing at the Cloud Run service, a global `INTERNAL_SELF_MANAGED` backend service, attaches the NEG, and imports an `HTTPRoute` bound to the mesh on the service's `*.run.app` host.
6. **Deploy Client Service in Service Mesh** — `gcloud run deploy fortio` attached to the mesh via `--mesh="projects/$GCP_PROJECT/locations/global/meshes/$MESH_NAME"`.
7. **Invoke Destination Service from Client Service** — calls `$TEST_SERVICE_URL/fortio/fetch/<destination-host>` with an identity token to prove traffic is routed through the mesh.

The script supports **preview / create / delete** modes, so the same flow tears down all the serverless resources at the end without manual cleanup.

## Why serverless + mesh matters

This lab is the bridge between the Kubernetes-based modules in this repo and a fully managed serverless target. It demonstrates that the same Cloud Service Mesh used by `modules/Bank_GKE/asm.tf` and `modules/MC_Bank_GKE/asm.tf` can extend to Cloud Run via a serverless NEG — so a workload running on Cloud Run can participate in the same mesh policy, observability, and identity model as the GKE workloads.

## Serverless build & delivery

`rad-ui/automation/cloudbuild_deployment_{create,destroy,purge,update}.yaml` are Cloud Build pipelines — Google's serverless CI/CD platform. There are no self-hosted build runners; every module deployment runs in an ephemeral, fully managed builder. The pipelines:

- Pull module source from a Git repo on demand.
- Restore an OpenTofu provider cache from GCS for fast `init`.
- Run `tofu apply` / `destroy` / purge with the same `_DEPLOYMENT_BUCKET_ID` substitution.

This is the operational definition of "serverless infrastructure delivery": the platform that *deploys* infrastructure has no infrastructure of its own.

## What is *not* here

The repository does not currently include native Cloud Functions modules, Eventarc triggers, Pub/Sub processing pipelines, or Workflows orchestrations. The serverless story today is focused on Cloud Run + mesh. These would be natural additions to the `scripts/` catalog or as new entries under `modules/`.
