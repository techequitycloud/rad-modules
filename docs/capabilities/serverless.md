# Serverless

Serverless coverage is concentrated in two places: a Cloud Run + Cloud Service Mesh lab, and the Cloud Build pipelines that deliver every module.

## Cloud Run on Cloud Service Mesh

`scripts/gcp-cr-mesh/gcp-cr-mesh.sh` is an interactive lab automating the steps from <https://cloud.google.com/service-mesh/docs/configure-cloud-service-mesh-for-cloud-run>: enabling APIs (`run`, `dns`, `networkservices`, `networksecurity`, `trafficdirector`), creating the `Mesh` resource, deploying a Cloud Run destination service with `--no-allow-unauthenticated`, fronting it with a serverless NEG + global `INTERNAL_SELF_MANAGED` backend service + `HTTPRoute`, and invoking it from a mesh-enrolled `fortio` Cloud Run client.

The same Cloud Service Mesh that backs `modules/Bank_GKE/` and `modules/MC_Bank_GKE/` extends to Cloud Run via the serverless NEG. See [service-mesh](./service-mesh.md).

The script supports **preview / create / delete** modes, so the same flow tears down all the serverless resources at the end without manual cleanup.

## Serverless build & delivery

`rad-ui/automation/cloudbuild_deployment_{create,destroy,purge,update}.yaml` are Cloud Build pipelines — Google's serverless CI/CD platform. There are no self-hosted build runners; every module deployment runs in an ephemeral, fully managed builder. See [cicd](../practices/cicd.md).

## Container image registry

Node pool service accounts are granted `roles/artifactregistry.reader` (`gke.tf` in all three GKE modules), and `artifactregistry.googleapis.com` is enabled in `main.tf`. Artifact Registry is the intended image registry for any workloads built as part of this platform — a natural starting point for storing container images produced by Cloud Run or Cloud Build steps.

## What is not here — and what to add next

The following serverless primitives are not currently covered by any module or script. Each is a natural candidate for a new `scripts/` entry:

| Missing primitive | Natural addition |
|---|---|
| Cloud Functions (gen2) | HTTP-triggered or event-driven function lab in `scripts/` |
| Eventarc triggers | Pairing a Cloud Function or Cloud Run service to a GCS / Pub/Sub event |
| Pub/Sub processing pipelines | Fan-out / fan-in messaging patterns between Cloud Run services |
| Workflows orchestrations | Multi-step serverless orchestration alongside existing Cloud Run services |
| Cloud Run Jobs | Batch / one-shot serverless compute (e.g., post-deploy validation step) |

Adding any of these follows the same `scripts/<name>/<name>.sh` pattern with **preview / create / delete** modes already established by `gcp-cr-mesh` and `gcp-m2c-vm`.
